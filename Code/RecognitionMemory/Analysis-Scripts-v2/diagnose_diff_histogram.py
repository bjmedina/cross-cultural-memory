#!/usr/bin/env python3
"""Distributional view of reliability: is the per-sound spread real signal or noise?

For a group x condition cell:
  - FILLED histogram: the per-sound hit rate, centered (rate_j - mean). Its width is
    across-sound SIGNAL + sampling noise, i.e. how much sounds appear to differ.
  - LINE histograms (a few random splits): the per-sound half-A minus half-B
    difference. This cancels the true rate, so its width is pure sampling NOISE.

A reliable cell: the filled spread is much wider than the difference (signal sticks
out beyond noise). An unreliable cell (Tsimane' music): the two nearly coincide, the
apparent spread is all noise. NOTE the difference is not uniform when unreliable, it
is a narrow bump at 0; the diagnostic is width-of-spread vs width-of-difference.
Screened sample (d'>=2, finished). Hits."""
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT = HERE / "dprime_vs_isi_outputs"
CELLS = [("Music","Globalized-Music",("PRO","BOS","CAM"),"U.S. music","#1f77b4"),
         ("Music","Globalized-Music",("SBO","SNB","SBJ"),"San Borja music","#ff7f0e"),
         ("Music","Globalized-Music",("NVM","MAJ","MAN","NUM","NUV","CVR"),"Tsimane' music","#C62828"),
         ("World song","NHS",("NVM","MAJ","MAN","NUM","NUV","CVR"),"Tsimane' world song","#2E7D32")]
NSPLIT = 3
rng = np.random.default_rng(1)

import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
bins = np.linspace(-0.55, 0.55, 26)
fig, axes = plt.subplots(2, 2, figsize=(12, 8), sharex=True)
for ax, (clab, cond, codes, title, col) in zip(axes.ravel(), CELLS):
    h, f, _ = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
    with np.errstate(invalid="ignore"):
        rate = np.nanmean(h, 0)
    rate = rate[np.isfinite(rate)]
    dev = rate - np.nanmean(rate)
    ax.hist(dev, bins=bins, color=col, alpha=0.45, density=True,
            label=f"per-sound rate spread (SD={np.std(dev):.3f})")
    # half-A minus half-B is computed on half-samples, so its variance is 4x the
    # full-sample sampling-noise variance; scale by 1/2 to express it at the same
    # (full-sample) footing as the per-sound rate spread above.
    diff_sds = []
    for s in range(NSPLIT):
        idx = rng.permutation(h.shape[0]); a, b = idx[:h.shape[0]//2], idx[h.shape[0]//2:]
        with np.errstate(invalid="ignore"):
            va, vb = np.nanmean(h[a],0), np.nanmean(h[b],0)
        m = np.isfinite(va) & np.isfinite(vb); d = 0.5 * (va[m]-vb[m])
        diff_sds.append(np.std(d))
        ax.hist(d, bins=bins, histtype="step", lw=1.6, density=True, color="#333", alpha=0.7,
                label="sampling noise (full-sample scale)" if s == 0 else None)
    ax.axvline(0, color="#999", lw=0.8)
    ax.set_title(f"{title}   (noise SD={np.mean(diff_sds):.3f})", fontsize=11, color=col)
    ax.legend(fontsize=8, loc="upper right"); ax.set_yticks([])
    ax.set_xlabel("deviation from cell mean hit rate", fontsize=9.5)
fig.suptitle("Per-sound rate spread (signal+noise) vs half-differences (noise): "
             "for Tsimane' music they coincide", fontsize=12.5, fontweight="bold")
fig.tight_layout(rect=[0,0,1,0.96])
fig.savefig(OUT/"diagnose_diff_histogram.png", dpi=160, bbox_inches="tight")
print("saved diagnose_diff_histogram.png")
