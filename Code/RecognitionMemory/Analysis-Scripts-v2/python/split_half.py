"""Within-group split-half reliability + Spearman-Brown.

Python twin of MATLAB stats/estimateSplitHalfFlexible.m, stats/splitHalfSB.m,
and stats/calculateSplitHalfReliability.m.

The half-set point estimate is the MEDIAN of per-split correlations (see
../STATS.md §2). No Fisher-z averaging.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

import numpy as np

from ._utils import _corr, as_rng


@dataclass
class SplitHalfReliability:
    """Outputs of calculate_split_half_reliability, mirroring the MATLAB struct."""

    r_hit: float
    r_fa: float
    sb_hit: float
    sb_fa: float
    itemwise_hits: np.ndarray
    itemwise_fas: np.ndarray
    items: np.ndarray
    n_subjects: int
    split_dim: int = 1
    files: list = field(default_factory=list)


def estimate_split_half_flexible(
    data: np.ndarray,
    n_splits: int = 10_000,
    split_dim: int = 1,
    corr_type: str = "Spearman",
    rng: Optional[np.random.Generator] = None,
) -> tuple[float, float, np.ndarray]:
    """Median of per-split correlations + dispersion + full vector.

    Parameters
    ----------
    data : [n_sub x n_items] with NaN for missing.
    split_dim : 1 = split across participants (default), 2 = across stimuli.
    corr_type : 'Spearman' (default) or 'Pearson'.

    Returns
    -------
    point_r : median of per-split rs.
    std_r   : std of per-split rs (dispersion).
    rs      : ndarray of all per-split rs (with NaN for failed splits).
    """
    rng = as_rng(rng)
    n_splits = max(1, n_splits)
    n_sub, n_items = data.shape
    rs = np.full(n_splits, np.nan)

    for s in range(n_splits):
        if split_dim == 1:
            idx = rng.permutation(n_sub)
            half = n_sub // 2
            m1 = np.nanmean(data[idx[:half], :], axis=0)
            m2 = np.nanmean(data[idx[half:], :], axis=0)
        elif split_dim == 2:
            idx = rng.permutation(n_items)
            half = n_items // 2
            m1 = np.nanmean(data[:, idx[:half]], axis=1)
            m2 = np.nanmean(data[:, idx[half:]], axis=1)
        else:
            raise ValueError("split_dim must be 1 or 2.")

        rs[s] = _corr(m1, m2, corr_type)

    point_r = float(np.nanmedian(rs))
    std_r = float(np.nanstd(rs, ddof=0))
    return point_r, std_r, rs


def split_half_sb(
    M: np.ndarray,
    corr_type: str = "Spearman",
    n_rep: int = 200,
    split_dim: int = 1,
    rng: Optional[np.random.Generator] = None,
) -> float:
    """Spearman-Brown corrected split-half reliability.

    Thin wrapper around estimate_split_half_flexible that returns
    SB = 2*r/(1+r) directly. Returns NaN if M is empty or has too few
    rows/columns to split.

    Mirrors MATLAB stats/splitHalfSB.m.
    """
    if M.size == 0:
        return float("nan")
    n_sub, n_items = M.shape
    if (split_dim == 1 and n_sub < 4) or (split_dim == 2 and n_items < 4):
        return float("nan")

    point_r, _, _ = estimate_split_half_flexible(
        M, n_splits=n_rep, split_dim=split_dim, corr_type=corr_type, rng=rng
    )
    if not np.isfinite(point_r):
        return float("nan")
    return float((2 * point_r) / (1 + point_r))


def calculate_split_half_reliability(
    hits: np.ndarray,
    fas: np.ndarray,
    items: np.ndarray,
    n_splits: int = 10_000,
    split_dim: int = 1,
    corr_type: str = "Spearman",
    rng: Optional[np.random.Generator] = None,
) -> SplitHalfReliability:
    """Compute split-half reliability for hit and FA matrices.

    Mirrors MATLAB calculateSplitHalfReliability.m, but takes pre-built
    matrices instead of reading .mat files (file loading is left to the
    caller, who can use scipy.io.loadmat).
    """
    rng = as_rng(rng)
    r_hit, _, _ = estimate_split_half_flexible(
        hits, n_splits=n_splits, split_dim=split_dim, corr_type=corr_type, rng=rng
    )
    r_fa, _, _ = estimate_split_half_flexible(
        fas, n_splits=n_splits, split_dim=split_dim, corr_type=corr_type, rng=rng
    )
    sb_hit = (2 * r_hit) / (1 + r_hit) if np.isfinite(r_hit) else float("nan")
    sb_fa = (2 * r_fa) / (1 + r_fa) if np.isfinite(r_fa) else float("nan")

    return SplitHalfReliability(
        r_hit=r_hit,
        r_fa=r_fa,
        sb_hit=sb_hit,
        sb_fa=sb_fa,
        itemwise_hits=hits,
        itemwise_fas=fas,
        items=items,
        n_subjects=hits.shape[0],
        split_dim=split_dim,
    )
