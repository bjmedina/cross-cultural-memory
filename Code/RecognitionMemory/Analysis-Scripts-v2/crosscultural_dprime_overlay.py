#!/usr/bin/env python3
"""Cross-cultural d' vs ISI overlay (US vs San Borja vs Tsimane'), multi-ISI.

Combines the multi-ISI recognition-memory data that live in several places and
formats, and overlays one aggregate d'(ISI) curve per cultural group. Each group
hears a different stimulus set, so comparison is at the level of the group curve
(not itemwise).

d' / curve / bootstrap conventions are identical to aggregate_dprime_vs_isi.py
(and therefore to the psychophysics chapter, repo `bjmedina/memory`,
utls/dprime.py + human_analysis.py): d' = Phi^-1(hit) - Phi^-1(fa) with rates
clipped to [1e-2, 1-1e-2]; per-subject hit rate per ISI; FA pooled over all
non-repeat trials; group curve = population d' from across-subject mean rates;
bootstrap-over-subjects SEM.

DATA SOURCES (multi-ISI only; the *SingleISI* folders are excluded):
  US        : Prolific jsPsych .csv   (condition token 'ind_nature' / 'atexts' / ...)
  San Borja : Bolivia-2024 .mat       (sites SBO, SBJ; filename token 'ind-nature' / 'atexts')
  Tsimane'  : Bolivia-2024 .mat       (sites MAR, MOS, MAN, NVM)
            + Bolivia-2025 .mat       (sites NVM, MAJ; this repo's Results/, token 'Industrial-Nature')

Scoring (both formats map to the same hit/FA definitions):
  .mat  : repeat (repeatPosition finite) -> hit if isResponseCorrect==1;
          non-repeat (NaN)               -> FA  if isResponseCorrect==0;
          ISI = repeatPosition - 1.
  .csv  : repeat=='true'  -> hit if response>criterion (criterion=1, jsPsych);
          repeat=='false' -> FA  if response>criterion; ISI from the 'isi' column.

Default paths point at the folders Bryan connected:
  Prolific (US) : /Users/bjm/Documents/School/MIT/teaching/labs/bjmedina/BOLIVIA2024/FullData/RecognitionMemory/prolificResults
  Bolivia 2024  : /Users/bjm/Documents/School/MIT/teaching/labs/bjmedina/BOLIVIA2024/FullData/RecognitionMemory/Results
  Bolivia 2025  : <repo>/Data/RecognitionMemory/Results
Override with --prolific-dir / --bolivia2024-dir / --bolivia2025-dir.

Usage:
    python crosscultural_dprime_overlay.py --condition Industrial-Nature
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np
import pandas as pd
import scipy.io as sio

# reuse the chapter-matched d' math / plotting from the sibling module
sys.path.insert(0, str(Path(__file__).resolve().parent))
from aggregate_dprime_vs_isi import (  # noqa: E402
    compute_dprime, run_analysis, plot_overlay, ALLOWED_ISI,
    site_code_of, participant_id_of,
)

HERE = Path(__file__).resolve().parent
REPO_2025 = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
LABS = Path("/Users/bjm/Documents/School/MIT/teaching/labs/bjmedina/"
            "BOLIVIA2024/FullData/RecognitionMemory")

# group -> site codes (for the .mat sources)
SITES = {
    "US": (),  # US comes from prolific csv, no site filter
    "SanBorja": ("SBO", "SBJ", "SNB"),
    "Tsimane": ("MAR", "MOS", "MAN", "NVM", "MAJ", "NUM", "NUV", "CVR"),
}

# condition token per format (the filename/path spelling differs by year/format).
# NOTE: the multi-ISI experiment used the "v01" three-set design — environmental
# sounds (ind-nature), auditory textures (atexts), and a single combined
# world/globalized-music set (nhs-global). The 2025 split into separate
# Globalized-Music / NHS sets has NO multi-ISI data, so it is not used here.
COND_TOKENS = {
    "Industrial-Nature": {"mat2024": "ind-nature", "mat2025": "Industrial-Nature", "csv": "ind_nature"},
    "Textures":          {"mat2024": "atexts",     "mat2025": "Textures",          "csv": "atexts"},
    "NHS-Global":        {"mat2024": "nhs-global", "mat2025": "NHS",               "csv": "nhs_global"},
}

# A multi-ISI session sweeps many ISIs; a single-ISI session has only {0, 16}.
# Requiring a subject's repeats to span at least this many distinct ISIs cleanly
# excludes any single-ISI files that happen to share a condition tag/folder.
MIN_DISTINCT_ISI = 4


# ---------------------------------------------------------------------------
# loaders -> per-subject-per-ISI rows  (group, subject, isi, hit_rate, fa_rate, ...)
# ---------------------------------------------------------------------------
def _row(group, subject, isi, hits, fas, n_signal, n_noise):
    hit_rate = hits / n_signal if n_signal else np.nan
    fa_rate = fas / n_noise if n_noise else np.nan
    dp = (compute_dprime(hit_rate, fa_rate)
          if np.isfinite(hit_rate) and np.isfinite(fa_rate) else np.nan)
    return dict(group=group, subject=subject, isi=int(isi), hits=hits,
                false_alarms=fas, n_signal=n_signal, n_noise=n_noise,
                hit_rate=hit_rate, fa_rate=fa_rate, d_prime=dp)


def load_mat_dir(base: Path, codes, cond_token, group, source_tag):
    """Bolivia .mat files. Pools repeated-name parts (p1a/p1b/p1/p2) per subject."""
    if not base or not base.exists():
        return pd.DataFrame(), 0
    files = []
    for f in sorted(base.glob("*.mat")):
        n = f.name
        if "-original." in n.lower():
            continue
        if cond_token.lower() not in n.lower():
            continue
        code = site_code_of(n)
        if codes and code not in codes:
            continue
        files.append(f)

    grouped = defaultdict(list)
    for f in files:
        grouped[participant_id_of(f.name)].append(f)

    rows = []
    for subj, fs in sorted(grouped.items()):
        rp_all, corr_all = [], []
        for f in fs:
            d = sio.loadmat(f, variable_names=["repeatPosition", "isResponseCorrect"])
            rp_all.append(np.asarray(d["repeatPosition"]).ravel().astype(float))
            corr_all.append(np.asarray(d["isResponseCorrect"]).ravel().astype(float))
        rp = np.concatenate(rp_all)
        corr = np.concatenate(corr_all)
        repeat = np.isfinite(rp)
        noise = ~repeat
        n_noise = int(noise.sum())
        fas = int(np.nansum(1.0 - corr[noise])) if n_noise else 0
        subj_isis = [int(p) - 1 for p in np.unique(rp[repeat]) if (int(p) - 1) in ALLOWED_ISI]
        if len(subj_isis) < MIN_DISTINCT_ISI:   # skip single-ISI sessions
            continue
        for pos in np.unique(rp[repeat]):
            isi = int(pos) - 1
            if isi not in ALLOWED_ISI:
                continue
            idx = rp == pos
            rows.append(_row(group, f"{source_tag}:{subj}", isi,
                             int(np.nansum(corr[idx])), fas, int(idx.sum()), n_noise))
    return pd.DataFrame(rows), len(files)


def load_csv_dir(base: Path, cond_token, group, source_tag, criterion=1):
    """Prolific jsPsych .csv files (one participant per file)."""
    if not base or not base.exists():
        return pd.DataFrame(), 0
    files = [f for f in sorted(base.glob("*.csv")) if cond_token.lower() in f.name.lower()]
    rows = []
    for f in files:
        subj = participant_id_of(f.name)
        hit_counts, sig_counts = defaultdict(int), defaultdict(int)
        fas = n_noise = 0
        with open(f, newline="") as fh:
            for r in csv.DictReader(fh):
                resp, rep = r.get("response"), r.get("repeat")
                if resp in (None, "", "null") or rep not in ("true", "false"):
                    continue
                try:
                    is_yes = int(int(float(resp)) > criterion)
                except ValueError:
                    continue
                if rep == "true":
                    try:
                        isi = int(float(r.get("isi")))
                    except (TypeError, ValueError):
                        continue
                    if isi not in ALLOWED_ISI:
                        continue
                    sig_counts[isi] += 1
                    hit_counts[isi] += is_yes
                else:
                    n_noise += 1
                    fas += is_yes
        if len(sig_counts) < MIN_DISTINCT_ISI:   # skip single-ISI sessions
            continue
        for isi in sorted(sig_counts):
            rows.append(_row(group, f"{source_tag}:{subj}", isi,
                             hit_counts[isi], fas, sig_counts[isi], n_noise))
    return pd.DataFrame(rows), len(files)


def apply_isi0_filter(df, thr):
    if thr <= 0 or df.empty:
        return df, 0
    keep = []
    for subj, sdf in df.groupby("subject"):
        r0 = sdf[sdf.isi == 0]
        d0 = r0["d_prime"].iloc[0] if len(r0) else np.nan
        if np.isfinite(d0) and d0 >= thr:
            keep.append(subj)
    return df[df.subject.isin(keep)].copy(), df.subject.nunique() - len(keep)


# ---------------------------------------------------------------------------
def main(argv=None):
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--condition", default="Industrial-Nature",
                    choices=list(COND_TOKENS))
    ap.add_argument("--prolific-dir", default=str(LABS / "prolificResults"))
    ap.add_argument("--bolivia2024-dir", default=str(LABS / "Results"))
    ap.add_argument("--bolivia2025-dir", default=str(REPO_2025))
    ap.add_argument("--min-isi0-dprime", type=float, default=0.0)
    ap.add_argument("--n-boot", type=int, default=5000)
    ap.add_argument("--out-dir", default=str(HERE / "dprime_vs_isi_outputs"),
                    help="Figure/CSV output dir (default: <repo>/.../Analysis-Scripts-v2/"
                         "dprime_vs_isi_outputs).")
    args = ap.parse_args(argv)

    tok = COND_TOKENS[args.condition]
    prolific = Path(args.prolific_dir)
    bol24 = Path(args.bolivia2024_dir)
    bol25 = Path(args.bolivia2025_dir)

    print(f"Condition: {args.condition}   minISI0d'={args.min_isi0_dprime}\n")

    # ---- assemble each group from its sources ----
    sources = {
        "US": [load_csv_dir(prolific, tok["csv"], "US", "PRO24csv")],
        "SanBorja": [load_mat_dir(bol24, SITES["SanBorja"], tok["mat2024"], "SanBorja", "BOL24")],
        "Tsimane": [
            load_mat_dir(bol24, SITES["Tsimane"], tok["mat2024"], "Tsimane", "BOL24"),
            load_mat_dir(bol25, SITES["Tsimane"], tok["mat2025"], "Tsimane", "BOL25"),
        ],
    }

    results, per_subject, group_rows = {}, [], []
    for g, parts in sources.items():
        frames = [p[0] for p in parts if not p[0].empty]
        nfiles = sum(p[1] for p in parts)
        if not frames:
            results[g] = None
            print(f"[{g:9s}] NO multi-ISI data ({nfiles} files matched)")
            continue
        df = pd.concat(frames, ignore_index=True)
        df, n_excl = apply_isi0_filter(df, args.min_isi0_dprime)
        per_subject.append(df)
        out = run_analysis(df, n_boot=args.n_boot)
        results[g] = out
        pts = "  ".join(f"ISI{int(i)}={d:.2f}" for i, d in zip(out["isis"], out["dprime"]))
        print(f"[{g:9s}] N={out['N']:3d}  (files={nfiles}, excl={n_excl})")
        print(f"            {pts}")
        for i, isi in enumerate(out["isis"]):
            group_rows.append(dict(group=g, ISI=int(isi), dprime=out["dprime"][i],
                                   sem=out["boot"]["sem"][i],
                                   ci_low=out["boot"]["ci_low"][i],
                                   ci_high=out["boot"]["ci_high"][i], N=out["N"]))

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    tag = f"{args.condition}_minISI0d{args.min_isi0_dprime:g}"
    png = out_dir / f"crosscultural_dprime_vs_ISI_{tag}.png"
    plot_overlay(results, args.condition, png)
    print(f"\nSaved figure: {png}")
    if group_rows:
        gm = out_dir / f"crosscultural_dprime_vs_ISI_groupmeans_{tag}.csv"
        pd.DataFrame(group_rows).to_csv(gm, index=False)
        print(f"Saved group means: {gm}")
    if per_subject:
        ps = out_dir / f"crosscultural_dprime_vs_ISI_persubject_{tag}.csv"
        pd.concat(per_subject, ignore_index=True).to_csv(ps, index=False)
        print(f"Saved per-subject: {ps}")
    return results


if __name__ == "__main__":
    main()
