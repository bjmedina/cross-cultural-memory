# Agent plan: representation-similarity model of cross-cultural false alarms

A self-contained plan for an agent (e.g. Claude Code on the cluster) to test whether
DNN-embedding similarity predicts per-sound false-alarm (FA) rates, and whether a
fixed representation explains the *shared* confusability but not the culture-specific
music divergence. Encoding runs on the cluster; analysis reuses the existing
`Analysis-Scripts-v2` pipeline.

## 0. Objective and hypotheses

A false alarm is a novel sound mistaken for something recently heard, so a sound's
per-sound FA rate is a behavioral read-out of its similarity, in the listener's
representational space, to the rest of the set. If a DNN embedding captures that
space, model confusability should predict human FA.

- **H1 (validation).** Per-sound model confusability (cosine similarity to the other
  sounds in the set) predicts per-sound human FA rate within a group (Spearman > 0).
- **H2 (shared vs culture-specific).** A single fixed (Western-exposed) model predicts
  the *shared* confusability. For **world song** (unfamiliar to all groups) it predicts
  every group about equally; for **music** it predicts the **U.S. better than
  Tsimane'** (positive `rho_US - rho_Ts` gap). Environmental is intermediate.
- **H3 (representation level).** An **early** layer (cochleagram / low-level acoustics)
  predicts world-song FA for all groups; a **late** layer (learned categories) predicts
  music FA for the U.S. more than Tsimane'. This maps the diverge/not-diverge
  dissociation onto low- vs high-level representation.

Success = H1 holds broadly; the `rho_US - rho_Ts` gap is positive and largest for
music, ~0 for world song; and the late-layer gap exceeds the early-layer gap for music.

## 1. Environment and data (read before coding)

- **Repos.** Behavioral analysis: `cross-cultural-memory/Code/RecognitionMemory/Analysis-Scripts-v2`.
  Encoders live in the `memory` repo (`utls/runners_utils.py`: `build_encoder`,
  `encode_stimuli`; `utls/encoders.py`; `ScoreFunction.py`). Follow that repo's
  `CLAUDE.md`.
- **cox mock.** Every script that imports the encoder stack must prepend the `cox`
  mock (see memory `CLAUDE.md`), or imports fail.
- **Encoder config (kell2018).**
  ```python
  encoder_cfg = dict(encoder_type='kell2018', model_name='kell2018',
                     task='word_speaker_audioset', layer='relu0',
                     sr=20000, duration=2.0, rms_level=0.05,
                     time_avg=False, device='cuda')
  ```
  Model files: `/orcd/data/jhm/001/om2/bjmedina/models/cochdnn/model_directories/kell2018_word_speaker_audioset/`.
  Pick TWO layers: one EARLY (near-cochleagram, low-level) and one LATE (deep, learned).
- **Stimuli.** The 80 sounds per set. Names must match the behavioral names exactly,
  e.g. `mem_stim_14.wav`. Get the canonical per-set name list from behavior:
  `build_hit_fa_matrices(list_matfiles(BASE, CODES[group], cond, 2.0, False))[2]`.
  Sound sets (conditions): `Industrial-Nature` (Environmental), `Globalized-Music`
  (Music), `NHS` (World song). Locate the actual wav files on the cluster (they are
  NOT in the repo).
- **Screens / conventions.** Human FA rates use d'>=2 (ISI=0 catch) and finished
  sessions only (120 trials), both already enforced in `python/io.py`. Correlations
  are Spearman. Report the reliability-corrected value as **"corrected for
  attenuation"** (advisor's term), never alone, always beside observed r; flag cells
  where a group's split-half reliability < 0.5. No em-dash parentheticals in prose or
  captions.

## 2. Phase 1 - encode on the cluster

1. Assemble the wav paths for all sounds in all three sets, keyed by behavioral name.
2. For each chosen layer, run `build_encoder(encoder_cfg | {'layer': L})` then
   `encode_stimuli(...)` on the wavs. Keep `time_avg=False` unless memory is a problem;
   if you must reduce dimensionality, average over time and note it.
3. Save one file per layer, keyed by sound name, in
   `Analysis-Scripts-v2/representation/embeddings/`:
   - `"<layer>.npz"` with arrays keyed by name (preferred), OR
   - `"<layer>/<name>.npy"` (one file per sound).
   The loader in `representation_confusability.py::load_embeddings` reads either.
4. Sanity checks: 80 vectors per set per layer; consistent dimensionality; names match
   the behavioral list (no missing/extra). Log any mismatches.

