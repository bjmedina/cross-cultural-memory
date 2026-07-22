#!/usr/bin/env python3
"""Chapter-3 summary figure (MODEL): the fixed representation predicts a
cross-cultural difference only for music.

For each sound set, two bars = the model's in-context predictive-correlation gap to
Tsimane' at the mid learned layer (relu2),

    gap_US = rho(U.S.)      - rho(Tsimane')
    gap_SB = rho(San Borja) - rho(Tsimane').

A positive gap means the SAME representation predicts that group's per-sound false
alarms better than it predicts Tsimane's, i.e. it cannot account for all groups at
once. For globalized music both gaps are positive and exposure-ordered
(gap_US > gap_SB > 0); for environmental sounds and world song the gaps are not
positive, so the representation predicts every group comparably. Values and 95% CIs
are read from representation_gap.csv (paired sound bootstrap, Section cc-paired).
"""
import csv
from pathlib import Path

HERE = Path(__file__).resolve().parent
CSV = HERE / "results" / "kell2018_word_speaker_audioset" / "representation_gap.csv"
LAYER = "relu2"
CONDS = [("Environmental", "Environmental"),
         ("Music", "Globalized\nmusic"),
         ("World song", "World song\n(NHS)")]
PAIRS = [("US-Tsimane", "U.S. $-$ Tsimane’", "#1f77b4"),
         ("SanBorja-Tsimane", "San Borja $-$ Tsimane’", "#ff7f0e")]


def load():
    rows = [r for r in csv.DictReader(open(CSV))
            if r["layer"] == LAYER and r["metric"] == "euclidean" and str(r["k"]) == "3"]
    d = {}
    for r in rows:
        d[(r["cond"], r["pair"])] = (float(r["gap"]), float(r["ci_lo"]), float(r["ci_hi"]))
    return d


def main():
    d = load()
    import numpy as np
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(7.2, 4.6))
    x = np.arange(len(CONDS))
    w = 0.36
    for pi, (pair, plab, col) in enumerate(PAIRS):
        gaps = [d[(c[0], pair)][0] for c in CONDS]
        los = [d[(c[0], pair)][1] for c in CONDS]
        his = [d[(c[0], pair)][2] for c in CONDS]
        xs = x + (pi - 0.5) * w
        ax.bar(xs, gaps, w, color=col, label=plab, edgecolor="white", zorder=3)
        for xi, g, lo, hi in zip(xs, gaps, los, his):
            ax.plot([xi, xi], [lo, hi], color="black", lw=1.5, zorder=6)
            for yy in (lo, hi):
                ax.plot([xi - 0.07, xi + 0.07], [yy, yy], color="black", lw=1.5, zorder=6)
    ax.axhline(0, color="#444", lw=1)
    ax.set_xticks(x)
    ax.set_xticklabels([c[1] for c in CONDS], fontsize=10)
    ax.set_ylabel(r"model prediction gap to Tsimane’  "
                  r"($\rho_{\mathrm{group}}-\rho_{\mathrm{Tsimane'}}$)", fontsize=10)
    ax.set_title("Model in-context prediction gaps to Tsimane’, by sound set "
                 "(layer relu2)", fontsize=10.5, fontweight="bold")
    ax.legend(fontsize=9, loc="upper right", frameon=False)
    ax.grid(axis="y", ls="--", alpha=0.3)
    lo_all = min(v[1] for v in d.values())
    hi_all = max(v[2] for v in d.values())
    ax.set_ylim(lo_all - 0.06, hi_all + 0.08)
    fig.tight_layout()
    out = HERE / "results" / "_summary" / "summary_model_gap_relu2"
    fig.savefig(out.with_suffix(".png"), dpi=170, bbox_inches="tight")
    fig.savefig(out.with_suffix(".pdf"), bbox_inches="tight")
    print("saved", out.with_suffix(".pdf"))


if __name__ == "__main__":
    main()
