#!/usr/bin/env python3
"""Item-level bar figure (hits/FA x 3 sound sets x 3 pairs) with Fisher-z 95% CIs,
reliability ceilings, AND paired-contrast significance drawn on as brackets.
Stars from the recentered-null paired bootstrap; a filled marker flags contrasts
that survive Holm correction across the 18 tests."""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402
from python.split_half import calculate_split_half_reliability  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
CONDS = [("Industrial-Nature", "Environmental sounds"), ("Globalized-Music", "Globalized music"),
         ("NHS", "NHS (world song)")]
# bar order: US-SB, US-Ts (center), SB-Ts
PAIRS = [("US", "SanBorja"), ("US", "Tsimane"), ("SanBorja", "Tsimane")]
PAIRLAB = ["U.S.–\nSan Borja", "U.S.–\nTsimane’", "San Borja–\nTsimane’"]
BARCOLS = ["#7E57C2", "#5D8AA8", "#8D6E63"]
# contrasts among the 3 bars (i,j) and which pairwise correlation key
CONTRASTS = [(0, 1), (0, 2), (1, 2)]
MINRESP, B = 2, 1500


def align3(cond, kind):
    M = {}
    for g in GROUPS:
        h, f, it = build_hit_fa_matrices(list_matfiles(BASE, GROUPS[g], cond, 2.0, False))
        M[g] = ((h if kind == "hit" else f), list(it))
    sh = [i for i in M["US"][1] if i in set(M["SanBorja"][1]) and i in set(M["Tsimane"][1])]
    cols = lambda g: M[g][0][:, [ {x:k for k,x in enumerate(M[g][1])}[i] for i in sh]]
    return cols("US"), cols("SanBorja"), cols("Tsimane")


def three(U, S, T):
    nU=np.sum(~np.isnan(U),0); nS=np.sum(~np.isnan(S),0); nT=np.sum(~np.isnan(T),0)
    v=(nU>=MINRESP)&(nS>=MINRESP)&(nT>=MINRESP)
    u,s,t=np.nanmean(U[:,v],0),np.nanmean(S[:,v],0),np.nanmean(T[:,v],0)
    return [spearmanr(u,s).correlation, spearmanr(u,t).correlation, spearmanr(s,t).correlation]


def stars(p):
    return "***" if p<0.001 else "**" if p<0.01 else "*" if p<0.05 else ""


