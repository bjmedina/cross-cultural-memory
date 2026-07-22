#!/usr/bin/env python3
"""Non-normalized (raw) pairwise embedding-distance distributions, by sound set.

Companion to the normalized figure (repr_distance_hist.pdf): here the raw
euclidean pairwise distances are shown at true scale, faceted by layer (each panel
its own x-axis, since the scale differs enormously across layers). The set medians
are marked. If the globalized-music set (the only set with a cross-cultural
divergence) were merely more separated, its distribution would sit to the RIGHT;
instead it is the most crowded (leftmost median) at essentially every layer.

Primary trained CochDNN. Prints the median raw distance table and writes the figure.
"""
import sys
from pathlib import Path

import numpy as np
from scipy.spatial.distance import pdist
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from repr_models import MODELS, emb_dir  # noqa: E402

MODEL = "kell2018_word_speaker_audioset"
CONDS = [("Industrial-Nature", "Environmental"), ("Globalized-Music", "Music"),
         ("NHS", "World song")]
CCOL = {"Environmental": "#8c564b", "Music": "#9467bd", "World song": "#17becf"}
CH3 = Path("/orcd/data/jhm/001/om2/bjmedina/auditory-memory/memory/docs/thesis/figures/ch3")


def load_matrix(cond, layer):
    npz = emb_dir(MODEL) / f"{cond}__{layer}.npz"
    if not npz.exists():
        return None
    d = np.load(npz)
    return np.stack([np.asarray(d[k]).ravel() for k in d.files]).astype(np.float64)


def main():
    layers = MODELS[MODEL]["layers"]
    nice = {L: L.replace("input_after_preproc", "cochlea") for L in layers}
    dists = {}   # (layer, clab) -> pairwise distance vector
    for layer in layers:
        for cond, clab in CONDS:
            M = load_matrix(cond, layer)
            if M is not None:
                dists[(layer, clab)] = pdist(M, metric="euclidean")

    print(f"\n=== {MODEL}: median raw pairwise distance ===")
    print(f"  {'layer':<22} {'Environmental':>14} {'Music':>10} {'World song':>12}  most crowded")
    for layer in layers:
        v = {clab: float(np.median(dists[(layer, clab)])) for _, clab in CONDS
             if (layer, clab) in dists}
        if len(v) < 3:
            continue
        lo = min(v, key=v.get)
        print(f"  {nice[layer]:<22} {v['Environmental']:>14.2f} {v['Music']:>10.2f} "
              f"{v['World song']:>12.2f}  {lo}")

    # figure: one panel per layer, raw x-scale, 3 sets, medians marked
    ncol = 4
    nrow = int(np.ceil(len(layers) / ncol))
    fig, axes = plt.subplots(nrow, ncol, figsize=(3.4 * ncol, 2.7 * nrow), squeeze=False)
    for i, layer in enumerate(layers):
        ax = axes[i // ncol][i % ncol]
        for cond, clab in CONDS:
            dv = dists.get((layer, clab))
            if dv is None:
                continue
            ax.hist(dv, bins=40, density=True, histtype="step", lw=2.0,
                    color=CCOL[clab], alpha=0.95, label=clab)
            ax.axvline(np.median(dv), color=CCOL[clab], lw=1.2, ls=":")
        ax.set_title(nice[layer], fontsize=10)
        ax.set_xlabel("pairwise distance", fontsize=8)
        ax.tick_params(labelsize=7)
        ax.grid(True, ls="--", alpha=0.25)
    for j in range(len(layers), nrow * ncol):
        axes[j // ncol][j % ncol].axis("off")
    axes[0][0].legend(fontsize=8, frameon=False)
    fig.suptitle("Raw pairwise embedding-distance distributions, by layer "
                 "(CochDNN; dotted = set median)", fontsize=12, fontweight="bold")
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    out = HERE / "results" / "_summary" / "raw_distance_dist.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=150, bbox_inches="tight")
    if CH3.is_dir():
        fig.savefig(CH3 / "repr_distance_hist_raw.pdf", bbox_inches="tight")
        print("\nsaved", CH3 / "repr_distance_hist_raw.pdf")
    print("wrote", out)


if __name__ == "__main__":
    main()
