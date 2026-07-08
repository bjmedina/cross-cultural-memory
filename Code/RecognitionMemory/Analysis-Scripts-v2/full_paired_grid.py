#!/usr/bin/env python3
"""Full significance grid: every sound set x {hits, FA} x the three pairwise
contrasts, via the shared-resample paired bootstrap. Difference CI is centered
on the observed difference (d +/- 1.96*SD_boot, the Fisher-z-style 'center on the
data' principle) with a recentered-null two-sided p-value.
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
CONDS = [("Industrial-Nature", "Env"), ("Globalized-Music", "Music"), ("NHS", "NHS")]
MINRESP, NBOOT = 2, 3000
# contrasts among A=US, B=SanBorja, C=Tsimane
CONTRASTS = [("US–SB  vs  US–Ts", "ab", "ac"),
             ("US–SB  vs  SB–Ts", "ab", "bc"),
             ("US–Ts  vs  SB–Ts", "ac", "bc")]


def three_r(MA, MB, MC):
    nA = np.sum(~np.isnan(MA), 0); nB = np.sum(~np.isnan(MB), 0); nC = np.sum(~np.isnan(MC), 0)
    v = (nA >= MINRESP) & (nB >= MINRESP) & (nC >= MINRESP)
    a = np.nanmean(MA[:, v], 0); b = np.nanmean(MB[:, v], 0); c = np.nanmean(MC[:, v], 0)
    return dict(ab=spearmanr(a, b).correlation, ac=spearmanr(a, c).correlation,
                bc=spearmanr(b, c).correlation)


def align3(mats):
    its = [set(m[1]) for m in mats]
    shared = [it for it in mats[0][1] if it in its[1] and it in its[2]]
    return [M[:, [{x: k for k, x in enumerate(names)}[it] for it in shared]]
            for M, names in mats]


def main():
    cache = {}
    def mat(cond, g, kind):
        key = (cond, g)
        if key not in cache:
            cache[key] = build_hit_fa_matrices(list_matfiles(BASE, GROUPS[g], cond, 2.0, False))
        h, f, it = cache[key]
        return (h if kind == "hit" else f), it

    rng = np.random.default_rng(0)
    print(f"Paired bootstrap, B={NBOOT}. Difference = first minus second; "
          f"CI centered on observed diff; * = p<.05, ** = p<.01\n")
    print(f"{'set':<6}{'meas':<5}{'contrast':<20}{'r1':>6}{'r2':>6}{'diff':>8}"
          f"{'95% CI':>18}{'p':>8}")
    for cond, clab in CONDS:
        for kind in ("hit", "fa"):
            MA, MB, MC = align3([mat(cond, "US", kind), mat(cond, "SanBorja", kind),
                                 mat(cond, "Tsimane", kind)])
            obs = three_r(MA, MB, MC)
            nA, nB, nC = MA.shape[0], MB.shape[0], MC.shape[0]
            boot = {k: np.empty(NBOOT) for k in ("ab", "ac", "bc")}
            for t in range(NBOOT):
                iA = rng.integers(0, nA, nA); iB = rng.integers(0, nB, nB); iC = rng.integers(0, nC, nC)
                rb = three_r(MA[iA], MB[iB], MC[iC])
                for k in boot:
                    boot[k][t] = rb[k]
            for label, k1, k2 in CONTRASTS:
                d_obs = obs[k1] - obs[k2]
                d_boot = boot[k1] - boot[k2]
                sd = np.std(d_boot, ddof=1)
                lo, hi = d_obs - 1.96 * sd, d_obs + 1.96 * sd
                dc = d_boot - d_boot.mean()
                p = max(np.mean(np.abs(dc) >= abs(d_obs)), 1 / (NBOOT + 1))
                star = "**" if p < 0.01 else ("*" if p < 0.05 else "")
                print(f"{clab:<6}{kind:<5}{label:<20}{obs[k1]:>6.2f}{obs[k2]:>6.2f}"
                      f"{d_obs:>+8.3f}{f'[{lo:+.2f},{hi:+.2f}]':>18}{p:>7.3f}{star}")
        print()


if __name__ == "__main__":
    main()
