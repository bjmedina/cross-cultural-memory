"""Confidence-interval methods for bootstrap correlation distributions.

Three CI methods are provided. All take a bootstrap distribution of
correlations (`r_boot`) and the sample point estimate (`r_hat`), and return
(lo, hi) at level 1-alpha. See ../STATS.md §4 for the formulas and when each
is appropriate.

  - ci_percentile : the [alpha/2, 1-alpha/2] quantiles of r_boot. Simple;
    biased under bootstrap skew.
  - ci_fisher_z   : normal-approximation CI on the Fisher-z scale, centered
    on atanh(r_hat) with SD from the bootstrap z-space distribution, then
    back-transformed via tanh.
  - ci_bca        : Efron's bias-corrected and accelerated CI. Needs
    jackknife leave-one-out correlations for the acceleration term.

Use the wrapper `all_cis(r_hat, r_boot, jackknife_vals, alpha)` to get all
three at once.
"""

from __future__ import annotations

from typing import Optional

import numpy as np
from scipy.stats import norm


def ci_percentile(
    r_boot: np.ndarray, alpha: float = 0.05
) -> tuple[float, float]:
    """Percentile CI: [P(alpha/2), P(1-alpha/2)] of the bootstrap distribution."""
    r_boot = np.asarray(r_boot, dtype=float)
    r_boot = r_boot[np.isfinite(r_boot)]
    if r_boot.size == 0:
        return (float("nan"), float("nan"))
    lo, hi = np.percentile(r_boot, [100 * alpha / 2, 100 * (1 - alpha / 2)])
    return (float(lo), float(hi))


def ci_fisher_z(
    r_hat: float, r_boot: np.ndarray, alpha: float = 0.05
) -> tuple[float, float]:
    """Normal-approximation CI on the Fisher-z scale, back-transformed.

    z_hat = atanh(r_hat); sigma_z = SD(atanh(r_boot));
    CI_z = [z_hat - z_a * sigma_z, z_hat + z_a * sigma_z];
    CI_r = tanh(CI_z).

    Bootstrap r values exactly equal to +/-1 are clipped to +/-1+/-eps before
    atanh so that infinities don't contaminate the SD.
    """
    if not np.isfinite(r_hat):
        return (float("nan"), float("nan"))
    r_boot = np.asarray(r_boot, dtype=float)
    r_boot = r_boot[np.isfinite(r_boot)]
    if r_boot.size < 2:
        return (float("nan"), float("nan"))
    eps = 1e-6
    z_boot = np.arctanh(np.clip(r_boot, -1 + eps, 1 - eps))
    sigma_z = float(np.std(z_boot, ddof=1))
    z_hat = float(np.arctanh(np.clip(r_hat, -1 + eps, 1 - eps)))
    z_crit = float(norm.ppf(1 - alpha / 2))
    lo = float(np.tanh(z_hat - z_crit * sigma_z))
    hi = float(np.tanh(z_hat + z_crit * sigma_z))
    return (lo, hi)


def ci_bca(
    r_hat: float,
    r_boot: np.ndarray,
    jackknife_vals: np.ndarray,
    alpha: float = 0.05,
) -> tuple[float, float]:
    """Bias-corrected and accelerated (BCa) CI.

    Parameters
    ----------
    r_hat : sample point estimate.
    r_boot : bootstrap distribution of correlations.
    jackknife_vals : leave-one-out correlations at the same resampling level
        as r_boot (participants for participant bootstrap, stimuli for
        stimulus bootstrap). Used only for the acceleration term.
    alpha : 1 - confidence level (default 0.05 -> 95% CI).

    Notes
    -----
    If z0 = a = 0 the result equals the percentile CI. If jackknife_vals is
    empty or constant, acceleration is set to 0 and BCa reduces to a
    bias-corrected percentile interval (BC, no A).
    """
    if not np.isfinite(r_hat):
        return (float("nan"), float("nan"))
    r_boot = np.asarray(r_boot, dtype=float)
    r_boot = r_boot[np.isfinite(r_boot)]
    if r_boot.size < 2:
        return (float("nan"), float("nan"))

    # Bias correction z0
    frac_below = float((r_boot < r_hat).mean())
    # Guard against 0 / 1 which give +/- inf
    frac_below = min(max(frac_below, 1.0 / (2 * r_boot.size)), 1.0 - 1.0 / (2 * r_boot.size))
    z0 = float(norm.ppf(frac_below))

    # Acceleration a from jackknife
    jk = np.asarray(jackknife_vals, dtype=float)
    jk = jk[np.isfinite(jk)]
    if jk.size < 3:
        a = 0.0
    else:
        jk_mean = jk.mean()
        diff = jk_mean - jk
        num = (diff ** 3).sum()
        den = 6.0 * ((diff ** 2).sum()) ** 1.5
        a = float(num / den) if den > 0 else 0.0

    # Adjusted quantiles
    z_lo = norm.ppf(alpha / 2)
    z_hi = norm.ppf(1 - alpha / 2)
    alpha1 = norm.cdf(z0 + (z0 + z_lo) / (1 - a * (z0 + z_lo)))
    alpha2 = norm.cdf(z0 + (z0 + z_hi) / (1 - a * (z0 + z_hi)))

    # Clamp into (0, 1) so percentile() doesn't error
    alpha1 = min(max(alpha1, 1e-6), 1 - 1e-6)
    alpha2 = min(max(alpha2, 1e-6), 1 - 1e-6)

    lo, hi = np.percentile(r_boot, [100 * alpha1, 100 * alpha2])
    return (float(lo), float(hi))


def all_cis(
    r_hat: float,
    r_boot: np.ndarray,
    jackknife_vals: Optional[np.ndarray] = None,
    alpha: float = 0.05,
) -> dict:
    """Compute percentile, Fisher-z, and BCa CIs from the same bootstrap.

    Returns a dict with keys 'percentile', 'fisher_z', 'bca'; each is a
    (lo, hi) tuple. If jackknife_vals is None or too small, BCa falls back
    to bias-corrected percentile (acceleration set to 0).
    """
    return {
        "percentile": ci_percentile(r_boot, alpha=alpha),
        "fisher_z": ci_fisher_z(r_hat, r_boot, alpha=alpha),
        "bca": ci_bca(r_hat, r_boot, jackknife_vals if jackknife_vals is not None else np.array([]), alpha=alpha),
    }
