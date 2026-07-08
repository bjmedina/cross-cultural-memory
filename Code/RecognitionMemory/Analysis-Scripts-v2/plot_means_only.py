#!/usr/bin/env python3
"""Item-level between-group correlations, MEANS ONLY (no CIs). 2 rows (hits/FA)
x 3 sound sets x 3 group pairs."""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO","BOS","CAM"), "SanBorja": ("SBO","SNB","SBJ"),
          "Tsimane": ("NVM","MAJ","MAN","NUM","NUV","CVR")}
CONDS = [("Industrial-Nature","Environmental sounds"),("Globalized-Music","Globalized music"),("NHS","NHS (world song)")]
PAIRLAB = ["U.S.–\nSan Borja","U.S.–\nTsimane’","San Borja–\nTsimane’"]
BARCOLS = ["#7E57C2","#5D8AA8","#8D6E63"]
MINRESP = 2

def align3(cond, kind):
    M={}
    for g in GROUPS:
        h,f,it=build_hit_fa_matrices(list_matfiles(BASE,GROUPS[g],cond,2.0,False)); M[g]=((h if kind=="hit" else f),list(it))
    sh=[i for i in M["US"][1] if i in set(M["SanBorja"][1]) and i in set(M["Tsimane"][1])]
    cols=lambda g: M[g][0][:,[{x:k for k,x in enumerate(M[g][1])}[i] for i in sh]]
    return cols("US"),cols("SanBorja"),cols("Tsimane")

def three(U,S,T):
    nU=np.sum(~np.isnan(U),0);nS=np.sum(~np.isnan(S),0);nT=np.sum(~np.isnan(T),0)
    v=(nU>=MINRESP)&(nS>=MINRESP)&(nT>=MINRESP)
    u,s,t=np.nanmean(U[:,v],0),np.nanmean(S[:,v],0),np.nanmean(T[:,v],0)
    return [spearmanr(u,s).correlation,spearmanr(u,t).correlation,spearmanr(s,t).correlation]

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig,axes=plt.subplots(2,3,figsize=(12,7),sharey=True)
x=np.arange(3)
for row,kind in enumerate(["hit","fa"]):
    for col,(cond,clab) in enumerate(CONDS):
        ax=axes[row][col]; r=three(*align3(cond,kind))
        ax.bar(x,r,color=BARCOLS,width=0.66,edgecolor="white")
        for xi,v in zip(x,r): ax.text(xi,v+0.02,f"{v:.2f}",ha="center",fontsize=10,fontweight="bold")
        ax.set_xticks(x); ax.set_xticklabels(PAIRLAB,fontsize=8.5); ax.set_ylim(0,1.0); ax.grid(axis="y",ls="--",alpha=0.3)
        if row==0: ax.set_title(clab,fontsize=12)
        if col==0: ax.set_ylabel(("Hits" if kind=="hit" else "False alarms")+"\n\nitemwise correlation r",fontsize=10.5)
fig.tight_layout()
out=HERE/"dprime_vs_isi_outputs"/"itemwise-bars-means.png"
fig.savefig(out,dpi=170,bbox_inches="tight"); fig.savefig(out.with_suffix(".pdf"),bbox_inches="tight")
print("saved",out)
