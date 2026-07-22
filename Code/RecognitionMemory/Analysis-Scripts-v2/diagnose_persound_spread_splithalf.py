#!/usr/bin/env python3
"""Per-sound HIT-rate spread, split by participant parity.

Same quantity as diagnose_persound_spread.py (the distribution of per-sound hit
rates across the ~80 sounds), but computed twice: once on ODD-numbered participants
and once on EVEN-numbered participants (the split-half partition). A reliable cell
shows two similarly SPREAD distributions whose sounds line up (high split-half r); an
undifferentiated cell shows two compressed distributions that do not line up.

Grid: rows = condition, cols = group; each cell holds the odd and even violins.
Annotated per cell: SD of each half and the split-half Spearman r between the two
half-vectors (the reliability signal, uncorrected). Screened sample (d'>=2, finished)."""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT = HERE / "dprime_vs_isi_outputs"
GROUPS = [("US", ("PRO","BOS","CAM")), ("SanBorja", ("SBO","SNB","SBJ")),
          ("Tsimane", ("NVM","MAJ","MAN","NUM","NUV","CVR"))]
GLAB = {"US":"U.S.","SanBorja":"San Borja","Tsimane":"Tsimane'"}
GCOL = {"US":"#1f77b4","SanBorja":"#ff7f0e","Tsimane":"#2E7D32"}
CONDS = [("Industrial-Nature","Environmental"),("Globalized-Music","Music"),("NHS","World song")]
IDX = 0  # 0 = hits, 1 = false alarms


def halves(mat):
    """odd- and even-numbered participants (1-based): rows 0,2,4.. and 1,3,5.."""
    odd = mat[0::2]   # participants 1,3,5,... (1-based)
    even = mat[1::2]  # participants 2,4,6,...
    with np.errstate(invalid="ignore"):
        vo = np.nanmean(odd, 0); ve = np.nanmean(even, 0)
    return vo, ve


import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
ODDC, EVENC = "#5B8DEF", "#E8863A"

fig, axes = plt.subplots(3, 3, figsize=(13, 10), sharey=True)
for r, (cond, clab) in enumerate(CONDS):
    for c, (g, codes) in enumerate(GROUPS):
        ax = axes[r][c]
        h, f, _ = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
        mat = h if IDX == 0 else f
        vo, ve = halves(mat)
        mask = np.isfinite(vo) & np.isfinite(ve)
        vo, ve = vo[mask], ve[mask]
        rr = spearmanr(vo, ve).correlation
        vp = ax.violinplot([vo, ve], positions=[1, 2], showmedians=True, widths=0.85)
        for b, col in zip(vp["bodies"], [ODDC, EVENC]):
            b.set_facecolor(col); b.set_alpha(0.18)
        # each sound = one line connecting its odd-half and even-half rate, plus plain dots
        for i in range(len(vo)):
            ax.plot([1, 2], [vo[i], ve[i]], color=GCOL[g], lw=0.6, alpha=0.30, zorder=2)
        ax.scatter(np.full(len(vo), 1.0), vo, s=11, color=GCOL[g], zorder=3, edgecolor="white", linewidths=0.3)
        ax.scatter(np.full(len(ve), 2.0), ve, s=11, color=GCOL[g], zorder=3, edgecolor="white", linewidths=0.3)
        ax.set_xlim(0.6, 2.4)
        ax.set_xticks([1, 2]); ax.set_xticklabels(["odd", "even"], fontsize=9)
        ax.set_ylim(0, 1.05); ax.grid(axis="y", ls="--", alpha=0.3)
        ax.text(0.03, 0.97, f"SD odd={np.std(vo, ddof=1):.3f}\nSD even={np.std(ve, ddof=1):.3f}\n"
                            f"split-half r={rr:.2f}", transform=ax.transAxes, va="top",
                fontsize=8.5, color="#222")
        if r == 0: ax.set_title(GLAB[g], fontsize=12)
        if c == 0: ax.set_ylabel(f"{clab}\n\nper-sound {'hit' if IDX==0 else 'FA'} rate", fontsize=9.5)
fig.suptitle("Per-sound hit-rate spread by participant half (odd vs even)",
             fontsize=12.5, fontweight="bold")
fig.tight_layout(rect=[0, 0, 1, 0.97])
fig.savefig(OUT/"diagnose_persound_spread_splithalf.png", dpi=160, bbox_inches="tight")
print("saved diagnose_persound_spread_splithalf.png")

# quick table
print(f"\n{'cond':<14}{'group':<11}{'SD_odd':>8}{'SD_even':>9}{'split-half r':>14}")
for cond, clab in CONDS:
    for g, codes in GROUPS:
        h, f, _ = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
        mat = h if IDX == 0 else f
        vo, ve = halves(mat); m = np.isfinite(vo) & np.isfinite(ve); vo, ve = vo[m], ve[m]
        print(f"{clab:<14}{GLAB[g]:<11}{np.std(vo,ddof=1):>8.3f}{np.std(ve,ddof=1):>9.3f}"
              f"{spearmanr(vo,ve).correlation:>14.2f}")
    print()
