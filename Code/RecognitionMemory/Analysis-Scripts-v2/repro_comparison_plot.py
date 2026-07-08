#!/usr/bin/env python3
"""Side-by-side: the OLD slide values vs the new-code recipes, Natural sounds.

For each pair (Ts-SB, Ts-US, SB-US) and measure (hit, FA), four bars:
  - old slide          (what the 2023 MATLAB pipeline plotted)
  - new observed r     (clean Spearman, d'>=1.5, no fill-in)
  - new disattenuated  (r* = r / sqrt(rel_A rel_B))
  - new equal-N + disatt (equal-N fill-in bootstrap mean, then disattenuated)

Values computed by repro_old_itemwise.py and repro_old_equalN.py (screen=1.5,
no finished filter). Shows: disattenuation explains the high FA bars; the equal-N
fill-in explains the collapsed HIT bars for the U.S. pairs.
"""
import numpy as np
import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from pathlib import Path

OUT = Path(__file__).resolve().parent / "dprime_vs_isi_outputs"
PAIRS = ["Ts-SB", "Ts-US", "SB-US"]
# rows: [old, observed, disatt, equalN+disatt]
HIT = {"Ts-SB":[0.95,0.74,1.01,0.70], "Ts-US":[0.36,0.58,0.77,0.53], "SB-US":[0.51,0.65,0.85,0.58]}
FA  = {"Ts-SB":[0.87,0.65,0.80,0.65], "Ts-US":[0.77,0.60,0.70,0.59], "SB-US":[0.83,0.64,0.75,0.63]}
LABELS = ["old slide", "new: observed r", "new: disattenuated r*", "new: equal-N + disatt"]
COLORS = ["#9E9E9E", "#2E7D32", "#1565C0", "#C62828"]

fig, axes = plt.subplots(1, 2, figsize=(13, 5), sharey=True)
x = np.arange(len(PAIRS)); w = 0.2
for ax, (data, mlab) in zip(axes, [(HIT, "Hit consistency"), (FA, "False-alarm consistency")]):
    M = np.array([data[p] for p in PAIRS])   # 3 pairs x 4 recipes
    for k in range(4):
        ax.bar(x + (k-1.5)*w, M[:, k], w, color=COLORS[k], label=LABELS[k] if ax is axes[0] else None)
    ax.axhline(1.0, ls=":", color="#bbb", lw=1)
    ax.set_xticks(x); ax.set_xticklabels(["Tsimane'-\nSan Borja","Tsimane'-\nU.S.","San Borja-\nU.S."], fontsize=9)
    ax.set_title(mlab + "  (Natural sounds)", fontsize=11)
    ax.set_ylim(0, 1.12); ax.grid(axis="y", ls="--", alpha=0.3)
axes[0].set_ylabel("inter-group item-wise correlation", fontsize=10)
axes[0].legend(fontsize=8.5, loc="upper right", framealpha=0.95)
fig.suptitle("Old slide vs new-code recipes: disattenuation raises FA; equal-N fill-in "
             "collapses the U.S. hit pairs", fontsize=12.5, fontweight="bold")
fig.tight_layout(rect=[0,0,1,0.96])
fig.savefig(OUT/"repro_comparison.png", dpi=160, bbox_inches="tight")
fig.savefig(OUT/"repro_comparison.pdf", bbox_inches="tight")
print("saved repro_comparison")
