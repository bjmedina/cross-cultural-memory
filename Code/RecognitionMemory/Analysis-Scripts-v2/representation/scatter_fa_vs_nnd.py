#!/usr/bin/env python3
"""Per-sound scatter: human FA rate (y) vs model nearest-neighbor distance (x).

For each condition (row) x group (column), plot the 80 sounds with
  x = mean distance to the k nearest neighbors in the layer's embedding space
      (the NND; SMALL x = a sound sits close to something = predicted confusable),
  y = that group's per-sound false-alarm rate.
Annotated with Spearman rho(NND, FA); it is NEGATIVE when the prediction holds
(closer sounds are false-alarmed more), i.e. rho(NND,FA) = -rho(confusability,FA),
the latter being the positive value reported in representation_results.csv.

One figure per layer. Metric euclidean, k=3 (the headline configuration).
Run:  python scatter_fa_vs_nnd.py [relu0 relu4 ...]
"""
import sys
from pathlib import Path

import numpy as np
from scipy.stats import spearmanr
from scipy.spatial.distance import cdist
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_representation_analysis import (  # noqa: E402
    CONDS, CODES, GLAB, GCOL, load_embeddings, per_sound_fa, canonical_names,
    FIG_DIR, PRIMARY_METRIC, PRIMARY_K)

RES = HERE / "results"


def nnd(emb, names, metric=PRIMARY_METRIC, k=PRIMARY_K):
    """Mean distance to the k nearest neighbors (positive; small = confusable)."""
    M = np.stack([emb[n] for n in names]).astype(np.float64)
    D = cdist(M, M, metric=metric)
    np.fill_diagonal(D, np.inf)
    D.sort(axis=1)
    return dict(zip(names, D[:, :k].mean(axis=1)))


def make_figure(layer, metric=PRIMARY_METRIC):
    ncol = len(CODES)
    fig, axes = plt.subplots(len(CONDS), ncol, figsize=(4.0 * ncol, 3.6 * len(CONDS)),
                             squeeze=False)
    groups = list(CODES)
    for r, (cond, clab) in enumerate(CONDS):
        names = canonical_names(cond)
        emb = load_embeddings(cond, layer, names)
        shared = [n for n in names if n in emb]
        x_all = nnd(emb, shared, metric=metric)
        fa = {g: per_sound_fa(cond, CODES[g]) for g in CODES}
        for c, g in enumerate(groups):
            ax = axes[r][c]
            sh = [n for n in shared
                  if np.isfinite(x_all[n]) and np.isfinite(fa[g].get(n, np.nan))]
            x = np.array([x_all[n] for n in sh])
            y = np.array([fa[g][n] for n in sh])
            ax.scatter(x, y, s=22, color=GCOL[g], alpha=0.75, edgecolor="none")
            rho = spearmanr(x, y).correlation
            # rank-based trend line for a visual guide
            if len(x) >= 3:
                z = np.polyfit(x, y, 1)
                xr = np.array([x.min(), x.max()])
                ax.plot(xr, np.polyval(z, xr), color="#333", lw=1, ls="--", alpha=.7)
            ax.text(0.04, 0.95, f"$\\rho$(NND,FA)$={rho:+.2f}$\n$\\rho$(conf,FA)$={-rho:+.2f}$",
                    transform=ax.transAxes, va="top", ha="left", fontsize=8.5)
            if r == 0:
                ax.set_title(GLAB[g], fontsize=11)
            if c == 0:
                ax.set_ylabel(f"{clab}\nhuman FA rate", fontsize=9.5)
            if r == len(CONDS) - 1:
                ax.set_xlabel(f"mean {metric} dist. to {PRIMARY_K} NN (NND)", fontsize=9)
            ax.grid(True, ls="--", alpha=.25)
            ax.set_ylim(-0.02, 1.02)
    fig.suptitle(f"Human false-alarm rate vs model nearest-neighbor distance   "
                 f"(layer {layer}, metric={metric}, k={PRIMARY_K})\n"
                 f"closer to neighbors (left) predicts more false alarms; "
                 f"rho(conf,FA) = -rho(NND,FA)",
                 fontsize=12, fontweight="bold")
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    out = FIG_DIR / f"scatter_fa_vs_nnd_{metric}_{layer}.png"
    fig.savefig(out, dpi=150, bbox_inches="tight")
    plt.close(fig)
    print("saved", out)


if __name__ == "__main__":
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    args = sys.argv[1:]
    metrics = [a for a in args if a in ("euclidean", "cosine")] or ["euclidean", "cosine"]
    layers = [a for a in args if a not in ("euclidean", "cosine")] or ["relu0", "relu4"]
    for metric in metrics:
        for L in layers:
            make_figure(L, metric=metric)
