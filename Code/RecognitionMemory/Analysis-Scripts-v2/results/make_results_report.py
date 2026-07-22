"""Generate an internal results report (LaTeX + PDF) from real .mat data.

Loads US, San Borja, Tsimane' for each condition; runs the full intergroup
analysis (split-half reliability, bootstrap CIs across percentile / Fisher-z
/ BCa, paired-bootstrap comparison); emits `results.tex` with tables and
embedded bar charts.

Usage:
    cd Analysis-Scripts-v2/results
    python make_results_report.py
    pdflatex results.tex
    pdflatex results.tex   # second pass for refs

Configuration knobs live at the top. Expect ~15-20 minutes on a laptop.
"""

from __future__ import annotations

import argparse
import hashlib
import os
import pickle
import sys
from pathlib import Path

import matplotlib

matplotlib.use("Agg")  # safe on headless cluster nodes
import matplotlib.pyplot as plt
import numpy as np

# Make python/ importable
HERE = Path(__file__).resolve().parent
ROOT = HERE.parent  # Analysis-Scripts-v2/
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from python import (  # noqa: E402
    bootstrap_intergroup_correlation_sem,
    load_group,
    paired_bootstrap_compare_correlations,
)

# ----------------------------------------------------------------------------
# Configuration
# ----------------------------------------------------------------------------
BASE_DIR = ROOT.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT_DIR = HERE
FIG_DIR = HERE / "figures"
FIG_DIR.mkdir(exist_ok=True)
CACHE_DIR = HERE / "_cache"
CACHE_DIR.mkdir(exist_ok=True)
CACHE_VERSION = 1  # bump to invalidate all cached groups

CONDITIONS = ("Globalized-Music", "Industrial-Nature", "NHS")
TRIAL_TYPES = ("hit", "fa")
SITES = {
    "US": ("PRO", "BOS", "CAM"),
    "SanBorja": ("SBO", "SNB", "SBJ"),
    "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR"),
}
PAIR_ORDER = (("US", "SanBorja"), ("US", "Tsimane"), ("SanBorja", "Tsimane"))
PAIR_LABEL = {("US", "SanBorja"): r"US$-$SB",
              ("US", "Tsimane"): r"US$-$Tsi",
              ("SanBorja", "Tsimane"): r"SB$-$Tsi"}
MIN_ISI0_DPRIME = 2.0
IS_MULTI_ISI = False
MIN_RESP = 2
N_SPLITS = 1000      # within-group split-half reps (report diagnostic; grid uses 10k for reported reliabilities)
N_BOOT = 2000        # CI bootstrap
N_BOOT_PAIRED = 5000
SEED = 20260603

# ----------------------------------------------------------------------------
# Caching layer for load_group
# ----------------------------------------------------------------------------
def _stable_hash(s: str) -> int:
    """Process-stable 32-bit hash (Python's hash() randomizes per process)."""
    return int(hashlib.md5(s.encode()).hexdigest()[:8], 16)


def _group_cache_key(cond, codes, n_splits, group_seed):
    payload = (CACHE_VERSION, str(BASE_DIR), cond, tuple(codes), MIN_ISI0_DPRIME,
               IS_MULTI_ISI, n_splits, "Spearman", group_seed)
    return hashlib.sha256(repr(payload).encode()).hexdigest()[:16]


def cached_load_group(cond, label, codes, n_splits, group_seed, force_rebuild=False):
    """Load a group, caching the SplitHalfReliability struct on disk.

    Cache key depends on data dir, condition, site codes, d' threshold,
    multi-ISI flag, n_splits, corr type, and the per-group RNG seed (so the
    cached split-half rs are reproducible). Re-run with --rebuild-cache to
    force a refresh.
    """
    key = _group_cache_key(cond, codes, n_splits, group_seed)
    cache_path = CACHE_DIR / f"group_{cond}_{label}_{key}.pkl"
    if cache_path.exists() and not force_rebuild:
        print(f"  [{label}] cache HIT  ({cache_path.name})")
        with open(cache_path, "rb") as f:
            return pickle.load(f)
    print(f"  [{label}] cache MISS -- computing ...")
    g = load_group(
        BASE_DIR, codes, cond,
        min_isi0_dprime=MIN_ISI0_DPRIME, is_multi_isi=IS_MULTI_ISI,
        n_splits=n_splits, split_dim=1, corr_type="Spearman",
        rng=np.random.default_rng(group_seed),
        verbose=True,
    )
    if g is not None:
        with open(cache_path, "wb") as f:
            pickle.dump(g, f, protocol=4)
        print(f"  [{label}] cached -> {cache_path.name}")
    return g


