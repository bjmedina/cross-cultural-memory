#!/usr/bin/env python3
r"""Per-sound influence on the between-group correlation and its Fisher-z CI.

For each group pair (music condition), hit and FA:
  - full-sample Spearman r, with a Fisher-z 95% CI (sigma_z estimated by a
    bootstrap over sounds: CI = tanh(atanh(r) +/- 1.96 * SD(atanh(r_boot)))).
  - LEAVE-ONE-SOUND-OUT: drop each sound in turn, recompute r. The spread of those
    ~80 values shows whether any single sound drives the estimate; the largest
    |r_-i - r_full| is the most influential sound.
This is the item-level analogue of the participant-screen sweep: it asks whether
the correlation (and its CI) is robust to removing any one stimulus.
Screened sample (d'>=2, finished sessions)."""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT = HERE / "dprime_vs_isi_outputs"
CODES = {"US":("PRO","BOS","CAM"), "SB":("SBO","SNB","SBJ"),
         "Ts":("NVM","MAJ","MAN","NUM","NUV","CVR")}
COND = ("Globalized-Music", "Music")
PAIRS = [("US","SB","US-SB","#8E24AA"), ("US","Ts","US-Ts","#C62828"), ("SB","Ts","SB-Ts","#1565C0")]
NBOOT = 1500
rng = np.random.default_rng(0)


def persound(g, idx):
    h, f, it = build_hit_fa_matrices(list_matfiles(BASE, CODES[g], COND[0], 2.0, False))
    with np.errstate(invalid="ignore"):
        v = np.nanmean(h if idx == 0 else f, 0)
    return dict(zip(it, v))


def paired(a, b, idx):
    da, db = persound(a, idx), persound(b, idx)
    sh = [k for k in da if k in db and np.isfinite(da[k]) and np.isfinite(db[k])]
    return np.array([da[k] for k in sh]), np.array([db[k] for k in sh])


def fisher_ci(x, y):
    r = spearmanr(x, y).correlation
    n = len(x)
    z = np.array([np.arctanh(np.clip(spearmanr(x[i], y[i]).correlation, -0.999, 0.999))
                  for i in (rng.integers(0, n, n) for _ in range(NBOOT))])
    sd = np.nanstd(z)
    return r, np.tanh(np.arctanh(r) - 1.96*sd), np.tanh(np.arctanh(r) + 1.96*sd)


def loo(x, y):
    n = len(x)
    return np.array([spearmanr(np.delete(x, i), np.delete(y, i)).correlation for i in range(n)])


import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, axes = plt.subplots(1, 2, figsize=(12, 5), sharey=True)
print(f"{'meas':<5}{'pair':<7}{'N':>4}{'r_full':>8}{'Fisher 95% CI':>18}{'max |dr| (1 sound)':>20}")
for ax, (idx, mlab) in zip(axes, [(0, "hit rate"), (1, "FA rate")]):
    for k, (a, b, plab, col) in enumerate(PAIRS):
        x, y = paired(a, b, idx)
        r, lo, hi = fisher_ci(x, y)
        lv = loo(x, y)
        maxinf = np.max(np.abs(lv - r))
        ax.scatter(np.random.normal(k, 0.06, len(lv)), lv, s=10, color=col, alpha=0.35, zorder=2)
        ax.errorbar(k, r, yerr=[[r-lo],[hi-r]], fmt="o", color=col, ms=9, capsize=4, lw=1.6, zorder=3)
        print(f"{mlab:<5}{plab:<7}{len(x):>4}{r:>8.2f}{f'[{lo:.2f},{hi:.2f}]':>18}{maxinf:>20.3f}")
    ax.axhline(0, color="#999", lw=1); ax.set_xticks(range(3))
    ax.set_xticklabels([p[2] for p in PAIRS], fontsize=10); ax.set_ylim(-0.4, 1)
    ax.set_title(f"Music, {mlab}", fontsize=11); ax.grid(axis="y", ls="--", alpha=0.3)
axes[0].set_ylabel("between-group Spearman r", fontsize=10)
axes[1].plot([], [], "o", color="#555", label="full-sample r (Fisher-z 95% CI)")
axes[1].scatter([], [], s=10, color="#555", alpha=0.5, label="leave-one-sound-out r (each dot = 1 sound dropped)")
axes[1].legend(fontsize=8, loc="lower right")
fig.suptitle("Per-sound influence: full-sample r with Fisher-z CI, vs leave-one-sound-out",
             fontsize=12.5, fontweight="bold")
fig.tight_layout(rect=[0,0,1,0.96])
fig.savefig(OUT/"leave_one_out_persound.png", dpi=160, bbox_inches="tight")
print("\nsaved leave_one_out_persound.png")
