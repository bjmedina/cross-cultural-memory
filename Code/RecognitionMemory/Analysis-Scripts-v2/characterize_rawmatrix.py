#!/usr/bin/env python3
"""The rawest view: the participant x sound response grid itself.

For each group x condition, one cell = did that participant get that sound right
(green) or wrong (red); blank = they never saw it. Rows sorted by participant
accuracy, columns sorted by sound difficulty, so structure (bad rows, hard columns)
is visible without any statistics. Unfiltered (all participants)."""
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
GLAB = {"US":"U.S.","SanBorja":"San Borja","Tsimane":"Tsimane'"}
CONDS = [("Industrial-Nature","Environmental"),("Globalized-Music","Music"),("NHS","World song")]

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
cmap = ListedColormap(["#C62828", "#2E7D32"])  # 0=wrong red, 1=right green

fig, axes = plt.subplots(3, 3, figsize=(13, 9))
for r,(g,codes) in enumerate(GROUPS):
    for c,(cond,clab) in enumerate(CONDS):
        ax = axes[r][c]
        h,f,items = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 0.0, False))
        # correctness: on repeats correct=hit; on foils correct=1-FA
        acc = np.where(~np.isnan(h), h, np.where(~np.isnan(f), 1-f, np.nan))
        with np.errstate(invalid="ignore"):
            rord = np.argsort(-np.nanmean(acc, axis=1))   # best participants on top
            cord = np.argsort(-np.nanmean(acc, axis=0))    # easiest sounds on left
        M = acc[np.ix_(rord, cord)]
        ax.imshow(np.ma.masked_invalid(M), aspect="auto", cmap=cmap, vmin=0, vmax=1,
                  interpolation="nearest")
        ax.set_facecolor("#eeeeee")
        if r==0: ax.set_title(clab, fontsize=11)
        if c==0: ax.set_ylabel(f"{GLAB[g]}\nparticipants\n(sorted by accuracy)", fontsize=9)
        if r==2: ax.set_xlabel("sounds (sorted easy -> hard)", fontsize=9)
        ax.set_xticks([]); ax.set_yticks([])
fig.legend(handles=[plt.Rectangle((0,0),1,1,color="#2E7D32"),
                    plt.Rectangle((0,0),1,1,color="#C62828"),
                    plt.Rectangle((0,0),1,1,color="#eeeeee")],
           labels=["correct","incorrect","not seen"], loc="lower center",
           ncol=3, fontsize=9, frameon=False, bbox_to_anchor=(0.5,-0.01))
fig.suptitle("The raw data: participant x sound response grid  "
             "(finished sessions only, no d' screen)", fontsize=13, fontweight="bold")
fig.tight_layout(rect=[0,0.03,1,0.97])
fig.savefig(OUT/"characterize_rawmatrix.png",dpi=160,bbox_inches="tight")
fig.savefig(OUT/"characterize_rawmatrix.pdf",bbox_inches="tight")
print("saved characterize_rawmatrix")
