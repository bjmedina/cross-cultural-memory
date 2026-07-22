#!/usr/bin/env python3
"""Chapter-3 figure: per-sound human FA rate vs the CochDNN's in-context
confusability, one panel per sound set (row) x group (column), at a chosen layer.

Reproduces the exact measure behind repr_gap_depth / the reported rho values:
per-group in-context confusability (mean distance, negated, to the k nearest of the
sounds heard earlier in that group's own sequences), correlated with that group's
per-sound FA rate. x is z-scored per panel for display only (Spearman rho is
scale-invariant), so higher x = more confusable and a positive slope means the
prediction holds.

Usage:  python make_repr_scatter_ch3.py relu2 input_after_preproc
Default layers: relu2 (main) and input_after_preproc (cochleagram, supplement).
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
    load_sequences, incontext_confusability, PRIMARY_METRIC, PRIMARY_K)

OUT = HERE / "results" / "_summary"
GROUPS = ["US", "SanBorja", "Tsimane"]
LAYER_LABEL = {"relu2": "layer relu2 (mid, learned)",
               "input_after_preproc": "cochleagram (input)"}


def make_figure(layer):
    names_by_cond = {}
    D_by_cond = {}
    for cond, _ in CONDS:
        names = canonical_names(cond)
        emb = load_embeddings(cond, layer, names)
        shared = [n for n in names if n in emb]
        M = np.stack([emb[n] for n in shared]).astype(np.float64)
        D_by_cond[cond] = cdist(M, M, metric=PRIMARY_METRIC)
        names_by_cond[cond] = shared

    nrow, ncol = len(CONDS), len(GROUPS)
    fig, axes = plt.subplots(nrow, ncol, figsize=(3.6 * ncol, 3.6 * nrow),
                             squeeze=False)
    for r, (cond, clab) in enumerate(CONDS):
        shared = names_by_cond[cond]
        D = D_by_cond[cond]
        fa = {g: per_sound_fa(cond, CODES[g]) for g in GROUPS}
        for c, g in enumerate(GROUPS):
            ax = axes[r][c]
            seqs = load_sequences(cond, CODES[g])
            conf = incontext_confusability(D, shared, seqs, PRIMARY_K)
            sh = [n for n in shared
                  if np.isfinite(conf.get(n, np.nan))
                  and np.isfinite(fa[g].get(n, np.nan))]
            x = np.array([conf[n] for n in sh])
            y = np.array([fa[g][n] for n in sh])
            rho = spearmanr(x, y).correlation
            xz = (x - x.mean()) / x.std()  # display only; rho unchanged
            ax.scatter(xz, y, s=22, color=GCOL[g], alpha=0.75, edgecolor="none")
            if len(xz) >= 3:
                z = np.polyfit(xz, y, 1)
                xr = np.array([xz.min(), xz.max()])
                ax.plot(xr, np.polyval(z, xr), color="#333", lw=1, ls="--", alpha=.7)
            ax.text(0.05, 0.95, f"$\\rho={rho:+.2f}$", transform=ax.transAxes,
                    va="top", ha="left", fontsize=12)
            ax.set_ylim(-0.03, 1.03)
            ax.grid(True, ls="--", alpha=.25)
            if r == 0:
                ax.set_title(GLAB[g], fontsize=13)
            if c == 0:
                ax.set_ylabel(f"{clab}\nhuman FA rate", fontsize=11.5)
            if r == nrow - 1:
                ax.set_xlabel("in-context confusability (z)", fontsize=11.5)
    fig.tight_layout()
    OUT.mkdir(parents=True, exist_ok=True)
    stem = OUT / f"repr_fa_vs_confusability_{layer}"
    fig.savefig(stem.with_suffix(".png"), dpi=160, bbox_inches="tight")
    fig.savefig(stem.with_suffix(".pdf"), bbox_inches="tight")
    plt.close(fig)
    print("saved", stem.with_suffix(".pdf"))


if __name__ == "__main__":
    layers = sys.argv[1:] or ["relu2", "input_after_preproc"]
    for L in layers:
        make_figure(L)
