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

A cluster bootstrap generates $B$ resampled correlations $\{r^{(b)}_{AB}\}_{b=1}^B$ around the sample point estimate $\hat r_{AB}$. The headline value is always $\hat r_{AB}$ from §3, computed once on the original (un-resampled) data; the bootstrap is used only for uncertainty quantification. The bootstrap **median** is reported as a secondary sanity-check — it should sit close to $\hat r_{AB}$, and a large gap signals skew in the resampling distribution.

Three CI methods are computed from the same bootstrap distribution. They differ in how they cope with the small-$n$ skew that is common for correlation statistics, and we report all three by default so divergences between them are visible.

### 4.1 Resampling units

**Participant bootstrap (`BootstrapDim = 1`, default).** On each of $B$ iterations ($B = 1000$–$5000$), participants in group $A$ are resampled with replacement to size $n_A$, independently from group $B$. Item-level means $\bar h_A^{(b)}, \bar h_B^{(b)}$ are recomputed on the resampled participants, the coverage filter is re-applied, and a per-iteration correlation $r^{(b)}_{AB}$ is recorded. Captures uncertainty in "which participants we happened to recruit."

**Stimulus bootstrap (`BootstrapDim = 2`).** A single set of stimuli is resampled with replacement from the shared set $\mathcal{S}_{AB}$ and used for both groups. Group means are computed on this stimulus resample. Repeatedly drawn stimuli appear as repeated values in the correlation vector and inflate the apparent $n$ — the standard cluster-bootstrap-by-items quirk. Captures uncertainty in "which sounds we happened to use."

Reporting both side by side tells you which source of variance dominates; the two should usually be of similar magnitude. A large gap (participant bars wide, stimulus bars tight, or vice versa) localizes where the uncertainty is coming from and is itself a substantive finding.

### 4.2 Percentile CI (default)

The simplest summary of the bootstrap distribution:

$$\text{CI}^{\text{pct}}_{1-\alpha} = \bigl[\mathrm{P}_{\alpha/2}(\{r^{(b)}\}),\; \mathrm{P}_{1-\alpha/2}(\{r^{(b)}\})\bigr].$$

For $\alpha = 0.05$ this is the $[2.5\%, 97.5\%]$ quantile interval. The percentile CI is exact when the bootstrap distribution is unbiased and symmetric on the chosen scale. At small $n$ and for correlations near the boundaries, neither assumption holds — the sampling distribution of $r$ is skewed and the bootstrap inherits that skew, so the percentile CI can be biased (typically too narrow on the side closer to $\pm 1$).

### 4.3 Fisher-$z$ back-transformed CI

Fisher's $z$-transform $z = \mathrm{atanh}(r) = \tfrac{1}{2}\ln\!\bigl(\tfrac{1+r}{1-r}\bigr)$ maps $r \in (-1, 1)$ to $z \in \mathbb{R}$ in a way that makes the sampling distribution of $z$ approximately normal with variance independent of the true $\rho$. We build a normal-approximation CI on the $z$ scale, then transform the endpoints back:

$$\hat z = \mathrm{atanh}(\hat r_{AB}), \qquad \hat\sigma_z = \mathrm{SD}\!\bigl(\{\mathrm{atanh}(r^{(b)})\}\bigr),$$

$$\text{CI}^{\text{Fz}}_{1-\alpha} = \bigl[\tanh(\hat z - z_{1-\alpha/2}\,\hat\sigma_z),\; \tanh(\hat z + z_{1-\alpha/2}\,\hat\sigma_z)\bigr],$$

where $z_{1-\alpha/2} = 1.96$ for $\alpha = 0.05$. The interval is symmetric in $z$ but asymmetric in $r$, with more room on the side away from $\pm 1$.

Two notes. First, this is **not** the same as "Fisher-$z$ averaging" of the point estimate, which we explicitly reject (§4 preamble). The point estimate is still the untransformed sample $\hat r$; only the SE used to build the CI lives in $z$-space. Second, taking percentiles in $z$-space and back-transforming would give the same endpoints as the raw percentile CI (because $\tanh$ is monotonic), so the meaningful Fisher-$z$ CI must use a parameter like the bootstrap $z$-space SD as we do here.

### 4.4 BCa (bias-corrected and accelerated) CI

When the bootstrap distribution is both biased and skewed — the small-$n$ rule rather than the exception for correlations — Efron's BCa CI adjusts the percentile quantiles to compensate. Two corrections are estimated from the data:

**Bias correction $\hat z_0$.** A measure of how often the bootstrap correlation falls below the sample estimate:

$$\hat z_0 = \Phi^{-1}\!\Bigl(\widehat{\Pr}\bigl(r^{(b)} < \hat r_{AB}\bigr)\Bigr),$$

where $\Phi^{-1}$ is the inverse standard-normal CDF. If the bootstrap distribution is unbiased, exactly half the draws fall below $\hat r$ and $\hat z_0 = 0$.

**Acceleration $\hat a$.** A measure of how the standard error of $r$ changes with $r$, estimated from jackknife pseudo-values. Let $r_{(-i)}$ denote the correlation computed with the $i$-th resampling unit removed (jackknife at the same level as the bootstrap — participants for participant bootstrap, stimuli for stimulus bootstrap), and let $\bar r_{(\cdot)}$ be the mean of those $n$ leave-one-out correlations. Then

$$\hat a = \frac{\sum_i (\bar r_{(\cdot)} - r_{(-i)})^3}{6\bigl(\sum_i (\bar r_{(\cdot)} - r_{(-i)})^2\bigr)^{3/2}}.$$

If the SE of $r$ is constant in $r$, $\hat a = 0$ and BCa reduces to a bias-corrected interval; if the SE varies strongly with $r$ (typical for correlations near $\pm 1$), $\hat a \neq 0$ further widens or shifts the interval.

**Adjusted quantiles.** With $z_{\alpha/2}$ and $z_{1-\alpha/2}$ the standard-normal quantiles,

$$\alpha_1 = \Phi\!\left(\hat z_0 + \frac{\hat z_0 + z_{\alpha/2}}{1 - \hat a(\hat z_0 + z_{\alpha/2})}\right), \qquad \alpha_2 = \Phi\!\left(\hat z_0 + \frac{\hat z_0 + z_{1-\alpha/2}}{1 - \hat a(\hat z_0 + z_{1-\alpha/2})}\right),$$

and

$$\text{CI}^{\text{BCa}}_{1-\alpha} = \bigl[\mathrm{P}_{\alpha_1}(\{r^{(b)}\}),\; \mathrm{P}_{\alpha_2}(\{r^{(b)}\})\bigr].$$

When $\hat z_0 = \hat a = 0$ this is the percentile CI; otherwise the quantiles shift to correct for bias and skew. BCa is the recommended CI in most modern bootstrap references and is the one to report when the percentile and Fisher-$z$ CIs disagree.

### 4.5 What to report and what each method tells you

| Method | Strengths | When it fails |
|---|---|---|
| Percentile (§4.2) | Simple, makes no parametric assumption | Biased when bootstrap is skewed (common at small $n$) |
| Fisher-$z$ (§4.3) | Symmetric on a variance-stabilized scale; handles $r$ near $\pm 1$ | Assumes the $z$-space bootstrap is approximately normal |
| BCa (§4.4) | Corrects for both bias and skewness; second-order accurate | Acceleration is sensitive to outlying jackknife values |

In practice we recommend reporting **BCa** as the primary CI, with the percentile and Fisher-$z$ CIs available as diagnostics. If all three agree, the percentile CI is fine to report alone (less explanation in the methods). If BCa diverges substantially from the percentile CI, the bootstrap is operating in its bias/skew regime and the divergence itself should be flagged.

We considered but did not implement a **jackknife pseudo-value CI** (compute $r_{(-i)}$ for each unit, form pseudo-values $n\hat r - (n-1)r_{(-i)}$, and use their SE), because BCa already uses the jackknife in its acceleration term and a separate jackknife CI provides little additional information at the small Ns we work with.

## 5. Attenuation correction

Reliability-corrected ("disattenuated") itemwise correlations are reported alongside raw correlations. Following the classical Spearman correction for attenuation,

$$\hat r^{*}_{AB} = \frac{\hat r_{AB}}{\sqrt{\hat\rho_{SB}^{A}\,\hat\rho_{SB}^{B}}}.$$

The denominator is floored at machine epsilon to prevent division by very small reliabilities. **Corrected correlations are not clamped** to $[-1, 1]$: when one or both within-group reliabilities are small relative to the raw intergroup correlation, $\hat r^*$ can legitimately exceed $\pm 1$. This is a property of the formula, not a numerical failure — it tells you that the *attenuation-corrected* relationship at the group level is stronger than the geometric mean of the within-group reliabilities can support, which is itself a substantive observation about how noisy the within-group item structure is. Clamping would hide that signal. Values of $|\hat r^*| > 1$ in real output therefore mean "low within-group reliability is driving this estimate"; they should be reported and discussed, not silently bounded. Three modes select which reliability is used inside the bootstrap:

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
