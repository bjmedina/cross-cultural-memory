# How to interpret the item-level results

## The one big table
Everything starts from one **participant x sound** table of responses (for hits, and
separately for false alarms). Every other number is this table summarized one of two
ways:
- **Average each ROW (down across sounds)** -> one score per participant
  (hit rate, FA rate, d', criterion). This is "task performance": how good each person is.
- **Average each COLUMN (down across participants)** -> one rate per sound
  (its hit rate, its FA rate). This is the "item vector": how memorable / confusable
  each sound is. The between-group correlations compare these column-summaries.

These two summaries are the "marginals" of the table. The grand mean is the same
either way, so performance and item vectors agree on LEVEL; they differ in what
variation they expose (between people vs between sounds).

## Level vs pattern
- **Gap** (mean_A - mean_B of the per-sound rates) = how much lower one group scores.
  Same thing the performance boxplots show. This is a LEVEL difference.
- **Correlation** (Spearman on the two groups' item vectors) = do the groups rank the
  sounds the same way. This is a PATTERN similarity, and it ignores level.
They are independent: a group can score uniformly lower (big gap) yet rank the sounds
identically (high correlation). So "worse overall but agrees on which sounds are
memorable" is not a contradiction.

## The result
Only one comparison shows a real pattern break: **music false alarms, U.S. vs
Tsimane'** (r ~ 0.25, r* ~ 0.32). It survives disattenuation, so it is not a noise
artifact. Hits agree everywhere; environmental and world-song FA agreement stays high.
Reading: memorability (hits) is broadly shared across cultures; confusability (FAs)
in music is where experience reshapes memory.

## Why FA correlations can be high while hit correlations are lower
FA is measured on many observations per sound (every sound is a foil for nearly
everyone), so FA reliability is high (~0.8-0.9) and its correlation ceiling is high.
Hits rest on far fewer target observations per sound, so hit reliability (~0.65) caps
hit correlations. This is a coverage fact, not a magnitude effect (Spearman is
scale-invariant).

## The full joint (beyond the two marginals)
- **Memorability x confusability plane**: each sound as (hit rate, FA rate). Shows the
  two per-sound marginals are only weakly related, a sound can be memorable AND rarely
  confused.
- **Variance decomposition**: ~72-82% of the response variance is residual
  (participant x sound interaction + trial noise); only ~10-16% is between participants
  and ~8-16% between sounds. The reliable item signal is a small, systematic slice.
