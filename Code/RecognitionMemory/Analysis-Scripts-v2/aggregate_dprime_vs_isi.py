#!/usr/bin/env python3
"""Aggregate d' vs ISI curves for the multi-ISI experiment, overlaid by group.

Conventions are deliberately matched to the psychophysics / modeling chapter
(repo `bjmedina/memory`, modules utls/dprime.py, utls/human_analysis.py,
utls/human_plotting.py) so the cross-cultural forgetting curves are directly
comparable to that chapter's human curves:

  * d' = Phi^-1(hit_rate) - Phi^-1(fa_rate), with rates clipped to
    [1e-2, 1-1e-2]  (utls.dprime.compute_dprime).
  * Per subject: hit_rate is computed *per ISI* over repeat trials; fa_rate is
    a single value pooled over ALL non-repeat ("noise") trials
    (utls.dprime.recompute_dprime_by_isi_per_subject).
  * The group curve is the POPULATION d': Phi^-1(mean hit_rate per ISI) minus
    Phi^-1(mean fa_rate), i.e. d' is computed from the across-subject mean rates
    rather than averaging per-subject d' (utls.human_analysis.compute_dprime_curve).
  * Error bars are bootstrap SEMs from resampling subjects with replacement
    (utls.human_analysis.bootstrap_dprime, n_boot=5000).
  * Plot styling mirrors utls.human_plotting.plot_dprime_vs_isi (o- markers,
    capsize 4, black marker edges, linear ISI ticks, dashed grid).

Difference vs the chapter's loader: the chapter reads jsPsych DataFrames
(columns yt_id/response/repeat); here we read this repo's MATLAB .mat files
(stimulusPresented / repeatPosition / isResponseCorrect). Scoring maps onto the
same hit / false-alarm definitions:
    repeat trial  (repeatPosition finite) -> hit  if isResponseCorrect == 1
    non-repeat    (repeatPosition is NaN) -> FA   if isResponseCorrect == 0
    ISI = repeatPosition - 1   (repeatPosition == 1 -> ISI 0)

Each group hears a different stimulus set, so groups are compared at the level
of the aggregate d'(ISI) curve, not itemwise.

Usage:
    python aggregate_dprime_vs_isi.py
    python aggregate_dprime_vs_isi.py --condition Industrial-Nature --min-isi0-dprime 1.0
    python aggregate_dprime_vs_isi.py --groups US,SanBorja,Tsimane
    python aggregate_dprime_vs_isi.py --groups "NVM,MAJ"   # ad-hoc per-site

Outputs (to <BASE_DIR>/figures/<condition>/):
    aggDprime_vs_ISI_overlay_<condition>.png
    aggDprime_vs_ISI_groupmeans_<condition>.csv    (group x ISI: d', sem, ci, n)
    aggDprime_vs_ISI_persubject_<condition>.csv     (per-subject-per-ISI rates)
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np
import pandas as pd
import scipy.io as sio
from scipy.stats import norm

# ---------------------------------------------------------------------------
# Paths & group definitions
# ---------------------------------------------------------------------------
HERE = Path(__file__).resolve().parent
DEFAULT_BASE_DIR = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"

GROUPS = {
    "US": ("PRO", "BOS", "CAM"),
    "SanBorja": ("SBO", "SNB", "SBJ"),
    "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR"),
}

# Chapter palette (utls.human_plotting): greens for primary curves; we extend
# with distinct hues so multiple groups remain legible when overlaid.
GROUP_COLORS = {
    "US": "#1f77b4",
    "SanBorja": "#ff7f0e",
    "Tsimane": "#2E7D32",
}
FALLBACK_COLORS = ["#2E7D32", "#1f77b4", "#ff7f0e", "#9467bd", "#d62728", "#8c564b"]

ALLOWED_ISI = {-1, 0, 1, 2, 3, 4, 8, 16, 32, 64}  # matches utls.dprime


# ===========================================================================
# d' math — mirrors memory/utls/dprime.py and utls/human_analysis.py
# ===========================================================================
def compute_dprime(hit_rate, fa_rate):
    """d' = Phi^-1(hit) - Phi^-1(fa), rates clipped to [1e-2, 1-1e-2]."""
    hit_rate = np.clip(hit_rate, 1e-2, 1 - 1e-2)
    fa_rate = np.clip(fa_rate, 1e-2, 1 - 1e-2)
    return norm.ppf(hit_rate) - norm.ppf(fa_rate)


