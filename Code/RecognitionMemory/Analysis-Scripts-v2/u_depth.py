#!/usr/bin/env python3
r"""U-DEPTH: how much lower the most culturally distant pair (U.S.-Tsimane') sits
below the two flanking pairs, per stim set and measure.

=================  HOW IT IS CALCULATED  =================
Step 1. Per group g, per sound j, compute the mean response rate across the screened,
        finished participants of that group:
            hit rate  = mean over repeat presentations of that sound  (was it caught)
            FA rate   = mean over non-repeat presentations             (falsely called old)
        -> three per-sound vectors v_US, v_SB, v_Ts (one number per sound).
Step 2. Keep only sounds present in ALL THREE groups (intersection); N ~ 80 sounds.
Step 3. Three between-group Spearman rank correlations across those N sounds:
            r_US_SB = corr(v_US, v_SB)
            r_US_Ts = corr(v_US, v_Ts)     <- most culturally distant pair
            r_SB_Ts = corr(v_SB, v_Ts)
Step 4. U-depth = mean(r_US_SB, r_SB_Ts) - r_US_Ts.
        Interpretation: with U.S.-Tsimane' placed in the CENTER of the three bars,
        a POSITIVE U-depth means that middle pair dips below the two that flank it,
        i.e. the "U". U-depth = 0 means no dip; larger = deeper cultural divergence.
Step 5. Uncertainty by a dependence-preserving bootstrap over SOUNDS (the unit of the
        correlation; this design is stimulus-limited so effective N = number of
        sounds). Each iteration resamples N sounds WITH REPLACEMENT and recomputes
        all three correlations on the SAME resampled sound set (preserving their
        dependence), then U-depth. Report observed U-depth, the 2.5/97.5 percentile
        95% CI, and the bootstrap probability that U-depth > 0.
=========================================================
Screen: d'>=2 (ISI=0 catch), finished sessions only. Measure: observed Spearman r.
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
NBOOT = 4000
rng = np.random.default_rng(0)


def persound(g, cond, idx):
    h,f,it = build_hit_fa_matrices(list_matfiles(BASE, CODES[g], cond, 2.0, False))
    with np.errstate(invalid="ignore"):
        v = np.nanmean(h if idx==0 else f, 0)
    return dict(zip(it, v))


def aligned3(cond, idx):
    dU, dS, dT = persound("US",cond,idx), persound("SB",cond,idx), persound("Ts",cond,idx)
    sh = [k for k in dU if k in dS and k in dT
          and np.isfinite(dU[k]) and np.isfinite(dS[k]) and np.isfinite(dT[k])]
    return (np.array([dU[k] for k in sh]), np.array([dS[k] for k in sh]),
            np.array([dT[k] for k in sh]))


def udepth(U, S, T):
    r_US_SB = spearmanr(U, S).correlation
    r_US_Ts = spearmanr(U, T).correlation
    r_SB_Ts = spearmanr(S, T).correlation
    return (r_US_SB + r_SB_Ts)/2 - r_US_Ts, (r_US_SB, r_US_Ts, r_SB_Ts)


rows = {}
print(f"{'measure':<8}{'stim set':<14}{'N':>4}{'r_USSB':>8}{'r_USTs':>8}{'r_SBTs':>8}"
      f"{'U-depth':>9}{'95% CI':>16}{'P(>0)':>7}")
for idx, mlab in [(0,"hit"),(1,"fa")]:
    for cond, clab in CONDS:
        U,S,T = aligned3(cond, idx); n=len(U)
        D, (r1,r2,r3) = udepth(U,S,T)
        boot = np.empty(NBOOT)
        for b in range(NBOOT):
            ix = rng.integers(0, n, n)
            boot[b] = udepth(U[ix], S[ix], T[ix])[0]
        lo, hi = np.percentile(boot, [2.5, 97.5]); pgt = np.mean(boot > 0)
        rows[(mlab,clab)] = dict(n=n, D=D, lo=lo, hi=hi, p=pgt, r=(r1,r2,r3))
        print(f"{mlab:<8}{clab:<14}{n:>4}{r1:>8.2f}{r2:>8.2f}{r3:>8.2f}"
              f"{D:>9.3f}{f'[{lo:+.2f},{hi:+.2f}]':>16}{pgt:>7.2f}")
    print()

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, axes = plt.subplots(1, 2, figsize=(11, 4.8), sharey=True)
COLc = {"Environmental":"#2E7D32","Music":"#C62828","World song":"#1565C0"}
for ax,(idx,mlab,title) in zip(axes,[(0,"hit","Hit rate"),(1,"fa","False-alarm rate")]):
    labs=[c[1] for c in CONDS]; x=np.arange(len(labs))
    D=[rows[(mlab,l)]["D"] for l in labs]
    lo=[rows[(mlab,l)]["D"]-rows[(mlab,l)]["lo"] for l in labs]
    hi=[rows[(mlab,l)]["hi"]-rows[(mlab,l)]["D"] for l in labs]
    ax.bar(x, D, color=[COLc[l] for l in labs], alpha=0.85)
    ax.errorbar(x, D, yerr=[lo,hi], fmt="none", ecolor="black", capsize=4, lw=1.2)
    ax.axhline(0, color="#555", lw=1)
    ax.set_xticks(x); ax.set_xticklabels(labs, fontsize=9)
    ax.set_title(title, fontsize=11); ax.grid(axis="y", ls="--", alpha=0.3)
    for xi,l in zip(x,labs):
        ax.text(xi, rows[(mlab,l)]["hi"]+0.01, f"P(>0)={rows[(mlab,l)]['p']:.2f}",
                ha="center", fontsize=7.5)
axes[0].set_ylabel("U-depth  =  mean(US-SB, SB-Ts) - US-Ts", fontsize=10)
fig.suptitle("U-depth: how far U.S.-Tsimane' sits below the flanking pairs "
             "(higher = deeper cultural divergence)", fontsize=12, fontweight="bold")
fig.tight_layout(rect=[0,0,1,0.95])
fig.savefig(OUT/"u_depth.png", dpi=160, bbox_inches="tight")
fig.savefig(OUT/"u_depth.pdf", bbox_inches="tight")
print("saved u_depth")
