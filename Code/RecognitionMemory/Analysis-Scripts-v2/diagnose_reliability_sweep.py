#!/usr/bin/env python3
"""Does the Tsimane' music item signal appear if we tighten who we include?

Two sweeps of the per-sound HIT reliability (Spearman-Brown split-half):

  A. CATCH screen (clean): raise the d' threshold on the ISI=0 immediate-repeat
     trials. These are separate trials from the item measure, so selecting on them
     is not circular.
  B. MEMORY screen (secondary, partly circular): at catch d'>=2, additionally require
     each participant's own ISI=16 d' on that condition to exceed a threshold. This
     asks "keep only people who could actually do this task on this material."
     CAVEAT: it conditions on the same responses the item measure is built from. It
     restricts range rather than being independent, so read it as suggestive.

If the Tsimane' music curve RISES with stricter screens, the collapse reflects
guessing / task difficulty. If it stays flat near 0.2, it is genuine representational
non-differentiation.
"""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr, norm

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
CATCH = [0.0, 1.0, 2.0, 2.5, 3.0]
MEMT  = [-9.0, 0.0, 0.25, 0.5, 0.75]
EPS = 1e-2
rng = np.random.default_rng(0)


def sb(mat, nsplit=150):
    n = mat.shape[0]
    if n < 6: return np.nan
    rs = []
    for _ in range(nsplit):
        idx = rng.permutation(n); a, b = idx[:n//2], idx[n//2:]
        with np.errstate(invalid="ignore"):
            va, vb = np.nanmean(mat[a],0), np.nanmean(mat[b],0)
        m = np.isfinite(va) & np.isfinite(vb)
        if m.sum() >= 5: rs.append(spearmanr(va[m], vb[m]).correlation)
    if not rs: return np.nan
    r = np.nanmedian(rs)
    return (2*r)/(1+r) if np.isfinite(r) else np.nan


def per_participant_dprime(h, f):
    with np.errstate(invalid="ignore"):
        hr = np.nanmean(h, 1); fr = np.nanmean(f, 1)
    c = lambda p: np.clip(p, EPS, 1-EPS)
    return norm.ppf(c(hr)) - norm.ppf(c(fr))


relA = {}; relB = {}; nA = {}; nB = {}
for cond, clab in CONDS:
    for g, codes in GROUPS:
        # ---- sweep A: catch d' threshold ----
        for t in CATCH:
            h, f, _ = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, t, False))
            relA[(clab, g, t)] = sb(h); nA[(clab, g, t)] = h.shape[0]
        # ---- sweep B: memory d' threshold, at catch>=2 ----
        h2, f2, _ = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
        dp = per_participant_dprime(h2, f2)
        for t in MEMT:
            keep = dp > t
            relB[(clab, g, t)] = sb(h2[keep]) if keep.sum() >= 6 else np.nan
            nB[(clab, g, t)] = int(keep.sum())

print("=== Tsimane' MUSIC detail ===")
print(f"{'sweep':<8}{'threshold':>10}{'N':>5}{'hit reliability':>18}")
for t in CATCH:
    print(f"{'catch':<8}{t:>10.2f}{nA[('Music','Tsimane',t)]:>5}{relA[('Music','Tsimane',t)]:>18.2f}")
for t in MEMT:
    lab = "none" if t < -1 else f"{t:.2f}"
    print(f"{'memory':<8}{lab:>10}{nB[('Music','Tsimane',t)]:>5}{relB[('Music','Tsimane',t)]:>18.2f}")

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, axes = plt.subplots(2, 3, figsize=(13.5, 8), sharey=True)
for c, (cond, clab) in enumerate(CONDS):
    ax = axes[0][c]
    for g, _ in GROUPS:
        ax.plot(CATCH, [relA[(clab,g,t)] for t in CATCH], "o-", color=GCOL[g],
                label=GLAB[g] if c == 0 else None)
    ax.set_title(clab, fontsize=11); ax.set_ylim(0, 1); ax.grid(ls="--", alpha=.3)
    ax.set_xlabel("catch-trial d' threshold (ISI=0)", fontsize=9.5)
    ax2 = axes[1][c]
    xs = np.arange(len(MEMT))
    for g, _ in GROUPS:
        ax2.plot(xs, [relB[(clab,g,t)] for t in MEMT], "o-", color=GCOL[g])
    ax2.set_xticks(xs); ax2.set_xticklabels(["none","0",".25",".50",".75"], fontsize=8)
    ax2.set_ylim(0, 1); ax2.grid(ls="--", alpha=.3)
    ax2.set_xlabel("additional ISI=16 d' threshold", fontsize=9.5)
axes[0][0].set_ylabel("hit reliability $\\rho_{SB}$\n(A: catch screen)", fontsize=10)
axes[1][0].set_ylabel("hit reliability $\\rho_{SB}$\n(B: + memory screen)", fontsize=10)
axes[0][0].legend(fontsize=8, loc="lower left")
fig.suptitle("Does tightening inclusion recover the item signal? Tsimane' music stays flat",
             fontsize=12.5, fontweight="bold")
fig.tight_layout(rect=[0,0,1,0.96])
fig.savefig(OUT/"diagnose_reliability_sweep.png", dpi=160, bbox_inches="tight")
print("\nsaved diagnose_reliability_sweep.png")
