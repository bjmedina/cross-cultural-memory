#!/usr/bin/env python3
"""Chapter-3 figure: per-sound split-half scatter of the false-alarm rate.

One panel per sound set (row) x group (column). Points are the sounds; each
sound's mean FA rate in one random half of the group's participants (x) versus
the other half (y), for the median-representative split (the split whose
Spearman correlation is closest to the median over many random splits, so the
scatter shown matches the reported reliability). Each panel is annotated with the
Spearman-Brown split-half reliability (median split-half r, corrected to full
sample), the same quantity plotted in the reliability bars.

Reproduces the methodology of python/split_half.py. FA-only, matching the
chapter's false-recognizability focus.
"""
from pathlib import Path
import sys
import numpy as np
from scipy.stats import spearmanr
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
CONDS = [("Industrial-Nature", "Environmental"),
         ("Globalized-Music", "Globalized music"),
         ("NHS", "World song (NHS)")]
CODES = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
         "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
GLAB = {"US": "U.S.", "SanBorja": "San Borja", "Tsimane": "Tsimane’"}
GCOL = {"US": "#1f77b4", "SanBorja": "#ff7f0e", "Tsimane": "#2E7D32"}
GROUPS = ["US", "SanBorja", "Tsimane"]

N_SPLITS = 4000
N_PERM = 2000
SEED = 0

# selected measure (overridden by --measure in __main__)
MEASURE = "fa"
RLAB = "FA"          # axis label
RNAME = "false-alarm rate"   # suptitle phrase


def perm_p(m1, m2, r_obs, rng, nperm=N_PERM):
    """One-sided permutation p that split-half agreement exceeds chance.

    Shuffle the item labels of one half-vector and recompute Spearman; the null
    is 'no consistent per-sound structure' (r ~ 0). p = (1 + #[r_perm >= r_obs])
    / (nperm + 1).
    """
    n = len(m2)
    ge = 0
    for _ in range(nperm):
        rp = spearmanr(m1, m2[rng.permutation(n)]).correlation
        if np.isfinite(rp) and rp >= r_obs:
            ge += 1
    return (1 + ge) / (nperm + 1)


def representative_split(fa):
    """Return (m1, m2, sb, r_obs, p) for the median-representative split.

    fa : [n_sub x n_items] with NaN for unseen items.
    """
    rng = np.random.default_rng(SEED)
    n_sub = fa.shape[0]
    half = n_sub // 2
    rs = np.full(N_SPLITS, np.nan)
    perms = []
    for s in range(N_SPLITS):
        idx = rng.permutation(n_sub)
        perms.append(idx)
        m1 = np.nanmean(fa[idx[:half]], axis=0)
        m2 = np.nanmean(fa[idx[half:]], axis=0)
        ok = np.isfinite(m1) & np.isfinite(m2)
        if ok.sum() >= 3:
            rs[s] = spearmanr(m1[ok], m2[ok]).correlation
    med = np.nanmedian(rs)
    sb = 2 * med / (1 + med)
    # split closest to the median r
    j = int(np.nanargmin(np.abs(rs - med)))
    idx = perms[j]
    m1 = np.nanmean(fa[idx[:half]], axis=0)
    m2 = np.nanmean(fa[idx[half:]], axis=0)
    ok = np.isfinite(m1) & np.isfinite(m2)
    m1, m2 = m1[ok], m2[ok]
    r_obs = spearmanr(m1, m2).correlation
    p = perm_p(m1, m2, r_obs, rng)
    return m1, m2, sb, r_obs, p


def main():
    nrow, ncol = len(CONDS), len(GROUPS)
    fig, axes = plt.subplots(nrow, ncol, figsize=(3.5 * ncol, 3.4 * nrow),
                             squeeze=False)
    for r, (cond, clab) in enumerate(CONDS):
        for c, g in enumerate(GROUPS):
            ax = axes[r][c]
            files = list_matfiles(BASE, CODES[g], cond, 2.0, False)
            hit, fa, items = build_hit_fa_matrices(files)
            mat = hit if MEASURE == "hit" else fa
            m1, m2, sb, r_obs, p = representative_split(mat)
            pstr = "$p<0.001$" if p < 1e-3 else f"$p={p:.3f}$"
            print(f"{cond:18s} {g:9s} sb={sb:.2f} r={r_obs:.2f} p={p:.4f}")
            ax.scatter(m1, m2, s=20, color=GCOL[g], alpha=0.7, edgecolor="none")
            ax.plot([0, 1], [0, 1], color="#999", lw=1, ls="--")
            ax.text(0.05, 0.95, f"$\\hat\\rho_{{SB}}={sb:.2f}$\n{pstr}\n$n={mat.shape[0]}$",
                    transform=ax.transAxes, va="top", ha="left", fontsize=8.5)
            ax.set_xlim(-0.03, 1.03)
            ax.set_ylim(-0.03, 1.03)
            ax.set_aspect("equal")
            ax.grid(True, ls="--", alpha=0.25)
            if r == 0:
                ax.set_title(GLAB[g], fontsize=11)
            if c == 0:
                ax.set_ylabel(f"{clab}\n{RLAB} rate, half 2", fontsize=9.5)
            if r == nrow - 1:
                ax.set_xlabel(f"{RLAB} rate, half 1", fontsize=9.5)
    fig.suptitle(f"Per-sound {RNAME}: split-half agreement within each group",
                 fontsize=12, fontweight="bold")
    fig.tight_layout(rect=[0, 0, 1, 0.97])
    out = HERE / "dprime_vs_isi_outputs" / f"split_half_scatter_{MEASURE}"
    fig.savefig(out.with_suffix(".png"), dpi=170, bbox_inches="tight")
    fig.savefig(out.with_suffix(".pdf"), bbox_inches="tight")
    print("saved", out.with_suffix(".pdf"))


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser()
    ap.add_argument("--measure", choices=["hit", "fa"], default="fa")
    a = ap.parse_args()
    MEASURE = a.measure
    RLAB = "hit" if MEASURE == "hit" else "FA"
    RNAME = "hit rate" if MEASURE == "hit" else "false-alarm rate"
    main()
