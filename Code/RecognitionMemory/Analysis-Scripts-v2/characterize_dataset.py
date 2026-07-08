#!/usr/bin/env python3
"""Dataset characterization for the single-ISI item-level experiment.

(1) Per-group, per-condition task performance: per-participant hit rate,
    false-alarm rate, and d' (ISI=16), with distributions. Reports N and the
    d'>=2 inclusion-screen pass rate.
(2) Per-stimulus coverage: for each sound, how many participants in each group
    saw it as a repeat (target) vs a non-repeat (foil), per condition.

All participants are included (no screen) so the raw dataset is described; the
screen's effect is reported separately.
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from scipy.stats import norm

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = [("US", ("PRO", "BOS", "CAM")), ("SanBorja", ("SBO", "SNB", "SBJ")),
          ("Tsimane", ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR"))]
CONDS = [("Industrial-Nature", "Environmental"), ("Globalized-Music", "Music"), ("NHS", "World song")]
EPS = 1e-2
OUT = HERE / "dprime_vs_isi_outputs"


def clip(p):
    return np.clip(p, EPS, 1 - EPS)


def load(cond, codes, screen):
    thr = 2.0 if screen else 0.0
    files = list_matfiles(BASE, codes, cond, thr, False)
    if not files:
        return None
    hits, fas, items = build_hit_fa_matrices(files)
    return dict(hits=hits, fas=fas, items=items, n=hits.shape[0])


def main():
    data = {}
    print("=" * 78)
    print("(1) PERFORMANCE  (single-ISI, ISI=16; all participants, no screen)")
    print("=" * 78)
    print(f"{'condition':<14}{'group':<10}{'N':>5}{'screen%':>8}"
          f"{'hit rate':>18}{'FA rate':>18}{'d prime':>16}")
    for cond, clab in CONDS:
        for g, codes in GROUPS:
            d = load(cond, codes, screen=False)
            ds = load(cond, codes, screen=True)
            if d is None:
                continue
            hr = np.nanmean(d["hits"], axis=1)      # per-participant hit rate
            fr = np.nanmean(d["fas"], axis=1)        # per-participant FA rate
            dp = norm.ppf(clip(hr)) - norm.ppf(clip(fr))
            data[(clab, g)] = dict(hr=hr, fr=fr, dp=dp, n=d["n"],
                                   hits=d["hits"], fas=d["fas"], items=d["items"])
            npass = ds["n"] if ds else 0
            def ms(a):
                return f"{np.nanmean(a):.2f}±{np.nanstd(a):.2f}"
            print(f"{clab:<14}{g:<10}{d['n']:>5}{100*npass/d['n']:>7.0f}%"
                  f"{ms(hr):>18}{ms(fr):>18}{ms(dp):>16}")
        print()

    print("=" * 78)
    print("(2) COVERAGE  (# participants who saw each sound as repeat / non-repeat)")
    print("=" * 78)
    print(f"{'condition':<14}{'group':<10}{'#sounds':>8}"
          f"{'repeat obs/sound med[min,max]':>32}{'foil obs/sound med[min,max]':>32}")
    for cond, clab in CONDS:
        for g, codes in GROUPS:
            if (clab, g) not in data:
                continue
            D = data[(clab, g)]
            rep = np.sum(~np.isnan(D["hits"]), axis=0)   # per sound: #repeat observations
            foil = np.sum(~np.isnan(D["fas"]), axis=0)   # per sound: #foil observations
            def mm(a):
                return f"{int(np.median(a))} [{int(a.min())},{int(a.max())}]"
            print(f"{clab:<14}{g:<10}{len(rep):>8}{mm(rep):>32}{mm(foil):>32}")
        print()

    # ---- figures ----
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    GCOL = {"US": "#1f77b4", "SanBorja": "#ff7f0e", "Tsimane": "#2E7D32"}
    glabs = ["US", "SanBorja", "Tsimane"]

    # Figure 1: performance box plots, 3 metrics x 3 conditions
    fig, axes = plt.subplots(3, 3, figsize=(12.5, 9), sharex=True)
    metrics = [("dp", "d'"), ("hr", "hit rate"), ("fr", "false-alarm rate")]
    for r, (mk, mlab) in enumerate(metrics):
        for c, (cond, clab) in enumerate(CONDS):
            ax = axes[r][c]
            box = [data[(clab, g)][mk] for g in glabs if (clab, g) in data]
            labs = [g for g in glabs if (clab, g) in data]
            bp = ax.boxplot(box, patch_artist=True, widths=0.6, showfliers=False)
            for patch, g in zip(bp["boxes"], labs):
                patch.set_facecolor(GCOL[g]); patch.set_alpha(0.55)
            for med in bp["medians"]:
                med.set_color("black")
            # jittered points
            for xi, (g, arr) in enumerate(zip(labs, box), start=1):
                ax.scatter(np.random.normal(xi, 0.06, len(arr)), arr, s=6,
                           color=GCOL[g], alpha=0.5, zorder=3)
            ax.set_xticks(range(1, len(labs)+1)); ax.set_xticklabels(labs, fontsize=8)
            if mk in ("hr", "fr"):
                ax.set_ylim(0, 1)
            elif mk == "dp":
                ax.set_ylim(-0.5, 3.5)
            if r == 0:
                ax.set_title(clab, fontsize=11)
            if c == 0:
                ax.set_ylabel(mlab, fontsize=10)
            ax.grid(axis="y", ls="--", alpha=0.3)
    fig.suptitle("Task performance by group and sound set (single-ISI, ISI=16)\n"
                 r"No d$'\geq$2 catch-trial screen (finished sessions only, 120 trials)",
                 fontsize=12.5, fontweight="bold")
    fig.tight_layout(rect=[0, 0, 1, 0.97])
    fig.savefig(OUT / "characterize_performance.png", dpi=160, bbox_inches="tight")
    fig.savefig(OUT / "characterize_performance.pdf", bbox_inches="tight")
    print("saved characterize_performance.png")

    # Figure 2: coverage histograms (repeat obs per sound) by group, per condition
    fig, axes = plt.subplots(1, 3, figsize=(13, 4), sharey=True)
    for c, (cond, clab) in enumerate(CONDS):
        ax = axes[c]
        for g in glabs:
            if (clab, g) not in data:
                continue
            rep = np.sum(~np.isnan(data[(clab, g)]["hits"]), axis=0)
            ax.hist(rep, bins=range(0, int(rep.max())+3, 2), alpha=0.5,
                    color=GCOL[g], label=g, edgecolor="white")
        ax.set_title(clab, fontsize=11); ax.set_xlabel("# participants who saw a sound as a repeat")
        ax.grid(axis="y", ls="--", alpha=0.3)
        if c == 0:
            ax.set_ylabel("number of sounds"); ax.legend(fontsize=8)
    fig.suptitle("Per-stimulus coverage: repeat (target) observations per sound\n"
                 r"No d$'\geq$2 catch-trial screen (finished sessions only, 120 trials)",
                 fontsize=12.5, fontweight="bold")
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(OUT / "characterize_coverage.png", dpi=160, bbox_inches="tight")
    fig.savefig(OUT / "characterize_coverage.pdf", bbox_inches="tight")
    print("saved characterize_coverage.png")


if __name__ == "__main__":
    main()
