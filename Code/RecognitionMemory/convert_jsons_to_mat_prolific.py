#!/usr/bin/env python3
# -*- coding: utf-8 -*-

# ---------------- imports / deps ----------------
import os
import json
from datetime import datetime
from typing import List, Dict, Any, Tuple, Optional
import numpy as np
from scipy.io import savemat

# --------------- small utilities ----------------
def format_date(dt: datetime) -> str:
    """Format date like '26-Aug-2025'."""
    return dt.strftime("%d-%b-%Y")

def _cap3(name: str) -> str:
    """Uppercased first three alphabetic chars; fallback to first 3 raw chars."""
    letters = [c for c in name if c.isalpha()]
    return ("".join(letters[:3]) if len(letters) >= 3 else name[:3]).upper()

def _build_out_name(basename: str, run_id: int, date_str: str, experiment: str) -> str:
    """<ID>-<CAP3>-PRO_<basename>_Prolific_RecognitionMem_<date>_<experiment>.mat"""
    return f"{run_id:04d}-{_cap3(basename)}-PRO_{basename}_Prolific_RecognitionMem_{date_str}_{experiment}.mat"

# --------------- JSON loaders ----------------
def _load_json_records(fp: str) -> List[Dict[str, Any]]:
    """Load trial JSON; supports wrapper dict with 'filedata' containing a JSON-encoded list."""
    with open(fp, "r") as f:
        obj = json.load(f)
    if isinstance(obj, dict) and "filedata" in obj:
        return json.loads(obj["filedata"])
    return obj  # assume list[dict]

def _load_category_map(category_map_path: Optional[str]) -> Dict[str, str]:
    """Load mapping {filename -> type}; returns {} if path is None or missing."""
    if not category_map_path:
        return {}
    if not os.path.isfile(category_map_path):
        print(f"[WARN] category_map_path not found: {category_map_path}")
        return {}
    with open(category_map_path, "r") as f:
        rows = json.load(f)
    mapping: Dict[str, str] = {}
    for row in rows:
        fn = row.get("filename", "")
        ty = row.get("type", "")
        if isinstance(fn, str) and fn:
            mapping[fn] = ty if isinstance(ty, str) else ""
    return mapping

