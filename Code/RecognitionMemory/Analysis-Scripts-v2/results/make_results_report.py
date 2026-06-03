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

CONDITIONS = ("Globalized-Music", "Industrial-Nature")
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
N_SPLITS = 1000      # within-group split-half reps; 10000 is "final"
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
        trial_out = {"pairs": {}}

        # Pairwise intergroup bootstraps (participant dim by default)
        for a, b in PAIR_ORDER:
            print(f"  r({a}, {b}) ...")
            res = bootstrap_intergroup_correlation_sem(
                groups[a], groups[b], trial_type=trial,
                n_boot=N_BOOT, min_resp=MIN_RESP, bootstrap_dim=1,
                reliability_mode="fixed", correct_atten=True,
                rng=np.random.default_rng(SEED + _stable_hash(f"{cond}|{trial}|{a}|{b}") % 1_000_000),
                verbose=False,
            )
            trial_out["pairs"][(a, b)] = res

        # Paired-bootstrap comparison
        print(f"  paired bootstrap ...")
        paired = paired_bootstrap_compare_correlations(
            groups["US"], groups["SanBorja"], groups["Tsimane"],
            trial_type=trial,
            n_boot=N_BOOT_PAIRED, use_spearman=True, bootstrap_dim=1,
            min_resp=MIN_RESP,
            rng=np.random.default_rng(SEED + _stable_hash(f"{cond}|{trial}|paired") % 1_000_000),
            verbose=False,
        )
        trial_out["paired"] = paired

        out["trials"][trial] = trial_out

    return out


# ----------------------------------------------------------------------------
# Figure: triple bar chart with BCa CIs
# ----------------------------------------------------------------------------
def make_bar_figure(cond, trial, pairs_results, paired_result, save_path):
    points_raw = [r.point_raw for r in pairs_results.values()]
    points_cor = [r.point_corr for r in pairs_results.values()]

    bca_raw = [r.cis_raw["bca"] for r in pairs_results.values()]
    bca_cor = [r.cis_corr["bca"] for r in pairs_results.values()]

    n_items = [r.point_items_n for r in pairs_results.values()]

    pair_labels = [PAIR_LABEL[p] for p in pairs_results.keys()]
    x = np.arange(len(pair_labels))
    w = 0.35

    fig, ax = plt.subplots(figsize=(7.5, 4))
    raw_bars = ax.bar(x - w/2, points_raw, w, color="#888", label="raw r")
    cor_bars = ax.bar(x + w/2, points_cor, w, color="#4060b0", label="attenuation-corrected r")

    # Error bars from BCa. Clip half-widths to >= 0: if BCa shifts the CI
    # so far that the sample point estimate sits outside the bracket, the
    # bar visually flattens on one side and we annotate it.
    def _draw_eb(xi, p, lo, hi):
        if not (np.isfinite(lo) and np.isfinite(hi) and np.isfinite(p)):
            return
        lo_half = max(0.0, p - lo)
        hi_half = max(0.0, hi - p)
        ax.errorbar([xi], [p], yerr=[[lo_half], [hi_half]],
                    fmt="none", ecolor="k", capsize=3, lw=1)
        if p < lo or p > hi:
            ax.plot([xi], [p], marker="x", color="red", markersize=7)
    for xi, p, (lo, hi) in zip(x - w/2, points_raw, bca_raw):
        _draw_eb(xi, p, lo, hi)
    for xi, p, (lo, hi) in zip(x + w/2, points_cor, bca_cor):
        _draw_eb(xi, p, lo, hi)

    # Significance brackets from paired test
    ps = (paired_result.ab_vs_ac, paired_result.ab_vs_bc, paired_result.ac_vs_bc)
    pair_idx = [(0, 1), (0, 2), (1, 2)]
    ymax = max([h for _, h in bca_cor if np.isfinite(h)] +
               [h for _, h in bca_raw if np.isfinite(h)] + [0])
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
    ax.set_ylabel("intergroup correlation")
    ax.set_title(f"{cond}  |  {trial.upper()}  (BCa 95\\% CIs; n items: {', '.join(str(n) for n in n_items)})")
    ax.legend(loc="lower right", fontsize=9)
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
Intergroup itemwise correlations and paired-bootstrap comparisons for two conditions (\emph{Globalized-Music}, \emph{Industrial-Nature}) and two trial types (hits and false alarms). All numbers were produced by the Python pipeline in \texttt{Analysis-Scripts-v2/python/}; see \texttt{STATS.md} / \texttt{stats.pdf} for the methods. Bootstrap settings: $n_{\mathrm{boot}}=NBOOT_PLACEHOLDER$ for pairwise CIs, $n_{\mathrm{boot}}=NBOOT_PAIRED_PLACEHOLDER$ for the paired test, attenuation correction in \texttt{fixed} mode, participant-level resampling, \texttt{minResp}\,$=MINRESP_PLACEHOLDER$. Reported CIs are \textbf{BCa} (bias-corrected and accelerated) unless otherwise noted; percentile and Fisher-$z$ alternatives appear in the diagnostic tables. The default $p$-value is the recentered-null variant.

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


