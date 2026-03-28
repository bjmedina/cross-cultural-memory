# Analysis-Scripts-v2

Cross-cultural recognition memory analysis pipeline (MATLAB 2018b+ and Python 3.7+).

Computes within-group split-half reliability and between-group itemwise correlations for serial recognition memory data across three participant groups: US (Prolific/BOS/CAM), San Borja (SBO/SNB/SBJ), and Tsimane' (NVM/MAJ/MAN/NUM/NUV/CVR).

## Quick start

### MATLAB
```matlab
% From any directory:
run('/path/to/Analysis-Scripts-v2/run_cross_cultural_analysis.m')
```

### Python
```bash
python cross_cultural_analysis.py
```

---

## Directory structure

```
Analysis-Scripts-v2/
  run_cross_cultural_analysis.m      % Top-level driver
  cross_cultural_analysis.py         % Python reimplementation
  stats/
    runIntergroupCorrelationPipeline.m
    calculateSplitHalfReliability.m
    estimateSplitHalfFlexible.m
    bootstrapIntergroupCorrelationSEM.m
    pairedBootstrapCompareCorrelations.m
    plotTripleIntergroupBar_v2.m
    sensitivityMinResp.m
  utils/
    UTILS_getRecognitionMemFiles.m
    UTILS_getTopPerformers_ISI16_pythonPolicy.m
    UTILS_buildOutputDir.m
    ternary.m
```

---

## Main functions

### `run_cross_cultural_analysis.m`

Top-level driver script. Defines site groups, conditions, and `minResp`, then calls `runIntergroupCorrelationPipeline` for each condition and trial type.

```matlab
% Configuration (edit these in the script):
conditions = {'Globalized-Music', 'Industrial-Nature'};
minResp    = 2;
```

---

### `runIntergroupCorrelationPipeline(baseDir, trial_type, condition, placeCodesA, placeCodesB, placeCodesC, ...)`

Full pipeline: split-half reliability, bootstrap intergroup correlations, paired-bootstrap p-values, and bar chart.

```matlab
outs = runIntergroupCorrelationPipeline(baseDir, 'hit', 'Globalized-Music', ...
    {'PRO','BOS','CAM'}, {'SBO','SNB','SBJ'}, {'NVM','MAJ','MAN'}, ...
    'minResp', 3);
```

| Parameter | Description |
|-----------|-------------|
| `baseDir` | Folder containing `.mat` files |
| `trial_type` | `'hit'` or `'fa'` |
| `condition` | e.g. `'Globalized-Music'` |
| `placeCodesA/B/C` | Cell arrays of site codes for the three groups |
| `'minResp'` (2) | Min non-NaN observations per stimulus per group per bootstrap draw |

Returns a struct with fields: `ab`, `ac`, `bc` (intergroup results), `pvals` (paired comparisons), `reliability` (split-half structs).

---

### `calculateSplitHalfReliability(baseDir, placeCodes, condition, minISI0dprime, isMultiISI, nSplits, splitDim, top)`

Loads participant data, builds participant x stimulus matrices, and computes split-half reliability.

```matlab
outs = calculateSplitHalfReliability(baseDir, {'PRO','BOS','CAM'}, ...
    'Globalized-Music', 2.0, false, 10000, 1, false);
```

| Parameter | Description |
|-----------|-------------|
| `placeCodes` | Site codes, e.g. `{'BOS','CAM'}` or `{'ALL'}` |
| `minISI0dprime` | d' threshold at ISI=0 for participant inclusion |
| `isMultiISI` | `true` for multi-ISI experiments, `false` for single-ISI |
| `nSplits` | Number of random split-halves (e.g. 10000) |
| `splitDim` | `1` = split participants (stimulus-level reliability), `2` = split stimuli |
| `top` | `true` to use top-2/3 performer filter |

Output fields: `r_hit`, `r_fa`, `sb_hit`, `sb_fa`, `itemwise_hits`, `itemwise_fas`, `items`, `nSubjects`.

---

### `estimateSplitHalfFlexible(data, nSplits, splitDim, corrType)`

Low-level split-half correlation computation.

```matlab
[mean_r, std_r, rs] = estimateSplitHalfFlexible(hits, 10000, 1, 'Spearman');
```

| Parameter | Description |
|-----------|-------------|
| `data` | [participants x stimuli] matrix |
| `nSplits` | Number of random splits |
| `splitDim` | `1` = split participants, `2` = split stimuli |
| `corrType` | `'Spearman'` (default) or `'Pearson'` |

---

### `bootstrapIntergroupCorrelationSEM(outsA, outsB, trialType, ...)`

Bootstrap CIs for a single intergroup itemwise correlation with optional attenuation correction.

