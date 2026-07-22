#!/usr/bin/env python3
"""Encode the 80 recognition-memory stimuli per condition at EVERY kell2018 layer.

Culture-blind: one group-independent embedding per sound per layer. A single
forward pass per sound captures relu0..relu4 + relufc. Embeddings are keyed by
the behavioral sound name (e.g. 'mem_stim_14.wav') and saved per condition per
layer as representation/embeddings/<Cond>__<layer>.npz.

The set of sounds to encode is defined by the BEHAVIORAL item list (what the
participants actually heard, screened), not by directory contents, so the
Industrial-Nature "first 80 of 91" selection is handled automatically and stays
aligned with the human false-alarm rates.

RUN ON A GPU NODE (see slurm-scripts/encode_representation.sh). time_avg=False
to match the memory model's noise geometry (the config in AGENT_PLAN).
"""
import os
import sys
import types
from pathlib import Path

import numpy as np

# --- cox mock (constants.py imports cox.store, which is not installed) --------
_cox = types.ModuleType("cox")
_store = types.ModuleType("cox.store")
_store.PYTORCH_STATE = "pytorch_state"
_cox.store = _store
sys.modules["cox"] = _cox
sys.modules["cox.store"] = _store

# --- paths -------------------------------------------------------------------
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))                       # for python.io
MEMORY_REPO = Path("/orcd/data/jhm/001/om2/bjmedina/auditory-memory/memory")
sys.path.insert(0, str(MEMORY_REPO))                       # for utls.*

from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402
from utls.runners_utils import build_encoder                # noqa: E402
import torch                                                # noqa: E402
sys.path.insert(0, str(HERE))                              # for repr_models
from repr_models import current_model, emb_dir             # noqa: E402

BASE = HERE.parents[3] / "Data" / "RecognitionMemory" / "Results"
CODES = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
         "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}

MT = Path("/orcd/data/jhm/001/om2/bjmedina/mindhive/mcdermott/www/"
          "mturk_stimuli/bjmedina")
# Condition -> wav directory, resolved from stimulusPresented in the .mat files.
COND_WAVDIR = {
    "Industrial-Nature": MT / "mem_exp_ind-nature_2025",
    "Globalized-Music": MT / "global-music-2025-n_80",
    "NHS": MT / "nhs-region-n_80",
}
# Model + layers + output dir come from the shared registry (REPR_MODEL selects).
MODEL_TAG, SPEC = current_model()
LAYERS = SPEC["layers"]
OUT = emb_dir(MODEL_TAG)

MODE = SPEC.get("mode", "cochdnn")
ENCODER_CFG = dict(encoder_type=SPEC["encoder_type"], model_name=SPEC["model_name"],
                   task=SPEC["task"], layer=LAYERS[0],
                   sr=SPEC.get("sr", 20000), duration=2.0, rms_level=0.05,
                   time_avg=False, device="cuda")


def behavioral_item_names(cond):
    """Canonical per-set sound names (union across groups), from behavior.

    Verified elsewhere to equal 80 and to be identical across groups; we take
    the union and sort for a stable, reproducible order.
    """
    names = set()
    for codes in CODES.values():
        _, _, items = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
        names |= set(items.tolist())
    return sorted(names)


def extract_all_layers(enc, wav_path):
    """One forward pass -> {layer: 1-D float32 numpy vector}."""
    y = enc._preprocess(str(wav_path))
    tmp = enc._write_temp_wav(y)
    try:
        sound = enc.process_sound(tmp)
        with torch.no_grad():
            (_, _, layer_returns), _ = enc.model(sound, with_latent=True)
        return {L: layer_returns[L].detach().float().cpu().numpy().reshape(-1)
                for L in LAYERS}
    finally:
        try:
            os.remove(tmp)
        except OSError:
            pass


def extract_single(enc, wav_path):
    """Single-embedding encoders (e.g. spectemp): encoder(path) -> {layer: vec}."""
    out = enc(str(wav_path))
    if isinstance(out, dict):
        out = out.get("embedding", out)
    v = (out.detach().float().cpu().numpy() if hasattr(out, "detach")
         else np.asarray(out)).reshape(-1)
    return {LAYERS[0]: v}


