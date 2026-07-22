#!/usr/bin/env python3
"""Supplement: which simple acoustic features predict false alarms, per group?

Five intuitive, low-level descriptors per sound, computed with numpy/scipy (no
librosa): loudness, spectral centroid (where the energy sits in frequency),
noiselikeness (spectral flatness), roughness (fast amplitude modulation), and how
silent it is. For each sound set and group we correlate each feature with the
group's per-sound false-alarm rate (Spearman, bootstrap CI over sounds). This asks
whether plain acoustics predict false alarms, and whether any feature does so
differently across cultures.
"""
import sys
from pathlib import Path

import numpy as np
from scipy.io import wavfile
from scipy import signal
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from run_representation_analysis import CODES, GLAB, canonical_names, per_sound_fa  # noqa: E402

MT = Path("/orcd/data/jhm/001/om2/bjmedina/mindhive/mcdermott/www/"
          "mturk_stimuli/bjmedina")
COND_WAVDIR = {
    "Industrial-Nature": MT / "mem_exp_ind-nature_2025",
    "Globalized-Music": MT / "global-music-2025-n_80",
    "NHS": MT / "nhs-region-n_80",
}
CONDS = [("Industrial-Nature", "Environmental"), ("Globalized-Music", "Music"),
         ("NHS", "World song")]
FEATURES = ["loudness", "centroid", "noiselike", "roughness", "silence"]
FLABEL = {"loudness": "loudness", "centroid": "spectral\ncentroid",
          "noiselike": "noise-\nlikeness", "roughness": "roughness",
          "silence": "silence"}
GCOL = {"U.S.": "#1f77b4", "San Borja": "#ff7f0e", "Tsimane'": "#2E7D32"}
OUT = HERE / "results" / "_summary"
CH3 = Path("/orcd/data/jhm/001/om2/bjmedina/auditory-memory/memory/docs/"
           "thesis/figures/ch3")
EPS = 1e-10


def load_wav(path):
    sr, x = wavfile.read(path)
    x = x.astype(np.float64)
    if x.ndim > 1:
        x = x.mean(axis=1)
    if np.issubdtype(np.asarray(x).dtype, np.floating) and np.max(np.abs(x)) > 1.5:
        pass
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m  # peak-normalize so loudness is a within-clip dynamic measure
    return sr, x


def features(path):
    sr, x = load_wav(path)
    f, _, Z = signal.stft(x, fs=sr, nperseg=1024, noverlap=512)
    P = (np.abs(Z) ** 2)                      # freq x time power
    frame_e = P.sum(axis=0)                   # per-frame energy
    Ptot = P.sum() + EPS
    # spectral centroid (energy-weighted mean frequency, Hz)
    centroid = float((f[:, None] * P).sum() / Ptot)
    # noiselikeness: spectral flatness averaged over voiced frames
    voiced = frame_e > (0.05 * frame_e.max() + EPS)
    Pv = P[:, voiced] + EPS
    flat = np.exp(np.log(Pv).mean(axis=0)) / Pv.mean(axis=0)
    noiselike = float(flat.mean()) if flat.size else np.nan
    # loudness: crest / dynamic level of the clip (dB of RMS relative to peak=1)
    rms = np.sqrt(np.mean(x ** 2) + EPS)
    loudness = float(20 * np.log10(rms + EPS))
    # roughness: fraction of temporal-envelope modulation energy in 30-150 Hz
    env = np.abs(signal.hilbert(x))
    env = env - env.mean()
    E = np.abs(np.fft.rfft(env)) ** 2
    ef = np.fft.rfftfreq(len(env), d=1.0 / sr)
    band = (ef >= 30) & (ef <= 150)
    roughness = float(E[band].sum() / (E.sum() + EPS))
    # silence: fraction of frames below -40 dB relative to the loudest frame
    fe_db = 10 * np.log10(frame_e + EPS)
    silence = float(np.mean(fe_db < (fe_db.max() - 40)))
    return dict(loudness=loudness, centroid=centroid, noiselike=noiselike,
                roughness=roughness, silence=silence)


