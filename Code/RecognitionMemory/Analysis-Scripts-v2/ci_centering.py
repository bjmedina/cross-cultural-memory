#!/usr/bin/env python3
"""Is the CI centered on the OBSERVED r_hat, or on the (biased) bootstrap mean?

For every real cell, report r_hat, the bootstrap mean, the bootstrap bias
(mean_boot - r_hat), and the midpoint of each method's CI. A method whose CI
midpoint tracks r_hat is centered on the data; one that tracks the bootstrap
mean inherits the bootstrap bias.
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
CONDS = ["Industrial-Nature", "Globalized-Music", "NHS"]
PAIRS = [("US", "SanBorja"), ("US", "Tsimane"), ("SanBorja", "Tsimane")]
MINRESP, MINITEMS, B = 2, 5, 2000


def align(MA, iA, MB, iB):
    shared = [it for it in iA if it in set(iB)]
    pa = {it: k for k, it in enumerate(iA)}; pb = {it: k for k, it in enumerate(iB)}
    return MA[:, [pa[i] for i in shared]], MB[:, [pb[i] for i in shared]]


def main():
    rng = np.random.default_rng(0)
    cache = {}
    def mats(cond, g):
        if (cond, g) not in cache:
            files = list_matfiles(BASE, GROUPS[g], cond, 2.0, False)
            cache[(cond, g)] = build_hit_fa_matrices(files)
        return cache[(cond, g)]

    print(f"{'cell':<34}{'r_hat':>7}{'bootMu':>8}{'bias':>7} | "
          f"{'pct_mid':>8}{'Δr':>6} | {'fz_mid':>8}{'Δr':>6} | {'bca_mid':>8}{'Δr':>6}")
    agg = {"percentile": [], "fisher_z": [], "bca": []}
    for kind in ("hit", "fa"):
        for cond in CONDS:
            for a, b in PAIRS:
                hA, fA, iA = mats(cond, a); hB, fB, iB = mats(cond, b)
                MA, MB = align(hA if kind == "hit" else fA, iA,
                               hB if kind == "hit" else fB, iB)
                r_hat, _ = itemwise_corr(MA, MB, min_resp=MINRESP, min_items=MINITEMS)
                nA, nB = MA.shape[0], MB.shape[0]
                boot = np.array([itemwise_corr(MA[rng.integers(0, nA, nA)],
                                               MB[rng.integers(0, nB, nB)],
                                               min_resp=MINRESP, min_items=MINITEMS)[0]
                                 for _ in range(B)])
                jk, _ = jackknife_intergroup_corr(MA, MB, min_resp=MINRESP, min_items=MINITEMS)
                bmu = np.nanmean(boot)
                cis = {"percentile": ci_percentile(boot),
                       "fisher_z": ci_fisher_z(r_hat, boot),
                       "bca": ci_bca(r_hat, boot, jk)}
                mids = {m: (lo + hi) / 2 for m, (lo, hi) in cis.items()}
                for m in agg:
                    agg[m].append(abs(mids[m] - r_hat))
                lab = f"{kind} {cond[:11]:<11} {a[:3]}-{b[:3]}"
                print(f"{lab:<34}{r_hat:>7.3f}{bmu:>8.3f}{bmu-r_hat:>7.3f} | "
                      f"{mids['percentile']:>8.3f}{mids['percentile']-r_hat:>6.3f} | "
                      f"{mids['fisher_z']:>8.3f}{mids['fisher_z']-r_hat:>6.3f} | "
                      f"{mids['bca']:>8.3f}{mids['bca']-r_hat:>6.3f}")
    print("\nmean |CI midpoint - r_hat| across cells (centeredness; lower=better):")
    for m in agg:
        print(f"  {m:<11}{np.mean(agg[m]):.4f}")


if __name__ == "__main__":
    main()
