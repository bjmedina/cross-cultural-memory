#!/usr/bin/env python3
r"""Representation-similarity model of false alarms.

THEORY. A false alarm on a foil is a novel sound mistaken for something recently
heard, so the per-sound false-alarm rate is a behavioral read-out of how similar a
sound is, in the listener's representational space, to the other sounds in the set.
If a DNN embedding captures that space, then a sound's *model confusability* (its
similarity to the other sounds in its set) should predict its human false-alarm rate.

THREE TESTS.
  (T1) Validation: does model confusability predict per-sound FA within a group?
  (T2) Shared vs culture-specific: a single, fixed (e.g. Western-exposed) model should
       predict the SHARED confusability. For world song (unfamiliar to all) it should
       predict every group about equally; for music it should predict the U.S. better
       than Tsimane' (a positive US-minus-Ts predictive gap) if the space is Western.
  (T3) Level of representation: run an EARLY layer (cochleagram / low-level acoustics,
       culture-general) and a LATE layer (learned categories, experience-dependent).
       Prediction: world-song FA is predicted by low-level features for all groups;
       music FA is predicted by high-level features for the U.S. more than Tsimane'.

WHAT RUNS WHERE. Encoding (cochdnn / kell2018) runs on the CLUSTER; save one embedding
per sound per layer, keyed by the behavioral sound name (e.g. 'mem_stim_14.wav'). This
script consumes those embeddings and the human false-alarm rates. Fill in
load_embeddings() with your cluster output format (see the two examples below).
"""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[3] / "Data" / "RecognitionMemory" / "Results"
CODES = {"US": ("PRO","BOS","CAM"), "SanBorja": ("SBO","SNB","SBJ"),
         "Tsimane": ("NVM","MAJ","MAN","NUM","NUV","CVR")}
GLAB = {"US":"U.S.","SanBorja":"San Borja","Tsimane":"Tsimane'"}
CONDS = [("Industrial-Nature","Environmental"),("Globalized-Music","Music"),("NHS","World song")]

# --- EDIT THIS: where your cluster embeddings live, and which layers to compare ---
EMB_DIR = HERE / "embeddings"          # put cluster output here (or point elsewhere)
LAYERS = ["relu0", "relu4"]            # e.g. an EARLY (low-level) and a LATE (learned) layer


def load_embeddings(layer: str, sound_names: list[str]) -> dict[str, np.ndarray]:
    """Return {sound_name: 1-D embedding vector} for one layer, aligned to sound_names.

    Two common cluster formats are supported; keep whichever matches your output.
      (A) one .npz per layer with arrays keyed by sound name:
            EMB_DIR/<layer>.npz  ->  np.load(...)[name]
      (B) one .npy per sound in a per-layer folder:
            EMB_DIR/<layer>/<name>.npy
    Vectors may be high-dimensional (kell2018 relu0 ~18k); they are flattened.
    """
    npz = EMB_DIR / f"{layer}.npz"
    if npz.exists():
        d = np.load(npz)
        return {n: np.asarray(d[n]).ravel() for n in sound_names if n in d}
    folder = EMB_DIR / layer
    if folder.is_dir():
        out = {}
        for n in sound_names:
            p = folder / f"{n}.npy"
            if p.exists():
                out[n] = np.load(p).ravel()
        return out
    raise FileNotFoundError(
        f"No embeddings for layer '{layer}' at {npz} or {folder}. "
        f"Encode the {len(sound_names)} sounds on the cluster and save them there.")


def per_sound_fa(cond, codes):
    """Human per-sound false-alarm rate for a group (screened, finished sessions)."""
    _, f, it = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
    with np.errstate(invalid="ignore"):
        v = np.nanmean(f, 0)
    return dict(zip(it, v))


