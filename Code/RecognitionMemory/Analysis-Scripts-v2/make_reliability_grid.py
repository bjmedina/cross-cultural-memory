#!/usr/bin/env python3
"""Exhaustive within-group split-half reliability grid, hits AND false alarms,
with bootstrap confidence intervals.

For every sound set (column) and measure (row: false alarms, hits), plot the
Spearman--Brown split-half reliability of the per-sound rate for each of the three
groups, with a 95% bootstrap CI over participants as the error bar, the value
printed above each bar, and the reliability floor (0.5) marked.

Method matches python/split_half.py: median split-half Spearman over random
participant halves, Spearman--Brown corrected to full sample. The CI resamples
participants with replacement and recomputes the full pipeline on each resample
(median over N_SPLITS_BOOT random splits per resample; the extra split noise
widens the CI slightly, i.e. it is conservative). Percentile CI.
"""
from pathlib import Path
import argparse
import json
import sys
import numpy as np
from scipy.stats import rankdata
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
CONDS = [("Industrial-Nature", "Environmental sounds"),
         ("Globalized-Music", "Globalized music"),
         ("NHS", "World song (NHS)")]
CODES = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
         "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
GLAB = {"US": "U.S.", "SanBorja": "San Borja", "Tsimane": "Tsimane’"}
GCOL = {"US": "#1f77b4", "SanBorja": "#ff7f0e", "Tsimane": "#2E7D32"}
GROUPS = ["US", "SanBorja", "Tsimane"]
MEASURES = [("fa", "False alarms"), ("hit", "Hits")]

N_SPLITS = 10000       # splits for the point estimate (matches Methods S=10,000)
N_BOOT = 1000          # participant-bootstrap resamples
N_SPLITS_BOOT = 30     # splits per bootstrap resample
SEED = 0


def fast_spearman(x, y):
    """Spearman rho as Pearson on average ranks (fast path for small vectors)."""
    rx, ry = rankdata(x), rankdata(y)
    rx = rx - rx.mean()
    ry = ry - ry.mean()
    d = np.sqrt((rx * rx).sum() * (ry * ry).sum())
    return (rx * ry).sum() / d if d > 0 else np.nan


def _median_split_r(mat, ids, rng, n_splits):
    """Median split-half Spearman over random participant halves.

    ids gives the ORIGINAL participant index of each row (with duplicates when
    mat is a bootstrap resample). Halves are formed over unique original
    participants, so no participant's copies ever straddle the two halves;
    otherwise duplicated rows appear on both sides and spuriously inflate the
    split-half correlation.
    """
    rs = []
    uniq = np.unique(ids)
    hu = len(uniq) // 2
    for _ in range(n_splits):
        perm = rng.permutation(uniq)
        mask1 = np.isin(ids, perm[:hu])
        with np.errstate(invalid="ignore"):
            m1 = np.nanmean(mat[mask1], axis=0)
            m2 = np.nanmean(mat[~mask1], axis=0)
        ok = np.isfinite(m1) & np.isfinite(m2)
        if ok.sum() >= 3:
            r = fast_spearman(m1[ok], m2[ok])
            if np.isfinite(r):
                rs.append(r)
    return np.median(rs) if rs else np.nan


def sb(r):
    return 2 * r / (1 + r) if np.isfinite(r) else np.nan


def point_and_ci(mat):
    """(sb_point, sb_lo, sb_hi, n_subjects) with a participant bootstrap.

    CI is Fisher-z style: centered on the point estimate, with the width taken
    from the bootstrap SD on the atanh scale. A percentile CI is NOT usable
    here because each participant resample holds ~63% unique listeners, which
    systematically shifts the bootstrap replicates relative to the full-sample
    point estimate; centering on the point uses only the (valid) spread.
    """
    rng = np.random.default_rng(SEED)
    n = mat.shape[0]
    point = sb(_median_split_r(mat, np.arange(n), rng, N_SPLITS))
    boots = []
    for _ in range(N_BOOT):
        bidx = rng.integers(0, n, n)
        v = sb(_median_split_r(mat[bidx], bidx, rng, N_SPLITS_BOOT))
        if np.isfinite(v):
            boots.append(v)
    if len(boots) < 2 or not np.isfinite(point):
        return point, np.nan, np.nan, n
    eps = 1e-6
    z = np.arctanh(np.clip(boots, -1 + eps, 1 - eps))
    sigma = float(np.std(z, ddof=1))
    zh = float(np.arctanh(np.clip(point, -1 + eps, 1 - eps)))
    lo, hi = float(np.tanh(zh - 1.96 * sigma)), float(np.tanh(zh + 1.96 * sigma))
    return point, lo, hi, n


