#!/usr/bin/env python3
"""Descriptive: per-sound false-alarm-rate distributions, per group and set,
and the split-half reliabilities that give the analysis its ceiling.

Mirrors the item-distribution figure of Chapter 1, adding the group dimension:
a 3x3 grid (rows = sound set, columns = group) of per-sound false-alarm-rate
histograms, each annotated with its mean and its Spearman-Brown split-half
reliability. A companion bar chart shows the reliabilities directly.
"""
import csv
import sys
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_representation_analysis import (  # noqa: E402
    CODES, GLAB, canonical_names, build_hit_fa_matrices, list_matfiles, BASE)

CONDS = [("Industrial-Nature", "Environmental"), ("Globalized-Music", "Music"),
         ("NHS", "World song")]
GORDER = ["U.S.", "San Borja", "Tsimane'"]
GCOL = {"U.S.": "#1f77b4", "San Borja": "#ff7f0e", "Tsimane'": "#2E7D32"}
# per-set colours in the Chapter 1 spirit (one colour per sound set)
SCOL = {"Environmental": "#1f77b4", "Music": "#9467bd", "World song": "#2ca02c"}
OUT = HERE / "results" / "_summary"
CH3 = Path("/orcd/data/jhm/001/om2/bjmedina/auditory-memory/memory/docs/"
           "thesis/figures/ch3")
REL_CSV = HERE / "results" / "kell2018_word_speaker_audioset" / "representation_results.csv"


def reliabilities():
    """{(cond_label, group_label): fa_reliability} from the analysis output."""
    rel = {}
    if REL_CSV.exists():
        for r in csv.DictReader(open(REL_CSV)):
            rel[(r["cond"], r["group"])] = float(r["fa_reliability"])
    return rel


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    rel = reliabilities()
    GKEY = {v: k for k, v in GLAB.items()}

    def fa_mean_sem(cond, codes, names):
        """Per-sound FA mean and SEM across a group's listeners, aligned to names."""
        _, f, it = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
        it = [str(x) for x in it]
        mean = np.nanmean(f, 0)
        n = np.sum(~np.isnan(f), 0)
        with np.errstate(invalid="ignore"):
            sem = np.nanstd(f, 0) / np.sqrt(np.maximum(n, 1))
        d = {nm: (mean[i], sem[i]) for i, nm in enumerate(it)}
        m = np.array([d[nm][0] for nm in names if nm in d])
        s = np.array([d[nm][1] for nm in names if nm in d])
        return m, s

    # ---- sorted per-sound FA spectra (Chapter 1 style): rows = set, cols = group ----
    fig, axes = plt.subplots(3, 3, figsize=(13, 9), sharex=True, sharey=True)
    for ri, (cond, clab) in enumerate(CONDS):
        names = canonical_names(cond)
        for ci, g in enumerate(GORDER):
            ax = axes[ri][ci]
            m, s = fa_mean_sem(cond, CODES[GKEY[g]], names)
            order = np.argsort(m)
            x = np.arange(len(m))
            ax.bar(x, m[order], width=1.0, color=SCOL[clab], yerr=s[order],
                   capsize=0, error_kw=dict(lw=0.5, ecolor="0.5"))
            ax.axhline(np.nanmean(m), color="black", lw=1.1, ls="--")
            r = rel.get((clab, g))
            txt = f"{np.nanmin(m):.2f}-{np.nanmax(m):.2f}" + (f"\nrel {r:.2f}" if r else "")
            ax.text(0.03, 0.96, txt, transform=ax.transAxes, ha="left", va="top", fontsize=9)
            if ri == 0:
                ax.set_title(g, fontsize=12, color=GCOL[g], fontweight="bold")
            if ci == 0:
                ax.set_ylabel(f"{clab}\nfalse-alarm rate", fontsize=10)
            if ri == 2:
                ax.set_xlabel("sound (sorted by rate)", fontsize=10)
            ax.set_ylim(0, 1.0)
            ax.grid(axis="y", ls="--", alpha=0.25)
    fig.tight_layout()
    fig.savefig(OUT / "fa_histograms.png", dpi=150, bbox_inches="tight")
    if CH3.is_dir():
        fig.savefig(CH3 / "fa_histograms.pdf", bbox_inches="tight")
        print("wrote", CH3 / "fa_histograms.pdf", flush=True)
    plt.close(fig)
    print("wrote fa_histograms.png", flush=True)

    # ---- reliability bars: one panel per sound set, three group bars each ----
    conds = [c for _, c in CONDS]
    fig, axes = plt.subplots(1, 3, figsize=(12, 4.2), sharey=True)
    for ax, clab in zip(axes, conds):
        y = [rel.get((clab, g), np.nan) for g in GORDER]
        bars = ax.bar(GORDER, y, color=[GCOL[g] for g in GORDER], alpha=0.9,
                      width=0.7)
        ax.bar_label(bars, fmt="%.2f", fontsize=11, padding=3)
        ax.axhline(0.5, color="#b00", lw=1, ls=":")
        ax.set_title(clab, fontsize=12, fontweight="bold")
        ax.set_ylim(0, 1.0)
        ax.tick_params(axis="x", labelsize=10)
        ax.grid(axis="y", ls="--", alpha=0.3)
    axes[0].set_ylabel("split-half FA reliability\n(Spearman-Brown)", fontsize=10)
    axes[-1].plot([], [], color="#b00", ls=":", label="reliability floor (0.5)")
    axes[-1].legend(fontsize=8.5, loc="lower right", frameon=False)
    fig.tight_layout()
    fig.savefig(OUT / "fa_reliability_bars.png", dpi=150, bbox_inches="tight")
    if CH3.is_dir():
        fig.savefig(CH3 / "fa_reliability_bars.pdf", bbox_inches="tight")
        print("wrote", CH3 / "fa_reliability_bars.pdf", flush=True)
    plt.close(fig)
    print("wrote fa_reliability_bars.png", flush=True)


if __name__ == "__main__":
    main()
