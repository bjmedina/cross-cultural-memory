#!/usr/bin/env python3
"""Which per-sound quantity is most STABLE (reliable) for showing group differences?

Split-half reliability (Spearman-Brown, Spearman rank) of four candidate per-sound
measures, per group x condition:
  hit rate, FA rate, corrected recognition CR = hit - FA, and per-sound d'.
Higher = more stable = better ceiling for any between-group comparison. Finished
sessions only, d'>=2 screen."""
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
EPS = 1e-2
clip = lambda p: np.clip(p, EPS, 1-EPS)
rng = np.random.default_rng(0)


def measures(h, f):
    with np.errstate(invalid="ignore"):
        hr, fr = np.nanmean(h,0), np.nanmean(f,0)
    dp = norm.ppf(clip(hr)) - norm.ppf(clip(fr))
    return {"hit": hr, "fa": fr, "cr": hr - fr, "dprime": dp}


def splithalf(h, f, key, nsplit=300):
    n = h.shape[0]; rs = []
    for _ in range(nsplit):
        idx = rng.permutation(n); a, b = idx[:n//2], idx[n//2:]
        va = measures(h[a], f[a])[key]; vb = measures(h[b], f[b])[key]
        m = np.isfinite(va) & np.isfinite(vb)
        if m.sum() >= 5: rs.append(spearmanr(va[m], vb[m]).correlation)
    r = np.nanmedian(rs)
    return (2*r)/(1+r) if np.isfinite(r) else np.nan


KEYS = [("hit","hit rate"),("fa","FA rate"),("cr","corrected recog."),("dprime","d' (per sound)")]
R = {}
print(f"{'cond':<14}{'group':<10}" + "".join(f"{k[1]:>18}" for k in KEYS))
for cond, clab in CONDS:
    for g, codes in GROUPS:
        h,f,_ = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
        R[(clab,g)] = {k: splithalf(h,f,k) for k,_ in KEYS}
        print(f"{clab:<14}{GLAB[g]:<10}" + "".join(f"{R[(clab,g)][k]:>18.2f}" for k,_ in KEYS))
    print()

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, axes = plt.subplots(1, 3, figsize=(13.5, 4.6), sharey=True)
x = np.arange(len(KEYS)); w = 0.26
for c,(cond,clab) in enumerate(CONDS):
    ax = axes[c]
    for k,(g,_) in enumerate(GROUPS):
        vals = [R[(clab,g)][kk] for kk,_ in KEYS]
        ax.bar(x+(k-1)*w, vals, w, color=GCOL[g], label=GLAB[g] if c==0 else None, alpha=0.85)
    ax.set_xticks(x); ax.set_xticklabels([kk[1] for kk in KEYS], fontsize=8, rotation=15)
    ax.set_title(clab, fontsize=11); ax.set_ylim(0,1); ax.grid(axis="y", ls="--", alpha=0.3)
    if c==0: ax.set_ylabel("split-half reliability (stability)", fontsize=10); ax.legend(fontsize=8)
fig.suptitle("How stable is each per-sound quantity? Higher = more reliable across participants",
             fontsize=12.5, fontweight="bold")
fig.tight_layout(rect=[0,0,1,0.96])
fig.savefig(OUT/"reliability_by_measure.png",dpi=160,bbox_inches="tight")
fig.savefig(OUT/"reliability_by_measure.pdf",bbox_inches="tight")
print("saved reliability_by_measure")
