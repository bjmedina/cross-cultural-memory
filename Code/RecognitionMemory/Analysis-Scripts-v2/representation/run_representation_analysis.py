#!/usr/bin/env python3
r"""Representation-similarity model of cross-cultural false alarms (refined design).

Consumes the culture-blind embeddings produced by encode_representation.py and
tests whether DNN confusability predicts per-sound human false-alarm (FA) rates,
and whether that prediction diverges by culture in the way the behavior does.

DESIGN (see representation/AGENT_PLAN.md and the chapter-3 brief):
  1. One culture-blind network; every sound encoded at EVERY layer.
  2. Confusability from PAIRWISE DISTANCES via kNN: per layer, build the
     sound x sound distance matrix; a sound's confusability = mean distance to
     its k NEAREST neighbors, NEGATED so closer = more confusable. A false alarm
     happens when a sound is close to SOMETHING, not everything. Default metric
     EUCLIDEAN (matches the memory model's noise geometry); cosine as robustness.
     Sweep k = 1, 3, 5.
  3. Correlate PER GROUP, PER LAYER: confusability (shared across groups) vs each
     group's per-sound FA, Spearman across the ~80 sounds. Bootstrap over SOUNDS
     for 95% CIs (stimulus-limited; effective N = number of sounds).
  4. Read out: (a) depth curves rho(layer) per group, one panel per condition;
     (b) the gap rho_US - rho_Ts vs layer, one line per condition.

Reliability: the observed rho is attenuated by the human FA reliability (the
model is deterministic, reliability 1). We report the "corrected for attenuation"
value rho / sqrt(sb_fa) beside the observed rho, and flag cells with sb_fa < 0.5.

Outputs (in representation/results/):
  representation_results.csv     full rho + CI sweep (layer x cond x group x k x metric)
  representation_gap.csv         rho_US - rho_Ts + CI (layer x cond x k x metric)
  figures/repr_depth_curves.png  depth curves, one panel per condition
  figures/repr_gap_vs_layer.png  the US-minus-Tsimane' gap vs layer, per condition
"""
import sys
import csv
from pathlib import Path

import numpy as np
from scipy.stats import spearmanr
from scipy.spatial.distance import cdist

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
sys.path.insert(0, str(HERE))
from python.io import (list_matfiles, build_hit_fa_matrices,  # noqa: E402
                       load_group, _stim_basename)
from repr_models import current_model, emb_dir  # noqa: E402
import scipy.io as sio  # noqa: E402

BASE = HERE.parents[3] / "Data" / "RecognitionMemory" / "Results"
CODES = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
         "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
GLAB = {"US": "U.S.", "SanBorja": "San Borja", "Tsimane": "Tsimane'"}
GCOL = {"US": "#1f77b4", "SanBorja": "#ff7f0e", "Tsimane": "#2E7D32"}
CONDS = [("Industrial-Nature", "Environmental"),
         ("Globalized-Music", "Music"),
         ("NHS", "World song")]
CCOL = {"Environmental": "#8c564b", "Music": "#9467bd", "World song": "#17becf"}

# Model, layers, and embedding dir come from the shared registry (REPR_MODEL env).
# Full depth sweep for the selected model; results go to a per-model subdir.
MODEL_TAG, SPEC = current_model()
EMB_DIR = emb_dir(MODEL_TAG)
LAYERS = SPEC["layers"]
RES_DIR = HERE / "results" / MODEL_TAG
FIG_DIR = RES_DIR / "figures"
KS = [1, 3, 5]
PRIMARY_K = 3
METRICS = ["euclidean", "cosine"]
PRIMARY_METRIC = "euclidean"
N_BOOT = 5000
SEED = 20260708


# --------------------------------------------------------------------------- #
# loading
# --------------------------------------------------------------------------- #
def load_embeddings(cond, layer, names):
    """{name: 1-D vector} for one condition+layer, aligned to `names`."""
    npz = EMB_DIR / f"{cond}__{layer}.npz"
    if not npz.exists():
        raise FileNotFoundError(
            f"missing embeddings {npz.name}; run encode_representation.py first")
    d = np.load(npz)
    return {n: np.asarray(d[n]).ravel() for n in names if n in d.files}


def per_sound_fa(cond, codes):
    """Human per-sound FA rate for a group (screened, finished sessions)."""
    _, f, it = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
    with np.errstate(invalid="ignore"):
        v = np.nanmean(f, 0)
    return dict(zip([str(x) for x in it], v))