def boot_rho(a, b, n=2000, seed=20260709):
    rng = np.random.default_rng(seed)
    m = np.isfinite(a) & np.isfinite(b)
    a, b = a[m], b[m]
    if len(a) < 5:
        return np.nan, np.nan, np.nan
    obs = spearmanr(a, b).correlation
    idx = rng.integers(0, len(a), size=(n, len(a)))
    bs = np.array([spearmanr(a[i], b[i]).correlation for i in idx])
    return float(obs), float(np.nanpercentile(bs, 2.5)), float(np.nanpercentile(bs, 97.5))


def main():
    import csv
    OUT.mkdir(parents=True, exist_ok=True)
    rows = []
    feat_by_cond = {}
    for cond, clab in CONDS:
        names = canonical_names(cond)
        wavdir = COND_WAVDIR[cond]
        feats, kept = {k: [] for k in FEATURES}, []
        for nm in names:
            p = wavdir / nm
            if not p.exists():
                continue
            try:
                fv = features(p)
            except Exception as e:
                print(f"  skip {nm}: {e}", flush=True)
                continue
            kept.append(nm)
            for k in FEATURES:
                feats[k].append(fv[k])
        feat_by_cond[cond] = (kept, {k: np.array(feats[k]) for k in FEATURES})
        print(f"[{clab}] features for {len(kept)}/{len(names)} sounds", flush=True)
        for g, codes in CODES.items():
            gl = GLAB[g]
            fa = per_sound_fa(cond, codes)
            y = np.array([fa.get(nm, np.nan) for nm in kept])
            for k in FEATURES:
                obs, lo, hi = boot_rho(feat_by_cond[cond][1][k], y)
                rows.append(dict(condition=clab, group=gl, feature=k,
                                 rho=obs, ci_lo=lo, ci_hi=hi, n=len(kept)))

    with open(OUT / "acoustic_feature_fa.csv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=["condition", "group", "feature",
                                           "rho", "ci_lo", "ci_hi", "n"])
        w.writeheader()
        for r in rows:
            w.writerow(r)
    print("wrote acoustic_feature_fa.csv", flush=True)
    _figure(rows)


def _figure(rows):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    conds = ["Environmental", "Music", "World song"]
    groups = ["U.S.", "San Borja", "Tsimane'"]
    fig, axes = plt.subplots(1, 3, figsize=(15, 4.6), sharey=True)
    x = np.arange(len(FEATURES))
    w = 0.26
    for ax, cond in zip(axes, conds):
        for gi, g in enumerate(groups):
            vals = [next((r for r in rows if r["condition"] == cond
                          and r["group"] == g and r["feature"] == k), {}) for k in FEATURES]
            y = [v.get("rho", np.nan) for v in vals]
            lo = [v.get("rho", np.nan) - v.get("ci_lo", np.nan) for v in vals]
            hi = [v.get("ci_hi", np.nan) - v.get("rho", np.nan) for v in vals]
            ax.bar(x + (gi - 1) * w, y, w, yerr=[lo, hi], capsize=2,
                   color=GCOL[g], label=g, alpha=0.9, error_kw=dict(lw=0.8))
        ax.axhline(0, color="#555", lw=1)
        ax.set_xticks(x); ax.set_xticklabels([FLABEL[k] for k in FEATURES], fontsize=8)
        ax.set_title(cond, fontsize=11); ax.grid(axis="y", ls="--", alpha=0.3)
        ax.set_ylim(-0.8, 0.8)
    axes[0].set_ylabel(r"Spearman $\rho$(feature, false-alarm rate)", fontsize=10)
    axes[-1].legend(fontsize=8.5, loc="upper right", frameon=False)
    fig.tight_layout()
    fig.savefig(OUT / "acoustic_feature_fa.png", dpi=150, bbox_inches="tight")
    if CH3.is_dir():
        fig.savefig(CH3 / "acoustic_features.pdf", bbox_inches="tight")
        print("wrote", CH3 / "acoustic_features.pdf", flush=True)
    plt.close(fig)
    print("wrote acoustic_feature_fa.png", flush=True)


if __name__ == "__main__":
    main()
