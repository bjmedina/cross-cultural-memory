# Statistical methods — cross-cultural recognition memory pipeline

This document specifies, in publication-grade detail, the statistical procedures implemented in `Analysis-Scripts-v2/`. Every step below is traceable to a function in `stats/`; equations and code references are given where useful. Where there are two acceptable conventions, both are described and the default is named.

## 1. Data structure

Each participant *i* in group *g* contributes a single recognition memory session with mixed first-presentation and repeat trials. For each unique stimulus *j* that the participant encountered, we record two binary indicators:

- a **hit** indicator $h_{gij} \in \{0,1\}$, defined on the nonzero-ISI repeat occurrence of stimulus *j*, equal to $\text{isResponseCorrect}$ on that trial;
- a **false-alarm** indicator $f_{gij} \in \{0,1\}$, defined on the first (non-repeat) occurrence of stimulus *j*, equal to $1 - \text{isResponseCorrect}$ (i.e. 1 if the participant called a first-presentation item "old").

A participant who did not encounter stimulus *j* contributes NaN at $h_{gij}$ and $f_{gij}$. The two matrices $H_g, F_g \in (\{0,1\} \cup \{\text{NaN}\})^{n_g \times m}$ are built by `calculateSplitHalfReliability.m`, where $n_g$ is the number of participants in group *g* who passed the d′-at-ISI=0 inclusion threshold and $m$ is the union of stimuli encountered by any included participant in that group. Subsequent analyses align to the intersection of stimulus sets across the groups being compared.

## 2. Within-group split-half reliability

Reliability of an item-level rate vector is estimated by random split-half over participants (default; `splitDim = 1`) or over stimuli (`splitDim = 2`). The participant-split estimate is the more relevant quantity for intergroup itemwise correlation because the cross-cultural correlation is taken on participant-averaged item means.

For each of $S$ random splits ($S = 10{,}000$ by default), participants are partitioned at random into two halves. Item-level means are computed within each half — $\bar h^{(1)}, \bar h^{(2)} \in \mathbb{R}^m$ — and Spearman's rank correlation $r_s$ is computed across items, ignoring items where either half is NaN. Items with fewer than three valid pairs are dropped for that split. The half-set reliability is the **median** of the per-split correlations,

$$\hat\rho_{1/2} = \mathrm{median}\,\{r_s^{(1)}, \dots, r_s^{(S)}\}.$$