# ----------------------------------------------------------------------------
# Run analysis
# ----------------------------------------------------------------------------
def fmt_ci(lo, hi):
    if not (np.isfinite(lo) and np.isfinite(hi)):
        return "---"
    return f"[{lo:+.3f}, {hi:+.3f}]"


def fmt_r(r):
    return f"{r:+.3f}" if np.isfinite(r) else "---"


def fmt_p(p):
    if not np.isfinite(p):
        return "---"
    if p < 0.001:
        return "$<$0.001"
    return f"{p:.3f}"


def run_one_condition(cond, force_rebuild=False):
    print(f"\n========================================")
    print(f"Condition: {cond}")
    print(f"========================================")

    groups = {}
    for label, codes in SITES.items():
        print(f"\nLoading {label} ({'_'.join(codes)})...")
        group_seed = (SEED + _stable_hash(f"{cond}|{label}") % 1_000_000) & 0xFFFFFFFF
        groups[label] = cached_load_group(
            cond, label, codes, n_splits=N_SPLITS,
            group_seed=group_seed, force_rebuild=force_rebuild,
        )
        if groups[label] is None:
            print(f"  WARNING: no participants for {label}")

    if any(g is None for g in groups.values()):
        print(f"Skipping {cond}: missing groups.")
        return None

    out = {"groups": groups, "trials": {}}

    for trial in TRIAL_TYPES:
        print(f"\n--- Trial type: {trial} ---")
        trial_out = {"pairs": {}, "pairs_stim": {}}

        # Pairwise intergroup bootstraps (participant dim, BootstrapDim=1)
        for a, b in PAIR_ORDER:
            print(f"  r({a}, {b}) participant ...")
            res = bootstrap_intergroup_correlation_sem(
                groups[a], groups[b], trial_type=trial,
                n_boot=N_BOOT, min_resp=MIN_RESP, bootstrap_dim=1,
                reliability_mode="fixed", correct_atten=True,
                rng=np.random.default_rng(SEED + _stable_hash(f"{cond}|{trial}|{a}|{b}|p") % 1_000_000),
                verbose=False,
            )
            trial_out["pairs"][(a, b)] = res

        # Same pairs, stimulus dim (BootstrapDim=2)
        for a, b in PAIR_ORDER:
            print(f"  r({a}, {b}) stimulus ...")
            res2 = bootstrap_intergroup_correlation_sem(
                groups[a], groups[b], trial_type=trial,
                n_boot=N_BOOT, min_resp=MIN_RESP, bootstrap_dim=2,
                reliability_mode="fixed", correct_atten=True,
                rng=np.random.default_rng(SEED + _stable_hash(f"{cond}|{trial}|{a}|{b}|s") % 1_000_000),
                verbose=False,
            )
            trial_out["pairs_stim"][(a, b)] = res2

        # Paired-bootstrap comparison on attenuation-CORRECTED differences:
        # per-pair fixed ceilings sqrt(rho_SB,X * rho_SB,Y) from the full-sample
        # Spearman--Brown reliabilities, matching the plotted r* (fixed mode).
        print(f"  paired bootstrap ...")
        sb_of = {g: (res.sb_hit if trial == "hit" else res.sb_fa)
                 for g, res in groups.items()}
        ceilings = {
            "AB": float(np.sqrt(sb_of["US"] * sb_of["SanBorja"])),
            "AC": float(np.sqrt(sb_of["US"] * sb_of["Tsimane"])),
            "BC": float(np.sqrt(sb_of["SanBorja"] * sb_of["Tsimane"])),
        }
        paired = paired_bootstrap_compare_correlations(
            groups["US"], groups["SanBorja"], groups["Tsimane"],
            trial_type=trial,
            n_boot=N_BOOT_PAIRED, use_spearman=True, bootstrap_dim=1,
            min_resp=MIN_RESP,
            rng=np.random.default_rng(SEED + _stable_hash(f"{cond}|{trial}|paired") % 1_000_000),
            verbose=False,
            ceilings=ceilings,
        )
        trial_out["paired"] = paired

        out["trials"][trial] = trial_out

    return out