def canonical_names(cond):
    _, _, items = build_hit_fa_matrices(list_matfiles(BASE, CODES["US"], cond, 2.0, False))
    return [str(x) for x in items]


# --------------------------------------------------------------------------- #
# confusability -- IN CONTEXT: kNN geometry uses only the sounds a listener had
# already heard at that point in the sequence. Presentation order is randomized
# per participant, so we average each sound's in-context kNN over that GROUP's
# own participants (each group scored against its own experienced contexts).
# --------------------------------------------------------------------------- #
def load_sequences(cond, codes):
    """Per-participant (ordered stim basenames, foil mask) for one group."""
    seqs = []
    for f in list_matfiles(BASE, codes, cond, 2.0, False):
        d = sio.loadmat(f, variable_names=["stimulusPresented", "repeatPosition"])
        stims = [_stim_basename(s) for s in np.array(d["stimulusPresented"]).ravel()]
        rp = np.asarray(d["repeatPosition"]).ravel().astype(float)
        seqs.append((stims, ~np.isfinite(rp)))
    return seqs


def incontext_confusability(D, names, seqs, k):
    """Per-sound in-context confusability for one group, aligned to `names`.

    D: precomputed pairwise distance matrix over `names`. For each foil
    presentation, take the probe's mean distance to its k nearest neighbours among
    the DISTINCT sounds heard earlier in that same sequence, negate, and average
    over all of the group's presentations of that sound. Returns {name: value}.
    """
    idx = {n: i for i, n in enumerate(names)}
    acc = {n: [] for n in names}
    for stims, foil in seqs:
        seen, seen_set = [], set()
        for t, s in enumerate(stims):
            si = idx.get(s)
            if foil[t] and si is not None and seen:
                ctx = [j for j in seen if j != si]
                if ctx:
                    acc[s].append(-np.sort(D[si, ctx])[:min(k, len(ctx))].mean())
            if si is not None and si not in seen_set:
                seen.append(si); seen_set.add(si)
    return {n: (float(np.mean(acc[n])) if acc[n] else np.nan) for n in names}


# --------------------------------------------------------------------------- #
# statistics
# --------------------------------------------------------------------------- #
def boot_rho_ci(x, y, rng, n=N_BOOT):
    """Spearman(x, y) with a 95% CI bootstrapped over SOUNDS (paired resample)."""
    x = np.asarray(x, float); y = np.asarray(y, float)
    obs = spearmanr(x, y).correlation
    m = len(x)
    idx = rng.integers(0, m, size=(n, m))
    boots = np.empty(n)
    for b in range(n):
        boots[b] = spearmanr(x[idx[b]], y[idx[b]]).correlation
    lo, hi = np.nanpercentile(boots, [2.5, 97.5])
    return obs, lo, hi


# Exposure-ordered group pairs. The gradient prediction (Western-exposed model)
# is rho_US >= rho_SanBorja >= rho_Tsimane for music, i.e. all three gaps > 0,
# with San Borja intermediate; flat/zero for world song.
PAIRS = [("US", "Tsimane", "US-Tsimane"),
         ("US", "SanBorja", "US-SanBorja"),
         ("SanBorja", "Tsimane", "SanBorja-Tsimane")]


def boot_pair_gaps(xs, ys, rng, n=N_BOOT):
    """All pairwise rho gaps from ONE joint sound-resample.

    xs, ys: {group: array} aligned to the common support (each group has its own
    in-context confusability x_g and its own FA y_g). One shared set of resampled
    sound indices is applied to every group so the pair gaps share the draw.
    Returns {pair_label: (obs_gap, ci_lo, ci_hi)} for the exposure-ordered PAIRS,
    plus {group: (obs_rho, lo, hi)}.
    """
    m = len(next(iter(ys.values())))
    idx = rng.integers(0, m, size=(n, m))
    obs_rho, boot_rho = {}, {}
    for g, y in ys.items():
        x = np.asarray(xs[g], float)
        y = np.asarray(y, float)
        obs_rho[g] = spearmanr(x, y).correlation
        br = np.empty(n)
        for b in range(n):
            br[b] = spearmanr(x[idx[b]], y[idx[b]]).correlation
        boot_rho[g] = br
    gaps = {}
    for a, b_, lab in PAIRS:
        diff = boot_rho[a] - boot_rho[b_]
        lo, hi = np.nanpercentile(diff, [2.5, 97.5])
        gaps[lab] = (obs_rho[a] - obs_rho[b_], lo, hi)
    grho = {g: (obs_rho[g], *np.nanpercentile(boot_rho[g], [2.5, 97.5])) for g in ys}
    return gaps, grho


