#!/usr/bin/env python3
"""Is the low Tsimane' music hit reliability just a consequence of low hit rates?

Test directly: plot each group x condition cell's MEAN hit rate against its split-half
reliability. If low rates caused low reliability, the cells would fall on a rising
trend and Tsimane' music would sit on it. Instead reliability is roughly flat in the
mean, and Tsimane' music sits far below what its mean predicts. The decisive control is
Tsimane' WORLD SONG, nearly the same low mean, but reliable.

Right panel: the same fact as RANKS, which remove the floor compression. Each sound's
odd-half rank vs even-half rank for two matched-mean Tsimane' cells (music vs world
song). Ranks scramble for music, hold for world song."""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr, rankdata

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT = HERE / "dprime_vs_isi_outputs"
GROUPS = [("US", ("PRO","BOS","CAM")), ("SanBorja", ("SBO","SNB","SBJ")),
          ("Tsimane", ("NVM","MAJ","MAN","NUM","NUV","CVR"))]
GLAB = {"US":"U.S.","SanBorja":"San Borja","Tsimane":"Tsimane'"}
GCOL = {"US":"#1f77b4","SanBorja":"#ff7f0e","Tsimane":"#2E7D32"}
MARK = {"Environmental":"o","Music":"s","World song":"^"}
CONDS = [("Industrial-Nature","Environmental"),("Globalized-Music","Music"),("NHS","World song")]
rng = np.random.default_rng(0)


def sb(mat, nsplit=300):
    n = mat.shape[0]; rs = []
    for _ in range(nsplit):
        idx = rng.permutation(n); a, b = idx[:n//2], idx[n//2:]
        with np.errstate(invalid="ignore"):
            va, vb = np.nanmean(mat[a],0), np.nanmean(mat[b],0)
        m = np.isfinite(va) & np.isfinite(vb)
        if m.sum() >= 5: rs.append(spearmanr(va[m], vb[m]).correlation)
    r = np.nanmedian(rs)
    return (2*r)/(1+r) if np.isfinite(r) else np.nan


def halves(mat):
    with np.errstate(invalid="ignore"):
        return np.nanmean(mat[0::2],0), np.nanmean(mat[1::2],0)


import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, (axA, axB) = plt.subplots(1, 2, figsize=(13, 5.2))

# ---- Panel A: mean vs reliability, all 9 cells ----
cells = {}
for cond, clab in CONDS:
    for g, codes in GROUPS:
        h, f, _ = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
        with np.errstate(invalid="ignore"):
            mean = np.nanmean(np.nanmean(h, 0))
        cells[(clab, g)] = (mean, sb(h))
        axA.scatter(mean, cells[(clab, g)][1], s=110, color=GCOL[g], marker=MARK[clab],
                    edgecolor="white", linewidths=0.6, zorder=3)
axA.annotate("Tsimane'\nmusic", cells[("Music","Tsimane")], textcoords="offset points",
             xytext=(10, -6), fontsize=9, color="#C62828", fontweight="bold")
axA.annotate("Tsimane'\nworld song", cells[("World song","Tsimane")], textcoords="offset points",
             xytext=(8, 6), fontsize=9, color="#2E7D32")
axA.set_xlabel("cell mean hit rate", fontsize=10)
axA.set_ylabel("split-half hit reliability", fontsize=10)
axA.set_xlim(0, 1); axA.set_ylim(0, 1); axA.grid(ls="--", alpha=0.3)
axA.set_title("Reliability does not track the mean\n(one point = one group x sound set)", fontsize=11)
h1 = [plt.Line2D([],[],marker='o',ls='',color=GCOL[g],label=GLAB[g]) for g,_ in GROUPS]
h2 = [plt.Line2D([],[],marker=MARK[c],ls='',color='#666',label=c) for c in MARK]
axA.legend(handles=h1+h2, fontsize=8, loc="lower right")

# ---- Panel B: rank slopegraph, Tsimane' music vs world song (matched low mean) ----
for cond, clab, col, off in [("Globalized-Music","Music","#C62828",0),
                             ("NHS","World song","#2E7D32",1)]:
    h, f, _ = build_hit_fa_matrices(list_matfiles(BASE, ("NVM","MAJ","MAN","NUM","NUV","CVR"), cond, 2.0, False))
    vo, ve = halves(h); m = np.isfinite(vo) & np.isfinite(ve); vo, ve = vo[m], ve[m]
    ro = rankdata(vo)/len(vo); re = rankdata(ve)/len(ve)
    x0, x1 = off*3+1, off*3+2
    for i in range(len(ro)):
        axB.plot([x0, x1], [ro[i], re[i]], color=col, lw=0.6, alpha=0.3)
    axB.scatter([x0]*len(ro), ro, s=10, color=col); axB.scatter([x1]*len(re), re, s=10, color=col)
    axB.text((x0+x1)/2, 1.06, f"{clab}\nr={spearmanr(vo,ve).correlation:.2f}", ha="center",
             fontsize=9, color=col, fontweight="bold")
axB.set_xticks([1,2,4,5]); axB.set_xticklabels(["odd","even","odd","even"], fontsize=9)
axB.set_ylim(0, 1.14); axB.set_ylabel("per-sound rank (0=least, 1=most memorable)", fontsize=10)
axB.set_title("Tsimane' only, ranks remove the floor:\nmusic scrambles, world song holds", fontsize=11)
axB.grid(axis="y", ls="--", alpha=0.3)
fig.tight_layout()
fig.savefig(OUT/"diagnose_reliability_vs_mean.png", dpi=160, bbox_inches="tight")
print("saved diagnose_reliability_vs_mean.png")
print("\ncell means and reliabilities:")
for (clab, g), (mn, r) in cells.items():
    print(f"  {clab:<14}{GLAB[g]:<11} mean={mn:.2f}  rel={r:.2f}")