def _filter_main(records: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
    """Keep trials where stim_type == 'main'."""
    return [r for r in records if isinstance(r, dict) and r.get("stim_type") == "main"]

# ------------- stimulus / response helpers -------------
def _extract_stimulus_id(tr: Dict[str, Any]) -> str:
    """Prefer yt_id; else basename of 'stimulus' path/url; empty if unavailable."""
    sid = tr.get("yt_id", None)
    if sid:
        return str(sid)
    stim = tr.get("stimulus", "")
    if isinstance(stim, str) and stim:
        return os.path.basename(stim)
    return ""

def _ensure_stimulus_path(basename: str, platform: str, prefix_prolific: str) -> str:
    """For Prolific, prepend the fixed prefix when not present; passthrough otherwise."""
    if platform.lower() == "prolific":
        if basename.startswith(prefix_prolific) or basename.startswith("~/"):
            return basename
        return prefix_prolific.rstrip("/") + "/" + basename.lstrip("/")
    return basename

def _binarize_response(resp: Any, platform: str) -> Optional[float]:
    """Binary response (0.0/1.0) or None if missing; Prolific: Likert >1=>1 else 0; Tsimane: cast 0/1."""
    if resp is None:
        return None
    if isinstance(resp, (int, float)):
        if platform.lower() == "prolific":
            return 1.0 if resp > 1 else 0.0
        return (np.nan if np.isnan(resp) else (1.0 if resp >= 1 else 0.0))
    return None

def _compute_repeat_lag(stim_ids: List[str], repeats: List[bool]) -> np.ndarray:
    """Lag since previous occurrence; NaN for non-repeats; 0 if flagged repeat but no prior."""
    last_seen: Dict[str, int] = {}
    n = len(stim_ids)
    rp = np.full(n, np.nan, dtype=float)
    for i, (sid, rep) in enumerate(zip(stim_ids, repeats), start=1):
        if rep:
            prev = last_seen.get(sid, None)
            rp[i - 1] = float(i - prev) if prev is not None else 0.0
        if sid:
            last_seen[sid] = i
    return rp

# ---------------- mapping to MATLAB struct ----------------
def _map_trials_to_struct(
    mains: List[Dict[str, Any]],
    *,
    subject: str,
    condition: str,
    group_id: int,
    computer_id: int,
    dice_roll: int,
    platform: str,
    prefix_prolific: str,
    category_map: Dict[str, str],
) -> Dict[str, Any]:
    """
    Build MATLAB struct:
      - stimuli_type: always category from category_map[basename] (e.g., 'industrial'/'nature')
      - participantResponses: platform-specific binarization
      - stimulusPresented: Prolific path prefix added
      - repeatPosition: lag since previous occurrence (NaN for non-repeats; 0 if repeat without prior)
      - isResponseCorrect: compare binary response vs repeat flag
    """
    n = len(mains)
    blockNumber = np.arange(1, n + 1, dtype=float)
    containsRepeat = np.zeros(n, dtype=bool)
    isResponseCorrect = np.zeros(n, dtype=bool)
    participantResponses = np.full(n, np.nan, dtype=float)
    responseTime = np.full(n, np.nan, dtype=float)
    stimuli_type = np.empty(n, dtype=object)
    stimulusPresented = np.empty(n, dtype=object)

    stim_ids: List[str] = []
    rep_flags: List[bool] = []

    for i, tr in enumerate(mains):
        # RT: ms -> s
        rt = tr.get("rt", None)
        responseTime[i] = (rt / 1000.0) if isinstance(rt, (int, float)) else np.nan

        # Response (binary)
        rbin = _binarize_response(tr.get("response", None), platform=platform)
        participantResponses[i] = (np.nan if rbin is None else float(rbin))

        # Flags
        rep = bool(tr.get("repeat", False))
        containsRepeat[i] = rep

        # Stimulus ID/path and basename key for category map
        sid = _extract_stimulus_id(tr)
        stim_ids.append(sid)
        rep_flags.append(rep)

        # For Prolific we store with a fixed prefix; for Tsimane we pass through
        full_path_like = _ensure_stimulus_path(sid, platform, prefix_prolific)
        stimulusPresented[i] = full_path_like

        # Category from external mapping via basename
        key = os.path.basename(sid)  # e.g., mem_stim_61.wav
        stimuli_type[i] = category_map.get(key, "")  # "" if not found

    # Repeat lag vector
    repeatPosition = _compute_repeat_lag(stim_ids, rep_flags)

    # Correctness: response vs truth (repeat flag)
    truth = np.array(rep_flags, dtype=float)
    for i in range(n):
        rb = participantResponses[i]
        isResponseCorrect[i] = False if np.isnan(rb) else (rb == truth[i])

    totalSeconds = float(np.nansum(responseTime))
    totalMinutes = totalSeconds / 60.0

    return {
        "blockNumber": blockNumber,
        "computer_id": float(computer_id),
        "condition": condition,
        "containsRepeat": containsRepeat,
        "dice_roll": float(dice_roll),
        "group_id": float(group_id),
        "isResponseCorrect": isResponseCorrect,
        "participantResponses": participantResponses,
        "repeatPosition": repeatPosition,
        "responseTime": responseTime,
        "stimuli_type": stimuli_type,          # strictly from category_map
        "stimulusPresented": stimulusPresented,
        "subject": subject,
        "totalMinutes": float(totalMinutes),
        "totalSeconds": float(totalSeconds),
    }

# ---------------- API: single-file convert ----------------
def convert_one(
    json_fp: str,
    out_dir: str,
    run_id: int,
    experiment: str,
    *,
    platform: str = "prolific",  # 'prolific' or 'tsimane'
    condition: str = "Industrial–Nature",
    group_id: int = 1,
    computer_id: int = 1,
    dice_roll: int = 18,
    date_str: Optional[str] = None,
    subject: Optional[str] = None,
    stimulus_prefix_prolific: str = "~/static2025/Stimuli/RecognitionMemory/mem_exp_ind-nature_2025/",
    category_map_path: Optional[str] = None,
    preloaded_category_map: Optional[Dict[str, str]] = None,
) -> Tuple[str, Tuple[int, int]]:
    """Convert one JSON to .mat and return (out_path, (rows, cols))."""
    records = _load_json_records(json_fp)
    mains = _filter_main(records)
    base = os.path.splitext(os.path.basename(json_fp))[0]
    subject = base if subject is None else subject
    os.makedirs(out_dir, exist_ok=True)
    date_str = date_str or format_date(datetime.now())

    # Load/resolve category map
    category_map = preloaded_category_map if preloaded_category_map is not None else _load_category_map(category_map_path)

    data_struct = _map_trials_to_struct(
        mains,
        subject=subject,
        condition=condition,
        group_id=group_id,
        computer_id=computer_id,
        dice_roll=dice_roll,
        platform=platform,
        prefix_prolific=stimulus_prefix_prolific,
        category_map=category_map,
    )
    out_name = _build_out_name(base, run_id, date_str, experiment)
    out_path = os.path.join(out_dir, out_name)
    savemat(out_path, {"data": data_struct})
    rows = len(mains)
    cols = 15  # number of fields
    return out_path, (rows, cols)

# ---------------- API: directory convert ----------------
def convert_dir(
    json_dir: str,
    out_dir: str,
    start_id: int,
    experiment: str,
    *,
    platform: str = "prolific",  # 'prolific' or 'tsimane'
    condition: str = "Industrial–Nature",
    group_id: int = 1,
    computer_id: int = 1,
    dice_roll: int = 18,
    date_str: Optional[str] = None,
    stimulus_prefix_prolific: str = "~/static2025/Stimuli/RecognitionMemory/mem_exp_ind-nature_2025/",
    category_map_path: Optional[str] = None,
) -> List[Tuple[str, Tuple[int, int]]]:
    """
    Convert all .json files in json_dir; IDs auto-increment; returns [(path, (rows, cols)), ...].
    Supply category_map_path (e.g., '/mnt/data/filenames.json') so stimuli_type is populated.
    """
    results: List[Tuple[str, Tuple[int, int]]] = []
    run_id = start_id
    date_str = date_str or format_date(datetime.now())

    # Load the category map once for speed
    category_map = _load_category_map(category_map_path)

    for fname in sorted(os.listdir(json_dir)):
        if not fname.lower().endswith(".json"):
            continue
        fpath = os.path.join(json_dir, fname)
        try:
            out_path, shape = convert_one(
                fpath,
                out_dir,
                run_id,
                experiment,
                platform=platform,
                condition=condition,
                group_id=group_id,
                computer_id=computer_id,
                dice_roll=dice_roll,
                date_str=date_str,
                subject=None,
                stimulus_prefix_prolific=stimulus_prefix_prolific,
                category_map_path=None,
                preloaded_category_map=category_map,
            )
            results.append((out_path, shape))
            run_id += 1
        except Exception as e:
            print(f"[WARN] Skipped {fname}: {e}")
    return results


if __name__ == "__main__":
    results = convert_dir(
        json_dir="/Users/bjm/Documents/School/MIT/labs/mcdermott/Tsimane2025/Data/RecognitionMemory/Results/prolific/isi_16/ind-nature-len120/",
        out_dir="/Users/bjm/Documents/School/MIT/labs/mcdermott/Tsimane2025/Data/RecognitionMemory/Results/prolific/mats/",
        start_id=4000,
        experiment="Industrial-Nature",
        platform="prolific",
        condition="Industrial-Nature", # or "tsimane"
        date_str=format_date(datetime.now()),
        category_map_path="/Users/bjm/Documents/School/MIT/labs/mcdermott/static2025/Stimuli/RecognitionMemory/mem_exp_ind-nature_2025/filenames.json",
        stimulus_prefix_prolific="~/static2025/Stimuli/RecognitionMemory/mem_exp_ind-nature_2025/"
    )
    for p, sh in results:
        print(f"{p} -> {sh[0]} rows, {sh[1]} cols")


    results = convert_dir(
        json_dir="/Users/bjm/Documents/School/MIT/labs/mcdermott/Tsimane2025/Data/RecognitionMemory/Results/prolific/isi_16/atexts-len120/",
        out_dir="/Users/bjm/Documents/School/MIT/labs/mcdermott/Tsimane2025/Data/RecognitionMemory/Results/prolific/mats/",
        start_id=5000,
        experiment="Textures",
        platform="prolific",  # or "tsimane"
        date_str=format_date(datetime.now()),
        condition="Textures", # or "tsimane"
        category_map_path="/Users/bjm/Documents/School/MIT/labs/mcdermott/static2025/Stimuli/RecognitionMemory/mem_exp_atexts_2025/filenames.json",
        stimulus_prefix_prolific="~/static2025/Stimuli/RecognitionMemory/mem_exp_atexts_2025/"

    )
    for p, sh in results:
        print(f"{p} -> {sh[0]} rows, {sh[1]} cols")


    results = convert_dir(
        json_dir="/Users/bjm/Documents/School/MIT/labs/mcdermott/Tsimane2025/Data/RecognitionMemory/Results/prolific/isi_16/nhs-region-len120/",
        out_dir="/Users/bjm/Documents/School/MIT/labs/mcdermott/Tsimane2025/Data/RecognitionMemory/Results/prolific/mats/",
        start_id=6000,
        experiment="NHS",
        platform="prolific",  # or "tsimane"
        date_str=format_date(datetime.now()),
        condition="NHS", # or "tsimane"
        category_map_path="/Users/bjm/Documents/School/MIT/labs/mcdermott/static2025/Stimuli/RecognitionMemory/nhs-region-n_80/filenames.json",
        stimulus_prefix_prolific="~/static2025/Stimuli/RecognitionMemory/nhs-region-n_80/"

    )
    for p, sh in results:
        print(f"{p} -> {sh[0]} rows, {sh[1]} cols")

    results = convert_dir(
        json_dir="/Users/bjm/Documents/School/MIT/labs/mcdermott/Tsimane2025/Data/RecognitionMemory/Results/prolific/isi_16/global-music-len120/",
        out_dir="/Users/bjm/Documents/School/MIT/labs/mcdermott/Tsimane2025/Data/RecognitionMemory/Results/prolific/mats/",
        start_id=7000,
        experiment="Globalized-Music",
        platform="prolific",  # or "tsimane"
        date_str=format_date(datetime.now()),
        condition="Globalized-Music", # or "tsimane"
        category_map_path="/Users/bjm/Documents/School/MIT/labs/mcdermott/static2025/Stimuli/RecognitionMemory/global-music-2025-n_80/filenames.json",
        stimulus_prefix_prolific="~/static2025/Stimuli/RecognitionMemory/global-music-2025-n_80/"

    )
    for p, sh in results:
        print(f"{p} -> {sh[0]} rows, {sh[1]} cols")