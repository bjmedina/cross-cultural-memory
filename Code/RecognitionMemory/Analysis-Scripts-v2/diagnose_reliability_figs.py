#!/usr/bin/env python3
"""Visual evidence that the Tsimane' MUSIC hit reliability collapse is a loss of
across-sound SIGNAL, not a coverage/noise problem.

Figure A  split-half scatter grid (hits): each point is a sound, one random half of
          participants vs the other. A tight line = reliable item structure; a blob =
          none. Tsimane' music should be the blob.
Figure B  variance decomposition: across-sound SD split into binomial sampling noise
          and real signal, with observations-per-sound annotated (kills the "not enough
          data" explanation).
Figure C  per-sound rate distributions: how spread out sounds are within each cell,
          including the key control that Tsimane' world song sits at a similar mean to
          music yet stays spread out.
Screened sample (d'>=2, finished sessions)."""
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
rng = np.random.default_rng(0)

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

cache = {}
for cond, clab in CONDS:
    for g, codes in GROUPS:
        h, f, _ = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
        cache[(clab, g)] = h


def sb_reliability(mat, nsplit=300):
    n = mat.shape[0]; rs = []
    for _ in range(nsplit):
        idx = rng.permutation(n); a, b = idx[:n//2], idx[n//2:]
        with np.errstate(invalid="ignore"):
            va, vb = np.nanmean(mat[a],0), np.nanmean(mat[b],0)
        m = np.isfinite(va) & np.isfinite(vb)
        if m.sum() >= 5: rs.append(spearmanr(va[m], vb[m]).correlation)
    r = np.nanmedian(rs)
    return (2*r)/(1+r) if np.isfinite(r) else np.nan


def one_split(mat, seed=3):
    r2 = np.random.default_rng(seed)
    n = mat.shape[0]; idx = r2.permutation(n); a, b = idx[:n//2], idx[n//2:]
    with np.errstate(invalid="ignore"):
        va, vb = np.nanmean(mat[a],0), np.nanmean(mat[b],0)
    m = np.isfinite(va) & np.isfinite(vb)
    return va[m], vb[m]


def decompose(mat):
    n_j = np.sum(~np.isnan(mat), axis=0).astype(float)
    with np.errstate(invalid="ignore"):
        p_j = np.nanmean(mat, axis=0)
    ok = np.isfinite(p_j) & (n_j > 1); p, n = p_j[ok], n_j[ok]
    vt = np.var(p, ddof=1); vn = np.mean(p*(1-p)/n)
    return np.sqrt(vt), np.sqrt(vn), np.sqrt(max(vt-vn, 0)), float(np.median(n)), p


# ---------- Figure A: split-half scatter grid ----------
figA, axes = plt.subplots(3, 3, figsize=(11, 11))
for r, (cond, clab) in enumerate(CONDS):
    for c, (g, _) in enumerate(GROUPS):
        ax = axes[r][c]; mat = cache[(clab, g)]
        va, vb = one_split(mat)
        rr = spearmanr(va, vb).correlation
        ax.scatter(va, vb, s=20, color=GCOL[g], alpha=0.7, edgecolor="white", linewidths=0.4)
        ax.plot([0,1],[0,1], ls=":", color="#bbb", lw=1)
        ax.set_xlim(0,1); ax.set_ylim(0,1); ax.set_aspect("equal")
        ax.text(0.04, 0.92, f"r = {rr:.2f}", transform=ax.transAxes, fontsize=12, fontweight="bold")
        ax.text(0.04, 0.83, f"$\\rho_{{SB}}$ = {sb_reliability(mat):.2f}", transform=ax.transAxes,
                fontsize=10, color="#555")
        ax.set_xticks([0,0.5,1]); ax.set_yticks([0,0.5,1]); ax.tick_params(labelsize=8)
        if r == 0: ax.set_title(GLAB[g], fontsize=12)
        if c == 0: ax.set_ylabel(f"{clab}\n\nhalf B per-sound hit rate", fontsize=9.5)
        if r == 2: ax.set_xlabel("half A per-sound hit rate", fontsize=9.5)
figA.suptitle("Split-half reliability of per-sound HIT rate: each point is a sound",
              fontsize=13, fontweight="bold")
figA.tight_layout(rect=[0,0,1,0.97])
figA.savefig(OUT/"diagnose_splithalf_scatter.png", dpi=160, bbox_inches="tight")
print("saved diagnose_splithalf_scatter.png")

# ---------- Figure B: signal vs noise decomposition ----------
figB, axes = plt.subplots(1, 3, figsize=(13, 4.6), sharey=True)
x = np.arange(3); w = 0.36
for c, (cond, clab) in enumerate(CONDS):
    ax = axes[c]
    sig, noi, cov = [], [], []
    for g, _ in GROUPS:
        _, sn, ss, cv, _ = decompose(cache[(clab, g)]); sig.append(ss); noi.append(sn); cov.append(cv)
    ax.bar(x-w/2, sig, w, color=[GCOL[g] for g,_ in GROUPS], label="signal")
    ax.bar(x+w/2, noi, w, color="#BDBDBD", label="sampling noise")
    for i, cv in enumerate(cov):
        ax.text(x[i], 0.005, f"{cv:.0f} obs/sound", ha="center", fontsize=8, color="#444")
    ax.set_xticks(x); ax.set_xticklabels([GLAB[g] for g,_ in GROUPS], fontsize=9)
    ax.set_title(clab, fontsize=11); ax.set_ylim(0, 0.19); ax.grid(axis="y", ls="--", alpha=0.3)
axes[0].set_ylabel("across-sound SD of hit rate", fontsize=10)
axes[0].legend(fontsize=8, loc="upper right")
figB.suptitle("Where the reliability goes: real signal vs binomial noise (coverage annotated)",
              fontsize=12.5, fontweight="bold")
figB.tight_layout(rect=[0,0,1,0.95])
figB.savefig(OUT/"diagnose_signal_noise.png", dpi=160, bbox_inches="tight")
print("saved diagnose_signal_noise.png")

# ---------- Figure C: per-sound rate distributions ----------
figC, axes = plt.subplots(1, 3, figsize=(13, 4.6), sharey=True)
for c, (cond, clab) in enumerate(CONDS):
    ax = axes[c]
    data = [decompose(cache[(clab, g)])[4] for g, _ in GROUPS]
    vp = ax.violinplot(data, showmedians=True, widths=0.8)
    for b, (g, _) in zip(vp["bodies"], GROUPS):
        b.set_facecolor(GCOL[g]); b.set_alpha(0.6)
    for i, d in enumerate(data, start=1):
        ax.scatter(np.random.normal(i, 0.05, len(d)), d, s=5, color="#444", alpha=0.35, zorder=3)
        ax.text(i, 0.97, f"SD={np.std(d, ddof=1):.3f}", ha="center", fontsize=8, color="#333")
    ax.set_xticks([1,2,3]); ax.set_xticklabels([GLAB[g] for g,_ in GROUPS], fontsize=9)
    ax.set_ylim(0,1.03); ax.set_title(clab, fontsize=11); ax.grid(axis="y", ls="--", alpha=0.3)
axes[0].set_ylabel("per-sound hit rate (one point = one sound)", fontsize=10)
figC.suptitle("How much do sounds differ within each group? Tsimane' music is flat, "
              "world song at a similar mean is not", fontsize=12.5, fontweight="bold")
figC.tight_layout(rect=[0,0,1,0.95])
figC.savefig(OUT/"diagnose_persound_spread.png", dpi=160, bbox_inches="tight")
print("saved diagnose_persound_spread.png")
