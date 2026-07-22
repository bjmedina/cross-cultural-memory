"""Paired-bootstrap comparison of three intergroup correlations.

Python twin of MATLAB stats/pairedBootstrapCompareCorrelations.m.

Within each bootstrap iteration the resample of any group appearing in two
correlations is SHARED across those correlations (e.g. the same idx_a is
used for both r(A,B) and r(A,C)), preserving the dependence that makes
the test of "is r(A,B) = r(A,C)?" valid.

Two-sided p-values are computed under two definitions:
  - recentered-null (default; recommended): construct a null by recentering
    the bootstrap diff distribution at zero, then compare |observed diff|
    against |null|. Bootstrap analogue of a permutation test under H0:δ=0.
  - straddle-zero (legacy): p = 2*min(P(d>0), P(d<0)). Biased under skew
    at small N. Kept for back-compat with prior pipeline runs.

See ../STATS.md §6-7.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Optional

import numpy as np

from ._utils import _corr, as_rng, intersect_items_three
from .split_half import SplitHalfReliability


@dataclass
class PairedBootstrapResult:
    """Outputs of paired_bootstrap_compare_correlations."""

    ab_vs_ac: float  # recentered-null p
    ab_vs_bc: float
    ac_vs_bc: float
    pmat: np.ndarray  # 3x3 symmetric, bar order [AB, AC, BC]

    straddle: dict = field(default_factory=dict)  # legacy p-values + pmat

    observed: dict = field(default_factory=dict)  # r_AB, r_AC, r_BC
    observed_diffs: dict = field(default_factory=dict)

    diffs: dict = field(default_factory=dict)  # bootstrap diff distributions
    ci: dict = field(default_factory=dict)  # 95% CIs for each diff

    n_boot: int = 0
    n_items: int = 0
    bootstrap_dim: int = 1
    min_resp: int = 2


def _two_sided_straddle(diffs: np.ndarray) -> float:
    """p = 2 * min(P(d>0), P(d<0)). Percentile-style; biased under skew."""
    d = diffs[np.isfinite(diffs)]
    if d.size == 0:
        return float("nan")
    p = 2 * min(float((d > 0).mean()), float((d < 0).mean()))
    return min(p, 1.0)


def _two_sided_recentered(diffs: np.ndarray, observed: float) -> float:
    """p = P(|null| >= |observed|) where null = diffs - mean(diffs)."""
    d = diffs[np.isfinite(diffs)]
    if d.size == 0 or not np.isfinite(observed):
        return float("nan")
    null_dist = d - d.mean()
    p = float((np.abs(null_dist) >= abs(observed)).mean())
    return min(max(p, 1.0 / (d.size + 1)), 1.0)


def paired_bootstrap_compare_correlations(
    outs_a: SplitHalfReliability,
    outs_b: SplitHalfReliability,
    outs_c: SplitHalfReliability,
    trial_type: str = "hit",
    n_boot: int = 5000,
    use_spearman: bool = True,
    bootstrap_dim: int = 1,
    min_resp: int = 2,
    rng: Optional[np.random.Generator] = None,
    verbose: bool = True,
    ceilings: Optional[dict] = None,
) -> PairedBootstrapResult:
    """Paired-bootstrap comparison of r(A,B), r(A,C), r(B,C).

    Parameters mirror MATLAB pairedBootstrapCompareCorrelations.m.

    ceilings: optional dict with keys "AB", "AC", "BC" giving each pair's fixed
    attenuation ceiling sqrt(rho_SB,X * rho_SB,Y) from the FULL-sample
    Spearman--Brown reliabilities. When provided, the observed and every
    bootstrap replicate's correlations are divided by the pair's ceiling before
    the differences are formed, so the test, straddle p-values, and CIs are on
    attenuation-CORRECTED differences (reliabilities treated as fixed
    constants, consistent with reliability_mode='fixed' elsewhere).
    """
    rng = as_rng(rng)
    corr_type = "Spearman" if use_spearman else "Pearson"

    if trial_type.lower() == "hit":
        XA_full, XB_full, XC_full = outs_a.itemwise_hits, outs_b.itemwise_hits, outs_c.itemwise_hits
    elif trial_type.lower() == "fa":
        XA_full, XB_full, XC_full = outs_a.itemwise_fas, outs_b.itemwise_fas, outs_c.itemwise_fas
    else:
        raise ValueError("trial_type must be 'hit' or 'fa'.")

    shared, ia, ib, ic = intersect_items_three(
        list(outs_a.items), list(outs_b.items), list(outs_c.items)
    )
    XA = XA_full[:, ia]
    XB = XB_full[:, ib]
    XC = XC_full[:, ic]

    n_a, n_items = XA.shape
    n_b = XB.shape[0]
    n_c = XC.shape[0]

    if n_items < 5:
        nan3 = float("nan")
        return PairedBootstrapResult(
            ab_vs_ac=nan3, ab_vs_bc=nan3, ac_vs_bc=nan3,
            pmat=np.full((3, 3), np.nan), n_items=n_items, n_boot=n_boot,
            bootstrap_dim=bootstrap_dim, min_resp=min_resp,
        )

    # ---- observed correlations (sample point estimates) ----
    mean_a_full = np.nanmean(XA, axis=0)
    mean_b_full = np.nanmean(XB, axis=0)
    mean_c_full = np.nanmean(XC, axis=0)
    n_obs_a = np.sum(~np.isnan(XA), axis=0)
    n_obs_b = np.sum(~np.isnan(XB), axis=0)
    n_obs_c = np.sum(~np.isnan(XC), axis=0)
    valid_obs = (n_obs_a >= min_resp) & (n_obs_b >= min_resp) & (n_obs_c >= min_resp)

    r_ab_obs = _corr(mean_a_full[valid_obs], mean_b_full[valid_obs], corr_type)
    r_ac_obs = _corr(mean_a_full[valid_obs], mean_c_full[valid_obs], corr_type)
    r_bc_obs = _corr(mean_b_full[valid_obs], mean_c_full[valid_obs], corr_type)

    # ---- bootstrap ----
    r_ab_b = np.full(n_boot, np.nan)
    r_ac_b = np.full(n_boot, np.nan)
    r_bc_b = np.full(n_boot, np.nan)

    for b in range(n_boot):
        if bootstrap_dim == 1:
            idx_a = rng.integers(0, n_a, size=n_a)
            idx_b = rng.integers(0, n_b, size=n_b)
            idx_c = rng.integers(0, n_c, size=n_c)

            m_a = np.nanmean(XA[idx_a, :], axis=0)
            m_b = np.nanmean(XB[idx_b, :], axis=0)
            m_c = np.nanmean(XC[idx_c, :], axis=0)

            n_oa = np.sum(~np.isnan(XA[idx_a, :]), axis=0)
            n_ob = np.sum(~np.isnan(XB[idx_b, :]), axis=0)
            n_oc = np.sum(~np.isnan(XC[idx_c, :]), axis=0)

        elif bootstrap_dim == 2:
            idx_stim = rng.integers(0, n_items, size=n_items)
            m_a = np.nanmean(XA[:, idx_stim], axis=0)
            m_b = np.nanmean(XB[:, idx_stim], axis=0)
            m_c = np.nanmean(XC[:, idx_stim], axis=0)
            n_oa = np.sum(~np.isnan(XA[:, idx_stim]), axis=0)
            n_ob = np.sum(~np.isnan(XB[:, idx_stim]), axis=0)
            n_oc = np.sum(~np.isnan(XC[:, idx_stim]), axis=0)
        else:
            raise ValueError("bootstrap_dim must be 1 or 2.")

        v = (n_oa >= min_resp) & (n_ob >= min_resp) & (n_oc >= min_resp)
        if v.sum() < 5:
            continue

        # Critical: m_a is used for BOTH r(A,B) and r(A,C); idx_a was drawn once.
        r_ab_b[b] = _corr(m_a[v], m_b[v], corr_type)
        r_ac_b[b] = _corr(m_a[v], m_c[v], corr_type)
        r_bc_b[b] = _corr(m_b[v], m_c[v], corr_type)

    # ---- optional attenuation correction (fixed ceilings) ----
    # Divide observed and replicate correlations by each pair's fixed ceiling
    # sqrt(rho_SB,X * rho_SB,Y) so all downstream diffs/p-values/CIs are on
    # corrected values. Ceilings are full-sample constants (fixed mode), so
    # the paired structure of the bootstrap is unaffected.
    if ceilings is not None:
        eps = np.finfo(float).eps
        c_ab = max(float(ceilings["AB"]), eps)
        c_ac = max(float(ceilings["AC"]), eps)
        c_bc = max(float(ceilings["BC"]), eps)
        r_ab_obs, r_ac_obs, r_bc_obs = r_ab_obs / c_ab, r_ac_obs / c_ac, r_bc_obs / c_bc
        r_ab_b, r_ac_b, r_bc_b = r_ab_b / c_ab, r_ac_b / c_ac, r_bc_b / c_bc

    # ---- pairwise differences (paired by construction) ----
    diff_ab_ac = r_ab_b - r_ac_b
    diff_ab_bc = r_ab_b - r_bc_b
    diff_ac_bc = r_ac_b - r_bc_b

    d_ab_ac_obs = r_ab_obs - r_ac_obs
    d_ab_bc_obs = r_ab_obs - r_bc_obs
    d_ac_bc_obs = r_ac_obs - r_bc_obs

    # ---- p-values ----
    p_ab_ac_null = _two_sided_recentered(diff_ab_ac, d_ab_ac_obs)
    p_ab_bc_null = _two_sided_recentered(diff_ab_bc, d_ab_bc_obs)
    p_ac_bc_null = _two_sided_recentered(diff_ac_bc, d_ac_bc_obs)

    p_ab_ac_strad = _two_sided_straddle(diff_ab_ac)
    p_ab_bc_strad = _two_sided_straddle(diff_ab_bc)
    p_ac_bc_strad = _two_sided_straddle(diff_ac_bc)

    pmat = np.zeros((3, 3))
    pmat[0, 1] = pmat[1, 0] = p_ab_ac_null
    pmat[0, 2] = pmat[2, 0] = p_ab_bc_null
    pmat[1, 2] = pmat[2, 1] = p_ac_bc_null

    pmat_strad = np.zeros((3, 3))
    pmat_strad[0, 1] = pmat_strad[1, 0] = p_ab_ac_strad
    pmat_strad[0, 2] = pmat_strad[2, 0] = p_ab_bc_strad
    pmat_strad[1, 2] = pmat_strad[2, 1] = p_ac_bc_strad

    ci_ab_ac = tuple(np.nanpercentile(diff_ab_ac, [2.5, 97.5]))
    ci_ab_bc = tuple(np.nanpercentile(diff_ab_bc, [2.5, 97.5]))
    ci_ac_bc = tuple(np.nanpercentile(diff_ac_bc, [2.5, 97.5]))

    if verbose:
        dim_label = "participant" if bootstrap_dim == 1 else "stimulus"
        scale_label = "attenuation-corrected" if ceilings is not None else "raw"
        print(
            f"\n=== Paired Bootstrap Comparison ({trial_type.upper()}, "
            f"{dim_label}-level, {corr_type}, {scale_label}, "
            f"nBoot={n_boot}, minResp={min_resp}) ==="
        )
        print(f"Observed: r(A,B)={r_ab_obs:.3f}  r(A,C)={r_ac_obs:.3f}  r(B,C)={r_bc_obs:.3f}")
        print("                                                     p (null)  p (straddle)")
        print(
            f"r(A,B) vs r(A,C):  diff={d_ab_ac_obs:+.3f}  "
            f"95%CI=[{ci_ab_ac[0]:+.3f}, {ci_ab_ac[1]:+.3f}]  "
            f"{p_ab_ac_null:8.4f}  {p_ab_ac_strad:8.4f}"
        )
        print(
            f"r(A,B) vs r(B,C):  diff={d_ab_bc_obs:+.3f}  "
            f"95%CI=[{ci_ab_bc[0]:+.3f}, {ci_ab_bc[1]:+.3f}]  "
            f"{p_ab_bc_null:8.4f}  {p_ab_bc_strad:8.4f}"
        )
        print(
            f"r(A,C) vs r(B,C):  diff={d_ac_bc_obs:+.3f}  "
            f"95%CI=[{ci_ac_bc[0]:+.3f}, {ci_ac_bc[1]:+.3f}]  "
            f"{p_ac_bc_null:8.4f}  {p_ac_bc_strad:8.4f}"
        )

    return PairedBootstrapResult(
        ab_vs_ac=p_ab_ac_null,
        ab_vs_bc=p_ab_bc_null,
        ac_vs_bc=p_ac_bc_null,
        pmat=pmat,
        straddle=dict(
            ab_vs_ac=p_ab_ac_strad,
            ab_vs_bc=p_ab_bc_strad,
            ac_vs_bc=p_ac_bc_strad,
            pmat=pmat_strad,
        ),
        observed=dict(r_AB=r_ab_obs, r_AC=r_ac_obs, r_BC=r_bc_obs),
        observed_diffs=dict(
            AB_minus_AC=d_ab_ac_obs,
            AB_minus_BC=d_ab_bc_obs,
            AC_minus_BC=d_ac_bc_obs,
        ),
        diffs=dict(
            AB_minus_AC=diff_ab_ac,
            AB_minus_BC=diff_ab_bc,
            AC_minus_BC=diff_ac_bc,
        ),
        ci=dict(
            AB_minus_AC=ci_ab_ac,
            AB_minus_BC=ci_ab_bc,
            AC_minus_BC=ci_ac_bc,
        ),
        n_boot=n_boot,
        n_items=n_items,
        bootstrap_dim=bootstrap_dim,
        min_resp=min_resp,
    )
