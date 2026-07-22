#!/usr/bin/env python3
"""Recreate the old bolivia_results.pdf between-group bars and decompose WHY the
current numbers differ.

Two independent causes are isolated by changing ONE ingredient at a time, on the
same data infrastructure the current report uses:

  1. ERROR-BAR METHOD.  Old deck: resample the 80 SOUNDS and plot +/-1 SD
     (bootstrap_dim=2, err = std of the bootstrap r*).  Fix: resample
     PARTICIPANTS and plot a 95% CI (bootstrap_dim=1).  Same point estimates,
     so this isolates the error bars.

  2. SUBJECT SCREENS.  Old recipe: d'>=1.5, NO completeness filter
     (min_trials=0).  Current recipe: d'>=2.0 + full-session filter
     (min_trials=120).  This shifts the bar HEIGHTS.

Outputs (in ./bolivia_recreation_outputs/):
  fig1_recreate_deck.(png|pdf)   -- old recipe + old +/-1 SD error bars
  fig2_errorbar_cause.(png|pdf)  -- old points, old +/-1 SD vs participant 95% CI
  fig3_decomposition.(png|pdf)   -- old recipe vs new recipe, both participant 95% CI
  recreate_values.json           -- every number
  a validation table is printed to stdout (recreated vs deck).
"""
import sys
import json
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices          # noqa: E402
from python.split_half import calculate_split_half_reliability      # noqa: E402
from python.intergroup_corr import bootstrap_intergroup_correlation_sem  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT = HERE / "bolivia_recreation_outputs"
OUT.mkdir(exist_ok=True)

SITES = {
    "US": ("PRO", "BOS", "CAM"),
    "SanBorja": ("SBO", "SNB", "SBJ"),
    "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR"),
}
# (condition folder token, display name)
CONDS = [("Globalized-Music", "Music"), ("Industrial-Nature", "Natural sounds")]
# deck pair order + mapping to (groupA, groupB)
PAIRS = [
    ("Tsi-SB", "SanBorja", "Tsimane"),
    ("Tsi-US", "US", "Tsimane"),
    ("SB-US", "US", "SanBorja"),
]
TRIALS = ["hit", "fa"]

# r* bar heights read off bolivia_results.pdf (the old deck)
DECK = {
    ("Music", "hit"):          {"Tsi-SB": 0.82, "Tsi-US": 0.51, "SB-US": 1.04},
    ("Music", "fa"):           {"Tsi-SB": 0.66, "Tsi-US": 0.39, "SB-US": 0.79},
    ("Natural sounds", "hit"): {"Tsi-SB": 0.95, "Tsi-US": 0.36, "SB-US": 0.51},
    ("Natural sounds", "fa"):  {"Tsi-SB": 0.87, "Tsi-US": 0.77, "SB-US": 0.83},
}

N_SPLITS = 2000
N_BOOT = 3000
SEED = 20260720


GROUP_SEED = {"US": 11, "SanBorja": 22, "Tsimane": 33}


def load_groups(cond, dprime, min_trials):
    G = {}
    for lab, codes in SITES.items():
        files = list_matfiles(
            BASE, codes, cond, min_isi0_dprime=dprime,
            is_multi_isi=False, min_trials=min_trials,
        )
        hits, fas, items = build_hit_fa_matrices(files)
        rng = np.random.default_rng(SEED + GROUP_SEED[lab])
        G[lab] = calculate_split_half_reliability(
            hits, fas, items, n_splits=N_SPLITS, split_dim=1,
            corr_type="Spearman", rng=rng,
        )
    return G


def pair_stat(G, a, b, trial, bootdim):
    rng = np.random.default_rng(SEED + (1 if bootdim == 1 else 2) * 7919)
    return bootstrap_intergroup_correlation_sem(
        G[a], G[b], trial_type=trial, n_boot=N_BOOT,
        min_resp=2, min_items=5, use_spearman=True, reliability_mode="fixed",
        bootstrap_dim=bootdim, correct_atten=True, rng=rng, verbose=False,
    )


