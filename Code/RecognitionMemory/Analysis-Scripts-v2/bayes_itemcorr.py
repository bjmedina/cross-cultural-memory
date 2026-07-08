#!/usr/bin/env python3
"""(#2) One-stage Bayesian multilevel model of cross-cultural item structure.

Trial-level (Bernoulli) model. For each item j (the same 80 sounds across groups)
the per-group latent effects (b_US_j, b_SB_j, b_Ts_j) are drawn from a trivariate
normal with an LKJ correlation matrix Omega. The off-diagonals of Omega are the
between-group item-effect correlations, estimated DIRECTLY with full posterior
uncertainty, using all trial-level data, with no two-stage attenuation and no
disattenuation needed.

    y_{g,i,j} ~ Bernoulli(sigmoid( mu_g + a_{g,i} + b_{g,j} ))
    (b_US_j, b_SB_j, b_Ts_j) ~ MVN(0, diag(s) Omega diag(s)),  Omega ~ LKJ

Run on a chosen condition/measure (default Globalized-Music / fa). Saves the
posterior of the three correlations (mean + 94% HDI) to bayes_itemcorr_<cond>_<kind>.json.
"""
from __future__ import annotations
import sys, json, argparse
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}


def build_long(cond, kind):
    mats = {}
    for g, codes in GROUPS.items():
        h, f, it = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
        mats[g] = ((h if kind == "hit" else f), list(it))
    shared = [it for it in mats["US"][1] if it in set(mats["SanBorja"][1]) and it in set(mats["Tsimane"][1])]
    item_idx = {it: k for k, it in enumerate(shared)}
    obs, grp, pid, item = [], [], [], []
    pid_counter = 0
    for gi, g in enumerate(["US", "SanBorja", "Tsimane"]):
        M, names = mats[g]; pos = {it: k for k, it in enumerate(names)}
        cols = [pos[it] for it in shared]
        sub = M[:, cols]               # [n_part x m]
        for i in range(sub.shape[0]):
            row = sub[i]
            seen = np.where(~np.isnan(row))[0]
            if seen.size == 0:
                continue
            for j in seen:
                obs.append(int(row[j])); grp.append(gi); pid.append(pid_counter); item.append(int(j))
            pid_counter += 1
    return (np.array(obs), np.array(grp), np.array(pid), np.array(item),
            len(shared), pid_counter)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cond", default="Globalized-Music")
    ap.add_argument("--kind", default="fa")
    ap.add_argument("--draws", type=int, default=400)
    ap.add_argument("--tune", type=int, default=400)
    args = ap.parse_args()

    obs, grp, pid, item, m, npart = build_long(args.cond, args.kind)
    print(f"data: {len(obs)} obs, {m} items, {npart} participants", flush=True)

    import pymc as pm
    import arviz as az
    import pytensor.tensor as pt

    with pm.Model() as model:
        mu = pm.Normal("mu", 0.0, 1.5, shape=3)
        chol, corr, sds = pm.LKJCholeskyCov(
            "chol", n=3, eta=2.0, sd_dist=pm.HalfNormal.dist(1.0), compute_corr=True)
        z = pm.Normal("z", 0.0, 1.0, shape=(m, 3))
        b = pm.Deterministic("b", z @ chol.T)          # (m,3) per-group item effects
        sd_pid = pm.HalfNormal("sd_pid", 1.0)
        a = pm.Normal("a", 0.0, sd_pid, shape=npart)
        eta = mu[grp] + a[pid] + b[item, grp]
        pm.Bernoulli("y", logit_p=eta, observed=obs)
        Omega = pm.Deterministic("Omega", corr)
        idata = pm.sample(draws=args.draws, tune=args.tune, chains=2, cores=2,
                          target_accept=0.9, random_seed=0, progressbar=False)

    post = idata.posterior["Omega"]
    pairs = {"US-SanBorja": (0, 1), "US-Tsimane": (0, 2), "SanBorja-Tsimane": (1, 2)}
    out = {"cond": args.cond, "kind": args.kind, "n_obs": int(len(obs)),
           "m_items": m, "n_part": npart, "correlations": {}}
    for name, (i, j) in pairs.items():
        s = post[:, :, i, j].values.ravel()
        out["correlations"][name] = dict(mean=float(s.mean()),
                                         hdi=[float(np.percentile(s, 3)), float(np.percentile(s, 97))],
                                         p_gt0=float((s > 0).mean()))
    # difference US-SB minus US-Ts (the key contrast), full posterior
    dUS = post[:, :, 0, 1].values.ravel() - post[:, :, 0, 2].values.ravel()
    out["contrast_USSB_minus_USTs"] = dict(mean=float(dUS.mean()),
        hdi=[float(np.percentile(dUS, 3)), float(np.percentile(dUS, 97))],
        p_gt0=float((dUS > 0).mean()))
    try:
        out["max_rhat"] = float(az.rhat(idata).to_array().max())
    except Exception:
        pass
    fn = HERE / "dprime_vs_isi_outputs" / f"bayes_itemcorr_{args.cond}_{args.kind}.json"
    fn.write_text(json.dumps(out, indent=2))
    print("WROTE", fn, flush=True)
    print(json.dumps(out["correlations"], indent=2), flush=True)
    print("contrast:", out["contrast_USSB_minus_USTs"], flush=True)


if __name__ == "__main__":
    main()
