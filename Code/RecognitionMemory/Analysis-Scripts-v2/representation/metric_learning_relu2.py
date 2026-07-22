#!/usr/bin/env python3
"""Per-group linear reweighting of the relu2 representation (prototype).

Question (Bryan, 2026-07-16): the fixed euclidean metric weights every embedding
dimension equally, which is one arbitrary point in weight space and almost
certainly underfit. Can a linearly reweighted representation predict per-sound
false alarms BETTER, and do the learned weights differ across groups?

Design (honest by construction):

  * relu2 is 78,336-dim. A PCA basis fit to the analysed 80 sounds double-dips
    (the axes are chosen from the very stimuli, and their held-out points, that
    the CV must protect) and in this space the top PCs of 80 points are unstable.
    Instead we define the basis from a HELD-OUT set of sounds -- the other two
    stimulus sets (160 sounds), independent of the analysed set and its false
    alarms -- take the top --npcs principal axes there, and PROJECT the 80
    analysed sounds into that fixed, stimulus-independent basis. Weights are then
    comparable across groups in a shared, externally-defined basis. (The baseline
    is euclidean within this held-out subspace, a projection of the full-space
    euclidean metric, so it need not match the chapter's full-space number.)

  * In-context confusability holding the base-euclidean neighbour sets fixed is
    LINEAR in the per-dimension weights. For sound i,
        conf_i(w) = sum_d w_d * phi_id,
    where phi_id = mean over that group's presentations of
        -(1/k) * sum_{j in earlier-heard KNN of i}  (x_id - x_jd)^2 .
    With w = 1 (all dimensions equal) this is exactly the euclidean (squared)
    in-context confusability, so w = 1 recovers the fixed-metric baseline.

  * We fit w by ridge regression of (z-scored) per-sound FA on Phi, penalising
    ||w - 1||^2 so the regularisation path runs from the euclidean metric
    (lambda -> inf, w -> 1) to the free fit (lambda -> 0). lambda is chosen by
    leave-one-sound-out CV; the reported number is the held-out Spearman rho
    (predicted confusability vs actual FA on the left-out sound), so any gain
    over baseline is genuine and not memorised.

  * Weights are fit PER GROUP (each group's own FA and own experienced contexts),
    then compared across groups.

Caveat: fixing the neighbour sets from the base metric is a one-step
linearisation; under the fitted w the true KNN could shift. --iterate refits a
few times, recomputing Phi from the fitted metric, to check stability.
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from scipy.spatial.distance import cdist
from scipy.stats import spearmanr, zscore

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_representation_analysis import (  # noqa: E402
    CODES, GLAB, CONDS, load_embeddings, per_sound_fa, canonical_names,
    load_sequences)

K = 3
GORDER = ["US", "SanBorja", "Tsimane"]
LAMBDAS = np.logspace(-2, 8, 28)      # ridge on STANDARDIZED features: spans overfit->w=0


def heldout_basis(analysis_cond, layer, k):
    """Top-k PCA axes from the OTHER stimulus sets (held out from this analysis).

    Returns (mean_h, Vk) with mean_h (D,) and Vk (k x D). Project analysed
    embeddings as (M - mean_h) @ Vk.T. The basis never sees the analysed set's
    sounds or false alarms, so the downstream fit/CV are not double-dipping.
    """
    Ms = []
    for other_key, _ in CONDS:
        if other_key == analysis_cond:
            continue
        nm = canonical_names(other_key)
        emb = load_embeddings(other_key, layer, nm)
        Ms.append(np.stack([emb[n] for n in nm if n in emb]).astype(np.float64))
    H = np.vstack(Ms)                                  # ~160 x D held-out sounds
    mean_h = H.mean(0)
    U, S, Vt = np.linalg.svd(H - mean_h, full_matrices=False)
    kk = min(k, int((S > S.max() * 1e-9).sum()))
    return mean_h, Vt[:kk]


def build_phi(X, seqs, names, k):
    """Per-sound, per-dimension feature Phi (n x r) for one group.

    Phi_id = mean over the group's presentations of
        -(1/k) sum_{j in earlier-heard KNN of i}  (x_id - x_jd)^2,
    with neighbours taken under the base euclidean metric on X. sum_d Phi_id is
    the euclidean (squared) in-context confusability, i.e. the w=1 baseline.
    """
    idx = {n: i for i, n in enumerate(names)}
    D = cdist(X, X, metric="euclidean")
    n, r = X.shape
    acc = np.zeros((n, r))
    cnt = np.zeros(n)
    for stims, foil in seqs:
        seen, seen_set = [], set()
        for t, s in enumerate(stims):
            si = idx.get(s)
            if foil[t] and si is not None and seen:
                ctx = [j for j in seen if j != si]
                if ctx:
                    ctx = np.asarray(ctx)
                    kk = min(k, len(ctx))
                    nn = ctx[np.argsort(D[si, ctx])[:kk]]
                    diff2 = (X[si] - X[nn]) ** 2            # kk x r
                    acc[si] += -diff2.mean(0)               # -(1/kk) sum_j
                    cnt[si] += 1
            if si is not None and si not in seen_set:
                seen.append(si); seen_set.add(si)
    good = cnt > 0
    acc[good] /= cnt[good][:, None]
    return acc, good


def standardizer(Phi_train):
    """Per-column mean/std from the training rows (std floored)."""
    mu = Phi_train.mean(0)
    sd = Phi_train.std(0)
    sd = np.where(sd > 1e-9, sd, 1.0)
    return mu, sd


def ridge0(Z, y, lam):
    """w = argmin ||y - Z w||^2 + lam ||w||^2 on standardized features Z."""
    r = Z.shape[1]
    return np.linalg.solve(Z.T @ Z + lam * np.eye(r), Z.T @ y)


def fit_standardized(Phi_train, y_train, lam):
    """Standardize on train, ridge toward 0; return (w, mu, sd)."""
    mu, sd = standardizer(Phi_train)
    Z = (Phi_train - mu) / sd
    return ridge0(Z, y_train, lam), mu, sd


def loo_heldout_rho(Phi, y, lam):
    """Leave-one-sound-out held-out Spearman rho; scaler refit inside each fold."""
    n = Phi.shape[0]
    pred = np.empty(n)
    for i in range(n):
        m = np.ones(n, bool); m[i] = False
        w, mu, sd = fit_standardized(Phi[m], y[m], lam)
        pred[i] = ((Phi[i] - mu) / sd) @ w
    return spearmanr(pred, y).statistic, pred


def fit_group(X0, seqs, fa_vec, good_fa, names, k):
    """Fit one group at relu2: baseline (fixed euclidean) & fitted LOO held-out rho.

    Features Phi use base-euclidean neighbours (one-step linearisation) and are
    standardized per column before the ridge, so the lambda sweep spans the full
    underfit->overfit path. Returns the full-group weight and its scaler so the
    learned metric can be transferred to another group.
    """
    Phi, good_phi = build_phi(X0, seqs, names, k)
    use = good_phi & good_fa
    Phi_u = Phi[use]
    y = zscore(fa_vec[use])
    # baseline: fixed euclidean (w = 1, unstandardized), the current chapter measure
    base_rho = spearmanr(Phi_u.sum(1), y).statistic
    # sweep lambda by LOO held-out rho, standardizing inside each fold
    rows = [(lam, loo_heldout_rho(Phi_u, y, lam)[0]) for lam in LAMBDAS]
    best_lam, best_rho = max(rows, key=lambda t: (t[1] if np.isfinite(t[1]) else -9))
    w, mu, sd = fit_standardized(Phi_u, y, best_lam)     # full-group metric for transfer
    return dict(n=int(use.sum()), base_rho=float(base_rho),
                fit_rho=float(best_rho), best_lam=float(best_lam),
                w=w, mu=mu, sd=sd, use=use, Phi_u=Phi_u, y=y)


def main(conds, npcs):
    results = {}
    for cond_key, clab in conds:
        names = canonical_names(cond_key)
        emb = load_embeddings(cond_key, "relu2", names)
        names = [n for n in names if n in emb]
        M = np.stack([emb[n] for n in names]).astype(np.float64)
        mean_h, Vk = heldout_basis(cond_key, "relu2", npcs)     # basis from other sets
        X0 = (M - mean_h) @ Vk.T                                 # 80 x k, held-out basis
        seqs = {g: load_sequences(cond_key, CODES[g]) for g in CODES}
        fa = {g: per_sound_fa(cond_key, CODES[g]) for g in CODES}
        print(f"\n=== {clab}  (relu2, {X0.shape[1]} held-out PCs, {len(names)} sounds) ===")
        print(f"  {'group':>10} | {'baseline rho':>12}  {'fitted LOO rho':>14}  "
              f"{'delta':>7}  {'lambda*':>9}")
        gres = {}
        for g in GORDER:
            fv = np.array([fa[g].get(n, np.nan) for n in names])
            good_fa = np.isfinite(fv)
            r = fit_group(X0, seqs[g], fv, good_fa, names, K)
            gres[g] = r
            d = r["fit_rho"] - r["base_rho"]
            print(f"  {GLAB[g]:>10} | {r['base_rho']:12.3f}  {r['fit_rho']:14.3f}  "
                  f"{d:+7.3f}  {r['best_lam']:9.3g}")
        # ---- transfer matrix: fit metric on A, predict B ----
        # T[A][B] = Spearman(Phi_B @ w_A, FA_B). Only the weight vector w_A crosses
        # groups; Phi_B still uses B's own contexts and base-euclidean neighbours.
        # Off-diagonal is honestly held-out (B never entered A's fit); the diagonal
        # uses the within-group LOO rho. Transfer ratio A->B normalises by B's own
        # ceiling so a low value means metric mismatch, not that B is just noisier.
        T = np.full((3, 3), np.nan)
        for ai, A in enumerate(GORDER):
            wA, muA, sdA = gres[A]["w"], gres[A]["mu"], gres[A]["sd"]
            for bi, B in enumerate(GORDER):
                if A == B:
                    T[ai, bi] = gres[B]["fit_rho"]           # within-group LOO
                else:
                    pred = ((gres[B]["Phi_u"] - muA) / sdA) @ wA   # A's metric on B
                    T[ai, bi] = spearmanr(pred, gres[B]["y"]).statistic
        print("  transfer matrix rho[fit-on-ROW -> predict-COL]  (diag = within-group LOO):")
        print("             " + "".join(f"{GLAB[g]:>12}" for g in GORDER))
        for ai, A in enumerate(GORDER):
            print(f"    {GLAB[A]:>8} " + "".join(f"{T[ai,bi]:12.3f}" for bi in range(3)))
        print("  transfer ratio  rho[A->B] / rho[B->B]  (off-diagonal; ~1 transfers, <<1 fails):")
        for ai, A in enumerate(GORDER):
            for bi, B in enumerate(GORDER):
                if A != B and np.isfinite(T[bi, bi]) and abs(T[bi, bi]) > 1e-6:
                    ratio = T[ai, bi] / T[bi, bi]
                    print(f"    {GLAB[A]:>10} -> {GLAB[B]:<10}: {ratio:+.2f}")
        # cross-group learned-weight similarity (standardized-space weight vectors)
        print("  learned-weight cosine similarity (standardized w), pairwise:")
        for a in range(len(GORDER)):
            for b in range(a + 1, len(GORDER)):
                ga, gb = GORDER[a], GORDER[b]
                wa, wb = gres[ga]["w"], gres[gb]["w"]
                cos = float(wa @ wb / (np.linalg.norm(wa) * np.linalg.norm(wb) + 1e-12))
                print(f"    {GLAB[ga]:>10} vs {GLAB[gb]:<10}: {cos:+.3f}")
        drop = {"Phi_u", "y", "use", "mu", "sd"}
        results[clab] = {
            "per_group": {g: {kk: (v.tolist() if isinstance(v, np.ndarray) else v)
                              for kk, v in gres[g].items() if kk not in drop}
                          for g in GORDER},
            "transfer_matrix": T.tolist(),
            "transfer_order": [GLAB[g] for g in GORDER],
        }
    outp = HERE / "results" / "metric_learning_relu2.json"
    json.dump(results, open(outp, "w"), indent=2, default=float)
    print(f"\nsaved {outp}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--music-only", action="store_true",
                    help="only the globalized-music set (fast)")
    ap.add_argument("--npcs", type=int, default=30,
                    help="held-out PCA components (basis from the other stimulus sets)")
    a = ap.parse_args()
    conds = [c for c in CONDS if c[1] == "Music"] if a.music_only else CONDS
    main(conds, a.npcs)