# ----------------------------------------------------------------------------
# Figure: triple bar chart with BCa CIs
# ----------------------------------------------------------------------------
def make_bar_figure(cond, trial, pairs_results, paired_result, save_path, groups=None):
    """Attenuation-corrected intergroup correlations with Fisher-z 95% CIs.

    Only the corrected estimate is plotted (raw values and all CI variants stay
    in the report tables). Error bars are Fisher-z CIs: centered on the point
    estimate with the width from the bootstrap SD on the z scale. A percentile
    CI is not used here because participant resampling attenuates every
    replicate (~63% unique listeners per resample), shifting the whole
    bootstrap distribution below the point estimate. Cells whose corrected
    estimate reaches/exceeds 1 (possible when a within-group reliability is
    very low) fall back to the percentile CI and are flagged with a red x when
    the point sits outside it. Significance brackets are the paired-bootstrap
    comparison of the pairs' attenuation-CORRECTED correlations, with each
    pair's ceiling sqrt(rho_SB,X * rho_SB,Y) treated as a fixed constant
    (consistent with the plotted r*, fixed mode).
    """
    points_cor = [r.point_corr for r in pairs_results.values()]

    def _ci_for(rres):
        lo, hi = rres.cis_corr.get("fisher_z", (float("nan"), float("nan")))
        ok = np.isfinite(lo) and np.isfinite(hi) and abs(hi - lo) > 1e-4
        if not ok or (np.isfinite(rres.point_corr) and rres.point_corr >= 0.999):
            lo, hi = rres.cis_corr["percentile"]
        return lo, hi

    cis = [_ci_for(r) for r in pairs_results.values()]

    pair_labels = []
    for p in pairs_results.keys():
        lab = PAIR_LABEL[p]
        if groups is not None:
            a, b = p
            lab += f"\n$n$ = {groups[a].n_subjects}, {groups[b].n_subjects}"
        pair_labels.append(lab)

    x = np.arange(len(pair_labels))
    w = 0.55

    fig, ax = plt.subplots(figsize=(7.5, 4))
    ax.bar(x, points_cor, w, color="#4060b0", edgecolor="black", linewidth=0.9,
           label=r"attenuation-corrected $\hat r^*$")

    for xi, p, (lo, hi) in zip(x, points_cor, cis):
        if not (np.isfinite(lo) and np.isfinite(hi) and np.isfinite(p)):
            continue
        ax.errorbar([xi], [p], yerr=[[max(0.0, p - lo)], [max(0.0, hi - p)]],
                    fmt="none", ecolor="k", capsize=3, lw=1.1)
        if p < lo or p > hi:
            ax.plot([xi], [p], marker="x", color="red", markersize=7)

    # after attenuation correction the noise ceiling is r* = 1 by construction
    ax.axhline(1.0, color="#999", ls="--", lw=1.1)
    ax.plot([], [], color="#999", ls="--", lw=1.1,
            label=r"$\hat r^*=1$ (perfect agreement given noise)")

    # Significance brackets from the paired test (on corrected differences)
    ps = (paired_result.ab_vs_ac, paired_result.ab_vs_bc, paired_result.ac_vs_bc)
    pair_idx = [(0, 1), (0, 2), (1, 2)]
    ymax = max([h for _, h in cis if np.isfinite(h)] + [1.0])
    step = max(0.06, 0.08 * abs(ymax))
    for k, ((i, j), p) in enumerate(zip(pair_idx, ps)):
        if not np.isfinite(p):
            continue
        y = ymax + step * (k + 1)
        ax.plot([i, i, j, j], [y - step/3, y, y, y - step/3], color="k", lw=1)
        label = "n.s." if p > 0.05 else ("*" if p > 0.01 else ("**" if p > 0.001 else "***"))
        ax.text((i + j)/2, y + step/8, f"p={p:.3g} {label}", ha="center", fontsize=8)

    ax.axhline(0, color="k", lw=0.5, alpha=0.5)
    ax.set_xticks(x)
    ax.set_xticklabels(pair_labels)
    ax.set_ylabel(r"intergroup correlation ($\hat r^*$)")
    ax.set_title(f"{cond}  |  {trial.upper()}  (attenuation-corrected; Fisher-z 95% CIs)")
    ax.legend(loc="lower right", fontsize=9)
    plt.tight_layout()
    fig.savefig(save_path, dpi=150)
    plt.close(fig)


