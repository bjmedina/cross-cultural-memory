#!/usr/bin/env python3
"""6-panel item-level results bars (hits/FA x 3 sound sets), regenerated once per
CI method (percentile / Fisher-z / BCa) so the interval constructions can be
compared on the real data. Participant bootstrap is computed once; each method's
CI is drawn as a vertical interval on each bar. Red cap = attenuation ceiling
sqrt(rho_A rho_B). No figure title.

    python plot_itemlevel_bars_ci.py            # writes 3 figures, one per method
"""
from __future__ import annotations
import sys, argparse
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402
from python.intergroup_corr import itemwise_corr, jackknife_intergroup_corr  # noqa: E402
from python.split_half import calculate_split_half_reliability  # noqa: E402
from python.ci_methods import ci_percentile, ci_fisher_z, ci_bca  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
CONDS = [("Industrial-Nature", "Environmental sounds"),
         ("Globalized-Music", "Globalized music"), ("NHS", "NHS (world song)")]
PAIRS = [("US", "SanBorja"), ("US", "Tsimane"), ("SanBorja", "Tsimane")]
PAIRLAB = ["U.S.–\nSan Borja", "U.S.–\nTsimane’", "San Borja–\nTsimane’"]
BARCOLS = ["#7E57C2", "#5D8AA8", "#8D6E63"]
MINRESP, MINITEMS, B = 2, 5, 1000


def align(MA, iA, MB, iB):
    shared = [it for it in iA if it in set(iB)]
    if len(shared) < MINITEMS:
        return None, None
    pa = {it: k for k, it in enumerate(iA)}; pb = {it: k for k, it in enumerate(iB)}
    ca = [pa[it] for it in shared]; cb = [pb[it] for it in shared]
    return MA[:, ca], MB[:, cb]


def cell_bootstrap(A, B_, rng):
    r_hat, _ = itemwise_corr(A, B_, min_resp=MINRESP, min_items=MINITEMS)
    nA, nB = A.shape[0], B_.shape[0]
    boot = np.full(B, np.nan)
    for b in range(B):
        rb, _ = itemwise_corr(A[rng.integers(0, nA, nA)], B_[rng.integers(0, nB, nB)],
                              min_resp=MINRESP, min_items=MINITEMS)
        boot[b] = rb
    jk, _ = jackknife_intergroup_corr(A, B_, min_resp=MINRESP, min_items=MINITEMS)
    return r_hat, boot, jk


def main():
    rng = np.random.default_rng(0)
    # load matrices + reliabilities once
    G = {}
    for cond, _ in CONDS:
        G[cond] = {}
        for g, codes in GROUPS.items():
            files = list_matfiles(BASE, codes, cond, 2.0, False)
            hits, fas, items = build_hit_fa_matrices(files)
            rel = calculate_split_half_reliability(hits, fas, items, n_splits=500)
            G[cond][g] = dict(hit=hits, fa=fas, items=items,
                              ceil_hit=rel.sb_hit, ceil_fa=rel.sb_fa)

    # bootstrap every cell once
    cells = {}  # (kind,cond,pair_idx) -> dict(r, boot, jk, ceil)
    for kind in ("hit", "fa"):
        for cond, _ in CONDS:
            for pi, (a, b) in enumerate(PAIRS):
                A, Bm = align(G[cond][a][kind], G[cond][a]["items"],
                              G[cond][b][kind], G[cond][b]["items"])
                if A is None:
                    cells[(kind, cond, pi)] = None; continue
                r, boot, jk = cell_bootstrap(A, Bm, rng)
                ceil = np.sqrt(G[cond][a]["ceil_" + kind] * G[cond][b]["ceil_" + kind])
                cells[(kind, cond, pi)] = dict(r=r, boot=boot, jk=jk, ceil=ceil)
                print(f"{kind} {cond:18s} {a}-{b}: r={r:.2f}")

    methods = {"percentile": lambda c: ci_percentile(c["boot"]),
               "fisher_z":  lambda c: ci_fisher_z(c["r"], c["boot"]),
               "bca":       lambda c: ci_bca(c["r"], c["boot"], c["jk"])}

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    for mname, mfun in methods.items():
        fig, axes = plt.subplots(2, 3, figsize=(12.5, 7.4), sharey=True)
        x = np.arange(3)
        for row, kind in enumerate(["hit", "fa"]):
            for col, (cond, clab) in enumerate(CONDS):
                ax = axes[row][col]
                rs = [cells[(kind, cond, pi)]["r"] if cells[(kind, cond, pi)] else np.nan
                      for pi in range(3)]
                ax.bar(x, rs, color=BARCOLS, width=0.64, edgecolor="white", zorder=3)
                for pi in range(3):
                    c = cells[(kind, cond, pi)]
                    if not c:
                        continue
                    lo, hi = mfun(c)
                    if np.isfinite(lo) and np.isfinite(hi):
                        ax.plot([pi, pi], [lo, hi], color="black", lw=1.6, zorder=6)
                        for yy in (lo, hi):
                            ax.plot([pi-0.1, pi+0.1], [yy, yy], color="black", lw=1.6, zorder=6)
                    ax.plot([pi-0.32, pi+0.32], [c["ceil"], c["ceil"]],
                            color="#C62828", lw=2, zorder=5)
                    ax.text(pi, max(hi if np.isfinite(hi) else c["r"], c["r"]) + 0.03,
                            f"{c['r']:.2f}", ha="center", fontsize=8.5,
                            fontweight="bold", color="#212121")
                ax.set_xticks(x); ax.set_xticklabels(PAIRLAB, fontsize=8)
                ax.set_ylim(0, 1.05); ax.grid(axis="y", ls="--", alpha=0.3)
                if row == 0:
                    ax.set_title(clab, fontsize=12)
                if col == 0:
                    ax.set_ylabel(("Hits" if kind == "hit" else "False alarms")
                                  + "\n\nitemwise correlation r", fontsize=10.5)
        axes[0][2].plot([], [], color="black", lw=1.6, label=f"95% CI ({mname})")
        axes[0][2].plot([], [], color="#C62828", lw=2, label=r"ceiling $\sqrt{\rho_A\rho_B}$")
        axes[0][2].legend(loc="upper right", fontsize=8, framealpha=0.9)
        fig.tight_layout()
        d = HERE / "dprime_vs_isi_outputs"
        fig.savefig(d / f"itemwise-bars-CI-{mname}.pdf", bbox_inches="tight")
        fig.savefig(d / f"itemwise-bars-CI-{mname}.png", dpi=170, bbox_inches="tight")
        plt.close(fig)
        print("saved", d / f"itemwise-bars-CI-{mname}.png")


if __name__ == "__main__":
    main()
