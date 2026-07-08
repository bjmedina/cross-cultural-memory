#!/usr/bin/env python3
"""How do the between-group item correlations move as a function of the passing d'
(ISI=0 catch) criterion? Sweep the screen and recompute observed Spearman r for each
pair, per condition, for hits and FAs. Finished sessions only. Also reports the N
retained per group at each threshold."""
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
SCREENS = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5]


def rate(codes, cond, screen, idx):
    h,f,it = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, screen, False))
    with np.errstate(invalid="ignore"):
        v = np.nanmean(h if idx==0 else f, 0)
    return dict(zip(it, v)), (h if idx==0 else f).shape[0]


def corr(cond, a, b, screen, idx):
    da,_ = rate(CODES[a], cond, screen, idx); db,nb = rate(CODES[b], cond, screen, idx)
    sh=[k for k in da if k in db and np.isfinite(da[k]) and np.isfinite(db[k])]
    if len(sh)<5: return np.nan
    x=np.array([da[k] for k in sh]); y=np.array([db[k] for k in sh])
    return spearmanr(x,y).correlation


# N retained per group per screen
print("N retained per group vs screen:")
print(f"{'cond':<14}{'group':<10}" + "".join(f"{s:>6}" for s in SCREENS))
for cond,clab in CONDS:
    for g in CODES:
        ns=[len(list_matfiles(BASE, CODES[g], cond, s, False)) for s in SCREENS]
        print(f"{clab:<14}{g:<10}" + "".join(f"{n:>6}" for n in ns))
    print()

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, axes = plt.subplots(2, 3, figsize=(13.5, 8), sharex=True, sharey=True)
for r,(idx,mlab) in enumerate([(0,"hit rate"),(1,"FA rate")]):
    for c,(cond,clab) in enumerate(CONDS):
        ax=axes[r][c]
        for a,b,plab,col in PAIRS:
            ys=[corr(cond,a,b,s,idx) for s in SCREENS]
            ax.plot(SCREENS, ys, "o-", color=col, ms=5, label=plab if (r==0 and c==0) else None)
        ax.axvline(2.0, ls=":", color="#999", lw=1)   # our current screen
        ax.set_ylim(0,1); ax.grid(ls="--", alpha=0.3)
        if r==0: ax.set_title(clab, fontsize=11)
        if c==0: ax.set_ylabel(f"{mlab}\n\nbetween-group r (Spearman)", fontsize=9.5)
        if r==1: ax.set_xlabel("passing d' criterion (ISI=0 catch)", fontsize=9.5)
axes[0][0].legend(fontsize=8, loc="lower left", title="pair")
fig.suptitle("Between-group item correlations vs the passing d' criterion "
             "(dotted line = current screen, 2.0)", fontsize=12.5, fontweight="bold")
fig.tight_layout(rect=[0,0,1,0.96])
fig.savefig(OUT/"dprime_screen_sweep.png", dpi=160, bbox_inches="tight")
fig.savefig(OUT/"dprime_screen_sweep.pdf", bbox_inches="tight")
print("saved dprime_screen_sweep")
