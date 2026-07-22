#!/usr/bin/env python3
"""In-context confusability: kNN geometry using ONLY sounds heard up to that point.

The presentation order is randomized per participant, so the set of sounds a probe
could be confused with (what is already in memory) differs by presentation. For
each foil presentation we take the probe's mean distance to its k nearest neighbours
among the DISTINCT sounds heard earlier in that same sequence, and average per sound
over the pooled real sequences of ALL participants (blind to group, so the predictor
stays group-independent). We compare this in-context confusability against the
global measure (kNN over the full 80-sound set) for the primary model.
"""
import sys
from pathlib import Path

import numpy as np
from scipy.stats import spearmanr
from scipy.spatial.distance import cdist
import scipy.io as sio

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))
from run_representation_analysis import (  # noqa: E402
    CODES, GLAB, CONDS, load_embeddings, per_sound_fa, canonical_names, BASE)
from python.io import list_matfiles, _stim_basename  # noqa: E402
from repr_models import current_model  # noqa: E402

MODEL_TAG, SPEC = current_model()
LAYERS = SPEC["layers"]
METRIC, K = "euclidean", 3
GORDER = ["U.S.", "San Borja", "Tsimane'"]


def load_sequences(cond):
    """Pooled per-participant (ordered stims, foil mask) across ALL groups."""
    seqs = []
    for g, codes in CODES.items():
        for f in list_matfiles(BASE, codes, cond, 2.0, False):
            d = sio.loadmat(f, variable_names=["stimulusPresented", "repeatPosition"])
            stims = [_stim_basename(s) for s in np.array(d["stimulusPresented"]).ravel()]
            rp = np.asarray(d["repeatPosition"]).ravel().astype(float)
            seqs.append((stims, ~np.isfinite(rp)))
    return seqs


def global_conf(D, names, k):
    Dg = D.copy()
    np.fill_diagonal(Dg, np.inf)
    return {n: -np.sort(Dg[i])[:k].mean() for i, n in enumerate(names)}


def incontext_conf(D, names, seqs, k):
    idx = {n: i for i, n in enumerate(names)}
    acc = {n: [] for n in names}
    for stims, foil in seqs:
        seen, seen_set = [], set()
        for t, s in enumerate(stims):
            si = idx.get(s)
            if foil[t] and si is not None and seen:
                ctx = [j for j in seen if j != si]
                if ctx:
                    acc[s].append(-np.sort(D[si, ctx])[:min(k, len(ctx))].mean())
            if si is not None and si not in seen_set:
                seen.append(si); seen_set.add(si)
    return {n: (np.mean(acc[n]) if acc[n] else np.nan) for n in names}


def main():
    print(f"model={MODEL_TAG} metric={METRIC} k={K}\n")
    for cond, clab in CONDS:
        names = canonical_names(cond)
        seqs = load_sequences(cond)
        npres = sum(int(f.sum()) for _, f in seqs)
        fa = {g: per_sound_fa(cond, CODES[g]) for g in CODES}
        print(f"== {clab} ==  {len(seqs)} sequences, {npres} foil presentations")
        print(f"  {'layer':<20}{'group':<11}{'global':>9}{'in-context':>12}")
        for layer in LAYERS:
            emb = load_embeddings(cond, layer, names)
            common = [n for n in names if n in emb]
            M = np.stack([emb[n] for n in common])
            D = cdist(M, M, metric=METRIC)
            gc = global_conf(D, common, K)
            ic = incontext_conf(D, common, seqs, K)
            gv = np.array([gc[n] for n in common])
            iv = np.array([ic[n] for n in common])
            for g in CODES:
                y = np.array([fa[g].get(n, np.nan) for n in common])
                m = np.isfinite(y) & np.isfinite(iv)
                rg = spearmanr(gv[m], y[m]).correlation
                ri = spearmanr(iv[m], y[m]).correlation
                print(f"  {layer:<20}{GLAB[g]:<11}{rg:>+9.2f}{ri:>+12.2f}")
        print()


if __name__ == "__main__":
    main()
