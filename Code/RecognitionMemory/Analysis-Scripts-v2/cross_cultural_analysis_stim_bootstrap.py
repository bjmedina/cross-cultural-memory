"""
Cross-cultural recognition memory analysis — stimulus bootstrap variant (legacy).

NOTE: As of May 2026, the canonical implementation supports both bootstrap
levels via a single argument. Prefer:

    from python import bootstrap_intergroup_correlation_sem
    bootstrap_intergroup_correlation_sem(outs_a, outs_b, bootstrap_dim=2)

or the thin top-level driver:

    python run_cross_cultural_analysis.py

The original stimulus-bootstrap question this script answered ("how much does
the intergroup correlation depend on which sounds happened to be in our
stimulus set?") is now answered by passing bootstrap_dim=2 to the canonical
function. Error bars are typically narrower than the participant bootstrap
but reflect a different source of variance: stimulus sampling, not participant
sampling.

This script remains as a reference for its .mat loading + plotting code.

Bryan Medina -- Mar 2026; deprecation note added May 2026.
"""

import os
import sys
from pathlib import Path

import numpy as np
from scipy.stats import spearmanr
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

# Reuse all data-loading and reliability code from the main script
sys.path.insert(0, str(Path(__file__).parent))
from cross_cultural_analysis import (
    SITES, CONDITIONS, MIN_RESP, N_BOOT, N_SPLITS, MIN_ISI0_DPRIME,
    get_files, build_item_matrices, split_half_reliability,
)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
CI_TYPE = '95ci'   # '95ci' or 'sem'  (95ci is natural for stimulus bootstrap)


# ---------------------------------------------------------------------------
# Stimulus-resampling bootstrap
# ---------------------------------------------------------------------------
def intergroup_correlation_stim_boot(matA, matB, items_a, items_b,
                                     n_boot=N_BOOT, min_resp=MIN_RESP,
                                     rng=None):
    """
    Bootstrap intergroup itemwise Spearman correlation by resampling
    STIMULI with replacement.

    Each draw selects n_items stimuli (with replacement), computes
    group means over all participants for those stimuli, then correlates.

    Returns dict matching the format of intergroup_correlation_bootstrap().
    """
    if rng is None:
        rng = np.random.default_rng()

    # Align to shared items
    shared = sorted(set(items_a) & set(items_b))
    ia = [items_a.index(s) for s in shared]
    ib = [items_b.index(s) for s in shared]
    A = matA[:, ia]   # [nA x n_items]
    B = matB[:, ib]   # [nB x n_items]
    n_items = len(shared)

    # Per-item observation counts (over all participants — fixed, not resampled)
    obs_a = np.sum(~np.isnan(A), axis=0)
    obs_b = np.sum(~np.isnan(B), axis=0)

    # Point estimate (all stimuli passing min_resp)
    valid_all = (obs_a >= min_resp) & (obs_b >= min_resp)
    if valid_all.sum() < 5:
        return {'point': np.nan, 'median_boot': np.nan,
                'ci': [np.nan, np.nan], 'sem': np.nan, 'n_items': 0}

    mean_a = np.nanmean(A, axis=0)
    mean_b = np.nanmean(B, axis=0)
    r_point, _ = spearmanr(mean_a[valid_all], mean_b[valid_all])

    # Bootstrap: resample stimuli
    r_boot = np.full(n_boot, np.nan)
    for b in range(n_boot):
        idx = rng.integers(0, n_items, size=n_items)

        # For resampled stimuli, compute group means and check coverage
        # Note: duplicate stimulus draws are treated as independent columns
        bm_a = np.nanmean(A[:, idx], axis=0)   # [n_items]
        bm_b = np.nanmean(B[:, idx], axis=0)
        n_a  = obs_a[idx]
        n_b  = obs_b[idx]
        v = (n_a >= min_resp) & (n_b >= min_resp) & np.isfinite(bm_a) & np.isfinite(bm_b)

        if v.sum() < 5:
            continue
        r, _ = spearmanr(bm_a[v], bm_b[v])
        if np.isfinite(r):
            r_boot[b] = r

    r_boot = r_boot[np.isfinite(r_boot)]
    ci  = np.percentile(r_boot, [2.5, 97.5]) if len(r_boot) > 0 else [np.nan, np.nan]
    sem = np.std(r_boot, ddof=1)             if len(r_boot) > 1 else np.nan

    # Headline = sample point r; bootstrap median as secondary sanity check.
    median_boot = float(np.median(r_boot)) if len(r_boot) > 0 else np.nan

    return {
        'point':       r_point,
        'median_boot': median_boot,
        'ci':          list(ci),
        'sem':         sem,
        'n_items':     int(valid_all.sum()),
        'r_boot':      r_boot,
    }