def build_clap():
    """Load the CLAP audio branch offline from the HF cache."""
    os.environ.setdefault("HF_HUB_OFFLINE", "1")
    os.environ.setdefault("TRANSFORMERS_OFFLINE", "1")
    from transformers import ClapModel, ClapProcessor
    model = ClapModel.from_pretrained(SPEC["model_name"]).eval().to("cuda")
    proc = ClapProcessor.from_pretrained(SPEC["model_name"])
    return (model, proc)


def extract_clap(clap, wav_path):
    """CLAP HTSAT: 4 spatially-pooled Swin stages + the 512-d projection."""
    import scipy.io.wavfile as wavio
    from scipy.signal import resample_poly
    model, proc = clap
    sr, y = wavio.read(str(wav_path))
    y = y.astype(np.float32)
    y = y / (np.abs(y).max() + 1e-9)
    if y.ndim > 1:
        y = y.mean(1)
    y48 = resample_poly(y, 48000, sr)
    inp = proc(audios=y48, sampling_rate=48000, return_tensors="pt")
    inp = {k: v.to("cuda") for k, v in inp.items() if k in ("input_features", "is_longer")}
    with torch.no_grad():
        out = model.audio_model(**inp, output_hidden_states=True)
        proj = model.get_audio_features(**inp)
    hs = out.hidden_states  # each (1, C, H, W)
    feats = {f"stage{i}": hs[i].mean(dim=(2, 3)).squeeze(0).float().cpu().numpy().reshape(-1)
             for i in range(4)}
    feats["proj"] = proj.squeeze(0).float().cpu().numpy().reshape(-1)
    return feats


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    print(f"model: {MODEL_TAG}  layers: {LAYERS}  mode: {MODE}", flush=True)
    if MODE == "clap":
        print("loading CLAP (offline from HF cache) ...", flush=True)
        enc = build_clap()
        extract = extract_clap
    else:
        if SPEC["encoder_type"] == "spectemp":
            # The top ERB center frequency drifts a hair above Nyquist (FP), which
            # scipy.signal.gammatone rejects. Clamp centers just below Nyquist.
            from utls import encoders as _enc
            _orig = _enc.SpectTempEncoder._make_erb_cfs  # staticmethod -> plain fn
            _enc.SpectTempEncoder._make_erb_cfs = staticmethod(
                lambda low_hz, high_hz, n: np.minimum(_orig(low_hz, high_hz, n),
                                                      high_hz - 1.0))
        print(f"building encoder ({SPEC['encoder_type']}, {SPEC['task']}) ...", flush=True)
        enc = build_encoder(ENCODER_CFG)
        extract = extract_all_layers if MODE == "cochdnn" else extract_single

    for cond, wavdir in COND_WAVDIR.items():
        names = behavioral_item_names(cond)
        missing = [n for n in names if not (wavdir / n).exists()]
        assert not missing, f"{cond}: {len(missing)} wavs missing on disk: {missing[:5]}"
        assert len(names) == 80, f"{cond}: expected 80 sounds, got {len(names)}"
        print(f"\n[{cond}] encoding {len(names)} sounds from {wavdir}", flush=True)

        per_layer = {L: {} for L in LAYERS}
        for i, name in enumerate(names):
            feats = extract(enc, wavdir / name)
            for L in LAYERS:
                per_layer[L][name] = feats[L].astype(np.float32)
            if i == 0:
                dims = {L: feats[L].shape[0] for L in LAYERS}
                print(f"  layer dims: {dims}", flush=True)
            if (i + 1) % 20 == 0:
                print(f"  {i + 1}/{len(names)}", flush=True)

        for L in LAYERS:
            out_path = OUT / f"{cond}__{L}.npz"
            np.savez(out_path, **per_layer[L])
            print(f"  saved {out_path.name} "
                  f"({len(per_layer[L])} sounds x {per_layer[L][names[0]].shape[0]} dim)",
                  flush=True)

    print("\nDONE. embeddings in", OUT, flush=True)


if __name__ == "__main__":
    main()
