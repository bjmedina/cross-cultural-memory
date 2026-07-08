#!/usr/bin/env python3
"""One-figure reconciliation of the two levels of analysis.

Each point is a sound: its rate in the U.S. (x) vs in Tsimane' (y).
  - vertical offset below the diagonal  = the LEVEL gap (the per-participant
    performance difference: Tsimane' lower overall).
  - tightness around the upward trend   = the PATTERN agreement (the per-sound
    between-group correlation).
Level (performance) and pattern (correlation) are independent, so 'Tsimane' worse
overall but agree on which sounds are memorable/confusable' is consistent, not
contradictory. Screened sample (d'>=2). Rows: hit rate, FA rate."""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT = HERE / "dprime_vs_isi_outputs"
CODES = {"US": ("PRO","BOS","CAM"), "SanBorja": ("SBO","SNB","SBJ"),
         "Tsimane": ("NVM","MAJ","MAN","NUM","NUV","CVR")}
LAB = {"US": "U.S.", "SanBorja": "San Borja", "Tsimane": "Tsimane'"}
PAIRS = [("US","SanBorja"), ("US","Tsimane"), ("SanBorja","Tsimane")]
CONDS = [("Industrial-Nature","Environmental"),("Globalized-Music","Globalized music"),("NHS","World song")]


_rng = np.random.default_rng(0)


def matrices(codes, cond):
    h, f, it = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
    return h, f, list(it)


def splithalf(mat, nsplit=300):
    """Spearman-Brown-corrected split-half reliability of the per-sound vector."""
    n = mat.shape[0]; rs = []
    for _ in range(nsplit):
        idx = _rng.permutation(n); a, b = idx[:n//2], idx[n//2:]
        with np.errstate(invalid="ignore"):
            va, vb = np.nanmean(mat[a],0), np.nanmean(mat[b],0)
        m = np.isfinite(va) & np.isfinite(vb)
        if m.sum() >= 5:
            rs.append(spearmanr(va[m], vb[m]).correlation)
    r = np.nanmedian(rs)
    return (2*r)/(1+r) if np.isfinite(r) else np.nan


import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

for ga, gb in PAIRS:
    fig, axes = plt.subplots(2, 3, figsize=(12.5, 8.2))
    for r,(mk,mlab) in enumerate([(0,"hit rate"),(1,"FA rate")]):
        for c,(cond,clab) in enumerate(CONDS):
            ax=axes[r][c]
            hA,fA,itA=matrices(CODES[ga],cond); hB,fB,itB=matrices(CODES[gb],cond)
            mA,mB=(hA,hB) if mk==0 else (fA,fB)
            with np.errstate(invalid="ignore"):
                da=dict(zip(itA,np.nanmean(mA,0))); db=dict(zip(itB,np.nanmean(mB,0)))
            sh=[k for k in da if k in db and np.isfinite(da[k]) and np.isfinite(db[k])]
            x=np.array([da[k] for k in sh]); y=np.array([db[k] for k in sh])
            ax.plot([0,1],[0,1],ls=":",color="#999",lw=1.2)
            ax.scatter(x,y,s=18,c="#455A64",alpha=0.8,edgecolor="white",linewidths=0.4)
            r_s=spearmanr(x,y).correlation
            relA,relB=splithalf(mA),splithalf(mB)
            r_star=r_s/np.sqrt(relA*relB) if relA>0 and relB>0 else np.nan
            ax.text(0.04,0.92,f"r = {r_s:.2f}",transform=ax.transAxes,fontsize=12,fontweight="bold")
            ax.text(0.04,0.83,f"r* = {r_star:.2f}",transform=ax.transAxes,fontsize=9.5,color="#1565C0")
            ax.set_xlim(0,1);ax.set_ylim(0,1);ax.set_aspect("equal")
            ax.set_xticks([0,.5,1]);ax.set_yticks([0,.5,1]);ax.tick_params(labelsize=8)
            if r==0: ax.set_title(clab,fontsize=11)
            if c==0: ax.set_ylabel(f"{mlab}\n\n{LAB[gb]} per-sound rate",fontsize=9.5)
            if r==1: ax.set_xlabel(f"{LAB[ga]} per-sound rate",fontsize=9.5)
    fig.suptitle(f"Intergroup correlation scatter plots: {LAB[ga]} vs {LAB[gb]}",
                 fontsize=13, fontweight="bold")
    fig.text(0.5, 0.005, "r = observed Spearman;  r* = corrected for attenuation (r / "
             r"$\sqrt{\rho_A\,\rho_B}$, split-half reliabilities)",
             ha="center", fontsize=8.5, color="#444")
    fig.tight_layout(rect=[0,0.02,1,0.97])
    tag=f"{ga}_{gb}"
    fig.savefig(OUT/f"reconcile_scatter_{tag}.png",dpi=160,bbox_inches="tight")
    fig.savefig(OUT/f"reconcile_scatter_{tag}.pdf",bbox_inches="tight")
    plt.close(fig)
    print("saved reconcile_scatter_"+tag)