# ---------------------------------------------------------------------------
# Paired bootstrap (stimulus resampling)
# ---------------------------------------------------------------------------
def paired_bootstrap_compare_stim(matA, matB, matC,
                                   items_a, items_b, items_c,
                                   n_boot=N_BOOT, min_resp=MIN_RESP, rng=None):
    """
    Paired stimulus bootstrap to compare r(A,B), r(A,C), r(B,C).

    All three correlations use the same resampled stimulus set each draw,
    preserving dependence for the paired comparison.
    """
    if rng is None:
        rng = np.random.default_rng()

    shared = sorted(set(items_a) & set(items_b) & set(items_c))
    ia = [items_a.index(s) for s in shared]
    ib = [items_b.index(s) for s in shared]
    ic_ = [items_c.index(s) for s in shared]

    XA = matA[:, ia]
    XB = matB[:, ib]
    XC = matC[:, ic_]
    n_items = len(shared)

    obs_a = np.sum(~np.isnan(XA), axis=0)
    obs_b = np.sum(~np.isnan(XB), axis=0)
    obs_c = np.sum(~np.isnan(XC), axis=0)

    if n_items < 5:
        return {'pmat': np.full((3, 3), np.nan),
                'AB_vs_AC': np.nan, 'AB_vs_BC': np.nan, 'AC_vs_BC': np.nan}

    r_AB = np.full(n_boot, np.nan)
    r_AC = np.full(n_boot, np.nan)
    r_BC = np.full(n_boot, np.nan)

    for b in range(n_boot):
        idx = rng.integers(0, n_items, size=n_items)  # shared stimulus resample

        mA = np.nanmean(XA[:, idx], axis=0)
        mB = np.nanmean(XB[:, idx], axis=0)
        mC = np.nanmean(XC[:, idx], axis=0)

        nOA = obs_a[idx]
        nOB = obs_b[idx]
        nOC = obs_c[idx]

        v = ((nOA >= min_resp) & (nOB >= min_resp) & (nOC >= min_resp)
             & np.isfinite(mA) & np.isfinite(mB) & np.isfinite(mC))
        if v.sum() < 5:
            continue

        r_AB[b], _ = spearmanr(mA[v], mB[v])
        r_AC[b], _ = spearmanr(mA[v], mC[v])
        r_BC[b], _ = spearmanr(mB[v], mC[v])

    d_AB_AC = r_AB - r_AC
    d_AB_BC = r_AB - r_BC
    d_AC_BC = r_AC - r_BC

    def p_2sided(d):
        d = d[np.isfinite(d)]
        if len(d) == 0:
            return np.nan
        return min(2 * min(np.mean(d > 0), np.mean(d < 0)), 1.0)

    p_AB_AC = p_2sided(d_AB_AC)
    p_AB_BC = p_2sided(d_AB_BC)
    p_AC_BC = p_2sided(d_AC_BC)

    pmat = np.zeros((3, 3))
    pmat[0, 1] = pmat[1, 0] = p_AB_AC
    pmat[0, 2] = pmat[2, 0] = p_AB_BC
    pmat[1, 2] = pmat[2, 1] = p_AC_BC

    return {
        'AB_vs_AC': p_AB_AC, 'AB_vs_BC': p_AB_BC, 'AC_vs_BC': p_AC_BC,
        'pmat': pmat,
        'r_AB_boot': r_AB, 'r_AC_boot': r_AC, 'r_BC_boot': r_BC,
    }


# ---------------------------------------------------------------------------
# Plotting
# ---------------------------------------------------------------------------
def plot_bars(ab, ac, bc, pmat, condition, trial_type, out_dir, ci_type=CI_TYPE):
    """Bar chart with stimulus-bootstrap error bars."""
    labels = ['US-San Borja', "US-Tsimane'", "San Borja-Tsimane'"]
    vals = [ab['point'], ac['point'], bc['point']]

    if ci_type == 'sem':
        e = [max(0.0, x['sem']) for x in (ab, ac, bc)]
        err_neg, err_pos = e, e
        err_label = '±1 SEM (stim bootstrap)'
    else:
        ci_lo = [ab['ci'][0], ac['ci'][0], bc['ci'][0]]
        ci_hi = [ab['ci'][1], ac['ci'][1], bc['ci'][1]]
        err_neg = [max(0.0, v - lo) for v, lo in zip(vals, ci_lo)]
        err_pos = [max(0.0, hi - v) for v, hi in zip(vals, ci_hi)]
        err_label = '95% CI (stim bootstrap)'

    fig, ax = plt.subplots(figsize=(7, 5))
    x = np.arange(3)
    ax.bar(x, vals, width=0.5, color=['#6699cc', '#cc6666', '#66aa66'],
           edgecolor='none', alpha=0.85)
    ax.errorbar(x, vals, yerr=[err_neg, err_pos], fmt='none',
                ecolor='black', capsize=6, linewidth=1.3)

    for i in range(3):
        ax.text(i, vals[i] + err_pos[i] + 0.015, f'{vals[i]:.2f}',
                ha='center', va='bottom', fontweight='bold', fontsize=11)

    if pmat is not None:
        y_max = max(v + ep for v, ep in zip(vals, err_pos))
        for k, (i, j) in enumerate([(0, 1), (0, 2), (1, 2)]):
            y = y_max + 0.06 + k * 0.04
            p = pmat[i, j]
            p_txt = 'p < 0.001' if p < 0.001 else f'p = {p:.3f}'
            ax.plot([i, i, j, j], [y - 0.01, y, y, y - 0.01], 'k-', lw=0.8)
            ax.text((i + j) / 2, y + 0.005, p_txt,
                    ha='center', va='bottom', fontsize=9)

    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=11)
    ax.set_ylabel('Itemwise Spearman correlation', fontsize=12)
    ax.set_title(f'Intergroup {trial_type.upper()} correlations — {condition}\n'
                 f'({err_label})', fontsize=12)
    ax.set_ylim(bottom=0)
    ax.grid(axis='y', alpha=0.3)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)

    fig.tight_layout()
    fname = os.path.join(out_dir, f'intergroup_{trial_type}_{condition}_stimboot.png')
    fig.savefig(fname, dpi=150)
    plt.close(fig)
    print(f'  Saved: {fname}')


