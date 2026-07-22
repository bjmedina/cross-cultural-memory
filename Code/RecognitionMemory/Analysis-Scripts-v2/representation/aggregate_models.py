#!/usr/bin/env python3
"""Consolidate the per-model representation results into cross-model save-outs.

Scans results/<model_tag>/representation_{gap,results}.csv for every model that
has finished, and writes:
  results/_summary/model_gap_summary.csv    long: model,arch,training,condition,
                                            layer,layer_idx,layer_frac,metric,k,
                                            gap,ci_lo,ci_hi,sig
  results/_summary/model_rho_summary.csv    long: ...,group,rho,ci_lo,ci_hi,
                                            fa_reliability,rho_corrected,low_reliability
  results/_summary/music_gap_vs_depth.png   music gap rho_US-rho_Ts vs fractional
                                            depth, one line per model (filled
                                            marker = CI excludes 0)
  results/_summary/gap_by_condition.png     small multiples: gap vs depth per
                                            condition, per model

Depth is plotted as fractional depth (layer_idx / (n_layers-1)) so nets with
different layer counts are comparable on one axis. Metric/k default to the
headline euclidean / k=3; override with --metric / --k.
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
from repr_models import MODELS  # noqa: E402

RES = HERE / "results"
OUT = RES / "_summary"
PRIMARY_METRIC = "euclidean"
PRIMARY_K = "3"
# Chapter scope: multi-task-trained nets, their untrained control, and CLAP.
# Single-task paradigm models (audioset/speaker/word) are excluded from the
# main comparison (kept on disk for reference).
MAIN_MODELS = ["kell2018_word_speaker_audioset", "resnet50_word_speaker_audioset",
               "kell2018_word_speaker_audioset_randomize_weights",
               "resnet50_word_speaker_audioset_randomize_weights"]


def parse_tag(tag):
    """(arch, training, trained_bool) from a model tag."""
    if tag.startswith("kell2018"):
        arch = "kell2018"
    elif tag.startswith("resnet50"):
        arch = "resnet50"
    elif tag.startswith("CLAP"):
        arch = "CLAP"
    elif tag == "spectemp":
        arch = "spectemp"
    else:
        arch = tag
    if "randomize_weights" in tag:
        training, trained = "random(untrained)", False
    elif tag == "spectemp":
        training, trained = "acoustic-filterbank", False
    elif tag.startswith("CLAP"):
        training, trained = "contrastive(audio-text)", True
    else:
        training = tag.split("_", 1)[1] if "_" in tag else "trained"
        trained = True
    return arch, training, trained


def layer_order(tag):
    return MODELS[tag]["layers"] if tag in MODELS else None


def read_gap(model_dir):
    f = model_dir / "representation_gap.csv"
    if not f.exists():
        return []
    with open(f) as fh:
        return list(csv.DictReader(fh))


def read_rho(model_dir):
    f = model_dir / "representation_results.csv"
    if not f.exists():
        return []
    with open(f) as fh:
        return list(csv.DictReader(fh))


def collect():
    models = {}
    for d in sorted(RES.glob("*/")):
        tag = d.name
        if tag not in MAIN_MODELS:
            continue
        gap, rho = read_gap(d), read_rho(d)
        if gap or rho:
            models[tag] = (d, gap, rho)
    return models


def main():
    metric = sys.argv[sys.argv.index("--metric") + 1] if "--metric" in sys.argv else PRIMARY_METRIC
    k = sys.argv[sys.argv.index("--k") + 1] if "--k" in sys.argv else PRIMARY_K
    OUT.mkdir(parents=True, exist_ok=True)
    models = collect()
    if not models:
        print("no model results found yet under", RES)
        return

    gap_rows, rho_rows = [], []
    for tag, (d, gap, rho) in models.items():
        arch, training, trained = parse_tag(tag)
        order = layer_order(tag)
        # layer index/frac from registry order (fallback: first-seen order)
        seen = []
        for r in gap:
            if r["layer"] not in seen:
                seen.append(r["layer"])
        lay = order or seen
        idx = {L: i for i, L in enumerate(lay)}
        n = max(len(lay) - 1, 1)
        for r in gap:
            i = idx.get(r["layer"], 0)
            gap_rows.append(dict(
                model=tag, arch=arch, training=training, trained=int(trained),
                condition=r["cond"], layer=r["layer"], layer_idx=i,
                layer_frac=round(i / n, 4), pair=r.get("pair", "US-Tsimane"),
                metric=r["metric"], k=r["k"],
                gap=float(r["gap"]), ci_lo=float(r["ci_lo"]), ci_hi=float(r["ci_hi"]),
                sig=int(float(r["ci_lo"]) > 0 or float(r["ci_hi"]) < 0)))
        for r in rho:
            i = idx.get(r["layer"], 0)
            rho_rows.append(dict(
                model=tag, arch=arch, training=training, trained=int(trained),
                condition=r["cond"], layer=r["layer"], layer_idx=i,
                layer_frac=round(i / n, 4), group=r["group"], metric=r["metric"],
                k=r["k"], rho=float(r["rho"]), ci_lo=float(r["ci_lo"]),
                ci_hi=float(r["ci_hi"]), fa_reliability=r["fa_reliability"],
                rho_corrected=r["rho_corrected"], low_reliability=r["low_reliability"]))

    _write(OUT / "model_gap_summary.csv", gap_rows,
           ["model", "arch", "training", "trained", "condition", "layer",
            "layer_idx", "layer_frac", "pair", "metric", "k", "gap", "ci_lo",
            "ci_hi", "sig"])
    _write(OUT / "model_rho_summary.csv", rho_rows,
           ["model", "arch", "training", "trained", "condition", "layer", "layer_idx",
            "layer_frac", "group", "metric", "k", "rho", "ci_lo", "ci_hi",
            "fa_reliability", "rho_corrected", "low_reliability"])
    print(f"wrote {len(gap_rows)} gap rows, {len(rho_rows)} rho rows to {OUT}")

    _fig_music(gap_rows, metric, k)
    _fig_conditions(gap_rows, metric, k)
    _fig_gradient(rho_rows, metric, k)
    print("wrote figures to", OUT)


GCOL = {"U.S.": "#1f77b4", "San Borja": "#ff7f0e", "Tsimane'": "#2E7D32"}


def _fig_gradient(rho_rows, metric, k):
    """Exposure gradient: per-group rho vs depth for music, one panel per model.

    The three-group ordering (US > San Borja > Tsimane) is the key readout that
    San Borja sits intermediate; shown for every model that has all 3 groups.
    """
    rows = [r for r in rho_rows if r["condition"] == "Music"
            and r["metric"] == metric and r["k"] == k]
    if not rows:
        return
    tags = sorted({r["model"] for r in rows})
    ncol = min(4, len(tags))
    nrow = int(np.ceil(len(tags) / ncol))
    fig, axes = plt.subplots(nrow, ncol, figsize=(4.2 * ncol, 3.6 * nrow),
                             squeeze=False, sharey=True)
    for ax in axes.flat:
        ax.set_visible(False)
    for a, t in enumerate(tags):
        ax = axes.flat[a]; ax.set_visible(True)
        for g in ("U.S.", "San Borja", "Tsimane'"):
            rr = sorted([r for r in rows if r["model"] == t and r["group"] == g],
                        key=lambda r: r["layer_idx"])
            if not rr:
                continue
            ax.plot([r["layer_frac"] for r in rr], [r["rho"] for r in rr],
                    "-o", color=GCOL[g], lw=1.8, ms=4, label=g)
        ax.axhline(0, color="#555", lw=1); ax.grid(True, ls="--", alpha=.3)
        ax.set_title(t, fontsize=8)
        ax.set_xlabel("frac depth", fontsize=8)
    axes.flat[0].set_ylabel("rho(conf, music FA)", fontsize=9)
    axes.flat[0].legend(fontsize=7, loc="best")
    fig.suptitle(f"Music: per-group predictive rho vs depth (exposure gradient "
                 f"US > San Borja > Tsimane')  metric={metric}, k={k}",
                 fontsize=11, fontweight="bold")
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    fig.savefig(OUT / "music_exposure_gradient.png", dpi=150, bbox_inches="tight")
    plt.close(fig)


def _write(path, rows, cols):
    with open(path, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow({c: r[c] for c in cols})


# stable colors per model tag
def _model_colors(tags):
    cmap = plt.cm.tab10.colors + plt.cm.Set2.colors
    return {t: cmap[i % len(cmap)] for i, t in enumerate(sorted(tags))}


def _fig_music(gap_rows, metric, k):
    rows = [r for r in gap_rows if r["condition"] == "Music"
            and r["metric"] == metric and r["k"] == k
            and r.get("pair", "US-Tsimane") == "US-Tsimane"]
    if not rows:
        return
    tags = sorted({r["model"] for r in rows})
    col = _model_colors(tags)
    fig, ax = plt.subplots(figsize=(8.4, 5.2))
    for t in tags:
        rr = sorted([r for r in rows if r["model"] == t], key=lambda r: r["layer_idx"])
        x = [r["layer_frac"] for r in rr]; y = [r["gap"] for r in rr]
        trained = rr[0]["trained"]
        ls = "-" if trained else "--"
        ax.plot(x, y, ls, color=col[t], lw=2, marker="o", ms=6, label=t, alpha=0.9)
        for r in rr:  # fill significant markers
            if r["sig"]:
                ax.plot(r["layer_frac"], r["gap"], "o", color=col[t], ms=10,
                        markeredgecolor="black", markeredgewidth=1.2, zorder=5)
    ax.axhline(0, color="#555", lw=1)
    ax.set_xlabel("fractional depth (input -> output)", fontsize=11)
    ax.set_ylabel(r"music gap  $\rho_{US} - \rho_{Ts}$", fontsize=11)
    ax.set_title(f"Music U.S.-Tsimane' predictive gap vs depth, across models\n"
                 f"(metric={metric}, k={k}; solid=trained, dashed=untrained, "
                 f"ringed marker = 95% CI excludes 0)", fontsize=11)
    ax.grid(True, ls="--", alpha=0.3)
    ax.legend(fontsize=7.5, loc="upper right", ncol=1)
    fig.tight_layout()
    fig.savefig(OUT / "music_gap_vs_depth.png", dpi=160, bbox_inches="tight")
    plt.close(fig)


def _fig_conditions(gap_rows, metric, k):
    conds = ["Environmental", "Music", "World song"]
    rows = [r for r in gap_rows if r["metric"] == metric and r["k"] == k
            and r.get("pair", "US-Tsimane") == "US-Tsimane"]
    if not rows:
        return
    tags = sorted({r["model"] for r in rows})
    col = _model_colors(tags)
    fig, axes = plt.subplots(1, 3, figsize=(15, 4.6), sharey=True)
    for ax, cond in zip(axes, conds):
        for t in tags:
            rr = sorted([r for r in rows if r["model"] == t and r["condition"] == cond],
                        key=lambda r: r["layer_idx"])
            if not rr:
                continue
            ls = "-" if rr[0]["trained"] else "--"
            ax.plot([r["layer_frac"] for r in rr], [r["gap"] for r in rr], ls,
                    color=col[t], lw=1.8, marker="o", ms=4, label=t, alpha=0.85)
        ax.axhline(0, color="#555", lw=1)
        ax.set_title(cond, fontsize=11); ax.grid(True, ls="--", alpha=0.3)
        ax.set_xlabel("fractional depth", fontsize=9)
    axes[0].set_ylabel(r"$\rho_{US}-\rho_{Ts}$", fontsize=11)
    axes[-1].legend(fontsize=6.5, loc="upper right")
    fig.suptitle(f"U.S.-Tsimane' predictive gap vs depth by condition and model "
                 f"(metric={metric}, k={k})", fontsize=12, fontweight="bold")
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    fig.savefig(OUT / "gap_by_condition.png", dpi=160, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    main()
