#!/usr/bin/env python3
"""d'-screen sweep, but plotting DISATTENUATED r* = r / sqrt(rel_A rel_B), computed
legitimately: clean split-half reliability, no fill-in resampling. Shows what an
attenuation-corrected version looks like (curves spread apart, corrected toward the
reliability ceiling) without the old fill-in artifact. Dashed grey = observed r for
the same pair, for comparison. Finished sessions only."""
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
CONDS = [("Industrial-Nature","Environmental"),("Globalized-Music","Music"),("NHS","World song")]
PAIRS = [("US","SanBorja","US-SB","#8E24AA"),("US","Tsimane","US-Ts","#C62828"),
         ("SanBorja","Tsimane","SB-Ts","#1565C0")]
SCREENS = [0.0, 1.0, 1.5, 2.0, 2.5]
rng = np.random.default_rng(0)
_cache = {}


def mats(g, cond, screen):
    key=(g,cond,screen)
    if key not in _cache:
        _cache[key]=build_hit_fa_matrices(list_matfiles(BASE, CODES[g], cond, screen, False))
    return _cache[key]


def splithalf(mat, nsplit=150):
    n=mat.shape[0]; rs=[]
    for _ in range(nsplit):
        idx=rng.permutation(n); a,b=idx[:n//2],idx[n//2:]
        with np.errstate(invalid="ignore"):
            va,vb=np.nanmean(mat[a],0),np.nanmean(mat[b],0)
        m=np.isfinite(va)&np.isfinite(vb)
        if m.sum()>=5: rs.append(spearmanr(va[m],vb[m]).correlation)
    r=np.nanmedian(rs); return (2*r)/(1+r) if np.isfinite(r) else np.nan


def robs_rstar(cond, a, b, screen, idx):
    hA=mats(a,cond,screen)[idx]; itA=mats(a,cond,screen)[2]
    hB=mats(b,cond,screen)[idx]; itB=mats(b,cond,screen)[2]
    with np.errstate(invalid="ignore"):
        dA=dict(zip(itA,np.nanmean(hA,0))); dB=dict(zip(itB,np.nanmean(hB,0)))
    sh=[k for k in dA if k in dB and np.isfinite(dA[k]) and np.isfinite(dB[k])]
    if len(sh)<5: return np.nan, np.nan
    x=np.array([dA[k] for k in sh]); y=np.array([dB[k] for k in sh])
    r=spearmanr(x,y).correlation
    relA,relB=splithalf(hA),splithalf(hB)
    rstar=r/np.sqrt(relA*relB) if relA>0 and relB>0 else np.nan
    return r, rstar


import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, axes = plt.subplots(2, 3, figsize=(13.5, 8), sharex=True, sharey=True)
for r,(idx,mlab) in enumerate([(0,"hit rate"),(1,"FA rate")]):
    for c,(cond,clab) in enumerate(CONDS):
        ax=axes[r][c]
        for a,b,plab,col in PAIRS:
            obs=[]; star=[]
            for s in SCREENS:
                ro,rs=robs_rstar(cond,a,b,s,idx); obs.append(ro); star.append(rs)
            ax.plot(SCREENS, star, "o-", color=col, ms=5, label=plab if (r==0 and c==0) else None)
            ax.plot(SCREENS, obs, "--", color=col, lw=1, alpha=0.45)
        ax.axhline(1.0, ls=":", color="#ccc", lw=1); ax.axvline(2.0, ls=":", color="#999", lw=1)
        ax.set_ylim(0,1.15); ax.grid(ls="--", alpha=0.3)
        if r==0: ax.set_title(clab, fontsize=11)
        if c==0: ax.set_ylabel(f"{mlab}\n\ncorrelation", fontsize=9.5)
        if r==1: ax.set_xlabel("passing d' criterion", fontsize=9.5)
axes[0][0].legend(fontsize=8, loc="lower left", title="pair (solid=r*, dashed=obs)")
fig.suptitle("Attenuation-corrected r* (solid) vs observed r (dashed) across the d' criterion "
             ", clean reliability, no fill-in", fontsize=12, fontweight="bold")
fig.tight_layout(rect=[0,0,1,0.96])
fig.savefig(OUT/"dprime_screen_sweep_disatt.png", dpi=160, bbox_inches="tight")
fig.savefig(OUT/"dprime_screen_sweep_disatt.pdf", bbox_inches="tight")
print("saved dprime_screen_sweep_disatt")
