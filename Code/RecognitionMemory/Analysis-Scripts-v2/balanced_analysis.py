#!/usr/bin/env python3
"""Balanced re-analysis: set every group's n to the SMALLEST group's n (per sound
type x response type), by random subsampling, then recompute the between-group
itemwise correlations and within-group reliabilities. Equalizing n removes the
advantage the large U.S. sample has (higher reliability -> less attenuation), so
the three pairs are compared on equal footing. Averaged over R subsamples.
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402
from python.split_half import estimate_split_half_flexible  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
CONDS = [("Industrial-Nature", "Env"), ("Globalized-Music", "Music"), ("NHS", "NHS")]
MINRESP, R = 2, 150


def align3(mats):
    its = [set(m[1]) for m in mats]
    shared = [it for it in mats[0][1] if it in its[1] and it in its[2]]
    return [M[:, [{x: k for k, x in enumerate(names)}[it] for it in shared]] for M, names in mats]


def three_r(MA, MB, MC):
    nA = np.sum(~np.isnan(MA), 0); nB = np.sum(~np.isnan(MB), 0); nC = np.sum(~np.isnan(MC), 0)
    v = (nA >= MINRESP) & (nB >= MINRESP) & (nC >= MINRESP)
    a, b, c = np.nanmean(MA[:, v], 0), np.nanmean(MB[:, v], 0), np.nanmean(MC[:, v], 0)
    return (spearmanr(a, b).correlation, spearmanr(a, c).correlation, spearmanr(b, c).correlation)


def sb(X, rng):
    r, _, _ = estimate_split_half_flexible(X, n_splits=60, split_dim=1, corr_type="Spearman", rng=rng)
    return (2*r)/(1+r) if np.isfinite(r) else np.nan


def main():
    cache = {}
    def mat(cond, g, kind):
        if (cond, g) not in cache:
            cache[(cond, g)] = build_hit_fa_matrices(list_matfiles(BASE, GROUPS[g], cond, 2.0, False))
        h, f, it = cache[(cond, g)]
        return (h if kind == "hit" else f), it

    rng = np.random.default_rng(0)
    print(f"Balanced to min group n (R={R} subsamples). r order: US-SB, US-Ts, SB-Ts\n")
    print(f"{'cell':<11}{'n (US/SB/Ts)':<16}{'n_min':>6}  "
          f"{'r FULL (AB,AC,BC)':<22}{'r BALANCED (AB,AC,BC)':<24}{'rel bal US/SB/Ts'}")
    for cond, clab in CONDS:
        for kind in ("hit", "fa"):
            mats = [(mat(cond, g, kind)) for g in GROUPS]
            MA, MB, MC = align3(mats)
            ns = [MA.shape[0], MB.shape[0], MC.shape[0]]
            nmin = min(ns)
            full = three_r(MA, MB, MC)
            rr = np.zeros((R, 3)); rel = np.zeros((R, 3))
            for t in range(R):
                ia = rng.choice(ns[0], nmin, replace=False)
                ib = rng.choice(ns[1], nmin, replace=False)
                ic = rng.choice(ns[2], nmin, replace=False)
                A, B, C = MA[ia], MB[ib], MC[ic]
                rr[t] = three_r(A, B, C)
                rel[t] = [sb(A, rng), sb(B, rng), sb(C, rng)]
            bal = np.nanmean(rr, 0); relb = np.nanmean(rel, 0)
            print(f"{clab+' '+kind:<11}{f'{ns[0]}/{ns[1]}/{ns[2]}':<16}{nmin:>6}  "
                  f"{f'{full[0]:.2f}, {full[1]:.2f}, {full[2]:.2f}':<22}"
                  f"{f'{bal[0]:.2f}, {bal[1]:.2f}, {bal[2]:.2f}':<24}"
                  f"{relb[0]:.2f}/{relb[1]:.2f}/{relb[2]:.2f}")
        print()


if __name__ == "__main__":
    main()
