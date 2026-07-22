#!/usr/bin/env python3
"""Chapter-3 figure: cross-cultural d' vs ISI forgetting curves, one panel per
sound set, three cultural groups overlaid per panel.

This is the cross-cultural extension of the Chapter-1 forgetting-curve figure
(figures/ch1/dprime-vs-isi_all-sets.png): same population-d'(ISI) analysis, but
split by group (US / San Borja / Tsimane') within each sound set.

Sound sets are the multi-ISI "v01" three-set design shared by all three groups:
  - Environmental sounds   (ind-nature)
  - Auditory textures      (atexts)
  - Music, world/globalized(nhs-global)   [single combined set in the multi-ISI
                                            experiment; the 2025 Globalized-Music
                                            vs NHS split has no multi-ISI data]

All d'/curve/bootstrap conventions and loaders are reused from
crosscultural_dprime_overlay.py (which mirror the psychophysics chapter,
memory/utls/dprime.py + human_analysis.py). Default inclusion screen is the
chapter's d'>=2 at ISI=0.

Usage:
    python make_chapter3_dprime_figure.py            # writes PDF+PNG to ./dprime_vs_isi_outputs
    python make_chapter3_dprime_figure.py --out-dir /path/to/thesis/figures/ch3
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np
import pandas as pd

sys.path.insert(0, str(Path(__file__).resolve().parent))
import crosscultural_dprime_overlay as X  # noqa: E402

HERE = Path(__file__).resolve().parent

# panel order -> (condition key in X.COND_TOKENS, human-readable panel title)
PANELS = [
    ("Industrial-Nature", "Environmental sounds"),
    ("Textures", "Auditory textures"),
    ("NHS-Global", "Music (world / globalized)"),
]
GROUP_ORDER = ["US", "SanBorja", "Tsimane"]
GROUP_LABEL = {"US": "U.S.", "SanBorja": "San Borja", "Tsimane": "Tsimane’"}


def assemble_group(condition, prolific, bol24, bol25, thr):
    tok = X.COND_TOKENS[condition]
    parts = {
        "US": [X.load_csv_dir(prolific, tok["csv"], "US", "PROcsv")],
        "SanBorja": [X.load_mat_dir(bol24, X.SITES["SanBorja"], tok["mat2024"], "SanBorja", "BOL24")],
        "Tsimane": [
            X.load_mat_dir(bol24, X.SITES["Tsimane"], tok["mat2024"], "Tsimane", "BOL24"),
            X.load_mat_dir(bol25, X.SITES["Tsimane"], tok["mat2025"], "Tsimane", "BOL25"),
        ],
    }
    out = {}
    for g in GROUP_ORDER:
        frames = [p[0] for p in parts[g] if not p[0].empty]
        if not frames:
            out[g] = None
            continue
        df = pd.concat(frames, ignore_index=True)
        df, _ = X.apply_isi0_filter(df, thr)
        out[g] = X.run_analysis(df, n_boot=args_nboot) if not df.empty else None
    return out


def main(argv=None):
    global args_nboot
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--prolific-dir", default=str(X.LABS / "prolificResults"))
    ap.add_argument("--bolivia2024-dir", default=str(X.LABS / "Results"))
    ap.add_argument("--bolivia2025-dir", default=str(X.REPO_2025))
    ap.add_argument("--min-isi0-dprime", type=float, default=2.0)
    ap.add_argument("--n-boot", type=int, default=2000)
    ap.add_argument("--out-dir", default=str(HERE / "dprime_vs_isi_outputs"))
    ap.add_argument("--basename", default="dprime-vs-isi_crosscultural")
    args = ap.parse_args(argv)
    args_nboot = args.n_boot

    prolific = Path(args.prolific_dir)
    bol24 = Path(args.bolivia2024_dir)
    bol25 = Path(args.bolivia2025_dir)

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    colors = {"US": "#1f77b4", "SanBorja": "#ff7f0e", "Tsimane": "#2E7D32"}
    fig, axes = plt.subplots(1, len(PANELS), figsize=(13, 5.8), sharey=True)
    counts = {}

    for ax, (cond, title) in zip(axes, PANELS):
        res = assemble_group(cond, prolific, bol24, bol25, args.min_isi0_dprime)
        counts[cond] = {}
        all_isis = None
        for g in GROUP_ORDER:
            out = res[g]
            if out is None or out["N"] == 0:
                counts[cond][g] = 0
                continue
            counts[cond][g] = out["N"]
            ax.errorbar(out["isis"], out["dprime"], yerr=out["boot"]["sem"],
                        fmt="o-", color=colors[g], capsize=3, linewidth=1.8,
                        markersize=5, markeredgecolor="k", markeredgewidth=0.7,
                        label=f"{GROUP_LABEL[g]} (N={out['N']})")
            all_isis = out["isis"] if all_isis is None else all_isis
        if all_isis is not None:
            ax.set_xticks(all_isis)
            ax.set_xticklabels(all_isis, fontsize=10)
        ax.set_ylim(0, 3.5)
        ax.tick_params(axis="y", labelsize=10)
        ax.set_xlabel("ISI (intervening sounds)", fontsize=13)
        ax.set_title(title, fontsize=14)
        ax.grid(True, ls="--", alpha=0.4)
        ax.legend(loc="upper right", fontsize=10, framealpha=0.9)
        print(f"{cond}: " + "  ".join(f"{g}={counts[cond][g]}" for g in GROUP_ORDER))

    axes[0].set_ylabel("d' (sensitivity)", fontsize=14)
    fig.tight_layout()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    pdf = out_dir / f"{args.basename}.pdf"
    png = out_dir / f"{args.basename}.png"
    fig.savefig(pdf, bbox_inches="tight")
    fig.savefig(png, dpi=200, bbox_inches="tight")
    plt.close(fig)
    print(f"\nSaved: {pdf}\n       {png}")
    return counts


if __name__ == "__main__":
    main()