# ---------------------------------------------------------------------------
# Pipeline
# ---------------------------------------------------------------------------
def run_pipeline(data_dir, condition, sites, min_resp=MIN_RESP):
    site_names = list(sites.keys())
    assert len(site_names) == 3

    rng = np.random.default_rng(42)

    files = {}
    for name, codes in sites.items():
        files[name] = get_files(data_dir, codes, condition)
        print(f'  {name}: {len(files[name])} participants')

    matrices, items = {}, {}
    for name in site_names:
        if not files[name]:
            print(f'  WARNING: no files for {name}, skipping')
            return None
        h, f, it = build_item_matrices(files[name])
        matrices[name] = {'hits': h, 'fas': f}
        items[name] = it

    print('\n  Split-half reliability (participant split, Spearman):')
    for name in site_names:
        for tt, label in [('hits', 'Hits'), ('fas', 'FAs')]:
            r, std, sb = split_half_reliability(matrices[name][tt], N_SPLITS, rng)
            print(f'    {name} {label}: r = {r:.3f} ± {std:.3f}  (SB = {sb:.3f})')

    out_dir = os.path.join(data_dir, 'figures', condition)
    os.makedirs(out_dir, exist_ok=True)

    A, B, C = site_names
    results = {}
    for trial_type, mat_key in [('hit', 'hits'), ('fa', 'fas')]:
        print(f'\n  Intergroup {trial_type.upper()} correlations (stimulus bootstrap):')

        ab = intergroup_correlation_stim_boot(
            matrices[A][mat_key], matrices[B][mat_key],
            items[A], items[B], n_boot=N_BOOT, min_resp=min_resp, rng=rng)
        ac = intergroup_correlation_stim_boot(
            matrices[A][mat_key], matrices[C][mat_key],
            items[A], items[C], n_boot=N_BOOT, min_resp=min_resp, rng=rng)
        bc = intergroup_correlation_stim_boot(
            matrices[B][mat_key], matrices[C][mat_key],
            items[B], items[C], n_boot=N_BOOT, min_resp=min_resp, rng=rng)

        for tag, res in [(f'{A}-{B}', ab), (f'{A}-{C}', ac), (f'{B}-{C}', bc)]:
            print(f'    {tag}: r = {res["point"]:.3f}  '
                  f'95% CI [{res["ci"][0]:.3f}, {res["ci"][1]:.3f}]  '
                  f'SEM = {res["sem"]:.3f}  ({res["n_items"]} items)')

        pvals = paired_bootstrap_compare_stim(
            matrices[A][mat_key], matrices[B][mat_key], matrices[C][mat_key],
            items[A], items[B], items[C],
            n_boot=N_BOOT, min_resp=min_resp, rng=rng)

        print(f'    p-values:  {A}-{B} vs {A}-{C}: {pvals["AB_vs_AC"]:.4f}  |  '
              f'{A}-{B} vs {B}-{C}: {pvals["AB_vs_BC"]:.4f}  |  '
              f'{A}-{C} vs {B}-{C}: {pvals["AC_vs_BC"]:.4f}')

        plot_bars(ab, ac, bc, pvals['pmat'], condition, trial_type, out_dir)
        results[trial_type] = {'ab': ab, 'ac': ac, 'bc': bc, 'pvals': pvals}

    return results


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == '__main__':
    script_dir = Path(__file__).resolve().parent
    data_dir = str(script_dir / '..' / '..' / '..' / 'Data' / 'RecognitionMemory' / 'Results')
    data_dir = str(Path(data_dir).resolve())

    print(f'Data directory: {data_dir}')
    print('Bootstrap method: STIMULUS resampling\n')

    for cond in CONDITIONS:
        print(f'\n{"=" * 60}')
        print(f'Condition: {cond}')
        print(f'{"=" * 60}')
        run_pipeline(data_dir, cond, SITES, min_resp=MIN_RESP)

    print('\nDone.')
