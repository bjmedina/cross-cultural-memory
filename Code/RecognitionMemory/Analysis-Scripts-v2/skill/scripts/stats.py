#!/usr/bin/env python3
"""Reusable stats for the cross-cultural recognition-memory item-level analysis.

Signal-detection, split-half reliability, disattenuation, Fisher-z bootstrap CIs,
and the performance-gap test. All rate-based measures clip to [EPS, 1-EPS] before
any z-transform. Spearman is the default rank correlation for between-group work.
"""
from __future__ import annotations
import numpy as np
from scipy.stats import norm, spearmanr, wilcoxon

EPS = 1e-2


def clip(p):
    return np.clip(p, EPS, 1 - EPS)


def dprime(hit_rate, fa_rate):
    return norm.ppf(clip(hit_rate)) - norm.ppf(clip(fa_rate))


def criterion(hit_rate, fa_rate):
    return -0.5 * (norm.ppf(clip(hit_rate)) + norm.ppf(clip(fa_rate)))


def per_sound(matrix):
    """Column means of a participant x item matrix (per-sound rate vector)."""
    with np.errstate(invalid="ignore"):
        return np.nanmean(matrix, axis=0)


def split_half_reliability(matrix, nsplit=300, min_items=5, rng=None):
    """Spearman-Brown-corrected split-half reliability of the per-sound vector."""
    rng = rng or np.random.default_rng(0)
    n = matrix.shape[0]
    rs = []
    for _ in range(nsplit):
        idx = rng.permutation(n)
        a, b = idx[:n // 2], idx[n // 2:]
        va, vb = per_sound(matrix[a]), per_sound(matrix[b])
        m = np.isfinite(va) & np.isfinite(vb)
        if m.sum() >= min_items:
            rs.append(spearmanr(va[m], vb[m]).correlation)
    r = np.nanmedian(rs)
    return (2 * r) / (1 + r) if np.isfinite(r) else np.nan


def corrected_for_attenuation(r, rel_a, rel_b):
    """Correct an observed correlation for attenuation (Spearman 1904):
    r* = r / sqrt(rel_a * rel_b). Can exceed 1 when a reliability is low/noisy;
    report as-is next to observed r and flag rather than silently capping."""
    return r / np.sqrt(rel_a * rel_b) if rel_a > 0 and rel_b > 0 else np.nan


disattenuate = corrected_for_attenuation  # alias


def _paired(da, db, items_a, items_b):
    ia = {it: i for i, it in enumerate(items_a)}
    ib = {it: i for i, it in enumerate(items_b)}
    sh = [it for it in items_a if it in ib]
    x = np.array([da[ia[it]] for it in sh])
    y = np.array([db[ib[it]] for it in sh])
    m = np.isfinite(x) & np.isfinite(y)
    return x[m], y[m]


def between_group(matrix_a, items_a, matrix_b, items_b, nboot=2000, rng=None):
    """Observed Spearman r, disattenuated r*, and a Fisher-z BOOTSTRAP 95% CI
    (sigma_z estimated from the bootstrap, valid for Spearman)."""
    rng = rng or np.random.default_rng(0)
    x, y = _paired(per_sound(matrix_a), per_sound(matrix_b), items_a, items_b)
    n = len(x)
    r = spearmanr(x, y).correlation
    zs = np.empty(nboot)
    for b in range(nboot):
        idx = rng.integers(0, n, n)
        zs[b] = np.arctanh(np.clip(spearmanr(x[idx], y[idx]).correlation, -0.999, 0.999))
    zsd = np.nanstd(zs)
    lo, hi = np.tanh(np.arctanh(r) - 1.96 * zsd), np.tanh(np.arctanh(r) + 1.96 * zsd)
    rel_a = split_half_reliability(matrix_a, rng=rng)
    rel_b = split_half_reliability(matrix_b, rng=rng)
    return dict(n=n, r=r, ci=(lo, hi), rstar=disattenuate(r, rel_a, rel_b),
                rel_a=rel_a, rel_b=rel_b)


def performance_gap(matrix_a, items_a, matrix_b, items_b, nboot=2000, rng=None):
    """Gap = mean_A - mean_B of the per-sound rates (level offset), with a bootstrap
    CI and a paired Wilcoxon test. Independent of the correlation (pattern)."""
    rng = rng or np.random.default_rng(0)
    x, y = _paired(per_sound(matrix_a), per_sound(matrix_b), items_a, items_b)
    gap = x.mean() - y.mean()
    n = len(x)
    gaps = np.array([(lambda i: (x[i].mean() - y[i].mean()))(rng.integers(0, n, n))
                     for _ in range(nboot)])
    lo, hi = np.percentile(gaps, [2.5, 97.5])
    p = wilcoxon(x - y).pvalue if np.any(x - y != 0) else np.nan
    return dict(gap=gap, ci=(lo, hi), p=p, n=n)


def variance_decomposition(matrix):
    """Fraction of total response variance that is between-participant (row),
    between-sound (column), and residual (participant x item interaction + noise)."""
    mask = ~np.isnan(matrix)
    gm = np.nanmean(matrix)
    row = np.nanmean(matrix, axis=1) - gm
    col = np.nanmean(matrix, axis=0) - gm
    resid = matrix - (gm + row[:, None] + col[None, :])
    v_row = np.nansum(mask * row[:, None] ** 2)
    v_col = np.nansum(mask * col[None, :] ** 2)
    v_res = np.nansum(resid[mask] ** 2)
    tot = v_row + v_col + v_res
    return dict(participant=v_row / tot, sound=v_col / tot, residual=v_res / tot)