def main():
    rng = np.random.default_rng(0)
    cells = {}  # (kind,cond)-> dict(r, ci, ceil, cp[3 contrast p], cd[3 diff])
    all_p = []
    for cond, _ in CONDS:
        for kind in ("hit", "fa"):
            U, S, T = align3(cond, kind)
            r = three(U, S, T)
            nU,nS,nT = U.shape[0],S.shape[0],T.shape[0]
            relU=calculate_split_half_reliability(U,U,np.arange(U.shape[1]),n_splits=300).sb_hit
            relS=calculate_split_half_reliability(S,S,np.arange(S.shape[1]),n_splits=300).sb_hit
            relT=calculate_split_half_reliability(T,T,np.arange(T.shape[1]),n_splits=300).sb_hit
            rel=[relU,relS,relT]
            ceil=[np.sqrt(rel[0]*rel[1]),np.sqrt(rel[0]*rel[2]),np.sqrt(rel[1]*rel[2])]
            boot=np.empty((B,3))
            for bi in range(B):
                boot[bi]=three(U[rng.integers(0,nU,nU)],S[rng.integers(0,nS,nS)],T[rng.integers(0,nT,nT)])
            # Fisher-z CI per bar
            ci=[]
            for k in range(3):
                z=np.arctanh(np.clip(boot[:,k],-.999,.999)); sd=z.std(ddof=1)
                ci.append((np.tanh(np.arctanh(r[k])-1.96*sd), np.tanh(np.arctanh(r[k])+1.96*sd)))
            # contrast p (recentered)
            cp=[]; cd=[]
            for (i,j) in CONTRASTS:
                d=r[i]-r[j]; db=boot[:,i]-boot[:,j]
                p=max(np.mean(np.abs(db-db.mean())>=abs(d)),1/(B+1)); cp.append(p); cd.append(d); all_p.append(p)
            cells[(kind,cond)]=dict(r=r,ci=ci,ceil=ceil,cp=cp,cd=cd)
    # Holm across 18
    ps=np.array(all_p); order=np.argsort(ps); m=len(ps); holm=np.zeros(m,bool)
    for rank,idx in enumerate(order):
        if ps[idx]<=0.05/(m-rank): holm[idx]=True
        else: break
    # map holm back per cell/contrast (order of all_p append)
    it=iter(range(m))
    for cond,_ in CONDS:
        for kind in ("hit","fa"):
            cells[(kind,cond)]["holm"]=[holm[next(it)] for _ in CONTRASTS]

    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(2,3,figsize=(13,8.2),sharey=True)
    x=np.arange(3)
    for row,kind in enumerate(["hit","fa"]):
        for col,(cond,clab) in enumerate(CONDS):
            ax=axes[row][col]; C=cells[(kind,cond)]
            ax.bar(x,C["r"],color=BARCOLS,width=0.62,edgecolor="white",zorder=3)
            for k in range(3):
                lo,hi=C["ci"][k]
                ax.plot([k,k],[lo,hi],color="black",lw=1.5,zorder=6)
                for yy in (lo,hi): ax.plot([k-0.09,k+0.09],[yy,yy],color="black",lw=1.5,zorder=6)
                ax.plot([k-0.31,k+0.31],[C["ceil"][k]]*2,color="#C62828",lw=2,zorder=5)
                ax.text(k,max(hi,C["ceil"][k])+0.02,f"{C['r'][k]:.2f}",ha="center",fontsize=8,fontweight="bold")
            # significance brackets for p<.05 contrasts, staggered
            sig=[(ci_idx,(i,j)) for ci_idx,(i,j) in enumerate(CONTRASTS) if C["cp"][ci_idx]<0.05]
            base=max(max(hi for lo,hi in C["ci"]),max(C["ceil"]))+0.07
            for h,(ci_idx,(i,j)) in enumerate(sig):
                yb=base+0.11*h
                ax.plot([i,i,j,j],[yb-0.02,yb,yb,yb-0.02],color="black",lw=1.2)
                mark=stars(C["cp"][ci_idx])
                if C["holm"][ci_idx]: mark+=r"$^{\dagger}$"
                ax.text((i+j)/2,yb+0.005,mark,ha="center",va="bottom",fontsize=11,fontweight="bold")
            ax.set_xticks(x); ax.set_xticklabels(PAIRLAB,fontsize=8)
            ax.set_ylim(0,1.32); ax.grid(axis="y",ls="--",alpha=0.3)
            if row==0: ax.set_title(clab,fontsize=12)
            if col==0: ax.set_ylabel(("Hits" if kind=="hit" else "False alarms")+"\n\nitemwise correlation r",fontsize=10.5)
    axes[0][2].plot([],[],color="black",lw=1.5,label="95% CI (Fisher-z)")
    axes[0][2].plot([],[],color="#C62828",lw=2,label=r"ceiling $\sqrt{\rho_A\rho_B}$")
    axes[0][2].legend(loc="upper right",fontsize=8,framealpha=.9)
    fig.text(0.5,0.005,r"brackets: paired-bootstrap contrast,  * $p<.05$, ** $p<.01$, *** $p<.001$,  $\dagger$ survives Holm",
             ha="center",fontsize=9)
    fig.tight_layout(rect=[0,0.02,1,1])
    out=HERE/"dprime_vs_isi_outputs"/"itemwise-bars-sig.png"
    fig.savefig(out,dpi=170,bbox_inches="tight"); fig.savefig(out.with_suffix(".pdf"),bbox_inches="tight")
    print("saved",out)
    for cond,_ in CONDS:
        for kind in ("hit","fa"):
            C=cells[(kind,cond)]
            for ci_idx,(i,j) in enumerate(CONTRASTS):
                if C["cp"][ci_idx]<0.05:
                    print(f"  {kind} {cond[:6]:<6} bars{i}{j} d={C['cd'][ci_idx]:+.2f} p={C['cp'][ci_idx]:.3f} holm={C['holm'][ci_idx]}")


if __name__ == "__main__":
    main()