```matlab
result = bootstrapIntergroupCorrelationSEM(outsA, outsB, 'hit', ...
    'nBoot', 5000, 'BootstrapDim', 1, 'UseSpearman', true, ...
    'minResp', 2, 'ReliabilityMode', 'per-draw', 'CorrectAtten', true);
```

| Option | Default | Description |
|--------|---------|-------------|
| `'nBoot'` | 1000 | Number of bootstrap iterations |
| `'BootstrapDim'` | 1 | `1` = resample participants, `2` = resample stimuli |
| `'minResp'` | 2 | Min observations per stimulus per group per draw |
| `'UseSpearman'` | true | Spearman vs Pearson |
| `'ReliabilityMode'` | `'subset'` | `'fixed'`, `'subset'`, or `'per-draw'` |
| `'CorrectAtten'` | true | Apply attenuation correction |
| `'SplitHalfRepeats'` | 200 | Split-half iterations per bootstrap draw (for `'per-draw'` mode) |
| `'ReliabilitySplitDim'` | 1 | Split dimension for reliability estimation |

Output fields: `point_raw`, `point_corr`, `ci_raw`, `ci_corr`, `point_itemsN`.

---

### `pairedBootstrapCompareCorrelations(outsA, outsB, outsC, trialType, ...)`

Paired bootstrap test comparing three intergroup correlations. Uses shared resampling for group pairs that share a common group (preserving dependence).

```matlab
pvals = pairedBootstrapCompareCorrelations(outsA, outsB, outsC, 'hit', ...
    'nBoot', 5000, 'UseSpearman', true, 'minResp', 2);
```

| Option | Default | Description |
|--------|---------|-------------|
| `'nBoot'` | 5000 | Bootstrap iterations |
| `'UseSpearman'` | true | Spearman vs Pearson |
| `'BootstrapDim'` | 1 | Resample participants (1) or stimuli (2) |
| `'minResp'` | 2 | Min observations per stimulus per group |

Output: `pvals.pmat` (3x3 symmetric p-value matrix, bar order [AB, AC, BC]), plus `.AB_vs_AC`, `.AB_vs_BC`, `.AC_vs_BC`, `.diffs`, `.ci`.

---

### `plotTripleIntergroupBar_v2(pair1, pair2, pair3, condition, trial_type, baseDir, pmat)`

Bar chart comparing three intergroup correlations (raw and attenuation-corrected) with 95% CIs and optional p-value brackets.

```matlab
plotTripleIntergroupBar_v2(ab, ac, bc, 'Globalized-Music', 'hit', baseDir, pvals.pmat);
```

Bar order: US-San Borja | US-Tsimane' | San Borja-Tsimane'.

---

### `sensitivityMinResp(baseDir, trial_type, condition, placeCodesA, placeCodesB, placeCodesC, minRespVals)`

Sweeps `minResp` thresholds and plots how intergroup correlations and surviving stimulus counts change.

```matlab
results = sensitivityMinResp(baseDir, 'hit', 'Globalized-Music', ...
    {'PRO','BOS','CAM'}, {'SBO','SNB','SBJ'}, {'NVM','MAJ','MAN'}, ...
    [2 3 5 8 10]);
```

Produces a two-panel figure: correlation +/- CI vs minResp (left) and N surviving stimuli vs minResp (right).

---

## Utility functions

| Function | Description |
|----------|-------------|
| `UTILS_getRecognitionMemFiles(baseDir, placeCodes, condition, minISI0dprime, isMultiISI)` | List `.mat` files filtered by site code, condition, and ISI-0 d' threshold |
| `UTILS_getTopPerformers_ISI16_pythonPolicy(baseDir, placeCodes, condition, minISI0dprime, isMultiISI)` | Select top 2/3 participants by d' at ISI=16 |
| `UTILS_buildOutputDir(baseDir, condition)` | Create and return `baseDir/figures/condition/` path |
| `ternary(cond, a, b)` | Inline conditional: returns `a` if `cond` is true, else `b` |

---

## Data format

Each `.mat` file contains one participant's data with fields:
- `stimulusName` - cell array of stimulus names per trial
- `isResponseCorrect` - binary correctness per trial
- `repeatPosition` - NaN for non-repeats, position for repeats
- `ISI` - inter-stimulus interval (repeatPosition - 1)
- `dprime_ISI0` - d' at ISI=0 (used for participant filtering)
- `placeCode` - site identifier (e.g. `'PRO'`, `'SBO'`, `'NVM'`)

Hit trials: nonzero-ISI repeats (`~isnan(repeatPosition) & ISI > 0`), scored as `isResponseCorrect`.
FA trials: non-repeat trials (`isnan(repeatPosition)`), scored as `1 - isResponseCorrect`.

---

## Python version

`cross_cultural_analysis.py` reimplements the full pipeline using NumPy, SciPy, and Matplotlib. Edit the `BASE_DIR`, site codes, and conditions at the bottom of the file, then run directly.