def main():
    results = {}
    print(f"{'cond':<15}{'trial':<5}{'pair':<8}"
          f"{'nUS/SB/Ts':<16}{'old_r*':>8}{'deck':>7}{'d':>7}"
          f"{'old±1SD':>9}{'partCI_lo':>10}{'partCI_hi':>10}")
    for cond_tok, cond_name in CONDS:
        G_old = load_groups(cond_tok, dprime=1.5, min_trials=0)
        G_new = load_groups(cond_tok, dprime=2.0, min_trials=120)
        nold = {g: int(G_old[g].n_subjects) for g in SITES}
        nnew = {g: int(G_new[g].n_subjects) for g in SITES}
        for trial in TRIALS:
            for plab, a, b in PAIRS:
                old2 = pair_stat(G_old, a, b, trial, bootdim=2)   # old error bar
                old1 = pair_stat(G_old, a, b, trial, bootdim=1)   # fix error bar only
                new1 = pair_stat(G_new, a, b, trial, bootdim=1)   # fix screens too
                sd_old = float(np.std(old2.r_boot_corr, ddof=0))
                ci_old_lo, ci_old_hi = old1.cis_corr["percentile"]
                ci_new_lo, ci_new_hi = new1.cis_corr["percentile"]
                deck = DECK[(cond_name, trial)][plab]
                results[f"{cond_name}|{trial}|{plab}"] = dict(
                    old_recipe_rstar=old2.point_corr,
                    deck_rstar=deck,
                    old_pm1sd=sd_old,
                    old_data_participant_ci=[ci_old_lo, ci_old_hi],
                    old_data_participant_rstar=old1.point_corr,
                    new_recipe_rstar=new1.point_corr,
                    new_recipe_participant_ci=[ci_new_lo, ci_new_hi],
                    n_old=nold, n_new=nnew,
                )
                print(f"{cond_name:<15}{trial:<5}{plab:<8}"
                      f"{f'{nold[a]}/{nold[b]}':<16}"
                      f"{old2.point_corr:>8.2f}{deck:>7.2f}"
                      f"{old2.point_corr-deck:>+7.2f}"
                      f"{sd_old:>9.3f}{ci_new_lo:>10.2f}{ci_new_hi:>10.2f}")
        print()

    with open(OUT / "recreate_values.json", "w") as fh:
        json.dump(results, fh, indent=2, default=float)

    make_figures(results)
    print("Saved figures + recreate_values.json to", OUT)


# ---------------------------------------------------------------- figures ----
HIT_C = "#6aa84f"
FA_C = "#e06666"
GREY = "#9e9e9e"


def _panels(fig):
    axes = fig.subplots(2, 2, sharex=True)
    return axes