## 3. Phase 2 - model confusability

- **Global (already implemented)** in `representation_confusability.py`: per-sound
  confusability = mean cosine similarity to the OTHER sounds in the same set.
- **Sequence-context (add; more principled).** A foil false-alarms because it is
  similar to what was recently PRESENTED. For each foil presentation, from the
  participant's `stimulusPresented` order and `repeatPosition` (foil = `isnan(rp)`),
  take the preceding window (e.g. last 8 sounds) and compute max (or mean) cosine
  similarity of the foil embedding to those context embeddings. Average over all
  presentations of a sound to get its context-confusability. Extract the sequences from
  the raw `.mat` (see `characterize_deep.py` for reading `stimulusPresented`).
  Correlate this with human FA as a second, stronger predictor.

## 4. Phase 3 - the three tests + statistics

- For each layer x condition x group: Spearman(model confusability, human FA) across
  the ~80 sounds. Bootstrap over SOUNDS (resample sounds with replacement, recompute)
  for 95% CIs; the design is stimulus-limited so effective N = number of sounds.
- **H2/H3 metric:** per layer x condition, `rho_US - rho_Ts` with a bootstrap CI
  (resample sounds jointly so the two correlations share the resample). Expect
  positive and largest for music, ~0 for world song.
- **Layer contrast (H3):** compare early vs late `rho_US - rho_Ts` for music; expect
  late > early. Optionally sweep all available layers to show a monotonic emergence of
  the gap with depth.
- Multiple comparisons: if making per-cell claims, Holm-correct across the layer x
  condition x group grid, mirroring the behavioral chapter.

## 5. Phase 4 - figures (house style)

Reuse `skill/scripts/figures.py` conventions (group colors US `#1f77b4`, San Borja
`#ff7f0e`, Tsimane' `#2E7D32`). Produce:
1. `representation_confusability.png` (already scaffolded): rho(confusability, FA) by
   group, per condition, one panel per layer.
2. A `rho_US - rho_Ts` gap figure: bars per condition, early vs late layer, with
   bootstrap CIs, mirroring `u_depth.py` styling.
3. Optional depth-sweep line: the music U.S.-minus-Tsimane' gap vs layer index.

## 6. Phase 5 - integrate into the chapter

Add a Results subsection to `docs/thesis/chapter3.tex`, after the item-level FA
divergence result, titled e.g. "A representational-similarity account of the
divergence." State: model similarity predicts FA (H1); a fixed representation captures
the shared confusability but not the music U.S.-Tsimane' divergence (H2); and the
divergence lives in high-level, learned features, not low-level acoustics (H3). Tie to
the familiarity account (music familiarity differs across groups; world song is
uniformly unfamiliar). Keep captions em-dash-free; use "corrected for attenuation".

## 7. Verification / done criteria

- Embeddings: 80 sounds x 3 sets x each layer, names aligned, dims consistent.
- H1: rho(confusability, FA) > 0 for most group x condition cells (report CIs).
- H2: `rho_US - rho_Ts` positive and largest for music, ~0 for world song, CIs shown.
- H3: late-layer music gap > early-layer music gap.
- All figures regenerate from scratch via a single driver; numbers in the text match
  the scripts. Spot-check one condition by hand.
- Use a subagent (or a second pass) to re-verify the gap computation and the
  bootstrap, and to confirm no sound-name misalignment silently dropped items.

## 8. Pitfalls

- **Name misalignment** silently shrinks N; assert the intersection size == 80.
- **Dimensionality / normalization:** L2-normalize before cosine; kell2018 `relu0` is
  ~18k-dim, watch memory.
- **Encoding duration:** stimuli may exceed `duration=2.0`; confirm how the encoder
  crops/pads and keep it consistent across sets.
- **Reliability ceiling:** a model can only predict FA up to the human FA reliability
  (0.7-0.9 for FA). Interpret rho against that ceiling, not against 1.0.
- **Don't over-read hits:** item-level hit reliability is low (Tsimane' music ~0.22);
  the model test is on false alarms.

## 9. Deliverables

- `representation/embeddings/<layer>.npz` (or per-sound `.npy`) for >=2 layers.
- `representation/representation_confusability.py` results + figure (scaffold exists).
- `representation/representation_context.py` (sequence-context version) + results.
- Gap and depth-sweep figures.
- A drafted `chapter3.tex` Results subsection with numbers and CIs.
```
