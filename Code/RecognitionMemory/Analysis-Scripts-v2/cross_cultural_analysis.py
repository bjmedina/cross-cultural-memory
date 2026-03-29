"""
Cross-cultural recognition memory analysis.

Replicates the MATLAB Analysis-Scripts-v2 pipeline in Python:
  1. Load .mat files, filter by site codes and condition
  2. Build participant × stimulus matrices of hit rates and FA rates
  3. Compute within-group split-half reliability (participant split, Spearman)
  4. Bootstrap intergroup itemwise correlations with attenuation correction
  5. Paired bootstrap comparison of three group-pair correlations
  6. Bar chart with 95% CIs and p-value brackets

Usage:
    python cross_cultural_analysis.py

Bryan Medina -- Mar 2026
"""

import os
import re
import warnings
from pathlib import Path

import numpy as np
import scipy.io as sio
from scipy.stats import spearmanr, norm
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
SITES = {
    'US':        ['PRO', 'BOS', 'CAM'],
    'San Borja': ['SBO', 'SNB', 'SBJ'],
    "Tsimane'":  ['NVM', 'MAJ', 'MAN', 'NUM', 'NUV', 'CVR'],
}

CONDITIONS = ['Globalized-Music', 'Industrial-Nature']

MIN_ISI0_DPRIME = 2.0   # d' at ISI=0 threshold for participant inclusion
MIN_RESP        = 2      # minimum non-NaN observations per stimulus per group
N_BOOT          = 5000
N_SPLITS        = 10000
EPSILON         = 1e-5   # rate clipping to avoid infinite z-scores
CI_TYPE         = 'sem'  # 'sem' (±1 SEM) or '95ci' (percentile 95% CI)


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------
def load_mat(path):
    """Load a single .mat file, return a flat dict of arrays."""
    raw = sio.loadmat(path, squeeze_me=True)
    return raw


def extract_site_code(filename):
    """Pull the 3-letter site code from a filename like '1003-RMD-BOS_...'."""
    m = re.search(r'-([A-Z]{3})_', filename)
    return m.group(1) if m else None


def strip_path(stimulus_str):
    """Strip directory prefix from stimulus path, keep just the filename."""
    s = str(stimulus_str).strip()
    return s.rsplit('/', 1)[-1] if '/' in s else s


def clip_rate(p, eps=EPSILON):
    return np.clip(p, eps, 1 - eps)


def passes_dprime_filter(mat, threshold=MIN_ISI0_DPRIME):
    """Check if participant's d' at ISI=0 (repeatPosition==1) >= threshold."""
    sp = np.array([strip_path(s) for s in mat['stimulusPresented'].flat])
    rp = mat['repeatPosition'].flatten().astype(float)
    ic = mat['isResponseCorrect'].flatten().astype(float)

    # Build will-repeat-first mask (first occurrence of stimuli that repeat)
    unique_stims = np.unique(sp)
    will_repeat_first = np.zeros(len(sp), dtype=bool)
    for stim in unique_stims:
        idxs = np.where(sp == stim)[0]
        if len(idxs) > 1:
            will_repeat_first[idxs[0]] = True

    # FA rate from will-repeat-first trials
    if will_repeat_first.sum() == 0:
        return False
    fa_rate = clip_rate(1 - ic[will_repeat_first].mean())

    # Hit rate at ISI=0 (repeatPosition == 1)
    isi0_mask = rp == 1
    if isi0_mask.sum() == 0:
        return False
    hit_rate = clip_rate(ic[isi0_mask].mean())

    dprime = norm.ppf(hit_rate) - norm.ppf(fa_rate)
    return dprime >= threshold


def get_files(data_dir, site_codes, condition):
    """Return list of .mat file paths matching site codes and condition."""
    files = []
    for f in sorted(os.listdir(data_dir)):
        if not f.endswith('.mat'):
            continue
        if '-original.' in f or '_Multi-p' in f:
            continue
        if condition.lower() not in f.lower():
            continue
        code = extract_site_code(f)
        if code not in site_codes:
            continue

        path = os.path.join(data_dir, f)
        mat = load_mat(path)
        if passes_dprime_filter(mat):
            files.append(path)

    return files