def make_figures(R):
    plabs = [p[0] for p in PAIRS]
    x = np.arange(3)

    # ---- FIG 1: recreate the deck (old recipe, old +/-1 SD) ----
    fig = plt.figure(figsize=(11, 8), constrained_layout=True)
    axes = _panels(fig)
    for r, (_, cond) in enumerate(CONDS):
        for c, trial in enumerate(TRIALS):
            ax = axes[r][c]
            col = HIT_C if trial == "hit" else FA_C
            vals = [R[f"{cond}|{trial}|{pl}"]["old_recipe_rstar"] for pl in plabs]
            errs = [R[f"{cond}|{trial}|{pl}"]["old_pm1sd"] for pl in plabs]
            deck = [R[f"{cond}|{trial}|{pl}"]["deck_rstar"] for pl in plabs]
            ax.bar(x, vals, 0.6, color=col, edgecolor="k", lw=0.6)
            ax.errorbar(x, vals, yerr=errs, fmt="none", ecolor="k", capsize=3, lw=1.2)
            ax.plot(x, deck, "kx", ms=9, mew=2, label="deck value")
            ax.axhline(1.0, ls=":", color="#bbb", lw=1)
            ax.set_title(f"{trial.upper()} consistency on {cond}", fontsize=11)
            ax.set_ylim(0, 1.2)
            ax.set_xticks(x); ax.set_xticklabels(plabs)
            if c == 0:
                ax.set_ylabel("inter-group r*")
            if r == 0 and c == 0:
                ax.legend(fontsize=8, loc="upper left")
    fig.suptitle("Recreation of old deck: d'>=1.5, no completeness filter, "
                 "item-resample +/-1 SD error bars  (x = deck value)",
                 fontsize=13, fontweight="bold")
    fig.savefig(OUT / "fig1_recreate_deck.png", dpi=160)
    fig.savefig(OUT / "fig1_recreate_deck.pdf")
    plt.close(fig)

    # ---- FIG 2: isolate the error-bar cause (same points, two error bars) ----
    fig = plt.figure(figsize=(11, 8), constrained_layout=True)
    axes = _panels(fig)
    for r, (_, cond) in enumerate(CONDS):
        for c, trial in enumerate(TRIALS):
            ax = axes[r][c]
            vals = [R[f"{cond}|{trial}|{pl}"]["old_data_participant_rstar"] for pl in plabs]
            sd = [R[f"{cond}|{trial}|{pl}"]["old_pm1sd"] for pl in plabs]
            ci = [R[f"{cond}|{trial}|{pl}"]["old_data_participant_ci"] for pl in plabs]
            lo = [v - c0[0] for v, c0 in zip(vals, ci)]
            hi = [c0[1] - v for v, c0 in zip(vals, ci)]
            ax.bar(x, vals, 0.6, color=GREY, edgecolor="k", lw=0.6)
            # participant 95% CI (the correct one): thick black
            ax.errorbar(x, vals, yerr=[lo, hi], fmt="none", ecolor="k",
                        capsize=5, lw=2.4, label="participant 95% CI (correct)")
            # old +/-1 SD item-resample: thin red
            ax.errorbar(x, vals, yerr=sd, fmt="none", ecolor=FA_C,
                        capsize=3, lw=1.3, label="old: item-resample +/-1 SD")
            ax.axhline(0, color="k", lw=0.5)
            ax.set_title(f"{trial.upper()} consistency on {cond}", fontsize=11)
            ax.set_xticks(x); ax.set_xticklabels(plabs)
            if c == 0:
                ax.set_ylabel("inter-group r*")
            if r == 0 and c == 0:
                ax.legend(fontsize=8, loc="upper left")
    fig.suptitle("Cause #1: the error bars. Same point estimates; the old +/-1 SD "
                 "item-resample bars (red) understate uncertainty ~10x vs the "
                 "correct participant 95% CI (black)",
                 fontsize=12.5, fontweight="bold")
    fig.savefig(OUT / "fig2_errorbar_cause.png", dpi=160)
    fig.savefig(OUT / "fig2_errorbar_cause.pdf")
    plt.close(fig)

    # ---- FIG 3: old recipe vs new recipe, both with participant 95% CI ----
    fig = plt.figure(figsize=(11, 8), constrained_layout=True)
    axes = _panels(fig)
    w = 0.38
    for r, (_, cond) in enumerate(CONDS):
        for c, trial in enumerate(TRIALS):
            ax = axes[r][c]
            old_v = [R[f"{cond}|{trial}|{pl}"]["old_data_participant_rstar"] for pl in plabs]
            old_ci = [R[f"{cond}|{trial}|{pl}"]["old_data_participant_ci"] for pl in plabs]
            new_v = [R[f"{cond}|{trial}|{pl}"]["new_recipe_rstar"] for pl in plabs]
            new_ci = [R[f"{cond}|{trial}|{pl}"]["new_recipe_participant_ci"] for pl in plabs]
            for xi, v, c0 in zip(x - w / 2, old_v, old_ci):
                ax.bar(xi, v, w, color=GREY, edgecolor="k", lw=0.6)
                ax.errorbar(xi, v, yerr=[[v - c0[0]], [c0[1] - v]], fmt="none",
                            ecolor="k", capsize=3, lw=1.5)
            for xi, v, c0 in zip(x + w / 2, new_v, new_ci):
                ax.bar(xi, v, w, color="#4060b0", edgecolor="k", lw=0.6)
                ax.errorbar(xi, v, yerr=[[v - c0[0]], [c0[1] - v]], fmt="none",
                            ecolor="k", capsize=3, lw=1.5)
            ax.axhline(1.0, ls=":", color="#bbb", lw=1)
            ax.set_title(f"{trial.upper()} consistency on {cond}", fontsize=11)
            ax.set_xticks(x); ax.set_xticklabels(plabs)
            if c == 0:
                ax.set_ylabel("inter-group r*")
    fig.legend(handles=[
        plt.Rectangle((0, 0), 1, 1, fc=GREY, ec="k"),
        plt.Rectangle((0, 0), 1, 1, fc="#4060b0", ec="k"),
    ], labels=["old recipe (d'>=1.5, no filter)", "new recipe (d'>=2.0, completeness)"],
        loc="upper right", fontsize=9)
    fig.suptitle("Cause #2: the subject screens shift bar HEIGHTS "
                 "(both panels now use the correct participant 95% CI)",
                 fontsize=12.5, fontweight="bold")
    fig.savefig(OUT / "fig3_decomposition.png", dpi=160)
    fig.savefig(OUT / "fig3_decomposition.pdf")
    plt.close(fig)


if __name__ == "__main__":
    main()
