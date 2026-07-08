#!/usr/bin/env python3
"""The full JOINT distribution behind the two marginals.

The per-participant performance measures and the per-sound item vectors are both
averages of one participant x sound response matrix. This script shows the joint
structure that the marginals collapse away:

 (A) MEMORABILITY x CONFUSABILITY plane -- each sound as a point (hit rate on x,
     FA rate on y), per group, per condition. The joint of the two per-sound
     marginals; reveals whether memorable sounds are also less confusable.
 (B) VARIANCE DECOMPOSITION -- how much of the total response variance is between
     participants (row effect), between sounds (item effect), and participant x
     item interaction + noise (residual), per condition. Quantifies which marginal
     carries the signal.

Screened sample (d'>=2)."""
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT = HERE / "dprime_vs_isi_outputs"
GROUPS = [("US", ("PRO","BOS","CAM")), ("SanBorja", ("SBO","SNB","SBJ")),
          ("Tsimane", ("NVM","MAJ","MAN","NUM","NUV","CVR"))]
GCOL = {"US":"#1f77b4","SanBorja":"#ff7f0e","Tsimane":"#2E7D32"}
GLAB = {"US":"U.S.","SanBorja":"San Borja","Tsimane":"Tsimane'"}
CONDS = [("Industrial-Nature","Environmental"),("Globalized-Music","Music"),("NHS","World song")]


def load(codes, cond):
    h, f, it = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
    return h, f


def var_decomp(M):
    """Two-way random-effects variance components of a participant x item matrix
    with NaNs: total variance split into row (participant), column (item), and
    residual (interaction+noise) fractions."""
    mask = ~np.isnan(M)
    gm = np.nanmean(M)
    row = np.nanmean(M, axis=1) - gm          # participant deviations
    col = np.nanmean(M, axis=0) - gm          # item deviations
    fitted = gm + row[:,None] + col[None,:]
    resid = M - fitted
    v_row = np.nansum((mask * row[:,None]**2))
    v_col = np.nansum((mask * col[None,:]**2))
    v_res = np.nansum(resid[mask]**2)
    tot = v_row + v_col + v_res
    return v_row/tot, v_col/tot, v_res/tot


import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

# ---- Figure A: memorability x confusability plane ----
figA, axes = plt.subplots(1, 3, figsize=(13, 4.6), sharex=True, sharey=True)
for c,(cond,clab) in enumerate(CONDS):
    ax = axes[c]
    for g,codes in GROUPS:
        h,f = load(codes, cond)
        with np.errstate(invalid="ignore"):
            hr = np.nanmean(h,0); fr = np.nanmean(f,0)
        ax.scatter(hr, fr, s=16, color=GCOL[g], alpha=0.55, edgecolor="white",
                   linewidths=0.3, label=GLAB[g])
    ax.set_title(clab, fontsize=11); ax.set_xlim(0,1); ax.set_ylim(0,1)
    ax.plot([0,1],[0,1],ls=":",color="#ccc",lw=1)
    ax.set_xlabel("per-sound hit rate  (memorability)", fontsize=9.5)
    ax.grid(ls="--", alpha=0.3)
    if c==0:
        ax.set_ylabel("per-sound FA rate  (confusability)", fontsize=9.5); ax.legend(fontsize=8)
figA.suptitle("Full joint of the two per-sound marginals: each point is a sound in "
              "memorability x confusability space", fontsize=12, fontweight="bold")
figA.tight_layout(rect=[0,0,1,0.96])
figA.savefig(OUT/"full_joint_memorability_confusability.png",dpi=160,bbox_inches="tight")
figA.savefig(OUT/"full_joint_memorability_confusability.pdf",bbox_inches="tight")
print("saved full_joint_memorability_confusability")

# ---- Figure B: variance decomposition (hits) ----
figB, axes = plt.subplots(1, 3, figsize=(12, 4.4), sharey=True)
comp_lab = ["between participants\n(row / performance)", "between sounds\n(column / item)",
            "interaction + noise\n(residual)"]
comp_col = ["#5B8DEF", "#E8A13A", "#B0B0B0"]
for c,(cond,clab) in enumerate(CONDS):
    ax = axes[c]
    x = np.arange(3); w = 0.26
    for k,(g,codes) in enumerate(GROUPS):
        h,f = load(codes, cond)
        fr_row, fr_col, fr_res = var_decomp(h)   # hits
        ax.bar(x+(k-1)*w, [fr_row,fr_col,fr_res], w, color=GCOL[g],
               label=GLAB[g] if c==0 else None, alpha=0.85)
    ax.set_xticks(x); ax.set_xticklabels(comp_lab, fontsize=8)
    ax.set_title(clab, fontsize=11); ax.set_ylim(0,1); ax.grid(axis="y",ls="--",alpha=0.3)
    if c==0:
        ax.set_ylabel("fraction of total variance (hits)", fontsize=9.5); ax.legend(fontsize=8)
figB.suptitle("Where the variance lives: participant vs sound vs interaction "
              "(hit responses)", fontsize=12, fontweight="bold")
figB.tight_layout(rect=[0,0,1,0.96])
figB.savefig(OUT/"full_joint_variance_decomp.png",dpi=160,bbox_inches="tight")
figB.savefig(OUT/"full_joint_variance_decomp.pdf",bbox_inches="tight")
print("saved full_joint_variance_decomp")
