#!/usr/bin/env python3
"""Why oversampling the small groups does NOT create equal footing.

Resample the two small groups (San Borja, Tsimane') WITH REPLACEMENT up to the
U.S. group's n, then recompute reliabilities and between-group correlations.
Expectation: the between-group correlations barely change (resampling preserves a
group's mean item-rate vector), so no real information is added; and split-half
reliability is spuriously inflated, because duplicated participants can fall in
both halves and 'agree' with themselves. Averaged over R draws.
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402
from python.split_half import estimate_split_half_flexible, calculate_split_half_reliability  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
CONDS = [("Industrial-Nature", "Env"), ("NHS", "NHS")]
MINRESP, R = 2, 80


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
    r, _, _ = estimate_split_half_flexible(X, n_splits=80, split_dim=1, corr_type="Spearman", rng=rng)
    return (2*r)/(1+r) if np.isfinite(r) else np.nan


def main():
    rng = np.random.default_rng(0)
    print(f"Oversampling small groups WITH REPLACEMENT up to U.S. n (R={R}).\n")
    for cond, clab in CONDS:
        for kind in ("hit",):
            mats = [build_hit_fa_matrices(list_matfiles(BASE, GROUPS[g], cond, 2.0, False)) for g in GROUPS]
            mats = [(h if kind == "hit" else f, it) for (h, f, it) in mats]
            MA, MB, MC = align3(mats)
            nA, nB, nC = MA.shape[0], MB.shape[0], MC.shape[0]
            full = three_r(MA, MB, MC)
            relSB_true = calculate_split_half_reliability(MB, MB, np.arange(MB.shape[1]), n_splits=400).sb_hit
            relTs_true = calculate_split_half_reliability(MC, MC, np.arange(MC.shape[1]), n_splits=400).sb_hit
            rr = np.zeros((R, 3)); relSB = np.zeros(R); relTs = np.zeros(R)
            for t in range(R):
                B = MB[rng.integers(0, nB, nA)]   # oversample SB -> nA, with replacement
                C = MC[rng.integers(0, nC, nA)]   # oversample Ts -> nA
                rr[t] = three_r(MA, B, C)
                relSB[t] = sb(B, rng); relTs[t] = sb(C, rng)
            bal = np.nanmean(rr, 0)
            print(f"[{clab} {kind}]  n US/SB/Ts = {nA}/{nB}/{nC}  ->  oversample SB,Ts to {nA}")
            print(f"   correlations  full   : US-SB={full[0]:.2f}  US-Ts={full[1]:.2f}  SB-Ts={full[2]:.2f}")
            print(f"   correlations  oversmp: US-SB={bal[0]:.2f}  US-Ts={bal[1]:.2f}  SB-Ts={bal[2]:.2f}"
                  f"   (~unchanged: no info added)")
            print(f"   SanBorja reliability: true(n={nB})={relSB_true:.2f}   "
                  f"oversampled(n={nA})={np.nanmean(relSB):.2f}   (spuriously inflated)")
            print(f"   Tsimane  reliability: true(n={nC})={relTs_true:.2f}   "
                  f"oversampled(n={nA})={np.nanmean(relTs):.2f}\n")


if __name__ == "__main__":
    main()
