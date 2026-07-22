#!/usr/bin/env python3
r"""Why is the Tsimane' MUSIC hit reliability so low (~0.2)?

For a per-sound rate p_j estimated from n_j binary responses, the variance across
sounds decomposes as
      Var_total  =  Var_signal  +  Var_noise
where Var_noise is pure binomial sampling noise, Var_noise = mean_j[ p_j(1-p_j)/n_j ].
The reliability ceiling implied by that is
      rel_implied = Var_signal / Var_total = 1 - Var_noise/Var_total.

That separates the two candidate explanations:
  (a) MEASUREMENT: n_j is small, so Var_noise is large relative to Var_total.
  (b) NO ITEM STRUCTURE: Var_signal is genuinely ~0, the sounds really do not differ
      in memorability for that group, so there is nothing reliable to measure.

We report, per group x condition, for hits and for FAs: N participants, coverage n_j,
the mean and SD of the per-sound rate, the noise/signal split, the implied reliability,
and the measured split-half (Spearman-Brown) reliability for comparison.
Screened sample (d'>=2, finished sessions)."""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = [("US", ("PRO","BOS","CAM")), ("SanBorja", ("SBO","SNB","SBJ")),
          ("Tsimane", ("NVM","MAJ","MAN","NUM","NUV","CVR"))]
GLAB = {"US":"U.S.","SanBorja":"San Borja","Tsimane":"Tsimane'"}
CONDS = [("Industrial-Nature","Environmental"),("Globalized-Music","Music"),("NHS","World song")]
rng = np.random.default_rng(0)


def splithalf(mat, nsplit=300):
    n = mat.shape[0]; rs = []
    for _ in range(nsplit):
        idx = rng.permutation(n); a, b = idx[:n//2], idx[n//2:]
        with np.errstate(invalid="ignore"):
            va, vb = np.nanmean(mat[a], 0), np.nanmean(mat[b], 0)
        m = np.isfinite(va) & np.isfinite(vb)
        if m.sum() >= 5:
            rs.append(spearmanr(va[m], vb[m]).correlation)
    r = np.nanmedian(rs)
    return (2*r)/(1+r) if np.isfinite(r) else np.nan


def decompose(mat):
    """mat = participants x sounds, binary with NaN where not observed."""
    n_j = np.sum(~np.isnan(mat), axis=0).astype(float)          # observations per sound
    with np.errstate(invalid="ignore"):
        p_j = np.nanmean(mat, axis=0)
    ok = np.isfinite(p_j) & (n_j > 1)
    p, n = p_j[ok], n_j[ok]
    var_total = np.var(p, ddof=1)
    var_noise = np.mean(p * (1 - p) / n)                        # binomial sampling noise
    var_signal = max(var_total - var_noise, 0.0)
    rel_implied = var_signal / var_total if var_total > 0 else np.nan
    return dict(n_sounds=int(ok.sum()), cov_med=float(np.median(n)), cov_min=float(n.min()),
                mean=float(np.mean(p)), sd=float(np.sqrt(var_total)),
                sd_noise=float(np.sqrt(var_noise)), sd_signal=float(np.sqrt(var_signal)),
                rel_implied=float(rel_implied))


for kind, idx in [("HITS", 0), ("FALSE ALARMS", 1)]:
    print(f"\n================ {kind} ================")
    print(f"{'cond':<14}{'group':<11}{'N':>4}{'obs/sound':>10}{'mean':>7}{'SD_tot':>8}"
          f"{'SD_noise':>9}{'SD_signal':>10}{'rel_impl':>9}{'rel_meas':>9}")
    for cond, clab in CONDS:
        for g, codes in GROUPS:
            h, f, _ = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
            mat = h if idx == 0 else f
            d = decompose(mat)
            rel = splithalf(mat)
            print(f"{clab:<14}{GLAB[g]:<11}{mat.shape[0]:>4}{d['cov_med']:>10.0f}"
                  f"{d['mean']:>7.2f}{d['sd']:>8.3f}{d['sd_noise']:>9.3f}"
                  f"{d['sd_signal']:>10.3f}{d['rel_implied']:>9.2f}{rel:>9.2f}")
        print()
