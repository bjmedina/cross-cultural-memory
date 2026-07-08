#!/usr/bin/env python3
r"""U-depth computed BOTH ways: on the observed Spearman r and on the
attenuation-corrected r* = r / sqrt(rho_A rho_B).

Same U-depth definition and sound-level bootstrap as u_depth.py (see that file for
the full step-by-step). The only change: before forming U-depth we divide each of
the three pair correlations by the geometric mean of the two groups' split-half
reliabilities. Reliabilities are estimated once (Spearman-Brown split-half over
participants) and held fixed inside the bootstrap, which resamples SOUNDS.

A cell is FLAGGED (unreliable) when any involved group's reliability < 0.5, because
then r* is unstable and can exceed 1 (e.g. Tsimane' music hits, rho ~ 0.21).
Screen d'>=2, finished sessions only.
"""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT = HERE / "dprime_vs_isi_outputs"
CODES = {"US": ("PRO","BOS","CAM"), "SB": ("SBO","SNB","SBJ"),
         "Ts": ("NVM","MAJ","MAN","NUM","NUV","CVR")}
CONDS = [("Industrial-Nature","Environmental"),("Globalized-Music","Music"),("NHS","World song")]
NBOOT = 3000
RELFLOOR = 0.5
rng = np.random.default_rng(0)


def load(g, cond, idx):
    h,f,it = build_hit_fa_matrices(list_matfiles(BASE, CODES[g], cond, 2.0, False))
    return (h if idx==0 else f), list(it)


def splithalf(mat, nsplit=200):
    n=mat.shape[0]; rs=[]
    for _ in range(nsplit):
        p=rng.permutation(n); a,b=p[:n//2],p[n//2:]
        with np.errstate(invalid="ignore"):
            va,vb=np.nanmean(mat[a],0),np.nanmean(mat[b],0)
        m=np.isfinite(va)&np.isfinite(vb)
        if m.sum()>=5: rs.append(spearmanr(va[m],vb[m]).correlation)
    r=np.nanmedian(rs); return (2*r)/(1+r) if np.isfinite(r) else np.nan


def prep(cond, idx):
    mats={}; rels={}; vecs={}
    for g in CODES:
        M,it = load(g,cond,idx); mats[g]=(M,it)
        rels[g]=splithalf(M)
        with np.errstate(invalid="ignore"):
            vecs[g]=dict(zip(it,np.nanmean(M,0)))
    dU,dS,dT = vecs["US"],vecs["SB"],vecs["Ts"]
    sh=[k for k in dU if k in dS and k in dT
        and np.isfinite(dU[k]) and np.isfinite(dS[k]) and np.isfinite(dT[k])]
    U=np.array([dU[k] for k in sh]); S=np.array([dS[k] for k in sh]); T=np.array([dT[k] for k in sh])
    return U,S,T,rels


def depths(U,S,T,rels):
    rUS_SB=spearmanr(U,S).correlation; rUS_Ts=spearmanr(U,T).correlation; rSB_Ts=spearmanr(S,T).correlation
    D_obs=(rUS_SB+rSB_Ts)/2 - rUS_Ts
    def star(r,a,b): return r/np.sqrt(rels[a]*rels[b]) if rels[a]>0 and rels[b]>0 else np.nan
    D_cor=(star(rUS_SB,"US","SB")+star(rSB_Ts,"SB","Ts"))/2 - star(rUS_Ts,"US","Ts")
    return D_obs, D_cor


rows={}
print(f"{'meas':<5}{'stim set':<14}{'relUS':>6}{'relSB':>6}{'relTs':>6}"
      f"{'D_obs':>8}{'D_obs 95%CI':>16}{'D_cor':>8}{'D_cor 95%CI':>16}  flag")
for idx,mlab in [(0,"hit"),(1,"fa")]:
    for cond,clab in CONDS:
        U,S,T,rels = prep(cond,idx)
        Do,Dc = depths(U,S,T,rels); n=len(U)
        bo=np.empty(NBOOT); bc=np.empty(NBOOT)
        for b in range(NBOOT):
            ix=rng.integers(0,n,n)
            bo[b],bc[b]=depths(U[ix],S[ix],T[ix],rels)
        loo,hio=np.percentile(bo,[2.5,97.5]); loc,hic=np.percentile(bc,[2.5,97.5])
        flag = min(rels.values())<RELFLOOR
        rows[(mlab,clab)]=dict(Do=Do,loo=loo,hio=hio,Dc=Dc,loc=loc,hic=hic,flag=flag,
                               po=np.mean(bo>0),pc=np.mean(bc>0))
        print(f"{mlab:<5}{clab:<14}{rels['US']:>6.2f}{rels['SB']:>6.2f}{rels['Ts']:>6.2f}"
              f"{Do:>8.2f}{f'[{loo:+.2f},{hio:+.2f}]':>16}{Dc:>8.2f}{f'[{loc:+.2f},{hic:+.2f}]':>16}"
              f"  {'LOW-REL' if flag else ''}")
    print()

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, axes = plt.subplots(1, 2, figsize=(12, 5), sharey=True)
labs=[c[1] for c in CONDS]; x=np.arange(len(labs)); w=0.36
for ax,(idx,mlab,title) in zip(axes,[(0,"hit","Hit rate"),(1,"fa","False-alarm rate")]):
    Do=[rows[(mlab,l)]["Do"] for l in labs]; Dc=[rows[(mlab,l)]["Dc"] for l in labs]
    eo=[[rows[(mlab,l)]["Do"]-rows[(mlab,l)]["loo"] for l in labs],
        [rows[(mlab,l)]["hio"]-rows[(mlab,l)]["Do"] for l in labs]]
    ec=[[rows[(mlab,l)]["Dc"]-rows[(mlab,l)]["loc"] for l in labs],
        [rows[(mlab,l)]["hic"]-rows[(mlab,l)]["Dc"] for l in labs]]
    ax.bar(x-w/2, Do, w, color="#607D8B", label="observed r")
    ax.bar(x+w/2, Dc, w, color="#1565C0", label="corrected for attenuation r*")
    ax.errorbar(x-w/2, Do, yerr=eo, fmt="none", ecolor="black", capsize=3, lw=1)
    ax.errorbar(x+w/2, Dc, yerr=ec, fmt="none", ecolor="black", capsize=3, lw=1)
    for xi,l in zip(x,labs):
        if rows[(mlab,l)]["flag"]:
            ax.text(xi+w/2, rows[(mlab,l)]["Dc"]+0.02, "low-rel\n(untrustworthy)",
                    ha="center", va="bottom", fontsize=7, color="#C62828", fontweight="bold")
    ax.axhline(0, color="#555", lw=1); ax.set_xticks(x); ax.set_xticklabels(labs, fontsize=9)
    ax.set_title(title, fontsize=11); ax.grid(axis="y", ls="--", alpha=0.3)
axes[0].set_ylabel("U-depth  =  mean(US-SB, SB-Ts) - US-Ts", fontsize=10)
axes[0].legend(fontsize=8.5, loc="upper left")
fig.suptitle("U-depth, observed vs corrected for attenuation "
             "(higher = deeper U.S.-Tsimane' divergence)", fontsize=12, fontweight="bold")
fig.tight_layout(rect=[0,0,1,0.95])
fig.savefig(OUT/"u_depth_corrected.png", dpi=160, bbox_inches="tight")
fig.savefig(OUT/"u_depth_corrected.pdf", bbox_inches="tight")
print("saved u_depth_corrected")