# --------------------------------------------------------------------------- #
# main
# --------------------------------------------------------------------------- #
def main():
    RES_DIR.mkdir(parents=True, exist_ok=True)
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    rng = np.random.default_rng(SEED)

    # human FA reliability (Spearman-Brown split-half) per group x condition.
    print("computing human FA split-half reliability (for attenuation) ...", flush=True)
    rel = {}
    for cond, clab in CONDS:
        for g, codes in CODES.items():
            r = load_group(BASE, codes, cond, 2.0, False, n_splits=2000, verbose=False)
            rel[(clab, g)] = float(r.sb_fa) if r is not None else np.nan

    rows = []          # per group cell
    gaprows = []       # per condition gap cell
    depth = {}         # (clab, g, metric, k) -> [(rho, lo, hi) per layer]
    gapdepth = {}      # (clab, metric, k)    -> [(gap, lo, hi) per layer]

    for cond, clab in CONDS:
        names = canonical_names(cond)
        fa = {g: per_sound_fa(cond, CODES[g]) for g in CODES}
        seqs = {g: load_sequences(cond, CODES[g]) for g in CODES}
        for layer in LAYERS:
            emb = load_embeddings(cond, layer, names)
            shared = [n for n in names if n in emb]
            assert len(shared) == 80, f"{cond}/{layer}: {len(shared)} embeddings (expected 80)"
            M = np.stack([emb[n] for n in shared]).astype(np.float64)
            for metric in METRICS:
                D = cdist(M, M, metric=metric)   # precompute once per metric
                for k in KS:
                    # per-group in-context confusability (each group's own contexts)
                    confg = {g: incontext_confusability(D, shared, seqs[g], k)
                             for g in CODES}
                    y = {}
                    for g in CODES:
                        cg = confg[g]
                        sh = [n for n in shared
                              if np.isfinite(cg[n]) and np.isfinite(fa[g].get(n, np.nan))]
                        y[g] = (np.array([cg[n] for n in sh]),
                                np.array([fa[g][n] for n in sh]), sh)
                    for g in CODES:
                        xg, yg, sh = y[g]
                        rho, lo, hi = boot_rho_ci(xg, yg, rng)
                        rl = rel[(clab, g)]
                        corr = rho / np.sqrt(rl) if np.isfinite(rl) and rl > 0 else np.nan
                        rows.append(dict(cond=clab, layer=layer, group=GLAB[g],
                                         metric=metric, k=k, n=len(sh),
                                         rho=rho, ci_lo=lo, ci_hi=hi,
                                         fa_reliability=rl, rho_corrected=corr,
                                         low_reliability=int(np.isfinite(rl) and rl < 0.5)))
                        depth.setdefault((clab, g, metric, k), []).append((rho, lo, hi))
                    # all pairwise gaps on the common support (finite in ALL groups)
                    common = [n for n in shared
                              if all(np.isfinite(confg[g][n])
                                     and np.isfinite(fa[g].get(n, np.nan)) for g in CODES)]
                    xs = {g: np.array([confg[g][n] for n in common]) for g in CODES}
                    ys = {g: np.array([fa[g][n] for n in common]) for g in CODES}
                    gaps, _ = boot_pair_gaps(xs, ys, rng)
                    for lab, (gap, glo, ghi) in gaps.items():
                        gaprows.append(dict(cond=clab, layer=layer, metric=metric, k=k,
                                            pair=lab, n=len(common),
                                            gap=gap, ci_lo=glo, ci_hi=ghi))
                        if lab == "US-Tsimane":
                            gapdepth.setdefault((clab, metric, k), []).append((gap, glo, ghi))
        print(f"  done {clab}", flush=True)

    _write_csv(RES_DIR / "representation_results.csv", rows,
               ["cond", "layer", "group", "metric", "k", "n", "rho",
                "ci_lo", "ci_hi", "fa_reliability", "rho_corrected", "low_reliability"])
    _write_csv(RES_DIR / "representation_gap.csv", gaprows,
               ["cond", "layer", "metric", "k", "pair", "n", "gap", "ci_lo", "ci_hi"])

    _print_primary_tables(rows, gaprows)
    _fig_depth(depth)
    _fig_gap(gapdepth)
    print("\nwrote results + figures to", RES_DIR, flush=True)


def _write_csv(path, rows, cols):
    with open(path, "w", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=cols)
        w.writeheader()
        for r in rows:
            w.writerow({c: r[c] for c in cols})