def model_confusability(emb: dict[str, np.ndarray], metric: str = "euclidean",
                        k: int | None = 5) -> dict[str, float]:
    """Per-sound model confusability from the k NEAREST neighbors in the set, always
    signed so HIGHER = more confusable = predicts higher false-alarm rate.

    A false alarm happens when a sound is close to SOMETHING, not to everything, so we
    use nearest-neighbor structure: for each sound take its k nearest neighbors and
    average their distance (or similarity).
      k=1        -> nearest neighbor only (sharpest 'is there anything like it')
      k=5        -> DEFAULT, small-neighborhood robustness (sweep k=1,3,5)
      k=None     -> mean over ALL other sounds (the old global measure)
    metric='euclidean' (DEFAULT, matches the memory model's noise geometry): negative
        mean distance to the k nearest (closer = more confusable).
    metric='cosine' (robustness): mean cosine similarity to the k most similar.
    On L2-normalized embeddings the two give identical Spearman rankings."""
    names = list(emb)
    M = np.stack([emb[n] for n in names]).astype(float)
    if metric == "cosine":
        Mn = M / (np.linalg.norm(M, axis=1, keepdims=True) + 1e-12)
        S = Mn @ Mn.T
        np.fill_diagonal(S, np.nan)
        out = {}
        for i, n in enumerate(names):
            v = S[i][~np.isnan(S[i])]
            v = np.sort(v)[::-1][:k] if k else v      # top-k most similar
            out[n] = float(np.mean(v))
        return out
    sq = np.sum(M ** 2, axis=1)
    D = np.sqrt(np.clip(sq[:, None] + sq[None, :] - 2.0 * (M @ M.T), 0, None))
    np.fill_diagonal(D, np.nan)
    out = {}
    for i, n in enumerate(names):
        v = D[i][~np.isnan(D[i])]
        v = np.sort(v)[:k] if k else v                # k smallest distances
        out[n] = float(-np.mean(v))                   # closer = more confusable
    return out


def main():
    results = {}   # (layer, cond, group) -> (rho, n)
    for cond, clab in CONDS:
        # canonical sound-name list for this set (from behavior)
        _, _, items = build_hit_fa_matrices(list_matfiles(BASE, CODES["US"], cond, 2.0, False))
        fa = {g: per_sound_fa(cond, CODES[g]) for g in CODES}
        for layer in LAYERS:
            try:
                emb = load_embeddings(layer, list(items))
            except FileNotFoundError as e:
                print("[skip]", e); continue
            conf = model_confusability(emb)
            for g in CODES:
                sh = [n for n in conf if n in fa[g]
                      and np.isfinite(conf[n]) and np.isfinite(fa[g][n])]
                if len(sh) < 5:
                    continue
                x = np.array([conf[n] for n in sh]); y = np.array([fa[g][n] for n in sh])
                results[(layer, clab, g)] = (spearmanr(x, y).correlation, len(sh))

    if not results:
        print("\nNo embeddings found yet. Encode the sounds on the cluster, drop them in\n"
              f"{EMB_DIR}, then rerun. Expected sound names look like 'mem_stim_14.wav'.")
        return

    print(f"\n{'layer':<8}{'cond':<14}{'group':<10}{'rho(conf,FA)':>14}{'n':>5}")
    for (layer, clab, g), (rho, n) in results.items():
        print(f"{layer:<8}{clab:<14}{GLAB[g]:<10}{rho:>14.2f}{n:>5}")
    # US-minus-Tsimane' predictive gap per layer x condition (T2/T3)
    print(f"\n{'layer':<8}{'cond':<14}{'rho_US - rho_Ts (culture-specificity)':>40}")
    for layer in LAYERS:
        for cond, clab in CONDS:
            a = results.get((layer, clab, "US")); b = results.get((layer, clab, "Tsimane"))
            if a and b:
                print(f"{layer:<8}{clab:<14}{a[0]-b[0]:>40.2f}")

    # figure: predictive correlation by group, per condition, per layer
    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    GCOL = {"US":"#1f77b4","SanBorja":"#ff7f0e","Tsimane":"#2E7D32"}
    fig, axes = plt.subplots(1, len(LAYERS), figsize=(6.5*len(LAYERS), 4.6), sharey=True, squeeze=False)
    for c, layer in enumerate(LAYERS):
        ax = axes[0][c]; x = np.arange(len(CONDS)); w = 0.26
        for k, g in enumerate(CODES):
            vals = [results.get((layer, clab, g), (np.nan,))[0] for _, clab in CONDS]
            ax.bar(x+(k-1)*w, vals, w, color=GCOL[g], label=GLAB[g] if c == 0 else None)
        ax.axhline(0, color="#555", lw=1); ax.set_xticks(x)
        ax.set_xticklabels([clab for _, clab in CONDS], fontsize=9)
        ax.set_title(f"layer: {layer}", fontsize=11); ax.set_ylim(-0.2, 1); ax.grid(axis="y", ls="--", alpha=.3)
        if c == 0:
            ax.set_ylabel("rho(model confusability, human FA)", fontsize=10); ax.legend(fontsize=8)
    fig.suptitle("Does embedding similarity predict false alarms, and does it diverge by culture?",
                 fontsize=12, fontweight="bold")
    fig.tight_layout(rect=[0,0,1,0.96])
    fig.savefig(HERE/"representation_confusability.png", dpi=160, bbox_inches="tight")
    print("\nsaved representation_confusability.png")


if __name__ == "__main__":
    main()
