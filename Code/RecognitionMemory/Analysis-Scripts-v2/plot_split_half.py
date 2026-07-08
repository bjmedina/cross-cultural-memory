#!/usr/bin/env python3
"""Within-group split-half reliability (Spearman-Brown) per group, sound set, and
measure. Reads itemlevel_results.npz. Two panels: hits and false alarms."""
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
data = np.load(HERE / "dprime_vs_isi_outputs" / "itemlevel_results.npz",
               allow_pickle=True)["data"].item()

CONDS = [("Industrial-Nature", "Environmental"), ("Globalized-Music", "Globalized music"),
         ("NHS", "World song (NHS)")]
GROUPS = [("US", "U.S.", "#1f77b4"), ("SanBorja", "San Borja", "#ff7f0e"),
          ("Tsimane", "Tsimane’", "#2E7D32")]

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

fig, axes = plt.subplots(1, 2, figsize=(11, 4.6), sharey=True)
x = np.arange(len(CONDS)); w = 0.26
for ax, kind, title in [(axes[0], "ceil_hit", "Hits (memorability)"),
                        (axes[1], "ceil_fa", "False alarms (confusability)")]:
    for gi, (g, glab, col) in enumerate(GROUPS):
        vals = [data[c][g][kind] if data[c].get(g) else np.nan for c, _ in CONDS]
        bars = ax.bar(x + (gi-1)*w, vals, w, color=col, label=glab, edgecolor="white")
        for xi, v in zip(x + (gi-1)*w, vals):
            ax.text(xi, v+0.015, f"{v:.2f}", ha="center", fontsize=7.5)
    ax.set_xticks(x); ax.set_xticklabels([c[1] for c in CONDS], fontsize=9)
    ax.set_ylim(0, 1.0); ax.set_title(title, fontsize=11)
    ax.grid(axis="y", ls="--", alpha=0.3)
axes[0].set_ylabel("split-half reliability  ($\\hat\\rho_{SB}$)")
axes[0].legend(fontsize=8.5, loc="lower right")
fig.suptitle("Within-group split-half reliability", fontsize=12, fontweight="bold", y=1.00)
fig.tight_layout()
out = HERE / "dprime_vs_isi_outputs" / "split_half_reliability.png"
fig.savefig(out, dpi=170, bbox_inches="tight"); fig.savefig(out.with_suffix(".pdf"), bbox_inches="tight")
print("saved", out)