# ----------------------------------------------------------------------------
# Figure: side-by-side CI methods (percentile / Fisher-z / BCa)
# ----------------------------------------------------------------------------
def make_ci_comparison_figure(cond, trial, pairs_results, save_path):
    """Per-pair overlay of all three CI methods on the attenuation-corrected r.

    For each of the three group pairs we draw three error bars side by side,
    one per CI method. A red x marks the point estimate when it falls outside
    the corresponding CI (BCa pathology surfaces this way).
    """
    pair_labels = [PAIR_LABEL[p] for p in pairs_results.keys()]
    points = [r.point_corr for r in pairs_results.values()]
    methods = ("percentile", "fisher_z", "bca")
    colors  = {"percentile": "#888888", "fisher_z": "#4060b0", "bca": "#b04040"}
    offsets = {"percentile": -0.22, "fisher_z": 0.0, "bca": 0.22}

    fig, ax = plt.subplots(figsize=(8, 4))
    x = np.arange(len(pair_labels))

    drew_legend = set()
    for xi, p, res in zip(x, points, pairs_results.values()):
        if np.isfinite(p):
            ax.plot([xi - 0.32, xi + 0.32], [p, p], color="k", lw=0.7, alpha=0.4)
        for m in methods:
            lo, hi = res.cis_corr[m]
            if not (np.isfinite(lo) and np.isfinite(hi) and np.isfinite(p)):
                continue
            lo_half = max(0.0, p - lo)
            hi_half = max(0.0, hi - p)
            label = m if m not in drew_legend else None
            ax.errorbar([xi + offsets[m]], [p],
                        yerr=[[lo_half], [hi_half]],
                        fmt="o", color=colors[m], ecolor=colors[m],
                        capsize=4, lw=1.4, markersize=5, label=label)
            drew_legend.add(m)
            if p < lo or p > hi:
                ax.plot([xi + offsets[m]], [p],
                        marker="x", color="red", markersize=8, mew=1.5)

    ax.axhline(0, color="k", lw=0.5, alpha=0.4)
    ax.axhline(1, color="k", lw=0.5, alpha=0.3, ls=":")
    ax.set_xticks(x); ax.set_xticklabels(pair_labels)
    ax.set_ylabel(r"corrected $\hat r^*$")
    ax.set_title(f"{cond} | {trial.upper()}  --  CI methods overlay")
    ax.legend(loc="upper left", fontsize=9, frameon=True)
    plt.tight_layout()
    fig.savefig(save_path, dpi=150)
    plt.close(fig)


# ----------------------------------------------------------------------------
# LaTeX emission
# ----------------------------------------------------------------------------
def latex_escape(s: str) -> str:
    return s.replace("_", r"\_").replace("&", r"\&").replace("%", r"\%").replace("#", r"\#")


PREAMBLE = r"""\documentclass[11pt]{article}
\usepackage[margin=1in]{geometry}
\usepackage{booktabs}
\usepackage{graphicx}
\usepackage{amsmath, amssymb}
\usepackage{xcolor}
\usepackage{hyperref}
\usepackage{caption}
\setlength{\parskip}{0.5\baselineskip}
\setlength{\parindent}{0pt}

\title{Cross-cultural recognition memory: intergroup correlation results}
\author{Bryan Medina --- generated by \texttt{make\_results\_report.py}}
\date{\today}

\begin{document}
\maketitle

\section*{Overview}
Intergroup itemwise correlations and paired-bootstrap comparisons for three conditions (\emph{Globalized-Music}, \emph{Industrial-Nature}, \emph{NHS}) and two trial types (hits and false alarms). All numbers were produced by the Python pipeline in \texttt{Analysis-Scripts-v2/python/}; see \texttt{STATS.md} / \texttt{stats.pdf} for the methods. Bootstrap settings: $n_{\mathrm{boot}}=NBOOT_PLACEHOLDER$ for pairwise CIs, $n_{\mathrm{boot}}=NBOOT_PAIRED_PLACEHOLDER$ for the paired test, attenuation correction in \texttt{fixed} mode, participant-level resampling, \texttt{minResp}\,$=MINRESP_PLACEHOLDER$. The paired test compares \emph{attenuation-corrected} correlations: each pair's observed and replicate correlations are divided by the fixed ceiling $\sqrt{\hat\rho_{\mathrm{SB},A}\,\hat\rho_{\mathrm{SB},B}}$ (full-sample Spearman--Brown reliabilities) before the differences are formed. Reported CIs are \textbf{percentile}: $\bigl[\mathrm{P}_{2.5}, \mathrm{P}_{97.5}\bigr]$ of the bootstrap distribution. Fisher-$z$ back-transformed and BCa alternatives are shown in the diagnostic table beneath each headline. BCa was considered as the headline (it is the textbook recommendation for skewed bootstraps) but misfires in cells with low within-group reliability --- for those cells the bias correction $\hat z_0$ is so large that $\hat r$ falls at or outside the BCa interval. The percentile CI is conservative under skew (wider than warranted) but doesn't break in that pathological way and is therefore the safer headline. The default $p$-value is the recentered-null variant.

"""

