#!/usr/bin/env python3
"""Exploratory: in-context confusability from a CONCATENATED representation.

Instead of one layer at a time, stack all layers into a single vector (each
layer L2-normalized per sound before concatenation, so layers contribute equally
regardless of dimensionality), and compute the same per-group in-context
confusability on that combined space. Reports music per-group rho and pairwise
gaps, and the other sets, for the primary trained CochDNN, next to the best
single layer.
"""
import sys
from pathlib import Path

import numpy as np
from scipy.stats import spearmanr
from scipy.spatial.distance import cdist

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_representation_analysis import (  # noqa: E402
    CODES, GLAB, CONDS, load_embeddings, per_sound_fa, canonical_names,
    load_sequences, incontext_confusability)
from repr_models import current_model  # noqa: E402

_, SPEC = current_model()
LAYERS = SPEC["layers"]
K = 3
GORDER = ["U.S.", "San Borja", "Tsimane'"]


def concat_matrix(cond, names, layers):
    """80 x (sum dims) matrix; each layer L2-normalized per sound then concatenated."""
    blocks = []
    for L in layers:
        emb = load_embeddings(cond, L, names)
        M = np.stack([emb[n] for n in names]).astype(np.float64)
        nrm = np.linalg.norm(M, axis=1, keepdims=True)
        nrm[nrm == 0] = 1.0
        blocks.append(M / nrm)
    return np.hstack(blocks)


def gaps(confg, fa, names):
    common = [n for n in names if all(np.isfinite(confg[g][n]) and np.isfinite(fa[g].get(n, np.nan))
                                      for g in CODES)]
    rho = {}
    for g in CODES:
        x = np.array([confg[g][n] for n in common]); y = np.array([fa[g][n] for n in common])
        rho[GLAB[g]] = spearmanr(x, y).correlation
    def gp(a, b):
        return rho[a] - rho[b]
    return rho, {"US-SB": gp("U.S.", "San Borja"), "SB-Ts": gp("San Borja", "Tsimane'"),
                 "US-Ts": gp("U.S.", "Tsimane'")}


VARIANTS = {"concat ALL layers": LAYERS,
            "concat learned conv (relu0-relu4)": [L for L in LAYERS if L.startswith("relu") and L != "relufc"]}


def main():
    for cond, clab in CONDS:
        names = canonical_names(cond)
        fa = {g: per_sound_fa(cond, CODES[g]) for g in CODES}
        seqs = {g: load_sequences(cond, CODES[g]) for g in CODES}
        print(f"\n===== {clab} =====")
        for vlabel, layers in VARIANTS.items():
            M = concat_matrix(cond, names, layers)
            D = cdist(M, M, metric="euclidean")
            confg = {g: incontext_confusability(D, names, seqs[g], K) for g in CODES}
            rho, gp = gaps(confg, fa, names)
            ts = rho["Tsimane'"]
            print(f"  {vlabel:<34} US {rho['U.S.']:+.2f} / SB {rho['San Borja']:+.2f} / "
                  f"Ts {ts:+.2f}   gaps US-SB {gp['US-SB']:+.2f} "
                  f"SB-Ts {gp['SB-Ts']:+.2f} US-Ts {gp['US-Ts']:+.2f}", flush=True)


if __name__ == "__main__":
    main()
