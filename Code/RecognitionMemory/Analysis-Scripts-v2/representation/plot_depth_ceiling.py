#!/usr/bin/env python3
"""Redraw per-model depth curves with each group's reliability ceiling.

Reads results/<model>/representation_results.csv (already has rho, CI, and
fa_reliability per group x condition) and redraws the depth curves, adding a
dashed horizontal line at each group's correlation ceiling = sqrt(reliability).
No bootstrap re-run; pure replot. Writes repr_depth_curves_ceiling.png next to
the originals, for the multi-task nets + control + CLAP.
"""
import csv
import math
import sys
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from repr_models import MODELS  # noqa: E402

MAIN = ["kell2018_word_speaker_audioset", "resnet50_word_speaker_audioset",
        "kell2018_word_speaker_audioset_randomize_weights", "resnet50_word_speaker_audioset_randomize_weights"]
GLAB = ["U.S.", "San Borja", "Tsimane'"]
GCOL = {"U.S.": "#1f77b4", "San Borja": "#ff7f0e", "Tsimane'": "#2E7D32"}
CONDS = ["Environmental", "Music", "World song"]
METRIC, K = "euclidean", "3"


def main():
    for model in MAIN:
        f = HERE / "results" / model / "representation_results.csv"
        if not f.exists():
            continue
        rows = [r for r in csv.DictReader(open(f))
                if r["metric"] == METRIC and r["k"] == K]
        layers = MODELS[model]["layers"]
        xi = {L: i for i, L in enumerate(layers)}
        xs = np.arange(len(layers))
        fig, axes = plt.subplots(1, 3, figsize=(5.2 * 3, 4.5), sharey=True,
                                 squeeze=False)
        for c, cond in enumerate(CONDS):
            ax = axes[0][c]
            for g in GLAB:
                gr = sorted([r for r in rows if r["cond"] == cond and r["group"] == g],
                            key=lambda r: xi.get(r["layer"], 0))
                if not gr:
                    continue
                x = [xi[r["layer"]] for r in gr]
                y = [float(r["rho"]) for r in gr]
                lo = [float(r["ci_lo"]) for r in gr]
                hi = [float(r["ci_hi"]) for r in gr]
                ax.plot(x, y, "-o", color=GCOL[g], lw=2, ms=5, label=g)
                ax.fill_between(x, lo, hi, color=GCOL[g], alpha=0.13)
                rel = float(gr[0]["fa_reliability"])
                if rel > 0:  # reliability ceiling for this group
                    ax.axhline(math.sqrt(rel), color=GCOL[g], lw=1, ls=":", alpha=0.7)
            ax.axhline(0, color="#555", lw=1)
            ax.set_xticks(xs); ax.set_xticklabels(layers, rotation=45, fontsize=7)
            ax.set_title(cond, fontsize=11); ax.grid(axis="y", ls="--", alpha=.3)
            ax.set_xlabel("layer (input -> output)", fontsize=9)
            ax.set_ylim(-0.3, 1.0)
            if c == 0:
                ax.set_ylabel("rho(model confusability, human FA)", fontsize=10)
                ax.legend(fontsize=8, loc="upper left")
        fig.tight_layout()
        out = HERE / "results" / model / "figures" / "repr_depth_curves_ceiling.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(out, dpi=160, bbox_inches="tight")
        plt.close(fig)
        print("saved", out)


if __name__ == "__main__":
    main()