POSTAMBLE = r"""\end{document}
"""


def emit_group_table(f, results_by_cond):
    f.write(r"\section*{Site partition and within-group reliabilities}" + "\n")
    f.write(r"\begin{center}" + "\n")
    f.write(r"\begin{tabular}{llccccc}" + "\n")
    f.write(r"\toprule" + "\n")
    f.write(r"Condition & Group & $n_{\mathrm{subj}}$ & $n_{\mathrm{items}}$ & $\hat{\rho}^{\mathrm{SB}}_{\mathrm{hit}}$ & $\hat{\rho}^{\mathrm{SB}}_{\mathrm{fa}}$ \\" + "\n")
    f.write(r"\midrule" + "\n")
    for cond, out in results_by_cond.items():
        for label in ("US", "SanBorja", "Tsimane"):
            g = out["groups"][label]
            f.write(f"{latex_escape(cond)} & {label} & {g.n_subjects} & {len(g.items)} & "
                    f"{g.sb_hit:.3f} & {g.sb_fa:.3f} \\\\\n")
        f.write(r"\midrule" + "\n")
    f.write(r"\bottomrule" + "\n")
    f.write(r"\end{tabular}" + "\n")
    f.write(r"\end{center}" + "\n\n")


def emit_intergroup_table(f, cond, trial, trial_results):
    pairs_results = trial_results["pairs"]
    paired = trial_results["paired"]

    for trial, kind in (("hit", "HITS"), ("fa", "FALSE ALARMS")):
        if trial not in trial_results.get("__skip_marker__", [trial]):
            pass

    # Headline table: PERCENTILE CIs for raw and corrected r per pair
    f.write(r"\subsection*{Pairwise intergroup correlations (percentile 95\% CIs)}" + "\n")
    f.write(r"\begin{center}" + "\n")
    f.write(r"\begin{tabular}{lcccc}" + "\n")
    f.write(r"\toprule" + "\n")
    f.write(r"Pair & $\hat r$ (raw) & 95\% CI & $\hat r^*$ (corrected) & 95\% CI \\" + "\n")
    f.write(r"\midrule" + "\n")
    for pair in PAIR_ORDER:
        r = pairs_results[pair]
        ci_raw = r.cis_raw["percentile"]
        ci_cor = r.cis_corr["percentile"]
        f.write(f"{PAIR_LABEL[pair]} & {fmt_r(r.point_raw)} & {fmt_ci(*ci_raw)} & "
                f"{fmt_r(r.point_corr)} & {fmt_ci(*ci_cor)} \\\\\n")
    f.write(r"\bottomrule" + "\n")
    f.write(r"\end{tabular}" + "\n")
    f.write(r"\end{center}" + "\n\n")

    # Diagnostic: all three CI methods on corrected r
    f.write(r"\subsection*{Diagnostic --- alternative CIs on corrected $\hat r^*$}" + "\n")
    f.write(r"\begin{center}" + "\n")
    f.write(r"\includegraphics[width=0.85\textwidth]{figures/ci_compare_" + cond + "_" + trial + ".png}" + "\n")
    f.write(r"\end{center}" + "\n\n")

    f.write(r"\begin{center}" + "\n")
    f.write(r"\begin{tabular}{lcccc}" + "\n")
    f.write(r"\toprule" + "\n")
    f.write(r"Pair & $\hat r^*$ & Percentile 95\% CI & Fisher-$z$ 95\% CI & BCa 95\% CI \\" + "\n")
    f.write(r"\midrule" + "\n")
    for pair in PAIR_ORDER:
        r = pairs_results[pair]
        f.write(f"{PAIR_LABEL[pair]} & {fmt_r(r.point_corr)} & "
                f"{fmt_ci(*r.cis_corr['percentile'])} & "
                f"{fmt_ci(*r.cis_corr['fisher_z'])} & "
                f"{fmt_ci(*r.cis_corr['bca'])} \\\\\n")
    f.write(r"\bottomrule" + "\n")
    f.write(r"\end{tabular}" + "\n")
    f.write(r"\end{center}" + "\n\n")

    # Stimulus-bootstrap diagnostic
    pairs_stim = trial_results.get("pairs_stim", {})
    if pairs_stim:
        f.write(r"\subsection*{Stimulus-bootstrap diagnostic --- CIs on corrected $\hat r^*$ (resampling stimuli, not participants)}" + "\n")
        f.write(r"\begin{center}" + "\n")
        f.write(r"\begin{tabular}{lcccc}" + "\n")
        f.write(r"\toprule" + "\n")
        f.write(r"Pair & $\hat r^*$ & Percentile 95\% CI & Fisher-$z$ 95\% CI & BCa 95\% CI \\" + "\n")
        f.write(r"\midrule" + "\n")
        for pair in PAIR_ORDER:
            rs = pairs_stim[pair]
            f.write(f"{PAIR_LABEL[pair]} & {fmt_r(rs.point_corr)} & "
                    f"{fmt_ci(*rs.cis_corr['percentile'])} & "
                    f"{fmt_ci(*rs.cis_corr['fisher_z'])} & "
                    f"{fmt_ci(*rs.cis_corr['bca'])} \\\\\n")
        f.write(r"\bottomrule" + "\n")
        f.write(r"\end{tabular}" + "\n")
        f.write(r"\end{center}" + "\n\n")

    # Paired test table
    f.write(r"\subsection*{Paired-bootstrap comparison (attenuation-corrected differences)}" + "\n")
    f.write(r"\begin{center}" + "\n")
    f.write(r"\begin{tabular}{lcccc}" + "\n")
    f.write(r"\toprule" + "\n")
    f.write(r"Comparison & Observed diff & 95\% CI (diff) & $p$ (recentered) & $p$ (straddle) \\" + "\n")
    f.write(r"\midrule" + "\n")
    comparisons = (
        ("AB_minus_AC", "US-SB vs US-Tsi"),
        ("AB_minus_BC", "US-SB vs SB-Tsi"),
        ("AC_minus_BC", "US-Tsi vs SB-Tsi"),
    )
    p_null_map = {"AB_minus_AC": paired.ab_vs_ac, "AB_minus_BC": paired.ab_vs_bc, "AC_minus_BC": paired.ac_vs_bc}
    p_strad_map = {"AB_minus_AC": paired.straddle["ab_vs_ac"],
                   "AB_minus_BC": paired.straddle["ab_vs_bc"],
                   "AC_minus_BC": paired.straddle["ac_vs_bc"]}
    for key, label in comparisons:
        d = paired.observed_diffs[key]
        ci = paired.ci[key]
        f.write(f"{label} & {fmt_r(d)} & {fmt_ci(*ci)} & "
                f"{fmt_p(p_null_map[key])} & {fmt_p(p_strad_map[key])} \\\\\n")
    f.write(r"\bottomrule" + "\n")
    f.write(r"\end{tabular}" + "\n")
    f.write(r"\end{center}" + "\n\n")


