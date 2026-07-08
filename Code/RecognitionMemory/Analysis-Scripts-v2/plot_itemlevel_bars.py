#!/usr/bin/env python3
"""Real item-level summary bars: between-group itemwise correlation per sound set
and group pair, for hits and false alarms, each against its own attenuation
ceiling sqrt(rho_A * rho_B). Reads itemlevel_results.npz. No figure title.
"""
from __future__ import annotations
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
US, SB, TS = "#1f77b4", "#ff7f0e", "#2E7D32"
CONDS = [("Industrial-Nature", "Environmental sounds"),
         ("Globalized-Music", "Globalized music"),
         ("NHS", "NHS (world song)")]
# center = most distant pair (U.S.-Tsimane')
PAIRS = [("US", "SanBorja"), ("US", "Tsimane"), ("SanBorja", "Tsimane")]
PAIRLAB = ["U.S.–\nSan Borja", "U.S.–\nTsimane’", "San Borja–\nTsimane’"]
BARCOLS = ["#7E57C2", "#5D8AA8", "#8D6E63"]
MINRESP = 2


def pair_r(ga, gb, kind):
    xa, xb = [], []
    for it in set(ga[kind]) & set(gb[kind]):
        va, na = ga[kind][it]; vb, nb = gb[kind][it]
        if na >= MINRESP and nb >= MINRESP and np.isfinite(va) and np.isfinite(vb):
            xa.append(va); xb.append(vb)
    return spearmanr(xa, xb).correlation if len(xa) >= 5 else np.nan


def main():
    data = np.load(HERE / "dprime_vs_isi_outputs" / "itemlevel_results.npz",
                   allow_pickle=True)["data"].item()
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, axes = plt.subplots(2, 3, figsize=(12.5, 7.4), sharey=True)
    x = np.arange(3)
    for row, kind in enumerate(["hit", "fa"]):
        for col, (cond, clab) in enumerate(CONDS):
            ax = axes[row][col]
            grp = data[cond]
            rs = [pair_r(grp[a], grp[b], kind) for a, b in PAIRS]
            ceil = [np.sqrt(grp[a]["ceil_" + kind] * grp[b]["ceil_" + kind])
                    for a, b in PAIRS]
            ax.bar(x, rs, color=BARCOLS, width=0.64, edgecolor="white", zorder=3)
            # per-pair attenuation ceiling as a red cap over each bar
            for xi, c in zip(x, ceil):
                ax.plot([xi-0.32, xi+0.32], [c, c], color="#C62828", lw=2, zorder=5)
            for xi, v in zip(x, rs):
                ax.text(xi, v+0.02, f"{v:.2f}", ha="center", fontsize=9,
                        fontweight="bold", color="#212121")
            ax.set_xticks(x); ax.set_xticklabels(PAIRLAB, fontsize=8)
            ax.set_ylim(0, 1.0); ax.grid(axis="y", ls="--", alpha=0.3)
            if row == 0:
                ax.set_title(clab, fontsize=12)
            if col == 0:
                ax.set_ylabel(("Hits" if kind == "hit" else "False alarms")
                              + "\n\nitemwise correlation r", fontsize=10.5)
    # one shared legend note for the ceiling
    axes[0][2].plot([], [], color="#C62828", lw=2,
                    label=r"attenuation ceiling $\sqrt{\rho_A\rho_B}$")
    axes[0][2].legend(loc="upper right", fontsize=8, framealpha=0.9)

    fig.tight_layout()
    d = HERE / "dprime_vs_isi_outputs"
    fig.savefig(d / "itemwise-bars.pdf", bbox_inches="tight")
    fig.savefig(d / "itemwise-bars.png", dpi=180, bbox_inches="tight")
    print("saved", d / "itemwise-bars.pdf")


if __name__ == "__main__":
    main()
