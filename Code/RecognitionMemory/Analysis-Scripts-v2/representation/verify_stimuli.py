#!/usr/bin/env python3
"""Pre-encode verification: behavioral item names vs on-disk wav basenames.

Asserts, per condition, that the set of behavioral item names (the sounds that
actually appear as foils/repeats in the screened .mat files) is present in the
stimulus wav directory, and reports the intersection size. The design requires
== 80 per set with nothing silently dropped.

Item names collide across conditions (every set uses mem_stim_<k>.wav), so this
must be done per condition against that condition's own wav directory.
"""
import sys
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[3] / "Data" / "RecognitionMemory" / "Results"
CODES = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
         "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}

MT = Path("/orcd/data/jhm/001/om2/bjmedina/mindhive/mcdermott/www/"
          "mturk_stimuli/bjmedina")
# Condition -> (behavioral condition string, wav directory) resolved from the
# stimulusPresented paths stored in the .mat files themselves.
COND_WAVDIR = {
    "Industrial-Nature": MT / "mem_exp_ind-nature_2025",
    "Globalized-Music": MT / "global-music-2025-n_80",
    "NHS": MT / "nhs-region-n_80",
}


def behavioral_items(cond):
    """Union of item names across all groups, plus per-group sets."""
    per_group = {}
    for g, codes in CODES.items():
        files = list_matfiles(BASE, codes, cond, 2.0, False)
        _, _, items = build_hit_fa_matrices(files)
        per_group[g] = set(items.tolist())
    union = set().union(*per_group.values())
    inter = set.intersection(*per_group.values()) if per_group else set()
    return per_group, union, inter


def main():
    ok = True
    for cond, wavdir in COND_WAVDIR.items():
        wavs = {p.name for p in wavdir.glob("mem_stim_*.wav")}
        per_group, union, inter = behavioral_items(cond)
        present = union & wavs
        missing = union - wavs
        print(f"\n=== {cond} ===")
        print(f"  wav dir: {wavdir}  ({len(wavs)} wavs on disk)")
        for g in CODES:
            print(f"  behavioral items [{g:8s}]: {len(per_group[g])}")
        print(f"  union across groups : {len(union)}")
        print(f"  intersection groups : {len(inter)}")
        print(f"  union present in wav dir : {len(present)}")
        if missing:
            print(f"  !! MISSING from wav dir ({len(missing)}): "
                  f"{sorted(missing)[:8]}{' ...' if len(missing) > 8 else ''}")
        # The canonical set to encode = behavioral union that exists on disk.
        n = len(present)
        flag = "OK" if n == 80 else "CHECK"
        if n != 80:
            ok = False
        print(f"  -> ENCODE SET SIZE = {n}  [{flag}]")
    print("\nALL SETS == 80:" , ok)
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
