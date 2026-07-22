# Cross-cultural recognition memory: analysis log

Running record of the item-level cross-cultural analysis for dissertation Chapter 3.
Everything below uses the screened sample unless noted. All scripts live in
`Analysis-Scripts-v2/`; figures land in `dprime_vs_isi_outputs/`.

## Setup and conventions

- **Groups (site codes):** U.S. = `PRO, BOS, CAM`; San Borja = `SBO, SNB, SBJ`;
  Tsimane' = `NVM, MAJ, MAN, NUM, NUV, CVR`. Exposure gradient U.S. -> SB -> Tsimane'.
- **Sound sets (conditions):** `Industrial-Nature` = Environmental; `Globalized-Music`
  = Music; `NHS` = World song.
- **Screens (both in `python/io.py`):** d' >= 2 on the ISI=0 catch trials, AND
  completed sessions only (120 trials, `min_trials=120`). Multi-ISI sessions are also
  120 trials, so nothing there is dropped.
- **Item measures:** per-sound hit rate (targets) and false-alarm rate (foils),
  averaged over participants. Rates clipped to [0.01, 0.99] for d'/criterion.
- **Correlations:** Spearman. Report observed r AND the value **corrected for
  attenuation** r* = r / sqrt(rho_A rho_B) (advisor's term), never r* alone; flag
  cells where a group reliability is not bounded away from zero.
- **CIs:** Fisher-z with a bootstrap-estimated sigma_z; the design is stimulus-limited
  so the bootstrap resamples SOUNDS (effective N = number of sounds).
- **Style:** no em-dash parentheticals; commas.

## Headline result

The item-level cross-cultural story is carried by FALSE ALARMS (the similarity-driven
error, and the reliably measured channel). Between-group FA consistency is below the
within-group ceiling (a culture-specific component), tracks cultural distance
(U.S.-Tsimane' lowest), and is **stimulus-set-dependent**:

| FA between-group r (screen 2.0) | US-SB | US-Ts | SB-Ts |
|---|---|---|---|
| Environmental | 0.64 | 0.59 | 0.64 |
| **Music** | 0.63 | **0.25** | 0.42 |
| World song | 0.77 | 0.75 | 0.75 |

**U-depth** = mean(r_US-SB, r_SB-Ts) - r_US-Ts, sound-level bootstrap:
- Music FA: **0.28 [0.10, 0.45]**, corrected **0.37 [0.14, 0.60]** (CI excludes 0).
- Environmental FA: 0.05 [-0.08, 0.18] (n.s.). World song FA: 0.01 [-0.09, 0.10] (n.s.).

Reading: music (familiar to market-exposed groups, less to Tsimane') diverges; world
song (unfamiliar to all) does not; environmental is intermediate. Scripts: `u_depth.py`,
`u_depth_corrected.py`, `reconcile_scatter.py`, `quantify_gap_corr.py`,
`itemwise_ushape.py`, `plot_itemlevel_results.py`. Chapter figure: `make_udepth_fa.py`
-> `docs/thesis/figures/ch3/u_depth_fa.pdf`.

## Robustness of the music-FA effect

- **d'-screen sweep** (`dprime_screen_sweep.py`, `..._table.py`, `..._disatt.py`):
  music FA US-Ts stays ~0.20-0.30 across screen 0.0-2.5; all other cells flat. The
  effect does not depend on the screen.
- **Leave-one-sound-out** (`leave_one_out_persound.py`): no single sound moves any music
  correlation by more than dr ~ 0.04; the low music-FA US-Ts is not outlier-driven.
- Earlier (pre-log) robustness: permutation null, split-half replication (100%), a
  36-spec specification curve, and a Bayesian multilevel model all isolate music FA
  US-Ts as the one surviving contrast.

## Within-group reliability

Split-half (Spearman-Brown). **FA reliabilities high everywhere (0.69-0.91)**, so FA
r* is well-defined. **Hit reliabilities lower (0.65-0.78) and collapse for Tsimane'
music (~0.22, p=0.15, not significantly > 0).** This is why hits go to the supplement
and why attenuation-corrected HIT correlations for music blow past 1.0 (dividing by
sqrt(~0)). Scripts: `reliability_by_measure.py`, `diagnose_reliability.py`.

## Why Tsimane' music hit reliability is ~0.2 (investigated five ways)

Conclusion: it is a genuine ABSENCE of item-level memorability structure for
Tsimane' listeners on globalized music, not a coverage, floor, or attention artifact.

1. **Signal/noise decomposition** (`diagnose_reliability.py`): across-sound signal SD
   = 0.048 vs binomial noise SD = 0.088. Only cell where noise exceeds signal; implied
   reliability (0.23) matches measured.
2. **Coverage is fine:** 26 obs/sound, comparable to their other sets and more than
   San Borja music (23, reliability 0.72).
3. **Split-half scatter 2x2 control** (`diagnose_reliability_figs.py`): Tsimane' music
   r = 0.15 blob; same group is reliable elsewhere (env 0.71, world 0.65), same 80
   clips are reliable for U.S. (0.77) and San Borja (0.72). Only the intersection fails.
4. **Reliability does not track the mean** (`diagnose_reliability_vs_mean.py`): 8 of 9
   cells sit at 0.65-0.77 regardless of mean (0.33-0.85); Tsimane' world song at nearly
   the same low mean (0.33) is reliable (0.65). Low rate does not cause low reliability.
5. **Inclusion sweep** (`diagnose_reliability_sweep.py`): raising the catch screen
   (0.23, 0.24, 0.24) or adding an ISI=16 memory screen (0.21-0.28) never lifts it.
   Restricting to better performers does not recover signal, so not guessing.

Supporting distributional view: `diagnose_diff_histogram.py` (per-sound rate spread
equals the sampling-noise floor for Tsimane' music; scale the half-difference by 1/2 to
compare like with like). Slopegraph: `diagnose_persound_spread_splithalf.py`.

Caveat: signal sits near the noise floor so the estimate is imprecise (~0.03-0.07), and
"undifferentiated representation" vs "floor performance at delay" cannot be fully
separated, though the catch screen is passed and stricter screens do not change it.

## Old Bolivia deck forensics (why the numbers changed)

Traced the deck-era MATLAB, all still present as parallel dirs (`Analysis/`,
`Analysis-Scripts/`), not in git history. Three separable causes, only the first a true
stats error:
1. **Error-bar bug:** `Analysis/plotIntergroupTripleWithSwarm.m:109-110` plots
   `se = std(rk)/sqrt(numel(rk))`, the SEM of the bootstrap draws, which shrinks with
   more draws. A correct percentile CI sits unused in the same function. This made the
   ~+/-0.01 bars.
2. **Over-correction:** `simulateIntergroupItemwiseCorrelation.m` disattenuates with the
   RAW split-half r (`outsA.r_hit`/`r_fa`), not Spearman-Brown, with no clamp, so r*
   exceeds 1.
3. **Different groups/sample:** current uses merged US (PRO+BOS+CAM) and San Borja
   (SBO+SNB+SBJ) plus a completeness screen; the deck's "Prolific" label and
   `test_itemwise.m` suggest PRO alone / SBO alone, on the older `Tsimane2025` data root
   (not accessible here). Screen was d'>=2.0 (not 1.5); no completeness filter existed.
Could not recover exact deck N or regenerate the figure exactly.

## Chapter status

`docs/thesis/chapter3.tex` (repo `bjmedina/memory`, branch
`identifiability-model-class`, commit ac16b2c) reframed: abstract + intro around FA /
perceptual similarity and the stimulus-set dissociation; Results FA-first with the
U-depth figure as centerpiece; hits moved to a Supplementary section with the
reliability justification; "corrected for attenuation" throughout.

## Open / next

- **Representation-similarity model (pending).** One culture-blind DNN, encode every
  sound at every layer, kNN confusability (Euclidean default, cosine robustness,
  k=1/3/5) from the pairwise distance matrix, correlate PER GROUP PER LAYER against that
  group's FA -> depth curves rho(layer) and the rho_US - rho_Ts gap vs depth (expected:
  music rises with depth, world song flat). Scripts: `representation/AGENT_PLAN.md`,
  `representation/run_representation_analysis.py`, `representation/representation_confusability.py`.
  Needs cluster embeddings + stimulus wavs + the .mat behavioral data (none in git).
- Regenerate the attenuation-corrected HIT figure with the two undefined Tsimane'-music
  cells flagged and observed r shown alongside.
- Draft the supplement paragraph on the Tsimane'-music-hit reliability collapse.

## How to reproduce

All scripts are plain Python (NumPy, SciPy, matplotlib) and are run from
`Analysis-Scripts-v2/`. They import the shared loader `python/io.py`, which applies the
screens, and read the behavioral `.mat` files from
`../../Data/RecognitionMemory/Results` (set `BASE`/`DATA_BASE` at the top of a script if
your data lives elsewhere). Figures are written to `dprime_vs_isi_outputs/`.

```bash
cd Code/RecognitionMemory/Analysis-Scripts-v2

# --- main item-level result (false alarms) ---
python u_depth.py                     # U-depth per set, observed, hit+FA, P(>0)   -> u_depth.png
python u_depth_corrected.py           # U-depth observed vs corrected for attenuation
python reconcile_scatter.py           # per-sound US-vs-group scatters, r and r*   (3 pair figs)
python quantify_gap_corr.py           # gap vs correlation, per pair               -> quantify_gap_corr.png
python itemwise_ushape.py             # real U-shape, US-Ts centered, hit/FA rows
python itemlevel_results.py           # writes itemlevel_results.npz (per-sound vectors + ceilings)
python plot_itemlevel_results.py --kind fa    # 3x3 scatter grid, FA (also --kind hit)
../../..  # chapter centerpiece:
python ../../../../docs/thesis/figures/ch3/make_udepth_fa.py   # -> figures/ch3/u_depth_fa.pdf

# --- robustness of the music-FA effect ---
python dprime_screen_sweep.py         # between-group r vs d' screen (observed)
python dprime_screen_sweep_disatt.py  # same, corrected for attenuation (with reliability)
python dprime_screen_table.py         # r and r* per condition x pair x screen (printed table)
python leave_one_out_persound.py      # per-sound influence + Fisher-z CI (music)  -> leave_one_out_persound.png

# --- dataset characterization ---
python characterize_dataset.py        # per-group d'/hit/FA boxplots + coverage
python characterize_deep.py           # criterion, RT, catch-d', item difficulty, trial counts
python characterize_coverage_detail.py# per-sound repeat/foil observation counts
python characterize_rawmatrix.py      # raw participant x sound correct/incorrect grid
python full_distribution.py           # memorability x confusability plane + variance decomposition
python reliability_by_measure.py      # split-half reliability of hit/FA/CR/d' per cell

# --- Tsimane' music hit-reliability collapse (5 angles) ---
python diagnose_reliability.py            # signal/noise variance decomposition (table)
python diagnose_reliability_figs.py       # split-half scatter grid + signal/noise bars + spread
python diagnose_reliability_vs_mean.py    # reliability vs cell mean (+ rank slopegraph)
python diagnose_reliability_sweep.py      # reliability vs catch and memory screens
python diagnose_persound_spread_splithalf.py  # odd/even split-half slopegraph
python diagnose_diff_histogram.py         # rate spread vs sampling-noise distribution

# --- representation-similarity model (runs on the cluster; needs embeddings) ---
# edit CONFIG paths, then:
python representation/run_representation_analysis.py
# see representation/AGENT_PLAN.md for the full protocol (encode all layers, kNN
# confusability, per-group per-layer correlation, depth curves + gap vs depth).
```

Old-deck forensics is reading-only (MATLAB, no re-run needed): the key files are
`Analysis-Scripts/stats/runIntergroupCorrelationPipeline.m`,
`Analysis-Scripts/stats/simulateIntergroupItemwiseCorrelation.m`, and
`Analysis/plotIntergroupTripleWithSwarm.m` (lines 109-110 = the SEM error-bar bug).