def population_fa_rate(df):
    return df["fa_rate"].mean()


def population_hit_rates_by_isi(df):
    return df.groupby("isi")["hit_rate"].mean().sort_index()


def compute_dprime_curve(df):
    """Population d' curve from across-subject mean rates (chapter convention)."""
    fa = population_fa_rate(df)
    hrs = population_hit_rates_by_isi(df)
    isis = hrs.index.to_numpy()
    dp = np.array([compute_dprime(h, fa) for h in hrs.values])
    return isis, dp


def compute_dprime_for_subjects(df, subjects):
    return compute_dprime_curve(df[df["subject"].isin(subjects)])


def bootstrap_dprime(df, n_boot=5000, seed=0):
    """Bootstrap CIs on the population d' curve by resampling subjects."""
    rng = np.random.default_rng(seed)
    subjects = df["subject"].unique()
    isis, _ = compute_dprime_curve(df)
    boot_mat = np.zeros((n_boot, len(isis)))
    for b in range(n_boot):
        sampled = rng.choice(subjects, size=len(subjects), replace=True)
        _, dp = compute_dprime_curve(df[df["subject"].isin(sampled)])
        boot_mat[b] = dp
    return {
        "isis": isis,
        "mean": boot_mat.mean(axis=0),
        "sem": boot_mat.std(axis=0, ddof=1),
        "ci_low": np.percentile(boot_mat, 2.5, axis=0),
        "ci_high": np.percentile(boot_mat, 97.5, axis=0),
    }


def run_analysis(df, n_boot=5000, seed=0):
    """Population d' curve + bootstrap (mirrors human_analysis.run_analysis)."""
    df_clean = df[df["isi"] != -1].copy()
    isis, dp = compute_dprime_curve(df_clean)
    boot = bootstrap_dprime(df_clean, n_boot=n_boot, seed=seed)
    return {
        "isis": isis,
        "dprime": dp,
        "boot": boot,
        "N": df_clean["subject"].nunique(),
    }


# ===========================================================================
# Loading — adapt this repo's .mat schema into the chapter's per-subject table
# ===========================================================================
def site_code_of(filename: str):
    m = re.match(r"^[^-]+-[^-]+-([A-Za-z]+)_", filename)
    return m.group(1) if m else None


def participant_id_of(filename: str):
    return filename.split("_")[0]


def list_multi_isi_files(base_dir: Path, codes, condition: str):
    out = []
    for f in sorted(base_dir.glob("*.mat")):
        name = f.name
        if "-original." in name.lower():
            continue
        if condition.lower() not in name.lower():
            continue
        if "_multi-p" not in name.lower():
            continue
        code = site_code_of(name)
        if code in codes:
            out.append(f)
    return out


def load_trials(f: Path):
    d = sio.loadmat(
        f, variable_names=["stimulusPresented", "repeatPosition", "isResponseCorrect"]
    )
    rp = np.asarray(d["repeatPosition"]).ravel().astype(float)
    corr = np.asarray(d["isResponseCorrect"]).ravel().astype(float)
    return rp, corr


