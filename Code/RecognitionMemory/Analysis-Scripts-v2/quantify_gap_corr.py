#!/usr/bin/env python3
"""Quantify the two things the reconciliation scatter shows, separately:

  GAP (performance/level offset) = mean_A - mean_B of the per-sound rates
      (paired over the same sounds; equals the group difference in the
      performance figure; the vertical offset from the diagonal).
  PATTERN (agreement)            = Spearman r of the same paired vectors
      (rank-based, invariant to the gap; the tightness of the scatter).

CIs from a dependence-preserving bootstrap over sounds (resample sound indices
jointly, recompute Gap and r). r-CI via Fisher-z (SD of atanh(r_boot)); Gap-CI
percentile. Paired Wilcoxon tests whether the gap != 0. Screened sample (d'>=2)."""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr, wilcoxon

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT = HERE / "dprime_vs_isi_outputs"
CODES = {"US": ("PRO","BOS","CAM"), "SanBorja": ("SBO","SNB","SBJ"),
         "Tsimane": ("NVM","MAJ","MAN","NUM","NUV","CVR")}
LAB = {"US":"U.S.","SanBorja":"San Borja","Tsimane":"Tsimane'"}
PAIRS = [("US","SanBorja"), ("US","Tsimane"), ("SanBorja","Tsimane")]
CONDS = [("Industrial-Nature","Env"), ("Globalized-Music","Music"), ("NHS","World song")]
NBOOT = 800
rng = np.random.default_rng(0)


def matrices(codes, cond):
    h, f, it = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
    return h, f, list(it)


def splithalf(mat, nsplit=300):
    n = mat.shape[0]; rs=[]
    for _ in range(nsplit):
        idx=rng.permutation(n); a,b=idx[:n//2],idx[n//2:]
        with np.errstate(invalid="ignore"):
            va,vb=np.nanmean(mat[a],0),np.nanmean(mat[b],0)
        m=np.isfinite(va)&np.isfinite(vb)
        if m.sum()>=5: rs.append(spearmanr(va[m],vb[m]).correlation)
    r=np.nanmedian(rs)
    return (2*r)/(1+r) if np.isfinite(r) else np.nan


def paired(ga, gb, cond, mk):
    hA,fA,itA = matrices(CODES[ga],cond); hB,fB,itB = matrices(CODES[gb],cond)
    mA,mB = (hA,hB) if mk=="hit" else (fA,fB)
    with np.errstate(invalid="ignore"):
        dA=dict(zip(itA,np.nanmean(mA,0))); dB=dict(zip(itB,np.nanmean(mB,0)))
    sh=[k for k in dA if k in dB and np.isfinite(dA[k]) and np.isfinite(dB[k])]
    x=np.array([dA[k] for k in sh]); y=np.array([dB[k] for k in sh])
    return x, y, splithalf(mA), splithalf(mB)


def analyze(x, y, relA, relB):
    gap = x.mean()-y.mean()
    r = spearmanr(x,y).correlation
    rstar = r/np.sqrt(relA*relB) if relA>0 and relB>0 else np.nan
    n = len(x)
    gaps=np.empty(NBOOT); zs=np.empty(NBOOT)
    for b in range(NBOOT):
        idx = rng.integers(0,n,n)
        xb,yb = x[idx],y[idx]
        gaps[b]=xb.mean()-yb.mean()
        rb=spearmanr(xb,yb).correlation
        zs[b]=np.arctanh(np.clip(rb,-0.999,0.999))
    glo,ghi=np.percentile(gaps,[2.5,97.5])
    zsd=np.nanstd(zs)
    rlo,rhi=np.tanh(np.arctanh(r)-1.96*zsd), np.tanh(np.arctanh(r)+1.96*zsd)
    p = wilcoxon(x-y).pvalue if np.any(x-y!=0) else np.nan
    return dict(n=n,gap=gap,glo=glo,ghi=ghi,r=r,rlo=rlo,rhi=rhi,p=p,
                rstar=rstar,relA=relA,relB=relB)


rows=[]
print(f"{'pair':<20}{'cond':<10}{'meas':<5}{'N':>4}"
      f"{'GAP (A-B) [95% CI]':>26}{'p':>9}   {'r_obs [95% CI]':>22}"
      f"{'relA':>6}{'relB':>6}{'r* disatt':>11}")
for ga,gb in PAIRS:
    for cond,clab in CONDS:
        for mk in ("hit","fa"):
            x,y,relA,relB=paired(ga,gb,cond,mk)
            a=analyze(x,y,relA,relB); a.update(pair=f"{LAB[ga]} vs {LAB[gb]}",cond=clab,meas=mk)
            rows.append(a)
            print(f"{a['pair']:<8}{clab:<10}{mk:<5}{a['n']:>4}"
                  f"{a['gap']:>10.2f} [{a['glo']:+.2f},{a['ghi']:+.2f}]{a['p']:>9.1e}"
                  f"   {a['r']:>5.2f} [{a['rlo']:.2f},{a['rhi']:.2f}]"
                  f"{relA:>6.2f}{relB:>6.2f}{a['rstar']:>11.2f}")
    print()

# figure: one scatter panel per group pair. x = performance gap, y = correlation.
# 6 points/panel (3 conditions x hit/FA), each labeled by condition. Shows the two
# quantities are independent and isolates the one low-correlation outlier.
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
MC={"hit":"#2E7D32","fa":"#C62828"}
CABB={"Env":"Env","Music":"Music","World song":"World"}
pairs_order=[f"{LAB[a]} vs {LAB[b]}" for a,b in PAIRS]
fig,axes=plt.subplots(1,3,figsize=(13.5,4.8),sharex=True,sharey=True)
for ax,pl in zip(axes,pairs_order):
    sub=[a for a in rows if a["pair"]==pl]
    for a in sub:
        col=MC[a["meas"]]
        ax.errorbar(a["gap"],a["r"],yerr=[[a["r"]-a["rlo"]],[a["rhi"]-a["r"]]],
                    xerr=[[a["gap"]-a["glo"]],[a["ghi"]-a["gap"]]],
                    fmt="o",color=col,ms=9,capsize=2,lw=1,alpha=0.9,zorder=3)
        ax.annotate(CABB[a["cond"]],(a["gap"],a["r"]),textcoords="offset points",
                    xytext=(7,4),fontsize=8,color=col)
    ax.set_title(pl,fontsize=11)
    ax.set_xlim(-0.03,0.5); ax.set_ylim(0,1)
    ax.grid(ls="--",alpha=0.3)
    ax.set_xlabel("performance gap\n(mean$_A$ - mean$_B$ across sounds)",fontsize=9.5)
axes[0].set_ylabel("between-group correlation\n(Spearman r)",fontsize=9.5)
hl=[plt.Line2D([],[],marker='o',ls='',color=MC['hit'],label='hit rate'),
    plt.Line2D([],[],marker='o',ls='',color=MC['fa'],label='FA rate')]
axes[2].legend(handles=hl,fontsize=9,loc="lower right",framealpha=0.95)
fig.suptitle("Performance gap and item-pattern correlation are independent",
             fontsize=13,fontweight="bold")
fig.tight_layout(rect=[0,0,1,0.97])
fig.savefig(OUT/"quantify_gap_corr.png",dpi=160,bbox_inches="tight")
fig.savefig(OUT/"quantify_gap_corr.pdf",bbox_inches="tight")
print("saved quantify_gap_corr")
