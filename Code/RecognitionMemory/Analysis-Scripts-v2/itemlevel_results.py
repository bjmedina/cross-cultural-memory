#!/usr/bin/env python3
"""Real item-level cross-cultural results: per-item rate vectors, between-group
itemwise correlations, and within-group split-half ceilings, per sound set.

Single-ISI (ISI=16) item-level data only (is_multi_isi=False), inclusion screen
d'>=2 at ISI=0, minResp>=2 shared items — mirrors run_cross_cultural_analysis.py
/ the chapter's Methods. Saves per-pair scatter inputs + a summary to npz, and
prints a table. Plotting is done by plot_itemlevel_results.py.
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402
from python.split_half import calculate_split_half_reliability  # noqa: E402

BASE_DIR = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"),
          "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
CONDITIONS = ["Industrial-Nature", "Globalized-Music", "NHS"]
PAIRS = [("US", "SanBorja"), ("US", "Tsimane"), ("SanBorja", "Tsimane")]
MIN_ISI0, MINRESP, NSPLITS = 2.0, 2, 2000


def per_item_mean(mat, items):
    with np.errstate(invalid="ignore"):
        m = np.nanmean(mat, axis=0)
    n = np.sum(~np.isnan(mat), axis=0)
    return {it: (v, c) for it, v, c in zip(items, m, n)}


def main():
    out = {}
    for cond in CONDITIONS:
        grp = {}
        for g, codes in GROUPS.items():
            files = list_matfiles(BASE_DIR, codes, cond, MIN_ISI0, False)
            if not files:
                grp[g] = None
                continue
            hits, fas, items = build_hit_fa_matrices(files)
            rel = calculate_split_half_reliability(hits, fas, items, n_splits=NSPLITS)
            grp[g] = dict(n=hits.shape[0], items=items,
                          hit=per_item_mean(hits, items), fa=per_item_mean(fas, items),
                          ceil_hit=rel.sb_hit, ceil_fa=rel.sb_fa)
        out[cond] = grp
        print(f"\n=== {cond} ===")
        for g in GROUPS:
            if grp[g]:
                print(f"  {g:9s} n={grp[g]['n']:3d}  ceiling(hit)={grp[g]['ceil_hit']:.2f} "
                      f"ceiling(fa)={grp[g]['ceil_fa']:.2f}  items={len(grp[g]['items'])}")
            else:
                print(f"  {g:9s} no data")
        for a, b in PAIRS:
            if not (grp[a] and grp[b]):
                continue
            for kind in ("hit", "fa"):
                xa, xb = [], []
                for it in set(grp[a][kind]) & set(grp[b][kind]):
                    va, na = grp[a][kind][it]; vb, nb = grp[b][kind][it]
                    if na >= MINRESP and nb >= MINRESP and np.isfinite(va) and np.isfinite(vb):
                        xa.append(va); xb.append(vb)
                r = spearmanr(xa, xb).correlation if len(xa) >= 5 else np.nan
                print(f"    {a:9s}-{b:9s} {kind}: r={r:.3f}  (items={len(xa)})")

    np.savez(HERE / "dprime_vs_isi_outputs" / "itemlevel_results.npz",
             data=np.array(out, dtype=object))
    print("\nsaved itemlevel_results.npz")
    return out


if __name__ == "__main__":
    main()