def _print_primary_tables(rows, gaprows):
    print(f"\n=== rho(confusability, FA), metric={PRIMARY_METRIC}, k={PRIMARY_K} ===")
    print(f"{'cond':<14}{'layer':<8}{'group':<10}{'rho':>7}{'  95% CI':>16}"
          f"{'rel':>7}{'corr':>8}{'flag':>6}")
    for r in rows:
        if r["metric"] != PRIMARY_METRIC or r["k"] != PRIMARY_K:
            continue
        flag = "LOWREL" if r["low_reliability"] else ""
        print(f"{r['cond']:<14}{r['layer']:<8}{r['group']:<10}{r['rho']:>7.2f}"
              f"  [{r['ci_lo']:>5.2f},{r['ci_hi']:>5.2f}]"
              f"{r['fa_reliability']:>7.2f}{r['rho_corrected']:>8.2f}{flag:>6}")
    print(f"\n=== pairwise gaps (exposure gradient), metric={PRIMARY_METRIC}, "
          f"k={PRIMARY_K} ===")
    print(f"{'cond':<14}{'layer':<8}{'pair':<18}{'gap':>7}{'  95% CI':>16}")
    for r in gaprows:
        if r["metric"] != PRIMARY_METRIC or r["k"] != PRIMARY_K:
            continue
        print(f"{r['cond']:<14}{r['layer']:<8}{r['pair']:<18}{r['gap']:>7.2f}"
              f"  [{r['ci_lo']:>5.2f},{r['ci_hi']:>5.2f}]")


def _fig_depth(depth):
    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    xs = np.arange(len(LAYERS))
    fig, axes = plt.subplots(1, len(CONDS), figsize=(5.2 * len(CONDS), 4.4),
                             sharey=True, squeeze=False)
    for c, (cond, clab) in enumerate(CONDS):
        ax = axes[0][c]
        for g in CODES:
            seq = depth.get((clab, g, PRIMARY_METRIC, PRIMARY_K))
            if not seq:
                continue
            rho = [s[0] for s in seq]; lo = [s[1] for s in seq]; hi = [s[2] for s in seq]
            ax.plot(xs, rho, "-o", color=GCOL[g], label=GLAB[g], lw=2, ms=5)
            ax.fill_between(xs, lo, hi, color=GCOL[g], alpha=0.15)
        ax.axhline(0, color="#555", lw=1)
        ax.set_xticks(xs); ax.set_xticklabels(LAYERS, rotation=45, fontsize=8)
        ax.set_title(clab, fontsize=11); ax.grid(axis="y", ls="--", alpha=.3)
        ax.set_xlabel("layer (early -> late)", fontsize=9)
        if c == 0:
            ax.set_ylabel("rho(model confusability, human FA)", fontsize=10)
            ax.legend(fontsize=8, loc="upper left")
    fig.suptitle(f"Does DNN confusability predict false alarms, by depth?  "
                 f"(metric={PRIMARY_METRIC}, k={PRIMARY_K})",
                 fontsize=12, fontweight="bold")
    fig.tight_layout(rect=[0, 0, 1, 0.95])
    fig.savefig(FIG_DIR / "repr_depth_curves.png", dpi=160, bbox_inches="tight")
    plt.close(fig)


def _fig_gap(gapdepth):
    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    xs = np.arange(len(LAYERS))
    fig, ax = plt.subplots(figsize=(6.4, 4.6))
    for cond, clab in CONDS:
        seq = gapdepth.get((clab, PRIMARY_METRIC, PRIMARY_K))
        if not seq:
            continue
        gap = [s[0] for s in seq]; lo = [s[1] for s in seq]; hi = [s[2] for s in seq]
        ax.plot(xs, gap, "-o", color=CCOL[clab], label=clab, lw=2, ms=5)
        ax.fill_between(xs, lo, hi, color=CCOL[clab], alpha=0.15)
    ax.axhline(0, color="#555", lw=1)
    ax.set_xticks(xs); ax.set_xticklabels(LAYERS, rotation=45, fontsize=8)
    ax.set_xlabel("layer (early -> late)", fontsize=10)
    ax.set_ylabel("rho_US - rho_Tsimane'", fontsize=10)
    ax.set_title(f"Culture-specificity of prediction vs depth\n"
                 f"(metric={PRIMARY_METRIC}, k={PRIMARY_K})", fontsize=11)
    ax.grid(axis="y", ls="--", alpha=.3); ax.legend(fontsize=9)
    fig.tight_layout()
    fig.savefig(FIG_DIR / "repr_gap_vs_layer.png", dpi=160, bbox_inches="tight")
    plt.close(fig)


if __name__ == "__main__":
    main()