The median is used in place of an arithmetic or Fisher-$z$ mean because it is robust to skew and to occasional degenerate splits (e.g., a split where one half's item rates have near-zero variance), and it is invariant to monotone transforms of $r$. The standard deviation of $\{r_s\}$ is reported as a dispersion statistic.

The reliability of the full participant set is obtained by the Spearman–Brown formula,

$$\hat\rho_{SB} = \frac{2\hat\rho_{1/2}}{1+\hat\rho_{1/2}},$$

and is the quantity used for attenuation correction in §5. Implementation: `estimateSplitHalfFlexible.m`. The same procedure with the same defaults is used for the FA matrix.

## 3. Intergroup itemwise correlation: point estimate

Given two groups $A$ and $B$ aligned on a shared item set $\mathcal{S}_{AB}$, define the item-level group means
$\bar h_{Aj} = \frac{1}{|\{i: h_{Aij}\ne\text{NaN}\}|}\sum_{i: h_{Aij}\ne\text{NaN}} h_{Aij}$,
and analogously $\bar h_{Bj}$.

An item *j* is retained in the correlation if it has at least `minResp` non-NaN observations in each group (default `minResp = 2`); items below this threshold are removed before correlation. A minimum of `minItems = 5` retained items is required; otherwise the estimate is NaN.

The point estimate is

$$\hat r_{AB} = \mathrm{corr}_{\text{Spearman}}\!\left(\{\bar h_{Aj}\}_{j\in \mathcal{V}_{AB}},\, \{\bar h_{Bj}\}_{j\in \mathcal{V}_{AB}}\right),$$

where $\mathcal{V}_{AB} \subseteq \mathcal{S}_{AB}$ is the set of items meeting the coverage criterion. Implementation: `bootstrapIntergroupCorrelationSEM.m` (helper `compute_r_on_items`). Spearman is the default given the bounded, often skewed nature of group-mean hit rates; Pearson is available via `'UseSpearman', false`.

## 4. Bootstrap confidence intervals

A cluster bootstrap is used to obtain confidence intervals on the intergroup correlation. Two resampling units are supported.

**Participant bootstrap (`BootstrapDim = 1`, default).** On each of $B$ iterations ($B = 1000$–$5000$), participants in group $A$ are resampled with replacement to size $n_A$, independently from group $B$. Item-level means $\bar h_A^{(b)}, \bar h_B^{(b)}$ are recomputed on the resampled participants, the coverage filter is re-applied, and a per-iteration correlation $r^{(b)}_{AB}$ is recorded.

**Stimulus bootstrap (`BootstrapDim = 2`).** A single set of stimuli is resampled with replacement from the shared set $\mathcal{S}_{AB}$ and used for both groups. Group means are computed on this stimulus resample. Note that, by construction, repeatedly drawn stimuli appear as repeated values in the correlation vector and inflate the apparent $n$; this is the standard cluster-bootstrap-by-items quirk and is the appropriate procedure when stimuli are treated as the random factor.

The headline central value is the sample point estimate $\hat r_{AB}$ from §3, computed once on the original (un-resampled) data. The bootstrap is used only for uncertainty quantification, not for re-estimating the central value. Across bootstrap iterations the distribution is summarized by:

- a **95% percentile CI** = $[\mathrm{P}_{2.5}, \mathrm{P}_{97.5}]$ of the $r^{(b)}$ distribution;
- the **median** of the bootstrap distribution as a secondary sanity-check value. The bootstrap median should sit close to $\hat r_{AB}$; a large gap signals skew in the resampling distribution and is itself diagnostic.

No Fisher-$z$ averaging is used. Fisher-$z$ stabilizes variance of correlations but introduces a transform on the central value; reporting the untransformed sample $\hat r$ alongside a percentile CI avoids this and is the more transparent choice.

## 5. Attenuation correction

Reliability-corrected ("disattenuated") itemwise correlations are reported alongside raw correlations. Following the classical Spearman correction for attenuation,

$$\hat r^{*}_{AB} = \frac{\hat r_{AB}}{\sqrt{\hat\rho_{SB}^{A}\,\hat\rho_{SB}^{B}}}.$$

To prevent division by very small reliabilities, the denominator is floored at machine epsilon; corrected correlations are then clamped to $[-1, 1]$. Three modes select which reliability is used inside the bootstrap:

- **`'fixed'`** — the full-sample reliabilities $\hat\rho_{SB}^{A,B}$ from `calculateSplitHalfReliability` are used unchanged in every bootstrap iteration. Fastest; conservative under variation in reliability.
- **`'subset'`** — reliabilities are recomputed once on the item subset that survives the coverage filter at the *point* estimate, and held fixed across bootstrap iterations.
- **`'per-draw'`** — reliabilities are recomputed on each bootstrap resample, using the same resampled participants (or stimuli) and item set as that iteration's correlation. This is the rigorous choice and propagates resample-level uncertainty into the corrected estimate, at the cost of a factor of $\sim$`SplitHalfRepeats` more correlation calls per iteration.

Implementation: `bootstrapIntergroupCorrelationSEM.m`, switch block `relMode` ∈ {`fixed`, `subset`, `per-draw`}.

## 6. Paired-bootstrap comparison of three intergroup correlations

The substantive question — whether the US–San Borja correlation differs from the US–Tsimané correlation, etc. — requires testing equality of two correlations that *share a group*. Independent bootstrap CIs for each correlation are not sufficient: $\hat r_{AB}$ and $\hat r_{AC}$ are dependent because both depend on group $A$, and ignoring this dependence overstates the variance of the difference.

We use the test in `pairedBootstrapCompareCorrelations.m`, which preserves dependence by *sharing the bootstrap resample of any group that appears in both correlations being compared*. Concretely, on iteration $b$:

1. Independently resample participants within each group: indices $\boldsymbol\pi_A^{(b)}, \boldsymbol\pi_B^{(b)}, \boldsymbol\pi_C^{(b)}$ (participant bootstrap), or a single shared item resample $\boldsymbol\pi_{\text{stim}}^{(b)}$ (stimulus bootstrap).
2. From the *same* resample of $A$, compute both $\bar h_A^{(b)}$ used in $r^{(b)}_{AB}$ and $\bar h_A^{(b)}$ used in $r^{(b)}_{AC}$. Analogously for $B$ in $r^{(b)}_{AB}$ vs $r^{(b)}_{BC}$, and $C$ in $r^{(b)}_{AC}$ vs $r^{(b)}_{BC}$.
3. Compute all three correlations $r^{(b)}_{AB}, r^{(b)}_{AC}, r^{(b)}_{BC}$ on the items meeting `minResp` in all three groups for that iteration.
4. Form the three pairwise differences $d^{(b)}_{AB,AC} = r^{(b)}_{AB} - r^{(b)}_{AC}$, etc.

The empirical distributions $\{d^{(b)}\}_{b=1}^B$ are the bootstrap distributions of the differences, and their 2.5/97.5 percentiles are reported as 95% CIs.

We emphasize that "paired" here refers to the **shared-group resample**, not matched participants across cultures. Participants are not matched across sites.

## 7. Two-sided p-values

Two p-value definitions are computed and reported.

**Recentered-null (default; reported as `pvals.AB_vs_AC` etc.).** Let $\bar d$ denote the bootstrap mean of $d^{(b)}$ and $d^{\text{obs}}$ the observed difference computed on the original sample. The null distribution is constructed by recentering the bootstrap distribution at zero, $\tilde d^{(b)} = d^{(b)} - \bar d$, and the two-sided p-value is

$$p_{\text{null}} = \widehat{\Pr}\!\left(\,|\tilde d| \ge |d^{\text{obs}}|\,\right),$$

floored at $1/(B+1)$ to avoid reporting $p=0$. This is the bootstrap analogue of a permutation test under $H_0: \delta = 0$ and is the test we recommend reporting.

**Straddle-zero (legacy; reported as `pvals.straddle.AB_vs_AC` etc.).** $p = 2\min\!\big(\widehat{\Pr}(d^{(b)} > 0),\, \widehat{\Pr}(d^{(b)} < 0)\big)$. Asks whether the bootstrap CI of the difference crosses zero. It is biased under skew of the bootstrap distribution — particularly at small $n$ — but is the percentile-style p value reported in earlier iterations of this pipeline and is retained for backward comparability.

When the two diverge appreciably, the recentered-null variant is the appropriate one to report; differences typically indicate skew in the bootstrap of $d$ and are themselves diagnostic.

## 8. Small-sample considerations and validation

With per-group $n \in [15, 35]$ and shared-item counts $m \in [40, 80]$ — typical for cross-cultural fieldwork — both the bootstrap CIs and the paired test operate at the lower edge of their valid range. We address this two ways.

**Reporting.** Each pipeline run records (i) the per-iteration count of retained items after the `minResp` filter, (ii) within-group SB reliabilities, and (iii) the gap between recentered-null and straddle-zero p-values. Any of these falling far outside their typical range is a signal that the test is operating near its limits and the corresponding p-value should be interpreted with caution.

**Calibration via simulation.** The script `powerSimulationPairedBootstrap.m` generates synthetic three-group recognition memory data with a specified true correlation structure across groups and at the per-group sample sizes of the real study. Under $H_0$ (all three pairwise true correlations equal), the script reports the empirical type-I error rate of each pairwise test; under $H_1$ (one correlation differs by a specified $\Delta$), it reports power. CI coverage for each difference is also reported. Running this once for the actual site sizes provides the operating characteristics that should accompany any reported p-value from the real data.

Recommended diagnostic run before reporting a significant difference:
```matlab
out = powerSimulationPairedBootstrap( ...
        'nA',n_US, 'nB',n_SanBorja, 'nC',n_Tsimane, ...
        'nItems',m_shared, 'rho',[r r r], 'nReps',500);
% Inspect out.reject_null; should be ~= alpha (e.g. 0.05) if calibrated.
```

## 9. Software and reproducibility

All MATLAB analyses use MATLAB 2018b+. Random splits and bootstrap resamples are drawn with `rng('shuffle')` at the top of each routine; for reproducible runs, set `rng(seed)` once before calling `run_cross_cultural_analysis.m`.

A Python twin lives in `python/` and mirrors MATLAB's `stats/` 1:1 — `split_half.py`, `intergroup_corr.py`, `paired_bootstrap.py`, `power_simulation.py`, with shared helpers in `_utils.py`. The top-level driver is `run_cross_cultural_analysis.py`. The two languages compute the same statistics (including the recentered-null and straddle-zero p-values of §7 and the calibration sim of §8) and produce numerically matching results to within bootstrap sampling error. Python 3.7+, NumPy, SciPy.

The legacy single-file scripts `cross_cultural_analysis.py` and `cross_cultural_analysis_stim_bootstrap.py` predate the median / recentered-null conventions and are retained for their `.mat`-loading and plotting code only; new work should use the `python/` package.

## Appendix: function-to-equation map

| Function | Equation / Step |
|---|---|
| `calculateSplitHalfReliability` | §1 matrix construction; calls §2 |
| `estimateSplitHalfFlexible` | §2 $\hat\rho_{1/2}$ |
| Spearman–Brown formula inline | §2 $\hat\rho_{SB}$ |
| `bootstrapIntergroupCorrelationSEM` | §3 point estimate; §4 CIs; §5 attenuation |
| `pairedBootstrapCompareCorrelations` | §6 paired bootstrap; §7 both p-values |
| `plotTripleIntergroupBar_v2` | reporting |
| `sensitivityMinResp` | sensitivity to `minResp` |
| `powerSimulationPairedBootstrap` | §8 calibration |
