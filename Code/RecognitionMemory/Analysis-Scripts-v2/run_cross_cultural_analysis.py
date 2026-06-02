"""Top-level Python driver for the cross-cultural recognition memory analysis.

Mirrors run_cross_cultural_analysis.m. For each condition (Globalized-Music,
Industrial-Nature) and trial type (hit, fa) this script:

  1. Loads per-participant .mat files for each site group.
  2. Builds participant x item hit / FA matrices.
  3. Computes within-group split-half reliability (Spearman, participant split).
  4. Bootstraps the three cross-site itemwise correlations.
  5. Runs the paired-bootstrap test comparing the three site pairs (both
     recentered-null and straddle-zero p-values).

Usage:
    python run_cross_cultural_analysis.py

Edit BASE_DIR below if the default path doesn't resolve. All analysis math
lives in the python/ subpackage; this file only orchestrates.
"""

from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
import scipy.io as sio

# Make the python/ subpackage importable when running this file directly.
HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

from python import (  # noqa: E402
    bootstrap_intergroup_correlation_sem,
    paired_bootstrap_compare_correlations,
    load_group,
)

# ---------------------------------------------------------------------------
# 1. Paths
# ---------------------------------------------------------------------------
BASE_DIR = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"

if not BASE_DIR.exists():
    raise FileNotFoundError(
        f"Data directory not found: {BASE_DIR}\n"
        "Edit BASE_DIR at the top of this script."
    )

# ---------------------------------------------------------------------------
# 2. Site definitions
# ---------------------------------------------------------------------------
US = ("PRO", "BOS", "CAM")
SAN_BORJA = ("SBO", "SNB", "SBJ")
TSIMANE = ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")

# ---------------------------------------------------------------------------
# 3. Configuration
# ---------------------------------------------------------------------------
CONDITIONS = ("Globalized-Music", "Industrial-Nature")
MIN_RESP = 2
MIN_ISI0_DPRIME = 2.0
N_SPLITS = 10_000
N_BOOT = 1000
N_BOOT_PAIRED = 5000


# ---------------------------------------------------------------------------
# 4. Run
#    Loading helpers live in python/io.py and are imported above.
# ---------------------------------------------------------------------------
def main():
    print(f"Data directory: {BASE_DIR}")
    results = {}
    for cond in CONDITIONS:
        print(f"\n========================================")
        print(f"Condition: {cond}")
        print(f"========================================")
        groups = {}
        for label, codes in [("US", US), ("SanBorja", SAN_BORJA), ("Tsimane", TSIMANE)]:
            print(f"\nLoading {label} ({'_'.join(codes)})...")
            groups[label] = load_group(
                BASE_DIR, codes, cond,
                min_isi0_dprime=MIN_ISI0_DPRIME, n_splits=N_SPLITS,
            )

        if any(g is None for g in groups.values()):
            print("  Skipping condition (one or more groups empty).")
            continue

        for trial_type in ("hit", "fa"):
            print(f"\n--- Trial type: {trial_type} ---")
            # Pairwise bootstraps for the three site pairs
            ab = bootstrap_intergroup_correlation_sem(
                groups["US"], groups["SanBorja"], trial_type=trial_type,
                n_boot=N_BOOT, min_resp=MIN_RESP,
            )
            ac = bootstrap_intergroup_correlation_sem(
                groups["US"], groups["Tsimane"], trial_type=trial_type,
                n_boot=N_BOOT, min_resp=MIN_RESP,
            )
            bc = bootstrap_intergroup_correlation_sem(
                groups["SanBorja"], groups["Tsimane"], trial_type=trial_type,
                n_boot=N_BOOT, min_resp=MIN_RESP,
            )
            # Paired-bootstrap comparison
            pvals = paired_bootstrap_compare_correlations(
                groups["US"], groups["SanBorja"], groups["Tsimane"],
                trial_type=trial_type, n_boot=N_BOOT_PAIRED, min_resp=MIN_RESP,
            )
            results.setdefault(cond, {})[trial_type] = dict(
                ab=ab, ac=ac, bc=bc, pvals=pvals,
            )

    print("\nDone.")
    return results


if __name__ == "__main__":
    main()
