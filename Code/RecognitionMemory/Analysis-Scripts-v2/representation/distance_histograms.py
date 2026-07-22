#!/usr/bin/env python3
"""Supplemental: distribution of pairwise embedding distances per sound set.

Question: is prediction weaker for world song / environmental simply because
those stimuli sit CLOSER TOGETHER in the embedding space (a more crowded set
compresses the confusability differences the model can exploit)? For each main
model and layer, plot the distribution of all pairwise distances, one histogram
per condition, and tabulate the median pairwise distance.

Considers only the multi-task-trained nets (+ the untrained control and CLAP);
single-task paradigm models are excluded per the chapter scope.
"""
import sys
import csv
from itertools import combinations
from pathlib import Path

import numpy as np
from scipy.spatial.distance import pdist
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from repr_models import MODELS, emb_dir  # noqa: E402

MAIN_MODELS = ["kell2018_word_speaker_audioset", "resnet50_word_speaker_audioset",
               "kell2018_word_speaker_audioset_randomize_weights",
               "resnet50_word_speaker_audioset_randomize_weights"]
CONDS = [("Industrial-Nature", "Environmental"), ("Globalized-Music", "Music"),
         ("NHS", "World song")]
CCOL = {"Environmental": "#8c564b", "Music": "#9467bd", "World song": "#17becf"}
OUT = HERE / "results" / "_summary"
METRIC = "euclidean"


def load_matrix(model, cond, layer):
    npz = emb_dir(model) / f"{cond}__{layer}.npz"
    if not npz.exists():
        return None
    d = np.load(npz)
    return np.stack([np.asarray(d[k]).ravel() for k in d.files]).astype(np.float64)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    med_rows = []
    # only models whose embeddings are actually on disk (skip un-encoded ones,
    # e.g. resnet50 randomized, so we never draw a blank row)
    models = [m for m in MAIN_MODELS if m in MODELS and any(emb_dir(m).glob("*.npz"))]
    nrow, ncol = len(models), len(CONDS)
    fig, axes = plt.subplots(nrow, ncol, figsize=(4.2 * ncol, 3.2 * nrow),
                             squeeze=False, sharey="row")
    for ri, model in enumerate(models):
        layers = MODELS[model]["layers"]
        cmap = plt.cm.plasma(np.linspace(0.08, 0.92, len(layers)))
        # per-layer grand median across all 3 sets -> normalize so a "crowded"
        # set shows a leftward-shifted distribution (values < 1).
        grand = {}
        mats = {}
        for li, layer in enumerate(layers):
            allv = []
            for cond, clab in CONDS:
                M = load_matrix(model, cond, layer)
                if M is None:
                    continue
                dv = pdist(M, metric=METRIC)
                mats[(layer, clab)] = dv
                allv.append(dv)
                med_rows.append(dict(model=model, layer=layer, condition=clab,
                                     median_dist=float(np.median(dv)),
                                     mean_dist=float(np.mean(dv)), n_pairs=len(dv)))
            gv = np.concatenate(allv) if allv else np.array([1.0])
            grand[layer] = np.median(gv) if np.median(gv) > 0 else 1.0
        for ci, (cond, clab) in enumerate(CONDS):
            ax = axes[ri][ci]
            meds = []
            for li, layer in enumerate(layers):
                dv = mats.get((layer, clab))
                if dv is None:
                    continue
                norm = dv / grand[layer]
                ax.hist(norm, bins=40, density=True, histtype="step",
                        lw=2.3, color=cmap[li], alpha=0.95,
                        label=(layer if ci == ncol - 1 else None))
                med = float(np.median(norm))
                meds.append((med, cmap[li]))
            # median markers: a short colored tick at the top of the panel
            ymax = ax.get_ylim()[1]
            for med, col in meds:
                ax.plot([med], [ymax * 0.97], marker="v", color=col, ms=5,
                        markeredgecolor="black", markeredgewidth=0.4, clip_on=False)
            ax.axvline(1.0, color="#999", lw=0.9, ls=":")
            # note the across-layer mean of medians/means for this set
            if meds:
                mm = np.mean([m for m, _ in meds])
                ax.text(0.97, 0.62, f"med~{mm:.2f}", transform=ax.transAxes,
                        ha="right", va="top", fontsize=6.5, color="#333")
            if ri == 0:
                ax.set_title(clab, fontsize=11)
            if ri == nrow - 1:
                ax.set_xlabel("pairwise dist / layer median", fontsize=8)
            if ci == 0:
                ax.set_ylabel(model.replace("_word_speaker_audioset", "_wsa"),
                              fontsize=8)
            ax.grid(True, ls="--", alpha=0.25)
        axes[ri][ncol - 1].legend(fontsize=6, title="layer", title_fontsize=6,
                                  loc="upper right")
    fig.tight_layout()
    fig.savefig(OUT / "distance_histograms.png", dpi=150, bbox_inches="tight")
    # vector copy for the thesis supplement, if the chapter figure dir exists
    ch3 = Path("/orcd/data/jhm/001/om2/bjmedina/auditory-memory/memory/docs/"
               "thesis/figures/ch3")
    if ch3.is_dir():
        fig.savefig(ch3 / "repr_distance_hist.pdf", bbox_inches="tight")
        print("saved", ch3 / "repr_distance_hist.pdf", flush=True)
    plt.close(fig)
    print("saved", OUT / "distance_histograms.png", flush=True)

    with open(OUT / "pairwise_distance_medians.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["model", "layer", "condition",
                                           "median_dist", "mean_dist", "n_pairs"])
        w.writeheader()
        for r in med_rows:
            w.writerow(r)
    print("wrote pairwise_distance_medians.csv", flush=True)


if __name__ == "__main__":
    main()
