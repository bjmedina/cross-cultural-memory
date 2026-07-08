#!/usr/bin/env python3
"""Re-do the item-level results with PEARSON (alongside Spearman for comparison).
Per condition x measure: the three between-group correlations (Spearman vs
Pearson), and the paired-bootstrap contrasts (Pearson) with recentered-null p.
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr, pearsonr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
CONDS = [("Industrial-Nature", "Env"), ("Globalized-Music", "Music"), ("NHS", "NHS")]
PAIRS = [("US", "SanBorja", "US-SB"), ("US", "Tsimane", "US-Ts"), ("SanBorja", "Tsimane", "SB-Ts")]
CONTRASTS = [("US-SB vs US-Ts", "ab", "ac"), ("US-SB vs SB-Ts", "ab", "bc"), ("US-Ts vs SB-Ts", "ac", "bc")]
MINRESP, NBOOT = 2, 2000


def mats(cond, g, kind):
    h, f, it = build_hit_fa_matrices(list_matfiles(BASE, GROUPS[g], cond, 2.0, False))
    return (h if kind == "hit" else f), list(it)


def align3(cond, kind):
    M = {g: mats(cond, g, kind) for g in GROUPS}
    sh = [i for i in M["US"][1] if i in set(M["SanBorja"][1]) and i in set(M["Tsimane"][1])]
    def cols(g):
        Mat, names = M[g]; p = {x: k for k, x in enumerate(names)}
        return Mat[:, [p[i] for i in sh]]
    return cols("US"), cols("SanBorja"), cols("Tsimane")


def three(U, S, T, how):
    f = spearmanr if how == "spearman" else (lambda a, b: pearsonr(a, b))
    nU = np.sum(~np.isnan(U), 0); nS = np.sum(~np.isnan(S), 0); nT = np.sum(~np.isnan(T), 0)
    v = (nU >= MINRESP) & (nS >= MINRESP) & (nT >= MINRESP)
    u, s, t = np.nanmean(U[:, v], 0), np.nanmean(S[:, v], 0), np.nanmean(T[:, v], 0)
    rs = lambda a, b: (spearmanr(a, b).correlation if how == "spearman" else pearsonr(a, b)[0])
    return dict(ab=rs(u, s), ac=rs(u, t), bc=rs(s, t))


def main():
    rng = np.random.default_rng(0)
    print(f"{'cell':<11}{'pair':<7}{'Spearman':>9}{'Pearson':>9}")
    pear = {}
    for cond, clab in CONDS:
        for kind in ("hit", "fa"):
            U, S, T = align3(cond, kind)
            sp = three(U, S, T, "spearman"); pe = three(U, S, T, "pearson")
            pear[(clab, kind)] = (U, S, T, pe)
            for a, b, lab in PAIRS:
                key = {"US-SB": "ab", "US-Ts": "ac", "SB-Ts": "bc"}[lab]
                print(f"{clab+' '+kind:<11}{lab:<7}{sp[key]:>9.2f}{pe[key]:>9.2f}")
        print()

    print("=== Paired contrasts, PEARSON (recentered-null p) ===")
    print(f"{'cell':<11}{'contrast':<18}{'diff':>8}{'p':>8}")
    for cond, clab in CONDS:
        for kind in ("hit", "fa"):
            U, S, T, pe = pear[(clab, kind)]
            nU, nS, nT = U.shape[0], S.shape[0], T.shape[0]
            boot = {k: np.empty(NBOOT) for k in ("ab", "ac", "bc")}
            for bi in range(NBOOT):
                d = three(U[rng.integers(0, nU, nU)], S[rng.integers(0, nS, nS)],
                          T[rng.integers(0, nT, nT)], "pearson")
                for k in boot:
                    boot[k][bi] = d[k]
            for lab, k1, k2 in CONTRASTS:
                d_obs = pe[k1] - pe[k2]; db = boot[k1] - boot[k2]
                p = max(np.mean(np.abs(db - db.mean()) >= abs(d_obs)), 1 / (NBOOT + 1))
                star = "**" if p < 0.01 else ("*" if p < 0.05 else "")
                print(f"{clab+' '+kind:<11}{lab:<18}{d_obs:>+8.3f}{p:>7.3f}{star}")
        print()


if __name__ == "__main__":
    main()
