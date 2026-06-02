"""Shared low-level helpers used across the stats modules.

Mirrors the MATLAB utils/ helpers and the local compute_r_on_items / clamp_unit
logic from bootstrapIntergroupCorrelationSEM.m. Keeping these in one module
means the bootstrap, paired bootstrap, and power simulation all use exactly
the same coverage filter and correlation call.
"""

from __future__ import annotations

from typing import Optional, Sequence, Tuple

import numpy as np
from scipy.stats import pearsonr, spearmanr


# ---------------------------------------------------------------------------
# Random number generation
# ---------------------------------------------------------------------------
def as_rng(rng: Optional[np.random.Generator]) -> np.random.Generator:
    """Coerce an optional Generator argument into a usable Generator.

    Matches the MATLAB convention of `rng('shuffle')` at the top of each
    routine when no seed is given.
    """
    if rng is None:
        return np.random.default_rng()
    return rng


# ---------------------------------------------------------------------------
# Numerics
# ---------------------------------------------------------------------------
def clamp_unit(x: float) -> float:
    """Clamp a correlation-like value to [-1, 1]. Mirrors MATLAB clamp_unit."""
    return float(np.clip(x, -1.0, 1.0))


def _corr(x: np.ndarray, y: np.ndarray, corr_type: str = "Spearman") -> float:
    """Single correlation call, dropping any NaN pairs.

    Returns NaN if fewer than 3 valid pairs remain. corr_type matches
    MATLAB's 'Spearman' / 'Pearson'.
    """
    x = np.asarray(x, dtype=float).ravel()
    y = np.asarray(y, dtype=float).ravel()
    mask = np.isfinite(x) & np.isfinite(y)
    if mask.sum() < 3:
        return float("nan")
    if corr_type.lower().startswith("s"):
        r, _ = spearmanr(x[mask], y[mask])
    else:
        r, _ = pearsonr(x[mask], y[mask])
    return float(r) if np.isfinite(r) else float("nan")


# ---------------------------------------------------------------------------
# Item alignment
# ---------------------------------------------------------------------------
def intersect_items(
    items_a: Sequence[str], items_b: Sequence[str]
) -> Tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Stable intersection of two item label sequences.

    Returns (shared_items, ia, ib) such that items_a[ia] == items_b[ib] ==
    shared_items, preserving the order of items_a (MATLAB's 'stable' flag).
    """
    items_a = list(items_a)
    items_b = list(items_b)
    set_b = set(items_b)
    shared = [s for s in items_a if s in set_b]
    idx_a = np.array([items_a.index(s) for s in shared], dtype=int)
    idx_b = np.array([items_b.index(s) for s in shared], dtype=int)
    return np.array(shared, dtype=object), idx_a, idx_b


def intersect_items_three(
    items_a: Sequence[str], items_b: Sequence[str], items_c: Sequence[str]
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Three-way stable intersection. Returns (shared, ia, ib, ic)."""
    shared_ab, ia_ab, ib_ab = intersect_items(items_a, items_b)
    shared_abc, i_in_ab, ic_in_c = intersect_items(shared_ab, items_c)
    ia = ia_ab[i_in_ab]
    ib = ib_ab[i_in_ab]
    ic = ic_in_c
    return shared_abc, ia, ib, ic