def emit_intergroup_table(f, cond, trial_results):
    pairs_results = trial_results["pairs"]
    paired = trial_results["paired"]

    for trial, kind in (("hit", "HITS"), ("fa", "FALSE ALARMS")):
        if trial not in trial_results.get("__skip_marker__", [trial]):
            pass

    # Headline table: BCa CIs for raw and corrected r per pair
    f.write(r"\subsection*{Pairwise intergroup correlations (BCa 95\% CIs)}" + "\n")
    f.write(r"\begin{center}" + "\n")
    f.write(r"\begin{tabular}{lcccc}" + "\n")
    f.write(r"\toprule" + "\n")
    f.write(r"Pair & $\hat r$ (raw) & 95\% CI (BCa) & $\hat r^*$ (corrected) & 95\% CI (BCa) \\" + "\n")
    f.write(r"\midrule" + "\n")
    for pair in PAIR_ORDER:
        r = pairs_results[pair]
        ci_raw = r.cis_raw["bca"]
        ci_cor = r.cis_corr["bca"]
        f.write(f"{PAIR_LABEL[pair]} & {fmt_r(r.point_raw)} & {fmt_ci(*ci_raw)} & "
                f"{fmt_r(r.point_corr)} & {fmt_ci(*ci_cor)} \\\\\n")
    f.write(r"\bottomrule" + "\n")
    f.write(r"\end{tabular}" + "\n")
    f.write(r"\end{center}" + "\n\n")

    # Diagnostic: all three CI methods on corrected r
    f.write(r"\subsection*{Diagnostic --- alternative CIs on corrected $\hat r^*$}" + "\n")
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

    # Paired test table
    f.write(r"\subsection*{Paired-bootstrap comparison}" + "\n")
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
        emit_intergroup_table(f, cond, trial_results)
        fig_rel = f"figures/bar_{cond}_{trial}.png"
        f.write(r"\begin{center}" + "\n")
        f.write(r"\includegraphics[width=0.85\textwidth]{" + fig_rel + "}" + "\n")
        f.write(r"\end{center}" + "\n\n")
    f.write(r"\clearpage" + "\n\n")


def emit_methods_note(f):
    f.write(r"\section*{Methods note}" + "\n")
    f.write(r"""All correlations are Spearman. Within-group reliabilities are split-half (Spearman--Brown corrected) computed by participant split. Attenuation correction applied as $\hat r^* = \hat r / \sqrt{\hat\rho^{\mathrm{SB}}_A \hat\rho^{\mathrm{SB}}_B}$, clamped to $[-1, 1]$. Bootstrap CIs computed three ways from the same resampled distribution: \textbf{percentile} (the $[\mathrm{P}_{2.5}, \mathrm{P}_{97.5}]$ quantiles), \textbf{Fisher-$z$ back-transformed} (normal-approx CI on the $z$-scale, using bootstrap $z$-space SD, centered on $\mathrm{atanh}(\hat r)$), and \textbf{BCa} (bias-corrected and accelerated with jackknife). Paired-bootstrap comparisons share the resample of any group that appears in both correlations under test; $p$-values are reported under two definitions, recentered-null (recommended) and straddle-zero (legacy).
""")
    f.write("\n")


def write_results_tex(results_by_cond, out_path):
    with open(out_path, "w") as f:
        f.write(PREAMBLE
                .replace("NBOOT_PLACEHOLDER", str(N_BOOT))
                .replace("NBOOT_PAIRED_PLACEHOLDER", str(N_BOOT_PAIRED))
                .replace("MINRESP_PLACEHOLDER", str(MIN_RESP)))
        emit_group_table(f, results_by_cond)
        for cond, out in results_by_cond.items():
            emit_section(f, cond, out)
        emit_methods_note(f)
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
            make_bar_figure(cond, trial, trial_results["pairs"], trial_results["paired"], fig_path)
            print(f"  wrote {fig_path}")
        results_by_cond[cond] = out

    # Emit LaTeX
    tex_path = OUT_DIR / "results.tex"
    write_results_tex(results_by_cond, tex_path)
    print(f"\nWrote {tex_path}")
    print("Next: pdflatex results.tex   (twice for refs)")


if __name__ == "__main__":
    main()
