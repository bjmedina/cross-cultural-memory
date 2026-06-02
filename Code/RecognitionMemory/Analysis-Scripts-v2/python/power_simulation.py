"""Monte Carlo calibration of the paired-bootstrap test under known truth.

Python twin of MATLAB stats/powerSimulationPairedBootstrap.m.

Generates synthetic three-group recognition memory data with a specified
true intergroup correlation structure, runs the paired-bootstrap test on
each replicate, and reports empirical type-I error / power and CI coverage
for the three pair comparisons.

See ../STATS.md §8.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional, Sequence

import numpy as np

from ._utils import as_rng
from .paired_bootstrap import paired_bootstrap_compare_correlations
from .split_half import SplitHalfReliability, estimate_split_half_flexible


@dataclass
class PowerSimulationResult:
    reject_null: np.ndarray  # shape (3,)  empirical rejection at recentered-null p
    reject_straddle: np.ndarray  # shape (3,)
    coverage: np.ndarray  # shape (3,)  fraction of CIs covering true diff
    mean_obs_r: np.ndarray  # shape (3,)
    mean_obs_diff: np.ndarray  # shape (3,)
    true_diff: np.ndarray  # shape (3,)
    p_null: np.ndarray
    p_straddle: np.ndarray
    obs_r: np.ndarray
    obs_diff: np.ndarray
    opts: dict = field(default_factory=dict)


def _within_group_sb(
    X: np.ndarray,
    n_rep: int,
    rng: np.random.Generator,
) -> float:
    """Quick Spearman-Brown reliability for the simulated group matrix."""
    point_r, _, _ = estimate_split_half_flexible(
        X, n_splits=n_rep, split_dim=1, corr_type="Spearman", rng=rng
    )
    if not np.isfinite(point_r):
        return float("nan")
    return float((2 * point_r) / (1 + point_r))


def power_simulation_paired_bootstrap(
    n_reps: int = 200,
    n_a: int = 25,
    n_b: int = 25,
    n_c: int = 25,
    n_items: int = 60,
    rho: Sequence[float] = (0.4, 0.4, 0.4),  # (AB, AC, BC)
    rel: Sequence[float] = (0.7, 0.7, 0.7),  # target within-group reliabilities
    base_rate: float = 0.7,
    item_spread: float = 0.15,
    alpha: float = 0.05,
    n_boot: int = 1000,
    use_spearman: bool = True,
    bootstrap_dim: int = 1,
    min_resp: int = 2,
    verbose: bool = False,
    seed: Optional[int] = None,
    progress_every: int = 25,
) -> PowerSimulationResult:
    """Monte Carlo evaluation of the paired-bootstrap test.

    Returns a PowerSimulationResult; .reject_null is the canonical
    headline (empirical rejection at the recentered-null p; should
    approximate alpha under H0).
    """
    rng = np.random.default_rng(seed)

    R = np.array([
        [1.0, rho[0], rho[1]],
        [rho[0], 1.0, rho[2]],
        [rho[1], rho[2], 1.0],
    ])
    # Sanity check PSD
    eigvals = np.linalg.eigvalsh(R)
    if eigvals.min() < -1e-8:
        raise ValueError(f"rho={tuple(rho)} does not yield a PSD covariance.")

    true_diff = np.array([rho[0] - rho[1], rho[0] - rho[2], rho[1] - rho[2]])

    # participant-level noise std to hit target reliability
    sig_t = item_spread
    n_group = np.array([n_a, n_b, n_c])
    sig_e = np.zeros(3)
    for g in range(3):
        r = rel[g]
        if r >= 1 or r <= 0:
            sig_e[g] = 0.0
        else:
            sig_e[g] = sig_t * np.sqrt(n_group[g] * (1 - r) / r)

    p_null = np.full((n_reps, 3), np.nan)
    p_straddle = np.full((n_reps, 3), np.nan)
    obs_r = np.full((n_reps, 3), np.nan)
    obs_diff = np.full((n_reps, 3), np.nan)
    ci_cover = np.zeros((n_reps, 3), dtype=bool)

    items = np.array([f"item{k:03d}" for k in range(n_items)], dtype=object)

    for rep in range(n_reps):
        Z = rng.multivariate_normal(mean=np.zeros(3), cov=R, size=n_items)
        item_rates = np.clip(base_rate + sig_t * Z, 0.02, 0.98)  # [n_items, 3]

        outs = []
        for g in range(3):
            n = n_group[g]
            E = sig_e[g] * rng.standard_normal((n, n_items))
            P = np.clip(item_rates[:, g][np.newaxis, :] + E, 0.01, 0.99)
            X = (rng.random((n, n_items)) < P).astype(float)
            sb = _within_group_sb(X, 20, rng)
            outs.append(
                SplitHalfReliability(
                    r_hit=float("nan"), r_fa=float("nan"),
                    sb_hit=sb, sb_fa=float("nan"),
                    itemwise_hits=X, itemwise_fas=np.full_like(X, np.nan),
                    items=items, n_subjects=n, split_dim=1,
                )
            )

        res = paired_bootstrap_compare_correlations(
            outs[0], outs[1], outs[2], trial_type="hit",
            n_boot=n_boot, use_spearman=use_spearman,
            bootstrap_dim=bootstrap_dim, min_resp=min_resp,
            rng=rng, verbose=verbose,
        )

        p_null[rep] = [res.ab_vs_ac, res.ab_vs_bc, res.ac_vs_bc]
        p_straddle[rep] = [
            res.straddle["ab_vs_ac"],
            res.straddle["ab_vs_bc"],
            res.straddle["ac_vs_bc"],
        ]
        obs_r[rep] = [res.observed["r_AB"], res.observed["r_AC"], res.observed["r_BC"]]
        obs_diff[rep] = [
            res.observed_diffs["AB_minus_AC"],
            res.observed_diffs["AB_minus_BC"],
            res.observed_diffs["AC_minus_BC"],
        ]
        ci_cover[rep, 0] = res.ci["AB_minus_AC"][0] <= true_diff[0] <= res.ci["AB_minus_AC"][1]
        ci_cover[rep, 1] = res.ci["AB_minus_BC"][0] <= true_diff[1] <= res.ci["AB_minus_BC"][1]
        ci_cover[rep, 2] = res.ci["AC_minus_BC"][0] <= true_diff[2] <= res.ci["AC_minus_BC"][1]

        if progress_every and (rep + 1) % progress_every == 0:
            print(f"  rep {rep + 1}/{n_reps}")

    result = PowerSimulationResult(
        reject_null=np.nanmean(p_null <= alpha, axis=0),
        reject_straddle=np.nanmean(p_straddle <= alpha, axis=0),
        coverage=ci_cover.mean(axis=0),
        mean_obs_r=np.nanmean(obs_r, axis=0),
        mean_obs_diff=np.nanmean(obs_diff, axis=0),
        true_diff=true_diff,
        p_null=p_null,
        p_straddle=p_straddle,
        obs_r=obs_r,
        obs_diff=obs_diff,
        opts=dict(
            n_reps=n_reps, n_a=n_a, n_b=n_b, n_c=n_c, n_items=n_items,
            rho=tuple(rho), rel=tuple(rel), base_rate=base_rate,
            item_spread=item_spread, alpha=alpha, n_boot=n_boot,
            use_spearman=use_spearman, bootstrap_dim=bootstrap_dim,
            min_resp=min_resp, seed=seed,
        ),
    )

    pair_labels = ["AB vs AC", "AB vs BC", "AC vs BC"]
    print(f"\n=== power_simulation_paired_bootstrap ({n_reps} reps) ===")
    print(
        f"N per group: A={n_a} B={n_b} C={n_c}   nItems={n_items}   "
        f"alpha={alpha}   nBoot={n_boot}"
    )
    print(
        f"True rho: AB={rho[0]:.2f} AC={rho[1]:.2f} BC={rho[2]:.2f}   "
        f"target rel: A={rel[0]:.2f} B={rel[1]:.2f} C={rel[2]:.2f}"
    )
    print(
        f"{'Pair':<12} {'true_diff':>12} {'mean_diff':>12} "
        f"{'reject_null':>14} {'reject_strad':>14} {'CI_cover':>12}"
    )
    for k in range(3):
        print(
            f"{pair_labels[k]:<12} {true_diff[k]:>12.3f} "
            f"{result.mean_obs_diff[k]:>12.3f} {result.reject_null[k]:>14.3f} "
            f"{result.reject_straddle[k]:>14.3f} {result.coverage[k]:>12.3f}"
        )

    return result
