---
name: recognition-memory-itemlevel
description: >
  Analyze the cross-cultural auditory recognition-memory dataset (U.S., San Borja,
  Tsimane'; environmental / globalized-music / world-song sound sets). Use for
  d'-vs-ISI forgetting curves, per-group task performance (d', hit, FA, criterion),
  within-group split-half reliability, between-group item-wise correlations with
  disattenuation and Fisher-z bootstrap CIs, and the marginals-vs-joint
  reconciliation (memorability x confusability plane, variance decomposition).
  Triggers on: recognition memory .mat data, item-level between-group agreement,
  memorability, confusability, split-half reliability, cross-cultural memory.
---

# Cross-cultural recognition-memory item-level analysis

This skill reproduces the item-level analysis pipeline for the cross-cultural
recognition-memory study (dissertation Chapter 3). It is **dataset-specific**: the
three groups, three sound sets, file-naming, and screen are hard-coded in
`reference/conventions.md`. For methods, formulas, and gotchas read that file
BEFORE writing analysis code.

## Data location

Per-participant `.mat` files:
`.../Data/RecognitionMemory/Results/` (single-ISI item-level, ISI=16) and the
multi-ISI sessions for the forgetting curves. Old raw copies live under
`BOLIVIA2024/FullData/RecognitionMemory/Results` and `.../prolificResultsFixed`.

## Workflow (do these in order)

1. **Load + screen.** `scripts.io.list_matfiles(base, codes, cond, min_isi0_dprime, is_multi_isi)`
   filters by site code + condition and applies the d'>=2 ISI=0 catch-trial
   inclusion screen. Pass `min_isi0_dprime=0.0` for an UNFILTERED (raw dataset)
   description; **any figure that skips the screen must be labeled UNFILTERED**.
2. **Build matrices.** `build_hit_fa_matrices(files)` -> participant x item hit and
   FA matrices (NaN where a participant did not see that item in that role).
3. **Two marginals.**
   - Per-participant (row means): hit rate, FA rate, d', criterion -> task
     performance (`scripts.stats.dprime`, `criterion`).
   - Per-sound (column means): the item vectors used for correlations.
4. **Within-group reliability.** `scripts.stats.split_half_reliability(matrix)`
   (Spearman-Brown corrected). This is the ceiling for between-group agreement.
5. **Between-group agreement.** `scripts.stats.between_group` -> observed Spearman r,
   disattenuated r* = r / sqrt(rho_A rho_B), and Fisher-z bootstrap 95% CI. Analyze
   **hits and FAs separately** (never merge; corrected recognition CR = hit - FA
   blurs the effect).
6. **Performance gap.** `scripts.stats.performance_gap` -> mean_A - mean_B across
   sounds with bootstrap CI and paired Wilcoxon. Gap = level; correlation = pattern;
   they are independent.
7. **Figures.** Use `scripts.figures` helpers for house style (group colors, the
   U-shape ordering with the most-distant pair U.S.-Tsimane' CENTERED, scatter grids
   annotated with r and r*, memorability x confusability plane, variance decomposition).

## Key results this pipeline reproduces

The only between-group divergence that survives correction and multiple robustness
checks is **music false alarms, U.S. vs Tsimane'** (r ~ 0.25, r* ~ 0.32), while hits
agree everywhere and world-song/environmental FA agreement stays high. Framing:
"memorability is shared; confusability is cultural." See `reference/interpretation.md`.

## Conventions to honor

- Rates clipped to [0.01, 0.99] before z-transform.
- Fisher-z CIs use a **bootstrapped** sigma_z (valid for Spearman; do NOT use the
  normal-theory 1/(n-3)).
- Captions and prose use commas, **no em-dash parentheticals**.
- Report both observed r and disattenuated r*; flag r* as unreliable when a group's
  reliability is very low (e.g. Tsimane' music hits, rho ~ 0.21).
