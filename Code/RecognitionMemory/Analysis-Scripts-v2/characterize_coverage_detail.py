#!/usr/bin/env python3
"""Per-stimulus coverage in detail: for each sound, how many participants heard it
as a REPEAT (target) vs as a NON-REPEAT (foil), per group and condition.
Grid: rows = group, cols = condition. Sounds sorted by repeat count."""
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT = HERE / "dprime_vs_isi_outputs"
GROUPS = [("US", ("PRO","BOS","CAM")), ("SanBorja", ("SBO","SNB","SBJ")),
          ("Tsimane", ("NVM","MAJ","MAN","NUM","NUV","CVR"))]
GLAB = {"US":"U.S.","SanBorja":"San Borja","Tsimane":"Tsimane’"}
GCOL = {"US":"#1f77b4","SanBorja":"#ff7f0e","Tsimane":"#2E7D32"}
CONDS = [("Industrial-Nature","Environmental"),("Globalized-Music","Music"),("NHS","World song")]

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt

fig, axes = plt.subplots(3, 3, figsize=(13.5, 9), sharex=True)
for r,(g,codes) in enumerate(GROUPS):
    for c,(cond,clab) in enumerate(CONDS):
        ax=axes[r][c]
        files=list_matfiles(BASE,codes,cond,0.0,False)
        hits,fas,items=build_hit_fa_matrices(files)
        N=hits.shape[0]
        rep=np.sum(~np.isnan(hits),axis=0)
        foil=np.sum(~np.isnan(fas),axis=0)
        order=np.argsort(rep)
        x=np.arange(len(rep))
        ax.fill_between(x, rep[order], color=GCOL[g], alpha=0.65, step="mid",
                        label="heard as repeat (target)")
        ax.plot(x, foil[order], color="#444", lw=1.3, label="heard as non-repeat (foil)")
        ax.axhline(N, ls="--", color="#C62828", lw=1.2)
        ax.text(1, N+1, f"N={N}", fontsize=8, color="#C62828", va="bottom")
        ax.text(0.98,0.06,f"repeat med={int(np.median(rep))}",transform=ax.transAxes,
                ha="right",fontsize=8,color=GCOL[g],fontweight="bold")
        ax.set_ylim(0, max(N*1.12, foil.max()*1.12)); ax.set_xlim(0,len(rep)-1)
        ax.grid(axis="y",ls="--",alpha=0.3)
        if r==0: ax.set_title(clab,fontsize=12)
        if c==0: ax.set_ylabel(f"{GLAB[g]}\n\n# participants",fontsize=10)
        if r==2: ax.set_xlabel("sound (sorted by repeat count)",fontsize=9)
axes[0][2].legend(fontsize=8,loc="center right")
fig.suptitle("Per-stimulus coverage: how many participants heard each sound as a repeat vs non-repeat\n"
             "No d$'\\geq$2 catch screen (finished sessions only, 120 trials)",
             fontsize=12.5,fontweight="bold")
fig.tight_layout(rect=[0,0,1,0.96])
fig.savefig(OUT/"characterize_coverage_detail.png",dpi=160,bbox_inches="tight")
fig.savefig(OUT/"characterize_coverage_detail.pdf",bbox_inches="tight")
print("saved characterize_coverage_detail")