def build_per_subject_table(base_dir, codes, condition, group_name, split_parts=False):
    """One row per (subject, ISI). Pools p1+p2 per participant by default.

    Mirrors recompute_dprime_by_isi_per_subject: hits/n_signal per ISI;
    false alarms pooled over all non-repeat trials (stored under ISI=-1 and
    propagated as fa_rate to every ISI row for that subject).
    """
    files = list_multi_isi_files(base_dir, codes, condition)
    grouped = defaultdict(list)
    for f in files:
        key = f.name if split_parts else participant_id_of(f.name)
        grouped[key].append(f)

    rows = []
    for subj, fs in sorted(grouped.items()):
        rp_all, corr_all = [], []
        for f in fs:
            rp, corr = load_trials(f)
            rp_all.append(rp)
            corr_all.append(corr)
        rp = np.concatenate(rp_all)
        corr = np.concatenate(corr_all)

        repeat_mask = np.isfinite(rp)
        noise_mask = ~repeat_mask

        # pooled false alarms over all non-repeat trials
        n_noise = int(noise_mask.sum())
        fas = int(np.nansum(1.0 - corr[noise_mask])) if n_noise else 0
        fa_rate = (fas / n_noise) if n_noise else np.nan

        # hit rate per ISI
        positions = np.unique(rp[repeat_mask])
        for pos in positions:
            isi = int(pos) - 1
            if isi not in ALLOWED_ISI:
                continue
            idx = rp == pos
            n_signal = int(idx.sum())
            hits = int(np.nansum(corr[idx]))
            hit_rate = hits / n_signal if n_signal else np.nan
            d_prime = (compute_dprime(hit_rate, fa_rate)
                       if np.isfinite(hit_rate) and np.isfinite(fa_rate) else np.nan)
            rows.append(dict(
                group=group_name, subject=f"{group_name}:{subj}", isi=isi,
                hits=hits, false_alarms=fas, n_signal=n_signal, n_noise=n_noise,
                hit_rate=hit_rate, fa_rate=fa_rate, d_prime=d_prime,
            ))
    return pd.DataFrame(rows), len(files)


def apply_isi0_filter(df, min_isi0_dprime):
    """Keep only subjects whose ISI=0 d' >= threshold (per-subject d_prime)."""
    if min_isi0_dprime <= 0:
        return df, 0
    keep = []
    for subj, sdf in df.groupby("subject"):
        row0 = sdf[sdf["isi"] == 0]
        d0 = row0["d_prime"].iloc[0] if len(row0) else np.nan
        if np.isfinite(d0) and d0 >= min_isi0_dprime:
            keep.append(subj)
    n_excluded = df["subject"].nunique() - len(keep)
    return df[df["subject"].isin(keep)].copy(), n_excluded


# ===========================================================================
# Plot — mirrors utls.human_plotting.plot_dprime_vs_isi
# ===========================================================================
def plot_overlay(results, condition, save_path, ylim=(0, 3.5)):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(7, 5))
    all_isis = None
    plotted = False
    for k, (gname, out) in enumerate(results.items()):
        if out is None or out["N"] == 0:
            continue
        color = GROUP_COLORS.get(gname, FALLBACK_COLORS[k % len(FALLBACK_COLORS)])
        ax.errorbar(
            out["isis"], out["dprime"], yerr=out["boot"]["sem"],
            fmt="o-", color=color, capsize=4, linewidth=2, markersize=6,
            markeredgecolor="k", markeredgewidth=0.8,
            label=f"{gname} (N={out['N']})",
        )
        all_isis = out["isis"] if all_isis is None else all_isis
        plotted = True

    if all_isis is not None:
        ax.set_xticks(all_isis)
        ax.set_xticklabels(all_isis)
    if ylim:
        ax.set_ylim(ylim)
    ax.set_xlabel("Inter-Stimulus Interval (ISI)")
    ax.set_ylabel("d' (Sensitivity)")
    ax.set_title(f"d' vs ISI — {condition} (multi-ISI)")
    ax.grid(True, which="both", ls="--", alpha=0.4)
    if plotted:
        ax.legend()
    else:
        ax.text(0.5, 0.5, "No multi-ISI data for selected groups",
                ha="center", va="center", transform=ax.transAxes)
    fig.tight_layout()
    fig.savefig(save_path, dpi=300, bbox_inches="tight")
    plt.close(fig)