def emit_section(f, cond, out):
    f.write(r"\section*{" + latex_escape(cond) + "}" + "\n\n")
    for trial in TRIAL_TYPES:
        kind = "Hits" if trial == "hit" else "False alarms"
        f.write(r"\subsubsection*{" + kind + "}" + "\n\n")
        trial_results = out["trials"][trial]
        emit_intergroup_table(f, cond, trial, trial_results)
        fig_rel = f"figures/bar_{cond}_{trial}.png"
        f.write(r"\begin{center}" + "\n")
        f.write(r"\includegraphics[width=0.85\textwidth]{" + fig_rel + "}" + "\n")
        f.write(r"\end{center}" + "\n\n")
    f.write(r"\clearpage" + "\n\n")


def run_scipy_crosscheck(seed=42):
    """Vanilla two-group BCa cross-check against scipy.stats.bootstrap.

    Generates a synthetic pair (X, Y) of length-N item-level group means
    drawn from a bivariate normal with known correlation; computes Spearman
    BCa CIs both with our ci_bca (after our jackknife) and with
    scipy.stats.bootstrap(method='BCa'). Returns a list of dicts ready for
    LaTeX tabulation.
    """
    from scipy import stats as sst
    from python.ci_methods import ci_bca
    rng = np.random.default_rng(seed)
    rows = []
    for rho_true, n_items in [(0.3, 80), (0.6, 80), (0.8, 50)]:
        cov = np.array([[1.0, rho_true], [rho_true, 1.0]])
        XY = rng.multivariate_normal([0, 0], cov, size=n_items)
        X, Y = XY[:, 0], XY[:, 1]
        sample_r, _ = sst.spearmanr(X, Y)

        # scipy BCa via stats.bootstrap on paired data
        def spearman_stat(a, b):
            r, _ = sst.spearmanr(a, b)
            return r if np.isfinite(r) else 0.0
        scipy_res = sst.bootstrap(
            (X, Y), spearman_stat,
            paired=True, vectorized=False,
            n_resamples=2000, method="BCa", random_state=rng,
            confidence_level=0.95,
        )
        scipy_lo = float(scipy_res.confidence_interval.low)
        scipy_hi = float(scipy_res.confidence_interval.high)

        # Our BCa: same paired item resample, then ci_bca with jackknife
        r_boot = np.empty(2000)
        for b in range(2000):
            idx = rng.integers(0, n_items, size=n_items)
            r_boot[b] = spearman_stat(X[idx], Y[idx])
        jk = np.empty(n_items)
        for i in range(n_items):
            keep = np.ones(n_items, dtype=bool); keep[i] = False
            jk[i] = spearman_stat(X[keep], Y[keep])
        ours_lo, ours_hi = ci_bca(sample_r, r_boot, jk, alpha=0.05)
        rows.append(dict(
            rho_true=rho_true, n=n_items, sample_r=sample_r,
            scipy_lo=scipy_lo, scipy_hi=scipy_hi,
            ours_lo=ours_lo, ours_hi=ours_hi,
        ))
    return rows


