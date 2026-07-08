#!/usr/bin/env python3
"""Deeper dataset characterization, all as plots, by group x condition:
  (a) response criterion c
  (b) reaction times (hits vs false alarms)
  (c) ISI=0 catch-trial d' (the inclusion-screen variable), with the d'>=2 line
  (d) per-sound difficulty distributions (per-sound hit rate and FA rate)
  (e) trials per participant (session completeness)
Reads the raw .mat trial fields directly (one load per file).
"""
from __future__ import annotations
import sys, re, glob
from pathlib import Path
import numpy as np
import scipy.io as sio
from scipy.stats import norm

HERE = Path(__file__).resolve().parent
BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT = HERE / "dprime_vs_isi_outputs"
GROUPS = [("US", {"PRO","BOS","CAM"}), ("SanBorja", {"SBO","SNB","SBJ"}),
          ("Tsimane", {"NVM","MAJ","MAN","NUM","NUV","CVR"})]
GCOL = {"US":"#1f77b4","SanBorja":"#ff7f0e","Tsimane":"#2E7D32"}
CONDS = [("Industrial-Nature","Environmental"),("Globalized-Music","Music"),("NHS","World song")]
EPS = 1e-2
clip = lambda p: np.clip(p, EPS, 1-EPS)
site = lambda n: (re.match(r"^[^-]+-[^-]+-([A-Za-z]+)_", n) or [None,None]).__getitem__(1) \
                 if re.match(r"^[^-]+-[^-]+-([A-Za-z]+)_", n) else None


def sbase(s):
    s = np.asarray(s).ravel()
    return str(s.item() if s.size==1 else s).split("/")[-1].split("\\")[-1]


def collect(cond, codes):
    files = [f for f in glob.glob(str(BASE/f"*{cond}*.mat"))
             if "Multi-p" not in f and "-original." not in f.lower() and site(Path(f).name) in codes]
    P = {k: [] for k in ["crit","dp","cdp","rt_hit","rt_fa","ntot"]}
    hit_by, fa_by = {}, {}
    for f in files:
        d = sio.loadmat(f, variable_names=["responseTime","repeatPosition","isResponseCorrect","stimulusPresented"])
        rp = np.asarray(d["repeatPosition"]).ravel().astype(float)
        cr = np.asarray(d["isResponseCorrect"]).ravel().astype(float)
        rt = np.asarray(d["responseTime"]).ravel().astype(float)
        st = [sbase(x) for x in np.asarray(d["stimulusPresented"]).ravel()]
        if rp.size < 120: continue          # finished sessions only
        rep, catch, non = rp>1, rp==1, np.isnan(rp)
        if rep.sum()==0 or non.sum()==0: continue
        hit=clip(np.nanmean(cr[rep])); fa=clip(np.nanmean(1-cr[non]))
        ch=clip(np.nanmean(cr[catch])) if catch.sum() else np.nan
        P["dp"].append(norm.ppf(hit)-norm.ppf(fa))
        P["cdp"].append(norm.ppf(ch)-norm.ppf(fa) if np.isfinite(ch) else np.nan)
        P["crit"].append(-0.5*(norm.ppf(hit)+norm.ppf(fa)))
        # RT by response type
        hit_mask = rep & (cr>0.5); fa_mask = non & (cr<0.5)
        P["rt_hit"].append(np.nanmedian(rt[hit_mask]) if hit_mask.sum() else np.nan)
        P["rt_fa"].append(np.nanmedian(rt[fa_mask]) if fa_mask.sum() else np.nan)
        P["ntot"].append(len(rp))
        for j,name in enumerate(st):
            if rep[j]: hit_by.setdefault(name,[]).append(cr[j])
            elif non[j]: fa_by.setdefault(name,[]).append(1-cr[j])
    per_sound_hit = np.array([np.mean(v) for v in hit_by.values()])
    per_sound_fa  = np.array([np.mean(v) for v in fa_by.values()])
    return {k:np.array(v,float) for k,v in P.items()} | dict(psh=per_sound_hit, psf=per_sound_fa)