# ===========================================================================
# Main
# ===========================================================================
def main(argv=None):
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base-dir", default=str(DEFAULT_BASE_DIR))
    ap.add_argument("--condition", default="Industrial-Nature")
    ap.add_argument("--groups", default="US,SanBorja,Tsimane",
                    help="Comma-separated names from GROUPS, or bare site codes "
                         "(e.g. 'NVM,MAJ') to plot per-site.")
    ap.add_argument("--min-isi0-dprime", type=float, default=0.0,
                    help="Min per-subject d' at ISI=0 for inclusion (default 0).")
    ap.add_argument("--n-boot", type=int, default=5000)
    ap.add_argument("--split-parts", action="store_true",
                    help="Treat each _Multi-p part as its own observation "
                         "(default pools p1+p2 per participant).")
    ap.add_argument("--out-dir", default=str(HERE / "dprime_vs_isi_outputs"),
                    help="Figure/CSV output dir (default: <repo>/.../Analysis-Scripts-v2/"
                         "dprime_vs_isi_outputs).")
    args = ap.parse_args(argv)

    base_dir = Path(args.base_dir)
    if not base_dir.exists():
        sys.exit(f"Data directory not found: {base_dir}")

    group_specs = {}
    for tok in (t.strip() for t in args.groups.split(",")):
        if not tok:
            continue
        group_specs[tok] = GROUPS.get(tok, (tok,))

    print(f"Data dir : {base_dir}")
    print(f"Condition: {args.condition}   minISI0d'={args.min_isi0_dprime}   "
          f"pool-parts={not args.split_parts}\n")

    results = {}
    per_subject_frames = []
    group_rows = []
    for k, (gname, codes) in enumerate(group_specs.items()):
        df, n_files = build_per_subject_table(
            base_dir, codes, args.condition, gname, split_parts=args.split_parts)
        if df.empty:
            results[gname] = None
            print(f"[{gname:9s}] codes={'+'.join(codes):22s} "
                  f"NO multi-ISI data ({n_files} files matched)")
            continue
        df, n_excl = apply_isi0_filter(df, args.min_isi0_dprime)
        per_subject_frames.append(df)
        out = run_analysis(df, n_boot=args.n_boot)
        results[gname] = out
        pts = "  ".join(f"ISI{int(i)}={d:.2f}" for i, d in zip(out["isis"], out["dprime"]))
        print(f"[{gname:9s}] codes={'+'.join(codes):22s} "
              f"N={out['N']:3d} (files={n_files}, excl={n_excl})")
        print(f"            {pts}")
        for i, isi in enumerate(out["isis"]):
            group_rows.append(dict(
                group=gname, ISI=int(isi),
                dprime=out["dprime"][i], sem=out["boot"]["sem"][i],
                ci_low=out["boot"]["ci_low"][i], ci_high=out["boot"]["ci_high"][i],
                N=out["N"]))

    fig_dir = Path(args.out_dir)
    fig_dir.mkdir(parents=True, exist_ok=True)
    tag = f"{args.condition}_minISI0d{args.min_isi0_dprime:g}"
    png = fig_dir / f"aggDprime_vs_ISI_overlay_{tag}.png"
    plot_overlay(results, args.condition, png)
    print(f"\nSaved figure: {png}")

    if group_rows:
        gm = fig_dir / f"aggDprime_vs_ISI_groupmeans_{tag}.csv"
        pd.DataFrame(group_rows).to_csv(gm, index=False)
        print(f"Saved group means: {gm}")
    if per_subject_frames:
        ps = fig_dir / f"aggDprime_vs_ISI_persubject_{tag}.csv"
        pd.concat(per_subject_frames, ignore_index=True).to_csv(ps, index=False)
        print(f"Saved per-subject: {ps}")

    return results


if __name__ == "__main__":
    main()