def emit_validation_section(f, rows):
    f.write(r"\clearpage" + "\n\n")
    f.write(r"\section*{Validation: BCa cross-check against \texttt{scipy.stats.bootstrap}}" + "\n")
    f.write(r"""On a vanilla synthetic case (paired bivariate-normal data, no NaNs, no coverage filter, no attenuation correction), our BCa implementation should match \texttt{scipy.stats.bootstrap(method=`BCa')}. The bootstrap distribution and the jackknife pseudo-values are constructed identically by both; the only thing being tested here is that our BCa formula matches the reference. Three known-truth cases below.
""")
    f.write("\n")
    f.write(r"\begin{center}" + "\n")
    f.write(r"\begin{tabular}{ccccccc}" + "\n")
    f.write(r"\toprule" + "\n")
    f.write(r"$\rho_{\text{true}}$ & $n$ & sample $\hat r$ & scipy BCa CI & our BCa CI & $\Delta$ lo & $\Delta$ hi \\" + "\n")
    f.write(r"\midrule" + "\n")
    for r in rows:
        d_lo = r["ours_lo"] - r["scipy_lo"]
        d_hi = r["ours_hi"] - r["scipy_hi"]
        f.write(f"{r['rho_true']:.2f} & {r['n']} & {r['sample_r']:+.3f} & "
                f"[{r['scipy_lo']:+.3f}, {r['scipy_hi']:+.3f}] & "
                f"[{r['ours_lo']:+.3f}, {r['ours_hi']:+.3f}] & "
                f"{d_lo:+.4f} & {d_hi:+.4f} \\\\\n")
    f.write(r"\bottomrule" + "\n")
    f.write(r"\end{tabular}" + "\n")
    f.write(r"\end{center}" + "\n\n")
    f.write(r"""\textbf{Reading the table.} The $\Delta$ columns are (ours $-$ scipy). They will not be exactly zero --- the two implementations use independent random streams, so the bootstrap distributions sampled are different. Agreement to within $\sim$0.02--0.05 across both endpoints is the expected outcome and indicates our formula and scipy's are computing the same quantity. Differences larger than that would suggest a bug in our BCa.
""")
    f.write("\n")