def main():
    D = {}
    for cond,_ in CONDS:
        for g,codes in GROUPS:
            D[(cond,g)] = collect(cond, codes)
            print(f"{cond:<18}{g:<10} n={len(D[(cond,g)]['dp'])}", flush=True)

    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    glabs=["US","SanBorja","Tsimane"]

    def boxpanel(ax, vals_by_group, ylab=None, hline=None):
        box=[vals_by_group[g] for g in glabs]; box=[v[np.isfinite(v)] for v in box]
        bp=ax.boxplot(box, patch_artist=True, widths=0.6, showfliers=False)
        for p,g in zip(bp["boxes"],glabs): p.set_facecolor(GCOL[g]); p.set_alpha(0.55)
        for m in bp["medians"]: m.set_color("black")
        for xi,(g,v) in enumerate(zip(glabs,box),1):
            ax.scatter(np.random.normal(xi,0.06,len(v)),v,s=6,color=GCOL[g],alpha=0.5,zorder=3)
        if hline is not None: ax.axhline(hline, ls="--", color="#C62828", lw=1.4)
        ax.set_xticks(range(1,4)); ax.set_xticklabels(glabs,fontsize=8)
        ax.grid(axis="y",ls="--",alpha=0.3)
        if ylab: ax.set_ylabel(ylab,fontsize=10)

    def simple(metric, title, fname, ylab, hline=None):
        fig,axes=plt.subplots(1,3,figsize=(12,4),sharey=True)
        for c,(cond,clab) in enumerate(CONDS):
            boxpanel(axes[c], {g:D[(cond,g)][metric] for g in glabs}, ylab if c==0 else None, hline)
            axes[c].set_title(clab,fontsize=11)
        fig.suptitle(title+"\nNo d$'\\geq$2 catch screen (finished sessions only, 120 trials)",
                     fontsize=12,fontweight="bold"); fig.tight_layout(rect=[0,0,1,0.95])
        fig.savefig(OUT/f"{fname}.png",dpi=155,bbox_inches="tight"); fig.savefig(OUT/f"{fname}.pdf",bbox_inches="tight")
        print("saved",fname)

    # (a) criterion
    simple("crit","Response criterion c by group and sound set  (c>0 = conservative)",
           "characterize_criterion","criterion c", hline=0)
    # (c) catch-trial ISI=0 d' with screen line
    simple("cdp","ISI=0 catch-trial d' (inclusion-screen variable); dashed line = screen d'=2",
           "characterize_catch","catch-trial d' (ISI=0)", hline=2.0)
    # (e) trials per participant
    simple("ntot","Trials completed per participant (session completeness)",
           "characterize_trialcounts","# trials")

    # (b) RT: hit vs FA, side by side per group
    fig,axes=plt.subplots(1,3,figsize=(12.5,4.2),sharey=True)
    for c,(cond,clab) in enumerate(CONDS):
        ax=axes[c]; pos=1
        xt,xl=[],[]
        for g in glabs:
            for mk,col in [("rt_hit","#2E7D32"),("rt_fa","#C62828")]:
                v=D[(cond,g)][mk]; v=v[np.isfinite(v)]
                bp=ax.boxplot([v],positions=[pos],widths=0.7,patch_artist=True,showfliers=False)
                bp["boxes"][0].set_facecolor(col); bp["boxes"][0].set_alpha(0.55); bp["medians"][0].set_color("black")
                pos+=1
            xt.append(pos-1.5); xl.append(g); pos+=0.8
        ax.set_xticks(xt); ax.set_xticklabels(glabs,fontsize=8); ax.set_title(clab,fontsize=11)
        ax.grid(axis="y",ls="--",alpha=0.3)
        if c==0: ax.set_ylabel("median RT (s)",fontsize=10)
    axes[0].plot([],[],color="#2E7D32",lw=6,alpha=.55,label="hits"); axes[0].plot([],[],color="#C62828",lw=6,alpha=.55,label="false alarms")
    axes[0].legend(fontsize=8,loc="upper right")
    fig.suptitle("Reaction time: hits vs false alarms, by group and sound set\n"
                 "No d$'\\geq$2 catch screen (finished sessions only, 120 trials)",fontsize=12,fontweight="bold")
    fig.tight_layout(rect=[0,0,1,0.96])
    fig.savefig(OUT/"characterize_rt.png",dpi=155,bbox_inches="tight"); fig.savefig(OUT/"characterize_rt.pdf",bbox_inches="tight")
    print("saved characterize_rt")

    # (d) per-sound difficulty: hit rate (top) and FA rate (bottom), violins by group
    fig,axes=plt.subplots(2,3,figsize=(12.5,7),sharex=True)
    for r,(mk,mlab) in enumerate([("psh","per-sound hit rate"),("psf","per-sound FA rate")]):
        for c,(cond,clab) in enumerate(CONDS):
            ax=axes[r][c]; data=[D[(cond,g)][mk] for g in glabs]
            vp=ax.violinplot(data,showmedians=True,widths=0.8)
            for b,g in zip(vp["bodies"],glabs): b.set_facecolor(GCOL[g]); b.set_alpha(0.55)
            ax.set_xticks(range(1,4)); ax.set_xticklabels(glabs,fontsize=8); ax.set_ylim(0,1); ax.grid(axis="y",ls="--",alpha=0.3)
            if r==0: ax.set_title(clab,fontsize=11)
            if c==0: ax.set_ylabel(mlab,fontsize=10)
    fig.suptitle("Per-sound difficulty: distribution across the 80 sounds, by group\n"
                 "No d$'\\geq$2 catch screen (finished sessions only, 120 trials)",fontsize=12,fontweight="bold")
    fig.tight_layout(rect=[0,0,1,0.97])
    fig.savefig(OUT/"characterize_item_difficulty.png",dpi=155,bbox_inches="tight"); fig.savefig(OUT/"characterize_item_difficulty.pdf",bbox_inches="tight")
    print("saved characterize_item_difficulty")


if __name__ == "__main__":
    main()
