#!/usr/bin/env python3
"""How do the CI methods change as the number of bootstrap resamples B grows?

For a few representative real cells, run R independent bootstrap pools at each B
on a grid, build percentile / Fisher-z / BCa CIs, and track the mean and
Monte-Carlo SD of each CI bound vs B. A stable method's bounds flatten early and
have small run-to-run SD; an unstable one keeps drifting / has wide SD. The
jackknife (BCa acceleration) is data-only, computed once per cell.

Output: ci_convergence.png  (rows = cells, cols = methods; lo/hi vs B with +/-SD).
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402
from python.intergroup_corr import itemwise_corr, jackknife_intergroup_corr  # noqa: E402
from python.ci_methods import ci_percentile, ci_fisher_z, ci_bca  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
MINRESP, MINITEMS = 2, 5
# representative cells: (label, condition, groupA, groupB, kind)
CELLS = [
    ("GM hits  U.S.–Tsimane’ (low reliability)", "Globalized-Music", "US", "Tsimane", "hit"),
    ("GM FA    U.S.–Tsimane’ (the dip, r≈0.25)", "Globalized-Music", "US", "Tsimane", "fa"),
    ("NHS FA   U.S.–San Borja (stable, r≈0.77)", "NHS", "US", "SanBorja", "fa"),
]
B_GRID = [50, 100, 200, 400, 800, 1600]
R = 25                      # independent bootstrap pools per B
METHODS = ["percentile", "fisher_z", "bca"]


def align(MA, iA, MB, iB):
    shared = [it for it in iA if it in set(iB)]
    pa = {it: k for k, it in enumerate(iA)}; pb = {it: k for k, it in enumerate(iB)}
    return MA[:, [pa[i] for i in shared]], MB[:, [pb[i] for i in shared]]


def main():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    # cache matrices per (cond, group)
    cache = {}
    def mats(cond, g):
        if (cond, g) not in cache:
            files = list_matfiles(BASE, GROUPS[g], cond, 2.0, False)
            h, f, it = build_hit_fa_matrices(files)
            cache[(cond, g)] = (h, f, it)
        return cache[(cond, g)]

    fig, axes = plt.subplots(len(CELLS), len(METHODS), figsize=(13, 9.5), sharex=True)
    rng = np.random.default_rng(0)

    for r_i, (label, cond, ga, gb, kind) in enumerate(CELLS):
        hA, fA, iA = mats(cond, ga); hB, fB, iB = mats(cond, gb)
        MA, MB = align(hA if kind == "hit" else fA, iA, hB if kind == "hit" else fB, iB)
        r_hat, _ = itemwise_corr(MA, MB, min_resp=MINRESP, min_items=MINITEMS)
        jk, _ = jackknife_intergroup_corr(MA, MB, min_resp=MINRESP, min_items=MINITEMS)
        nA, nB = MA.shape[0], MB.shape[0]

        # collect CI bounds: bounds[method][which][B] = list over R runs
        bounds = {m: {"lo": {B: [] for B in B_GRID}, "hi": {B: [] for B in B_GRID}}
                  for m in METHODS}
        Bmax = max(B_GRID)
        for _ in range(R):
            pool = np.empty(Bmax)
            for b in range(Bmax):
                rb, _ = itemwise_corr(MA[rng.integers(0, nA, nA)], MB[rng.integers(0, nB, nB)],
                                      min_resp=MINRESP, min_items=MINITEMS)
                pool[b] = rb
            for B in B_GRID:
                sub = pool[:B]
                cis = {"percentile": ci_percentile(sub),
                       "fisher_z": ci_fisher_z(r_hat, sub),
                       "bca": ci_bca(r_hat, sub, jk)}
                for m in METHODS:
                    lo, hi = cis[m]
                    bounds[m]["lo"][B].append(lo); bounds[m]["hi"][B].append(hi)

        for c_i, m in enumerate(METHODS):
            ax = axes[r_i][c_i]
            for which, col in [("lo", "#1565C0"), ("hi", "#C62828")]:
                mean = np.array([np.nanmean(bounds[m][which][B]) for B in B_GRID])
                sd = np.array([np.nanstd(bounds[m][which][B]) for B in B_GRID])
                ax.plot(B_GRID, mean, "-o", color=col, ms=4, lw=1.6)
                ax.fill_between(B_GRID, mean - sd, mean + sd, color=col, alpha=0.2)
            ax.axhline(r_hat, ls=":", color="#555", lw=1)
            ax.set_xscale("log")
            ax.set_xticks(B_GRID); ax.set_xticklabels(B_GRID, fontsize=7)
            ax.tick_params(labelsize=7)
            if r_i == 0:
                ax.set_title(m, fontsize=12)
            if c_i == 0:
                ax.set_ylabel(label, fontsize=8.5)
            if r_i == len(CELLS) - 1:
                ax.set_xlabel("bootstrap resamples B", fontsize=9)
            ax.grid(True, ls="--", alpha=0.3)
    axes[0][0].plot([], [], color="#1565C0", label="lower bound")
    axes[0][0].plot([], [], color="#C62828", label="upper bound")
    axes[0][0].legend(fontsize=7, loc="lower right")
    fig.suptitle("")  # no title
    fig.tight_layout()
    out = HERE / "dprime_vs_isi_outputs" / "ci_convergence.png"
    fig.savefig(out, dpi=160, bbox_inches="tight")
    fig.savefig(out.with_suffix(".pdf"), bbox_inches="tight")
    print("saved", out, f"(r_hat per row: "
          + ", ".join(f'{c[0][:6]}…' for c in CELLS) + ")")


if __name__ == "__main__":
    main()