def emit_methods_note(f):
    f.write(r"\section*{Methods note}" + "\n")
    f.write(r"""All correlations are Spearman. Within-group reliabilities are split-half (Spearman--Brown corrected) computed by participant split. Attenuation correction applied as $\hat r^* = \hat r / \sqrt{\hat\rho^{\mathrm{SB}}_A \hat\rho^{\mathrm{SB}}_B}$; \emph{not} clamped to $[-1, 1]$ (when within-group reliabilities are small relative to the raw correlation, $\hat r^*$ can legitimately exceed 1 --- this is a property of the formula and a substantive observation about within-group noise, not a numerical failure). Bootstrap CIs computed three ways from the same resampled distribution: \textbf{percentile} (the $[\mathrm{P}_{2.5}, \mathrm{P}_{97.5}]$ quantiles), \textbf{Fisher-$z$ back-transformed} (normal-approx CI on the $z$-scale, using bootstrap $z$-space SD, centered on $\mathrm{atanh}(\hat r)$), and \textbf{BCa} (bias-corrected and accelerated with jackknife). The headline is percentile; BCa is shown in the diagnostic table. We chose percentile as the headline after observing that BCa misfires in cells with low within-group reliability (Tsimane' Globalized-Music) --- there the bias correction $\hat z_0$ becomes extreme and the corrected interval excludes the sample point estimate. Percentile is conservative under skew (wider than warranted) but doesn't break in that pathological way. Paired-bootstrap comparisons share the resample of any group that appears in both correlations under test; $p$-values are reported under two definitions, recentered-null (recommended) and straddle-zero (legacy).
""")
    f.write("\n")


def write_results_tex(results_by_cond, out_path, scipy_rows=None):
    with open(out_path, "w") as f:
        f.write(PREAMBLE
                .replace("NBOOT_PLACEHOLDER", str(N_BOOT))
                .replace("NBOOT_PAIRED_PLACEHOLDER", str(N_BOOT_PAIRED))
                .replace("MINRESP_PLACEHOLDER", str(MIN_RESP)))
        emit_group_table(f, results_by_cond)
        for cond, out in results_by_cond.items():
            emit_section(f, cond, out)
        emit_methods_note(f)
        if scipy_rows is not None:
            emit_validation_section(f, scipy_rows)
        f.write(POSTAMBLE)


# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------
def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--rebuild-cache", action="store_true",
                   help="ignore cached groups and re-load + re-compute split-half from .mat files")
    args = p.parse_args()

    results_by_cond = {}
    for cond in CONDITIONS:
        out = run_one_condition(cond, force_rebuild=args.rebuild_cache)
        if out is None:
            continue
        # Generate figures
        for trial in TRIAL_TYPES:
            trial_results = out["trials"][trial]
            fig_path = FIG_DIR / f"bar_{cond}_{trial}.png"
            make_bar_figure(cond, trial, trial_results["pairs"], trial_results["paired"], fig_path, out["groups"])
            print(f"  wrote {fig_path}")
            ci_path = FIG_DIR / f"ci_compare_{cond}_{trial}.png"
            make_ci_comparison_figure(cond, trial, trial_results["pairs"], ci_path)
            print(f"  wrote {ci_path}")
        results_by_cond[cond] = out

    # scipy.stats.bootstrap cross-check (validation appendix)
    print("\nRunning scipy.stats.bootstrap cross-check ...")
    scipy_rows = run_scipy_crosscheck(seed=42)
    for r in scipy_rows:
        print(f"  rho={r['rho_true']:.2f} n={r['n']}: "
              f"sample r={r['sample_r']:+.3f}  "
              f"scipy=[{r['scipy_lo']:+.3f}, {r['scipy_hi']:+.3f}]  "
              f"ours=[{r['ours_lo']:+.3f}, {r['ours_hi']:+.3f}]")

    # Emit LaTeX
    tex_path = OUT_DIR / "results.tex"
    write_results_tex(results_by_cond, tex_path, scipy_rows=scipy_rows)
    print(f"\nWrote {tex_path}")
    print("Next: pdflatex results.tex   (twice for refs)")


if __name__ == "__main__":
    main()
