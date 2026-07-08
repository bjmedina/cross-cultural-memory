#!/usr/bin/env python3
"""Infinite-participant ceiling for the paired between-group correlation contrasts.

More participants -> higher within-group reliability -> less attenuation. The
best case is reliability = 1 (infinitely many participants), where the observable
correlation equals the DISATTENUATED (true) correlation. We then ask: with the
real number of items (m=80), is each pairwise difference significant at that
ceiling? If yes, more participants COULD get there; if no, the contrast is
item-limited (80 sounds can't resolve it) and more people won't help.

Test: Hotelling-Williams t for two dependent correlations sharing a variable
(an analytic proxy for the paired bootstrap; assumes ~normal, so read as a
feasibility estimate). Compares to the current bootstrap result.
"""
from __future__ import annotations
import numpy as np
from scipy.stats import t as tdist

M = 80  # number of items (sounds)
# observed (raw) correlations (AB=US-SB, AC=US-Ts, BC=SB-Ts) and within-group
# reliabilities (US, SB, Ts), per condition x measure, from itemlevel_results.py
CELLS = {
    "Env  hits":  dict(r=(0.62, 0.57, 0.72), rel=(0.78, 0.71, 0.71)),
    "Env  FA":    dict(r=(0.64, 0.59, 0.64), rel=(0.91, 0.80, 0.81)),
    "Music hits": dict(r=(0.48, 0.43, 0.41), rel=(0.78, 0.72, 0.21)),
    "Music FA":   dict(r=(0.63, 0.25, 0.42), rel=(0.86, 0.74, 0.70)),
    "NHS  hits":  dict(r=(0.49, 0.47, 0.54), rel=(0.65, 0.68, 0.65)),
    "NHS  FA":    dict(r=(0.77, 0.75, 0.75), rel=(0.91, 0.85, 0.83)),
}
# contrasts: (label, idx of the two compared corrs, idx of the "other" corr)
# r order is [AB, AC, BC]; A=US,B=SB,C=Ts
CONTRASTS = [("US-SB vs US-Ts", 0, 1, 2),   # share A; other = BC
             ("US-SB vs SB-Ts", 0, 2, 1),   # share B; other = AC
             ("US-Ts vs SB-Ts", 1, 2, 0)]   # share C; other = AB


def disattenuate(r, rel):
    relp = [rel[0]*rel[1], rel[0]*rel[2], rel[1]*rel[2]]  # AB, AC, BC pair reliabilities
    return [min(r[k] / np.sqrt(relp[k]), 0.95) for k in range(3)], relp


def williams_t(r1, r2, r_other, n):
    detR = 1 - r1**2 - r2**2 - r_other**2 + 2*r1*r2*r_other
    rbar = (r1 + r2) / 2
    denom = 2*((n-1)/(n-3))*detR + rbar**2*(1-r_other)**3
    if denom <= 0:
        return np.nan, np.nan
    tval = (r1 - r2) * np.sqrt((n-1)*(1+r_other) / denom)
    p = 2*tdist.sf(abs(tval), df=n-3)
    return tval, p


def main():
    print(f"Infinite-participant CEILING (reliability=1), m={M} items. "
          f"'*'=p<.05 at the ceiling.\n")
    print(f"{'cell':<11}{'contrast':<18}{'rawdiff':>8}{'truediff':>9}{'ceil_p':>9}")
    for name, d in CELLS.items():
        dis, relp = disattenuate(d["r"], d["rel"])
        warn = " (Ts rel very low; disattenuation unreliable)" if min(d["rel"]) < 0.4 else ""
        for lab, i, j, k in CONTRASTS:
            rawdiff = d["r"][i] - d["r"][j]
            truediff = dis[i] - dis[j]
            _, p = williams_t(dis[i], dis[j], dis[k], M)
            star = "*" if (np.isfinite(p) and p < 0.05) else ""
            print(f"{name:<11}{lab:<18}{rawdiff:>+8.2f}{truediff:>+9.2f}{p:>9.3f}{star}")
        if warn:
            print(f"           {warn}")
        print()


if __name__ == "__main__":
    main()
