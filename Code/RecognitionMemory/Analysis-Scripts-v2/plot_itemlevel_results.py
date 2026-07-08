#!/usr/bin/env python3
"""Plot real item-level between-group scatters (3 sound sets x 3 group pairs).

Reads itemlevel_results.npz (from itemlevel_results.py). One scatter per
(condition, group pair): each point is a sound, its rate in group A vs group B.
The most distant pair (U.S.-Tsimane') is the center column. No figure title.

    python plot_itemlevel_results.py --kind hit
    python plot_itemlevel_results.py --kind fa
"""
from __future__ import annotations
import argparse
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
US, SB, TS = "#1f77b4", "#ff7f0e", "#2E7D32"
GCOL = {"US": US, "SanBorja": SB, "Tsimane": TS}
GLAB = {"US": "U.S.", "SanBorja": "San Borja", "Tsimane": "Tsimane’"}
CONDS = [("Industrial-Nature", "Environmental sounds"),
         ("Globalized-Music", "Globalized music"),
         ("NHS", "NHS (world song)")]
# center column = most culturally distant pair (U.S.-Tsimane')
PAIRS = [("US", "SanBorja"), ("US", "Tsimane"), ("SanBorja", "Tsimane")]
MINRESP = 2


def aligned(ga, gb, kind):
    xa, xb = [], []
    for it in set(ga[kind]) & set(gb[kind]):
        va, na = ga[kind][it]; vb, nb = gb[kind][it]
        if na >= MINRESP and nb >= MINRESP and np.isfinite(va) and np.isfinite(vb):
            xa.append(va); xb.append(vb)
    return np.array(xa), np.array(xb)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--kind", choices=["hit", "fa"], default="hit")
    ap.add_argument("--out-dir", default=str(HERE / "dprime_vs_isi_outputs"))
    args = ap.parse_args()
    kind = args.kind
    rate_name = "hit rate" if kind == "hit" else "FA rate"

    data = np.load(HERE / "dprime_vs_isi_outputs" / "itemlevel_results.npz",
                   allow_pickle=True)["data"].item()

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, axes = plt.subplots(3, 3, figsize=(10.5, 11), sharex=True, sharey=True)
    for i, (cond, clab) in enumerate(CONDS):
        grp = data[cond]
        for j, (a, b) in enumerate(PAIRS):
            ax = axes[i][j]
            ax.plot([0, 1], [0, 1], ls=":", color="#bbb", lw=1)
            if grp.get(a) and grp.get(b):
                xa, xb = aligned(grp[a], grp[b], kind)
                r = spearmanr(xa, xb).correlation if len(xa) >= 5 else np.nan
                relA = grp[a].get("ceil_" + kind, np.nan)
                relB = grp[b].get("ceil_" + kind, np.nan)
                rstar = r / np.sqrt(relA * relB) if relA > 0 and relB > 0 else np.nan
                ax.scatter(xa, xb, s=20, c="#455A64", edgecolor="white",
                           linewidths=0.4, alpha=0.85)
                ax.text(0.05, 0.90, f"r = {r:.2f}", transform=ax.transAxes,
                        fontsize=12, fontweight="bold", color="#212121")
                ax.text(0.05, 0.80, f"r* = {rstar:.2f}", transform=ax.transAxes,
                        fontsize=10, color="#1565C0")
                ax.text(0.95, 0.06, f"n={len(xa)}", transform=ax.transAxes,
                        ha="right", fontsize=8, color="#888")
            ax.set_xlim(-0.03, 1.03); ax.set_ylim(-0.03, 1.03)
            ax.set_aspect("equal"); ax.set_xticks([0, 0.5, 1]); ax.set_yticks([0, 0.5, 1])
            ax.tick_params(labelsize=8)
            if i == 0:
                ax.set_title(f"{GLAB[a]}  vs  {GLAB[b]}", fontsize=11)
            if i == 2:
                ax.set_xlabel(f"{rate_name}, {GLAB[a]}", color=GCOL[a], fontsize=9.5)
            if j == 0:
                ax.set_ylabel(f"{clab}\n\n{rate_name}, {GLAB[b]}", color=GCOL[b], fontsize=9.5)
            else:
                ax.set_ylabel(f"{rate_name}, {GLAB[b]}", color=GCOL[b], fontsize=9.5)

    fig.text(0.5, 0.005, "r = observed Spearman;  r* = corrected for attenuation "
             r"(r / $\sqrt{\rho_A\,\rho_B}$, split-half reliabilities)",
             ha="center", fontsize=8.5, color="#444")
    fig.tight_layout(rect=[0, 0.015, 1, 1])
    base = f"itemwise-scatter-{kind}"
    d = Path(args.out_dir); d.mkdir(parents=True, exist_ok=True)
    fig.savefig(d / f"{base}.pdf", bbox_inches="tight")
    fig.savefig(d / f"{base}.png", dpi=170, bbox_inches="tight")
    print("saved", d / f"{base}.pdf")
    plt.close(fig)


if __name__ == "__main__":
    main()
