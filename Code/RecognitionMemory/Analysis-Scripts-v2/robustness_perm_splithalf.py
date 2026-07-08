#!/usr/bin/env python3
"""(#7) Permutation null for each between-group itemwise correlation, and
(#5) split-half replication of the music-FA U.S.-Tsimane' dip.

#7: shuffle the item labels of one group's rate vector and recompute the
    correlation -> assumption-light null for "the same sounds are memorable
    across cultures" (r > 0). p = (1 + #|r_perm| >= |r_obs|) / (nperm + 1).
#5: randomly split each group's participants into two disjoint halves; recompute
    the music-FA contrast r(US,SB) - r(US,Ts) in each half; report how often the
    dip (contrast > 0, i.e. US-Ts the lower) appears in BOTH halves.
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
PAIRS = [("US", "SanBorja", "US-SB"), ("US", "Tsimane", "US-Ts"), ("SanBorja", "Tsimane", "SB-Ts")]
MINRESP = 2
rng = np.random.default_rng(0)


def load(cond, g, kind):
    h, f, it = build_hit_fa_matrices(list_matfiles(BASE, GROUPS[g], cond, 2.0, False))
    return (h if kind == "hit" else f), it


def aligned_means(MA, iA, MB, iB):
    shared = [it for it in iA if it in set(iB)]
    pa = {x: k for k, x in enumerate(iA)}; pb = {x: k for k, x in enumerate(iB)}
    A = MA[:, [pa[i] for i in shared]]; B = MB[:, [pb[i] for i in shared]]
    nA = np.sum(~np.isnan(A), 0); nB = np.sum(~np.isnan(B), 0)
    v = (nA >= MINRESP) & (nB >= MINRESP)
    return np.nanmean(A[:, v], 0), np.nanmean(B[:, v], 0)


def perm_test(a, b, nperm=3000):
    r_obs = spearmanr(a, b).correlation
    cnt = 0
    for _ in range(nperm):
        rp = spearmanr(a, rng.permutation(b)).correlation
        if abs(rp) >= abs(r_obs):
            cnt += 1
    return r_obs, (1 + cnt) / (nperm + 1)


def main():
    cache = {}
    g = lambda c, gr, k: cache.setdefault((c, gr, k), load(c, gr, k))

    print("==== #7 Permutation null: between-group correlation vs chance "
          "(item-shuffle, nperm=3000) ====")
    print(f"{'cell':<11}{'pair':<7}{'r':>7}{'perm_p':>9}")
    for cond, clab in CONDS:
        for kind in ("hit", "fa"):
            for a, b, lab in PAIRS:
                MA, iA = g(cond, a, kind); MB, iB = g(cond, b, kind)
                xa, xb = aligned_means(MA, iA, MB, iB)
                r, p = perm_test(xa, xb)
                print(f"{clab+' '+kind:<11}{lab:<7}{r:>7.2f}{p:>9.4f}")
        print()

    print("==== #5 Split-half replication: music-FA contrast r(US,SB)-r(US,Ts) ====")
    MUS, iUS = g("Globalized-Music", "US", "fa")
    MSB, iSB = g("Globalized-Music", "SanBorja", "fa")
    MTS, iTS = g("Globalized-Music", "Tsimane", "fa")

    def contrast_from(rowsUS, rowsSB, rowsTS):
        # shared items across all three
        sh = [it for it in iUS if it in set(iSB) and it in set(iTS)]
        pu = {x: k for k, x in enumerate(iUS)}; ps = {x: k for k, x in enumerate(iSB)}; pt = {x: k for k, x in enumerate(iTS)}
        U = MUS[np.ix_(rowsUS, [pu[i] for i in sh])]
        S = MSB[np.ix_(rowsSB, [ps[i] for i in sh])]
        T = MTS[np.ix_(rowsTS, [pt[i] for i in sh])]
        nU = np.sum(~np.isnan(U), 0); nS = np.sum(~np.isnan(S), 0); nT = np.sum(~np.isnan(T), 0)
        v = (nU >= MINRESP) & (nS >= MINRESP) & (nT >= MINRESP)
        u, s, t = np.nanmean(U[:, v], 0), np.nanmean(S[:, v], 0), np.nanmean(T[:, v], 0)
        return spearmanr(u, s).correlation - spearmanr(u, t).correlation

    R = 400
    both_pos = 0; c1s = []; c2s = []
    for _ in range(R):
        def halves(n):
            idx = rng.permutation(n); h = n // 2
            return idx[:h], idx[h:]
        u1, u2 = halves(MUS.shape[0]); s1, s2 = halves(MSB.shape[0]); t1, t2 = halves(MTS.shape[0])
        c1 = contrast_from(u1, s1, t1); c2 = contrast_from(u2, s2, t2)
        c1s.append(c1); c2s.append(c2)
        if c1 > 0 and c2 > 0:
            both_pos += 1
    c1s = np.array(c1s); c2s = np.array(c2s)
    print(f"  contrast (US-SB minus US-Ts), mean over {R} random splits:")
    print(f"    half 1: {np.nanmean(c1s):+.3f}    half 2: {np.nanmean(c2s):+.3f}")
    print(f"    dip present (contrast>0) in BOTH halves: {both_pos/R*100:.0f}% of splits")
    print(f"    present in at least one half: {np.mean((c1s>0)|(c2s>0))*100:.0f}%")


if __name__ == "__main__":
    main()
