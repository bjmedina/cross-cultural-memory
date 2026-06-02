"""Intergroup itemwise correlation + cluster-bootstrap CIs + attenuation correction.

Python twin of MATLAB stats/bootstrapIntergroupCorrelationSEM.m, with the
helper itemwiseCorr from stats/itemwiseCorr.m.

Headline central value is the sample point estimate; bootstrap is used only
for the percentile CI. Bootstrap median is reported as a secondary sanity
check. No Fisher-z averaging. See ../STATS.md §3-5.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

import numpy as np

from ._utils import _corr, as_rng, clamp_unit, intersect_items
from .split_half import SplitHalfReliability, split_half_sb


@dataclass
class BootstrapResult:
    """Outputs of bootstrap_intergroup_correlation_sem, mirroring MATLAB outs."""

    point_raw: float
    point_corr: float
    point_items_n: int
    ci_raw: tuple
    ci_corr: tuple
    median_boot_raw: float
    median_boot_corr: float
    n_kept_items: np.ndarray
    shared_items: np.ndarray
    sb_point_a: float
    sb_point_b: float
    options: dict
    r_boot_raw: np.ndarray
    r_boot_corr: np.ndarray


def itemwise_corr(
    A: np.ndarray,
    B: np.ndarray,
    corr_type: str = "Spearman",
    min_resp: int = 2,
    min_items: int = 5,
) -> tuple[float, np.ndarray]:
    """Item-level correlation between two group matrices.

    Keeps only items with at least `min_resp` non-NaN observations in both
    groups; requires `min_items` surviving items. Returns (NaN, valid) if
    too few items survive.

    Mirrors MATLAB stats/itemwiseCorr.m.
    """
    n_obs_a = np.sum(~np.isnan(A), axis=0)
    n_obs_b = np.sum(~np.isnan(B), axis=0)
    valid = (n_obs_a >= min_resp) & (n_obs_b >= min_resp)
    if valid.sum() < min_items:
        return float("nan"), valid
    mean_a = np.nanmean(A[:, valid], axis=0)
    mean_b = np.nanmean(B[:, valid], axis=0)
    return _corr(mean_a, mean_b, corr_type), valid


def bootstrap_intergroup_correlation_sem(
    outs_a: SplitHalfReliability,
    outs_b: SplitHalfReliability,
    trial_type: str = "hit",
    n_boot: int = 1000,
    min_resp: int = 2,
    min_items: int = 5,
    use_spearman: bool = True,
    reliability_mode: str = "fixed",
    split_half_repeats: int = 200,
    reliability_split_dim: int = 1,
    bootstrap_dim: int = 1,
    correct_atten: bool = True,
    rng: Optional[np.random.Generator] = None,
    verbose: bool = True,
) -> BootstrapResult:
    """Cluster bootstrap CI for an intergroup itemwise correlation.

    Parameters mirror MATLAB bootstrapIntergroupCorrelationSEM. reliability_mode
    is one of 'fixed', 'subset', 'per-draw'.

    Returns a BootstrapResult with the sample point estimate as the headline
    and percentile CIs + bootstrap medians from the resampling distribution.
    """
    rng = as_rng(rng)
    corr_type = "Spearman" if use_spearman else "Pearson"

    if trial_type.lower() == "hit":
        A_full, B_full = outs_a.itemwise_hits, outs_b.itemwise_hits
        sb_fixed_a, sb_fixed_b = outs_a.sb_hit, outs_b.sb_hit
    elif trial_type.lower() == "fa":
        A_full, B_full = outs_a.itemwise_fas, outs_b.itemwise_fas
        sb_fixed_a, sb_fixed_b = outs_a.sb_fa, outs_b.sb_fa
    else:
        raise ValueError("trial_type must be 'hit' or 'fa'.")

    shared, ia, ib = intersect_items(list(outs_a.items), list(outs_b.items))
    A = A_full[:, ia]
    B = B_full[:, ib]
    n_a, n_items = A.shape
    n_b = B.shape[0]

    # ---- point estimate ----
    r_point_raw, valid_items_point = itemwise_corr(
        A, B, corr_type=corr_type, min_resp=min_resp, min_items=min_items
    )
    sb_a_point = float("nan")
    sb_b_point = float("nan")
    r_point_corr = float("nan")

    if correct_atten:
        if reliability_mode == "fixed":
            sb_a_use, sb_b_use = sb_fixed_a, sb_fixed_b
        elif reliability_mode == "subset":
            sb_a_use = split_half_sb(
                A[:, valid_items_point], corr_type, split_half_repeats, reliability_split_dim, rng=rng
            )
            sb_b_use = split_half_sb(
                B[:, valid_items_point], corr_type, split_half_repeats, reliability_split_dim, rng=rng
            )
        else:
            sb_a_use = float("nan")
            sb_b_use = float("nan")
        sb_a_point, sb_b_point = sb_a_use, sb_b_use
        if np.isfinite(sb_a_use) and np.isfinite(sb_b_use):
            denom = max(np.sqrt(max(sb_a_use * sb_b_use, 0)), np.finfo(float).eps)
            r_point_corr = clamp_unit(r_point_raw / denom)

    # ---- bootstrap ----
    r_boot_raw = np.full(n_boot, np.nan)
    r_boot_corr = np.full(n_boot, np.nan)
    n_kept = np.full(n_boot, np.nan)

    for b in range(n_boot):
        if bootstrap_dim == 1:
            idx_a = rng.integers(0, n_a, size=n_a)
            idx_b = rng.integers(0, n_b, size=n_b)
            A_draw_full = A[idx_a, :]
            B_draw_full = B[idx_b, :]
            mean_a = np.nanmean(A_draw_full, axis=0)
            mean_b = np.nanmean(B_draw_full, axis=0)
            n_obs_a = np.sum(~np.isnan(A_draw_full), axis=0)
            n_obs_b = np.sum(~np.isnan(B_draw_full), axis=0)
        elif bootstrap_dim == 2:
            idx_stim = rng.integers(0, n_items, size=n_items)
            A_draw_full = A[:, idx_stim]
            B_draw_full = B[:, idx_stim]
            mean_a = np.nanmean(A_draw_full, axis=0)
            mean_b = np.nanmean(B_draw_full, axis=0)
            n_obs_a = np.sum(~np.isnan(A_draw_full), axis=0)
            n_obs_b = np.sum(~np.isnan(B_draw_full), axis=0)
        else:
            raise ValueError("bootstrap_dim must be 1 or 2.")

        valid = (n_obs_a >= min_resp) & (n_obs_b >= min_resp)
        k = valid.sum()
        if k < min_items:
            continue

        r = _corr(mean_a[valid], mean_b[valid], corr_type)
        r_boot_raw[b] = r
        n_kept[b] = k

        if correct_atten:
            if reliability_mode == "fixed":
                sb_a, sb_b = sb_fixed_a, sb_fixed_b
            elif reliability_mode == "subset":
                sb_a, sb_b = sb_a_point, sb_b_point
            else:  # per-draw — recompute on the same resample / item subset
                if bootstrap_dim == 1:
                    A_draw = A_draw_full[:, valid]
                    B_draw = B_draw_full[:, valid]
                else:
                    A_draw = A[:, idx_stim[valid]]
                    B_draw = B[:, idx_stim[valid]]
                sb_a = split_half_sb(
                    A_draw, corr_type, int(np.ceil(split_half_repeats / 2)),
                    reliability_split_dim, rng=rng,
                )
                sb_b = split_half_sb(
                    B_draw, corr_type, int(np.ceil(split_half_repeats / 2)),
                    reliability_split_dim, rng=rng,
                )
            if np.isfinite(sb_a) and np.isfinite(sb_b):
                denom = max(np.sqrt(max(sb_a * sb_b, 0)), np.finfo(float).eps)
                r_boot_corr[b] = clamp_unit(r / denom)

    # ---- summarize ----
    r_boot_raw_clean = r_boot_raw[np.isfinite(r_boot_raw)]
    ci_raw = tuple(np.percentile(r_boot_raw_clean, [2.5, 97.5])) if r_boot_raw_clean.size else (float("nan"),) * 2
    median_raw = float(np.median(r_boot_raw_clean)) if r_boot_raw_clean.size else float("nan")

    r_boot_corr_clean = r_boot_corr[np.isfinite(r_boot_corr)]
    if r_boot_corr_clean.size:
        ci_corr = tuple(np.percentile(r_boot_corr_clean, [2.5, 97.5]))
        median_corr = float(np.median(r_boot_corr_clean))
    else:
        ci_corr = (float("nan"), float("nan"))
        median_corr = float("nan")

    if verbose:
        print(
            f"Intergroup {trial_type.upper()} | point r={r_point_raw:.3f} "
            f"(N={int(valid_items_point.sum())} items)"
        )
        print(
            f"Bootstrap RAW (bootDim={bootstrap_dim}): "
            f"95% CI [{ci_raw[0]:.3f}, {ci_raw[1]:.3f}], median={median_raw:.3f}"
        )
        if np.isfinite(r_point_corr):
            print(
                f"Corrected (mode={reliability_mode}, splitDim={reliability_split_dim}): "
                f"point={r_point_corr:.3f} | 95% CI [{ci_corr[0]:.3f}, {ci_corr[1]:.3f}], "
                f"median={median_corr:.3f}"
            )

    return BootstrapResult(
        point_raw=r_point_raw,
        point_corr=r_point_corr,
        point_items_n=int(valid_items_point.sum()),
        ci_raw=ci_raw,
        ci_corr=ci_corr,
        median_boot_raw=median_raw,
        median_boot_corr=median_corr,
        n_kept_items=n_kept[np.isfinite(n_kept)],
        shared_items=shared,
        sb_point_a=sb_a_point,
        sb_point_b=sb_b_point,
        options=dict(
            n_boot=n_boot,
            min_resp=min_resp,
            min_items=min_items,
            use_spearman=use_spearman,
            reliability_mode=reliability_mode,
            split_half_repeats=split_half_repeats,
            reliability_split_dim=reliability_split_dim,
            bootstrap_dim=bootstrap_dim,
            correct_atten=correct_atten,
        ),
        r_boot_raw=r_boot_raw_clean,
        r_boot_corr=r_boot_corr_clean,
    )