# ---------------------------------------------------------------------------
# Participant × stimulus matrices
# ---------------------------------------------------------------------------
def build_item_matrices(files):
    """
    Build [n_participants × n_stimuli] matrices for hits and false alarms.

    For each participant file:
      - hit trials: repeatPosition > 1 (nonzero-ISI repeats)
        value = isResponseCorrect (1 = hit, 0 = miss)
      - FA trials: repeatPosition is NaN (non-repeat presentations)
        value = 1 - isResponseCorrect (1 = false alarm, 0 = correct rejection)

    Returns:
        hits: np.ndarray [n_sub, n_items], NaN where participant didn't see item
        fas:  np.ndarray [n_sub, n_items], NaN where participant didn't see item
        items: list of stimulus names (sorted)
    """
    # First pass: collect all stimuli that appear as nonzero-ISI repeats
    all_items = set()
    for path in files:
        mat = load_mat(path)
        sp = np.array([strip_path(s) for s in mat['stimulusPresented'].flat])
        rp = mat['repeatPosition'].flatten().astype(float)
        mask = (~np.isnan(rp)) & (rp > 1)
        all_items.update(sp[mask])

    items = sorted(all_items)
    item_to_idx = {s: i for i, s in enumerate(items)}
    n_sub = len(files)
    n_items = len(items)

    hits = np.full((n_sub, n_items), np.nan)
    fas  = np.full((n_sub, n_items), np.nan)

    for i, path in enumerate(files):
        mat = load_mat(path)
        sp = np.array([strip_path(s) for s in mat['stimulusPresented'].flat])
        rp = mat['repeatPosition'].flatten().astype(float)
        ic = mat['isResponseCorrect'].flatten().astype(float)

        for t in range(len(sp)):
            idx = item_to_idx.get(sp[t])
            if idx is None:
                continue

            if not np.isnan(rp[t]) and rp[t] > 1:
                # Nonzero-ISI repeat → hit
                hits[i, idx] = ic[t]
            elif np.isnan(rp[t]):
                # Non-repeat → FA
                fas[i, idx] = 1 - ic[t]

    return hits, fas, items


