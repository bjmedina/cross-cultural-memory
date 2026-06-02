"""Loaders for per-participant .mat files.

Mirrors MATLAB utils/UTILS_getRecognitionMemFiles.m + the matrix-building
loop inside stats/calculateSplitHalfReliability.m. Used by the top-level
driver and the example notebooks.

Note on site-code matching: filenames have the form
    <run_id>-<sessionTag>-<SITE>_<participantId>_<RegionName>_RecognitionMem_<date>_<Condition>.mat
e.g. 000-DMA-SNB_DannyMollericona_SanBorja_RecognitionMem_28-Jul-2025_Globalized-Music.mat
We anchor the site filter on the strict slot "-<CODE>_" so a leading sessionTag
that happens to match a site code (e.g. 4088-SNB-PRO_..._Prolific_...) is
NOT mis-attributed. (The MATLAB twin uses a naive contains() and is subject
to that contamination -- see notes in STATS.md.)
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Iterable, Optional

import numpy as np
import scipy.io as sio
from scipy.stats import norm

from .split_half import SplitHalfReliability, calculate_split_half_reliability


def _clip_rate(p: float, eps: float = 1e-5) -> float:
    return max(min(p, 1 - eps), eps)


def compute_dprime_isi0(
    stims: list[str], rp: np.ndarray, corr: np.ndarray, eps: float = 1e-5
) -> float:
    """Compute d' at ISI=0 (repeatPosition == 1) for a single participant.

    Ports the on-the-fly computation in MATLAB UTILS_getRecognitionMemFiles.m:
      - FA rate from first-occurrence trials of items that will later repeat
      - Hit rate from trials at repeatPosition == 1
      - d' = z(hit) - z(FA), clipped at +/-eps

    Returns NaN if either component is undefined.
    """
    rp = np.asarray(rp).ravel().astype(float)
    corr = np.asarray(corr).ravel().astype(float)
    n_trials = len(stims)

    # first-occurrence vs repeat masks
    seen: dict[str, int] = {}
    counts: dict[str, int] = {}
    for i, s in enumerate(stims):
        counts[s] = counts.get(s, 0) + 1
        if s not in seen:
            seen[s] = i

    will_repeat_first = np.zeros(n_trials, dtype=bool)
    for s, first_i in seen.items():
        if counts[s] > 1:
            will_repeat_first[first_i] = True

    if not will_repeat_first.any():
        return float("nan")

    fa_raw = float(np.sum(~(corr[will_repeat_first] > 0.5))) / float(will_repeat_first.sum())
    fa = _clip_rate(fa_raw, eps)

    isi0_mask = rp == 1
    if not isi0_mask.any():
        return float("nan")
    hit_raw = float(np.sum(corr[isi0_mask] > 0.5)) / float(isi0_mask.sum())
    hit = _clip_rate(hit_raw, eps)

    return float(norm.ppf(hit) - norm.ppf(fa))


_SITE_SLOT_RE = re.compile(r"-([A-Z]{3})_")


def site_code_of(filename: str) -> Optional[str]:
    """Return the site code from a recognition memory filename, or None.

    Anchors on the strict slot "-<CODE>_" (preceded by '-', followed by '_').
    Returns the LAST match in the filename, since the pattern is
    "<runID>-<sessionTag>-<SITE>_<participant>_..." and we want the third
    dash-separated token before the first underscore.
    """
    matches = _SITE_SLOT_RE.findall(filename)
    return matches[-1] if matches else None


def list_matfiles(
    base_dir: Path | str,
    place_codes: Iterable[str],
    condition: str,
    min_isi0_dprime: float = 2.0,
    is_multi_isi: bool = False,
) -> list[Path]:
    """Return .mat files for the given site codes and condition, filtered by
    d' at ISI=0.

    Site-code matching is anchored on the strict slot "-<CODE>_" (see
    site_code_of), avoiding the false-positive bug where a leading sessionTag
    like "4088-SNB-PRO_..._Prolific_..." would otherwise be misassigned to SNB.

    Three additional filters match the MATLAB UTILS_getRecognitionMemFiles
    behavior:
      - Files with `-original.` in the name are excluded (legacy backups).
      - `is_multi_isi=False` (default) keeps single-ISI sessions; `True` keeps
        only files with `_Multi-p` (multi-ISI experiment).
      - d' at ISI=0 (computed on the fly, not stored) must be >= min_isi0_dprime.
    """
    base_dir = Path(base_dir)
    place_codes = set(place_codes)
    out = []
    for p in sorted(base_dir.glob("*.mat")):
        name = p.name
        if condition not in name:
            continue
        if "-original." in name:
            continue
        has_multi_tag = "_Multi-p" in name
        if is_multi_isi != has_multi_tag:
            continue
        code = site_code_of(name)
        if code is None or code not in place_codes:
            continue
        try:
            d = sio.loadmat(
                p, variable_names=["stimulusPresented", "repeatPosition", "isResponseCorrect"]
            )
        except Exception:
            continue
        stims_raw = np.array(d.get("stimulusPresented", [])).ravel()
        if stims_raw.size == 0:
            continue
        stims = [_stim_basename(s) for s in stims_raw]
        rp = np.asarray(d.get("repeatPosition", np.empty(0))).ravel().astype(float)
        corr = np.asarray(d.get("isResponseCorrect", np.empty(0))).ravel().astype(float)
        if rp.size == 0 or corr.size == 0:
            continue
        dp = compute_dprime_isi0(stims, rp, corr)
        if not np.isfinite(dp) or dp < min_isi0_dprime:
            continue
        out.append(p)
    return out


def _stim_basename(s) -> str:
    """Strip directory and extract bare stimulus filename from a MATLAB cell entry."""
    s = np.asarray(s).ravel()
    s = str(s.item()) if s.size == 1 else str(s)
    return s.split("/")[-1].split("\\")[-1]


def build_hit_fa_matrices(files: list[Path]):
    """Read each .mat file and assemble per-participant hit and FA matrices.

    Returns (hits, fas, items):
        hits : [n_sub x n_items] with NaN where the participant didn't see the
               item as a nonzero-ISI repeat; otherwise isResponseCorrect.
        fas  : [n_sub x n_items] with NaN where the participant didn't see the
               item as a non-repeat; otherwise 1 - isResponseCorrect.
        items: ndarray of stimulus basenames (object dtype).
    """
    seen: dict = {}
    all_items: list[str] = []
    parsed = []
    for f in files:
        d = sio.loadmat(
            f, variable_names=["stimulusPresented", "repeatPosition", "isResponseCorrect"]
        )
        stims_raw = np.array(d["stimulusPresented"]).ravel()
        stims = [_stim_basename(s) for s in stims_raw]
        rp = np.asarray(d["repeatPosition"]).ravel().astype(float)
        corr = np.asarray(d["isResponseCorrect"]).ravel().astype(float)
        parsed.append((stims, rp, corr))
        for s, r in zip(stims, rp):
            if np.isfinite(r) and r > 1 and s not in seen:
                seen[s] = True
                all_items.append(s)

    items = np.array(all_items, dtype=object)
    item_idx = {s: i for i, s in enumerate(items)}
    n_sub = len(parsed)
    n_items = len(items)
    hits = np.full((n_sub, n_items), np.nan)
    fas = np.full((n_sub, n_items), np.nan)
    for i, (stims, rp, corr) in enumerate(parsed):
        for t, s in enumerate(stims):
            j = item_idx.get(s)
            if j is None:
                continue
            if np.isfinite(rp[t]) and rp[t] > 1:
                hits[i, j] = corr[t]
            elif not np.isfinite(rp[t]):
                fas[i, j] = 1.0 - corr[t]
    return hits, fas, items


def load_group(
    base_dir: Path | str,
    place_codes: Iterable[str],
    condition: str,
    min_isi0_dprime: float = 2.0,
    is_multi_isi: bool = False,
    n_splits: int = 10_000,
    split_dim: int = 1,
    corr_type: str = "Spearman",
    rng: Optional[np.random.Generator] = None,
    verbose: bool = True,
) -> Optional[SplitHalfReliability]:
    """List files -> build matrices -> compute split-half reliability.

    Returns a SplitHalfReliability struct (or None if no files matched).
    """
    files = list_matfiles(base_dir, place_codes, condition, min_isi0_dprime, is_multi_isi)
    if not files:
        if verbose:
            print(f"  no files for {'_'.join(place_codes)} | {condition}")
        return None
    hits, fas, items = build_hit_fa_matrices(files)
    outs = calculate_split_half_reliability(
        hits, fas, items, n_splits=n_splits, split_dim=split_dim,
        corr_type=corr_type, rng=rng,
    )
    outs.files = [str(p) for p in files]
    if verbose:
        print(
            f"  {'_'.join(place_codes)}: n={outs.n_subjects} subj, "
            f"{len(items)} items, sb_hit={outs.sb_hit:.3f}, sb_fa={outs.sb_fa:.3f}"
        )
    return outs
