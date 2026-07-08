# Conventions and gotchas (cross-cultural recognition memory)

## Groups (site codes in the filename slot `-<CODE>_`)
- **U.S.** (online / Prolific): `PRO`, `BOS`, `CAM`
- **San Borja** (Bolivian market town): `SBO`, `SNB`, `SBJ`
- **Tsimane'** (Amazonian forager-horticulturalists): `NVM`, `MAJ`, `MAN`, `NUM`, `NUV`, `CVR`
Exposure ordering (cultural distance): U.S. -> San Borja -> Tsimane'. The most
distant pair is **U.S.-Tsimane'**; center it in U-shape figures.

## Sound sets (conditions)
- `Industrial-Nature` = Environmental sounds
- `Globalized-Music` = (globalized) Music
- `NHS` = world song. NOTE: the 2024 `nhs-global` files are a COMBINED music set;
  only Industrial-Nature has clean 2025 multi-ISI data. Do not mix them.

## Two data streams (never cross them)
1. **Multi-ISI** forgetting curves: `is_multi_isi=True`, ISI in {0,1,2,4,8,16,32,64}.
   Require >=4 distinct ISIs per session to exclude single-ISI contamination.
2. **Single-ISI=16** item-level: `is_multi_isi=False`. This is the item-level stream
   for reliability and between-group correlations.

## Inclusion screen
d' at the ISI=0 catch trials (repeatPosition==1) must be >= 2.0. Applied per
participant in `list_matfiles(min_isi0_dprime=2.0)`. Pass 0.0 to DESCRIBE the raw
dataset, but then LABEL the figure UNFILTERED. The catch d' (ISI=0) is the screen
variable; the memory d' (ISI=16) is the outcome, low values there are real forgetting.

## Signal detection
- Rates clipped to [0.01, 0.99] before z.
- d' = Phi^-1(hit) - Phi^-1(fa).
- criterion c = -0.5 (Phi^-1(hit) + Phi^-1(fa)); c is the midpoint of the two
  z-scores (conservative when c>0).
- hit = isResponseCorrect on a repeat (repeatPosition>1); FA = 1-isResponseCorrect
  on a non-repeat (isnan(repeatPosition)).

## Correlations
- Default = **Spearman** (rank based, scale/level invariant).
- Report observed r AND the **corrected-for-attenuation** r* = r / sqrt(rho_A rho_B)
  (BJM's advisor prefers the phrase "corrected for attenuation" over
  "disattenuated"; they are the same quantity, Spearman 1904).
- r* can exceed 1 and is UNRELIABLE when a group's reliability is very low
  (e.g. Tsimane' music hits, rho ~ 0.21). Flag, do not silently cap.
- Analyze hits and FAs SEPARATELY. Corrected recognition CR = hit - FA blurs the
  FA-specific effect and inherits noisy hits; keep it only as a cross-check.

## Confidence intervals
Fisher-z with a **bootstrap-estimated** sigma_z: z=atanh(r_boot), sigma=SD(z),
CI=tanh(z_hat +/- 1.96 sigma). Do NOT use normal-theory 1/(n-3) (that assumes
Pearson/normality). This was chosen because its interval is centered on the
observed r and stable, unlike percentile/BCa here.

## Style
- No em-dash parentheticals in prose or captions; use commas.
- Effective N for a between-group correlation is the number of SOUNDS (~80), not
  participants: the design is stimulus-limited.