# ---------------------------------------------------------------------------
# Split-half reliability (participant split, Spearman)
# ---------------------------------------------------------------------------
def split_half_reliability(matrix, n_splits=N_SPLITS, rng=None):
    """
    Split participants into two halves, compute stimulus-level means for
    each half, and correlate (Spearman). Repeat n_splits times.

    Returns (mean_r, std_r, spearman_brown_corrected).
    """
    if rng is None:
        rng = np.random.default_rng()

    n_sub = matrix.shape[0]
    if n_sub < 4:
        return np.nan, np.nan, np.nan

    rs = np.full(n_splits, np.nan)
    for s in range(n_splits):
        perm = rng.permutation(n_sub)
        half1 = matrix[perm[:n_sub // 2], :]
        half2 = matrix[perm[n_sub // 2:], :]

        with warnings.catch_warnings():
            warnings.simplefilter('ignore')
            m1 = np.nanmean(half1, axis=0)
            m2 = np.nanmean(half2, axis=0)

        valid = ~np.isnan(m1) & ~np.isnan(m2)
        if valid.sum() < 3:
            continue

        r, _ = spearmanr(m1[valid], m2[valid])
        if np.isfinite(r):
            rs[s] = r

    mean_r = np.nanmean(rs)
    std_r  = np.nanstd(rs)
    sb = (2 * mean_r) / (1 + mean_r) if np.isfinite(mean_r) else np.nan
    return mean_r, std_r, sb


# ---------------------------------------------------------------------------
# Intergroup itemwise correlation (bootstrap)
# ---------------------------------------------------------------------------
def intergroup_correlation_bootstrap(matA, matB, items_a, items_b,
                                     n_boot=N_BOOT, min_resp=MIN_RESP,
                                     rng=None):
    """
    Bootstrap intergroup itemwise Spearman correlation by resampling
    participants with replacement.

    Returns dict with point estimate, bootstrap mean, 95% CI, etc.
    """
    if rng is None:
        rng = np.random.default_rng()

    # Align to shared items
    shared = sorted(set(items_a) & set(items_b))
    ia = [items_a.index(s) for s in shared]
    ib = [items_b.index(s) for s in shared]
    A = matA[:, ia]
    B = matB[:, ib]

    nA, n_items = A.shape
    nB = B.shape[0]

    # Point estimate
    mean_a = np.nanmean(A, axis=0)
    mean_b = np.nanmean(B, axis=0)
    obs_a = np.sum(~np.isnan(A), axis=0)
    obs_b = np.sum(~np.isnan(B), axis=0)
    valid = (obs_a >= min_resp) & (obs_b >= min_resp)

    if valid.sum() < 5:
        return {'point': np.nan, 'mean_boot': np.nan,
                'ci': [np.nan, np.nan], 'n_items': 0}

    r_point, _ = spearmanr(mean_a[valid], mean_b[valid])

    # Bootstrap
    r_boot = np.full(n_boot, np.nan)
    for b in range(n_boot):
        idx_a = rng.integers(0, nA, size=nA)
        idx_b = rng.integers(0, nB, size=nB)

        bm_a = np.nanmean(A[idx_a, :], axis=0)
        bm_b = np.nanmean(B[idx_b, :], axis=0)
        n_a = np.sum(~np.isnan(A[idx_a, :]), axis=0)
        n_b = np.sum(~np.isnan(B[idx_b, :]), axis=0)
        v = (n_a >= min_resp) & (n_b >= min_resp)

        if v.sum() < 5:
            continue
        r, _ = spearmanr(bm_a[v], bm_b[v])
        if np.isfinite(r):
            r_boot[b] = r

    r_boot = r_boot[np.isfinite(r_boot)]
    ci = np.percentile(r_boot, [2.5, 97.5]) if len(r_boot) > 0 else [np.nan, np.nan]

    # Fisher-z mean
    z = np.arctanh(np.clip(r_boot, -0.999999, 0.999999))
    mean_boot = np.tanh(np.mean(z)) if len(z) > 0 else np.nan

    sem = np.std(r_boot, ddof=1) if len(r_boot) > 1 else np.nan

    return {
        'point': r_point,
        'mean_boot': mean_boot,
        'ci': list(ci),
        'sem': sem,
        'n_items': int(valid.sum()),
        'r_boot': r_boot,
    }


# ---------------------------------------------------------------------------
# Paired bootstrap comparison of three group pairs
# ---------------------------------------------------------------------------
def paired_bootstrap_compare(matA, matB, matC, items_a, items_b, items_c,
                              n_boot=N_BOOT, min_resp=MIN_RESP, rng=None):
    """
    Paired bootstrap to compare r(A,B), r(A,C), r(B,C).

    Key: within each iteration, all three correlations share the same
    resampled participants for the overlapping group, so the difference
    distributions are properly paired.

    Returns dict with p-values and bootstrap difference distributions.
    """
    if rng is None:
        rng = np.random.default_rng()

    # Align to items shared across ALL three groups
    shared = sorted(set(items_a) & set(items_b) & set(items_c))
    ia = [items_a.index(s) for s in shared]
    ib = [items_b.index(s) for s in shared]
    ic = [items_c.index(s) for s in shared]

    XA = matA[:, ia]
    XB = matB[:, ib]
    XC = matC[:, ic]

    nA, n_items = XA.shape
    nB = XB.shape[0]
    nC = XC.shape[0]

    if n_items < 5:
        return {'pmat': np.full((3, 3), np.nan),
                'AB_vs_AC': np.nan, 'AB_vs_BC': np.nan, 'AC_vs_BC': np.nan}

    r_AB = np.full(n_boot, np.nan)
    r_AC = np.full(n_boot, np.nan)
    r_BC = np.full(n_boot, np.nan)

    for b in range(n_boot):
        idx_a = rng.integers(0, nA, size=nA)
        idx_b = rng.integers(0, nB, size=nB)
        idx_c = rng.integers(0, nC, size=nC)

        mA = np.nanmean(XA[idx_a, :], axis=0)
        mB = np.nanmean(XB[idx_b, :], axis=0)
        mC = np.nanmean(XC[idx_c, :], axis=0)

        nOA = np.sum(~np.isnan(XA[idx_a, :]), axis=0)
        nOB = np.sum(~np.isnan(XB[idx_b, :]), axis=0)
        nOC = np.sum(~np.isnan(XC[idx_c, :]), axis=0)

        v = (nOA >= min_resp) & (nOB >= min_resp) & (nOC >= min_resp)
        if v.sum() < 5:
            continue

        r_AB[b], _ = spearmanr(mA[v], mB[v])
        r_AC[b], _ = spearmanr(mA[v], mC[v])
        r_BC[b], _ = spearmanr(mB[v], mC[v])

    # Differences
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

    # pmat indexed as [AB=0, AC=1, BC=2]
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
def plot_intergroup_bars(ab, ac, bc, pmat, condition, trial_type, out_dir,
                         ci_type=CI_TYPE):
    """Bar chart: [US-San Borja, US-Tsimane', San Borja-Tsimane'].

    ci_type : 'sem'  -> symmetric ±1 SEM error bars (bootstrap SD)
              '95ci' -> asymmetric 95% percentile CI error bars
    """
    labels = ['US-San Borja', "US-Tsimane'", "San Borja-Tsimane'"]
    vals = [ab['point'], ac['point'], bc['point']]

    if ci_type == 'sem':
        sems = [ab['sem'], ac['sem'], bc['sem']]
        err_neg = [max(0.0, s) for s in sems]
        err_pos = list(err_neg)
        err_label = '±1 SEM (bootstrap)'
    else:
        ci_lo = [ab['ci'][0], ac['ci'][0], bc['ci'][0]]
        ci_hi = [ab['ci'][1], ac['ci'][1], bc['ci'][1]]
        err_neg = [max(0.0, v - lo) for v, lo in zip(vals, ci_lo)]
        err_pos = [max(0.0, hi - v) for v, hi in zip(vals, ci_hi)]
        err_label = '95% CI (bootstrap)'

    fig, ax = plt.subplots(figsize=(7, 5))
    x = np.arange(3)
    bars = ax.bar(x, vals, width=0.5, color=['#6699cc', '#cc6666', '#66aa66'],
                  edgecolor='none', alpha=0.85)
    ax.errorbar(x, vals, yerr=[err_neg, err_pos], fmt='none',
                ecolor='black', capsize=6, linewidth=1.3)

    # Annotate values
    for i in range(3):
        ax.text(i, vals[i] + err_pos[i] + 0.015, f'{vals[i]:.2f}',
                ha='center', va='bottom', fontweight='bold', fontsize=11)

    # P-value brackets
    if pmat is not None:
        y_max = max(v + ep for v, ep in zip(vals, err_pos))
        bracket_pairs = [(0, 1), (0, 2), (1, 2)]
        for k, (i, j) in enumerate(bracket_pairs):
            y = y_max + 0.06 + k * 0.04
            p = pmat[i, j]
            p_txt = f'p < 0.001' if p < 0.001 else f'p = {p:.3f}'
            ax.plot([i, i, j, j], [y - 0.01, y, y, y - 0.01], 'k-', lw=0.8)
            ax.text((i + j) / 2, y + 0.005, p_txt, ha='center', va='bottom', fontsize=9)

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
    fname = os.path.join(out_dir, f'intergroup_{trial_type}_{condition}.png')
    fig.savefig(fname, dpi=150)
    plt.close(fig)
    print(f'  Saved: {fname}')


# ---------------------------------------------------------------------------
# Main pipeline
# ---------------------------------------------------------------------------
def run_pipeline(data_dir, condition, sites, min_resp=MIN_RESP):
    """
    Full pipeline for one condition.

    Parameters
    ----------
    data_dir : str
        Path to the Results/ folder containing .mat files.
    condition : str
        'Globalized-Music' or 'Industrial-Nature'.
    sites : dict
        {site_name: [codes]} mapping, e.g. SITES.
    min_resp : int
        Minimum non-NaN observations per stimulus per group.

    Returns
    -------
    dict with reliabilities, intergroup correlations, and p-values.
    """
    site_names = list(sites.keys())
    assert len(site_names) == 3, 'Exactly 3 sites required'

    rng = np.random.default_rng(42)

    # --- Load files per site ---
    files = {}
    for name, codes in sites.items():
        files[name] = get_files(data_dir, codes, condition)
        print(f'  {name}: {len(files[name])} participants')

    # --- Build item matrices ---
    matrices = {}
    items = {}
    for name in site_names:
        if len(files[name]) == 0:
            print(f'  WARNING: no files for {name}, skipping')
            return None
        h, f, it = build_item_matrices(files[name])
        matrices[name] = {'hits': h, 'fas': f}
        items[name] = it

    # --- Split-half reliability ---
    print('\n  Split-half reliability (participant split, Spearman):')
    reliabilities = {}
    for name in site_names:
        for tt in ['hits', 'fas']:
            r, std, sb = split_half_reliability(matrices[name][tt], N_SPLITS, rng)
            key = f'{name}_{tt}'
            reliabilities[key] = {'r': r, 'std': std, 'sb': sb}
            label = 'Hits' if tt == 'hits' else 'FAs'
            print(f'    {name} {label}: r = {r:.3f} ± {std:.3f}  (SB = {sb:.3f})')

    # --- Intergroup correlations (bootstrap) ---
    results = {}
    out_dir = os.path.join(data_dir, 'figures', condition)
    os.makedirs(out_dir, exist_ok=True)

    A, B, C = site_names
    for trial_type, mat_key in [('hit', 'hits'), ('fa', 'fas')]:
        print(f'\n  Intergroup {trial_type.upper()} correlations:')

        ab = intergroup_correlation_bootstrap(
            matrices[A][mat_key], matrices[B][mat_key],
            items[A], items[B], n_boot=N_BOOT, min_resp=min_resp, rng=rng)
        print(f'    {A}-{B}: r = {ab["point"]:.3f}  '
              f'95% CI [{ab["ci"][0]:.3f}, {ab["ci"][1]:.3f}]  '
              f'({ab["n_items"]} items)')

        ac = intergroup_correlation_bootstrap(
            matrices[A][mat_key], matrices[C][mat_key],
            items[A], items[C], n_boot=N_BOOT, min_resp=min_resp, rng=rng)
        print(f'    {A}-{C}: r = {ac["point"]:.3f}  '
              f'95% CI [{ac["ci"][0]:.3f}, {ac["ci"][1]:.3f}]  '
              f'({ac["n_items"]} items)')

        bc = intergroup_correlation_bootstrap(
            matrices[B][mat_key], matrices[C][mat_key],
            items[B], items[C], n_boot=N_BOOT, min_resp=min_resp, rng=rng)
        print(f'    {B}-{C}: r = {bc["point"]:.3f}  '
              f'95% CI [{bc["ci"][0]:.3f}, {bc["ci"][1]:.3f}]  '
              f'({bc["n_items"]} items)')

        # Paired bootstrap p-values
        pvals = paired_bootstrap_compare(
            matrices[A][mat_key], matrices[B][mat_key], matrices[C][mat_key],
            items[A], items[B], items[C],
            n_boot=N_BOOT, min_resp=min_resp, rng=rng)

        print(f'    p-values:  {A}-{B} vs {A}-{C}: {pvals["AB_vs_AC"]:.4f}  |  '
              f'{A}-{B} vs {B}-{C}: {pvals["AB_vs_BC"]:.4f}  |  '
              f'{A}-{C} vs {B}-{C}: {pvals["AC_vs_BC"]:.4f}')

        plot_intergroup_bars(ab, ac, bc, pvals['pmat'], condition, trial_type, out_dir,
                             ci_type=CI_TYPE)

        results[trial_type] = {'ab': ab, 'ac': ac, 'bc': bc, 'pvals': pvals}

    results['reliabilities'] = reliabilities
    return results


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
if __name__ == '__main__':
    script_dir = Path(__file__).resolve().parent
    data_dir = str(script_dir / '..' / '..' / '..' / 'Data' / 'RecognitionMemory' / 'Results')
    data_dir = str(Path(data_dir).resolve())

    print(f'Data directory: {data_dir}\n')

    all_results = {}
    for cond in CONDITIONS:
        print(f'\n{"=" * 60}')
        print(f'Condition: {cond}')
        print(f'{"=" * 60}')
        all_results[cond] = run_pipeline(data_dir, cond, SITES, min_resp=MIN_RESP)

    print('\nDone.')