def main(replot=False):
    cache = HERE / "dprime_vs_isi_outputs" / "reliability_grid_values.json"
    if replot and cache.exists():
        raw = json.load(open(cache))
        rel = {tuple(k.split("|")): tuple(v) for k, v in raw.items()}
        print(f"replotting from {cache}", flush=True)
    else:
        # one data load per (cond, group); both measures from the same matrices
        rel = {}
        for cond, _ in CONDS:
            for g in GROUPS:
                files = list_matfiles(BASE, CODES[g], cond, 2.0, False)
                hit, fa, _ = build_hit_fa_matrices(files)
                for meas, mat in (("fa", fa), ("hit", hit)):
                    point, lo, hi, n = point_and_ci(mat)
                    rel[(meas, cond, g)] = (float(point), float(lo), float(hi), int(n))
                    print(f"{meas:3s} {cond:18s} {GLAB[g]:10s} "
                          f"sb={point:.2f} CI=[{lo:.2f},{hi:.2f}] n={n}", flush=True)
        json.dump({"|".join(k): v for k, v in rel.items()}, open(cache, "w"))

    nrow, ncol = len(MEASURES), len(CONDS)
    fig, axes = plt.subplots(nrow, ncol, figsize=(3.7 * ncol, 3.2 * nrow),
                             squeeze=False, sharey=True)
    x = np.arange(len(GROUPS))
    for r, (meas, mlab) in enumerate(MEASURES):
        for c, (cond, clab) in enumerate(CONDS):
            ax = axes[r][c]
            vals = [rel[(meas, cond, g)][0] for g in GROUPS]
            los = [rel[(meas, cond, g)][1] for g in GROUPS]
            his = [rel[(meas, cond, g)][2] for g in GROUPS]
            ns = [rel[(meas, cond, g)][3] for g in GROUPS]
            ax.bar(x, vals, color=[GCOL[g] for g in GROUPS], width=0.62,
                   edgecolor="black", linewidth=0.6)
            yerr = [[max(0, v - lo) for v, lo in zip(vals, los)],
                    [max(0, hi - v) for v, hi in zip(vals, his)]]
            ax.errorbar(x, vals, yerr=yerr, fmt="none", ecolor="k", capsize=3,
                        lw=1.1, zorder=5)
            for xi, v, hi in zip(x, vals, his):
                top = hi if np.isfinite(hi) else v
                ax.text(xi, (top if np.isfinite(top) else 0) + 0.02,
                        f"{v:.2f}" if np.isfinite(v) else "n/a",
                        ha="center", va="bottom", fontsize=9)
            ax.set_xticks(x)
            ax.set_xticklabels([f"{GLAB[g]}\n$n={n}$" for g, n in zip(GROUPS, ns)],
                               fontsize=9)
            ax.set_ylim(0, 1.12)
            ax.grid(True, axis="y", ls="--", alpha=0.3)
            if r == 0:
                ax.set_title(clab, fontsize=12)
            if c == 0:
                ax.set_ylabel(f"{mlab}\nsplit-half reliability\n(Spearman--Brown)",
                              fontsize=10.5)
    fig.suptitle("Within-group split-half reliability of per-sound rates, "
                 "by measure, sound set, and group (Fisher-z 95% CIs)",
                 fontsize=13, fontweight="bold")
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    out = HERE / "dprime_vs_isi_outputs" / "reliability_grid"
    fig.savefig(out.with_suffix(".pdf"), bbox_inches="tight")
    fig.savefig(out.with_suffix(".png"), dpi=170, bbox_inches="tight")
    print("saved", out.with_suffix(".pdf"))


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--replot", action="store_true",
                    help="redraw from cached values without recomputing")
    main(replot=ap.parse_args().replot)
