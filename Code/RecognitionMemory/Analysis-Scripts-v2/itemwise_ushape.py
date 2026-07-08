#!/usr/bin/env python3
"""Real version of the item-wise schematic: between-group Spearman correlation for
the three group pairs, with the most culturally distant pair (U.S.-Tsimane') in the
CENTER so a dip traces a U. Rows = measure (hit rate, FA rate); columns = sound set.
Fisher-z bootstrap 95% CIs. The U appears only in the music FA panel."""
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
# ordered so the most distant pair (US-Ts) is in the middle -> a dip reads as a U
PAIRS = [("US","SanBorja","U.S.-\nSan Borja"),
         ("US","Tsimane","U.S.-\nTsimane'"),
         ("SanBorja","Tsimane","San Borja-\nTsimane'")]
CONDS = [("Industrial-Nature","Environmental"),("Globalized-Music","Music"),("NHS","World song")]
NBOOT = 2000
rng = np.random.default_rng(0)


def persound(codes, cond):
    h, f, it = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
    with np.errstate(invalid="ignore"):
        return dict(zip(it, np.nanmean(h,0))), dict(zip(it, np.nanmean(f,0)))


def corr_ci(ga, gb, cond, mk):
    hA,fA = persound(CODES[ga],cond); hB,fB = persound(CODES[gb],cond)
    dA,dB = (hA,hB) if mk=="hit" else (fA,fB)
    sh=[k for k in dA if k in dB and np.isfinite(dA[k]) and np.isfinite(dB[k])]
    x=np.array([dA[k] for k in sh]); y=np.array([dB[k] for k in sh]); n=len(x)
    r=spearmanr(x,y).correlation
    zs=np.empty(NBOOT)
    for b in range(NBOOT):
        idx=rng.integers(0,n,n)
        zs[b]=np.arctanh(np.clip(spearmanr(x[idx],y[idx]).correlation,-0.999,0.999))
    zsd=np.nanstd(zs)
    return r, np.tanh(np.arctanh(r)-1.96*zsd), np.tanh(np.arctanh(r)+1.96*zsd)


import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
MC={"hit":"#2E7D32","fa":"#C62828"}
fig,axes=plt.subplots(2,3,figsize=(12,7.5),sharex=True,sharey=True)
xpos=np.arange(3)
for r,(mk,mlab) in enumerate([("hit","hit rate"),("fa","FA rate")]):
    for c,(cond,clab) in enumerate(CONDS):
        ax=axes[r][c]
        rs=[]; los=[]; his=[]
        for ga,gb,_ in PAIRS:
            rr,lo,hi=corr_ci(ga,gb,cond,mk); rs.append(rr); los.append(lo); his.append(hi)
        ax.plot(xpos,rs,"-",color=MC[mk],lw=1.5,zorder=2)
        ax.errorbar(xpos,rs,yerr=[np.array(rs)-np.array(los),np.array(his)-np.array(rs)],
                    fmt="o",color=MC[mk],ms=8,capsize=3,zorder=3)
        for xi,rr in zip(xpos,rs):
            ax.annotate(f"{rr:.2f}",(xi,rr),textcoords="offset points",xytext=(0,10),
                        ha="center",fontsize=8.5,fontweight="bold",color=MC[mk])
        ax.set_ylim(0,1); ax.set_xlim(-0.4,2.4)
        ax.set_xticks(xpos); ax.set_xticklabels([p[2] for p in PAIRS],fontsize=8)
        ax.grid(axis="y",ls="--",alpha=0.3)
        if r==0: ax.set_title(clab,fontsize=11)
        if c==0: ax.set_ylabel(f"{mlab}\n\nbetween-group correlation",fontsize=9.5)
fig.suptitle("Item agreement across the three group pairs (U.S.-Tsimane' centered): "
             "the U appears only for music false alarms",fontsize=12,fontweight="bold")
fig.tight_layout(rect=[0,0,1,0.97])
fig.savefig(OUT/"itemwise_ushape.png",dpi=160,bbox_inches="tight")
fig.savefig(OUT/"itemwise_ushape.pdf",bbox_inches="tight")
print("saved itemwise_ushape")
