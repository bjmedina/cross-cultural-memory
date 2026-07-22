"""Shared model registry for the representation-similarity pipeline.

One place that both encode_representation.py and run_representation_analysis.py
agree on: which networks/layers exist, and where embeddings live. Embeddings are
stored per model under EMB_ROOT/<model_tag>/<Cond>__<layer>.npz.

Select a model at run time with the REPR_MODEL env var, e.g.
    REPR_MODEL=resnet50_word_speaker_audioset python encode_representation.py
Default is the kell2018 multi-task model.
"""
import os
from pathlib import Path

# Embeddings root (large + regenerable; kept under HOME, not the full jhm alloc).
EMB_ROOT = Path(os.environ.get("REPR_EMB_ROOT", "/home/bjmedina/repr_embeddings"))

# mode: how encode_representation.py extracts features.
#   "cochdnn" - one forward pass, all layers from layer_returns (kell2018/resnet50)
#   "single"  - encoder(filepath) -> one embedding (spectemp low-level baseline)
#   "clap"    - HuggingFace CLAP audio branch, hidden states + projection
MODELS = {
    # input_after_preproc = the cochleagram front-end (pre-weights, identical
    # across training), used as the in-pipeline low-level acoustic baseline.
    "kell2018_word_speaker_audioset": dict(
        encoder_type="kell2018", model_name="kell2018", task="word_speaker_audioset",
        mode="cochdnn", sr=20000,
        layers=["input_after_preproc", "relu0", "relu1", "relu2", "relu3",
                "relu4", "relufc"]),
    "resnet50_word_speaker_audioset": dict(
        encoder_type="resnet50", model_name="resnet50", task="word_speaker_audioset",
        mode="cochdnn", sr=20000,
        layers=["input_after_preproc", "layer1", "layer2", "layer3", "layer4"]),
    # single-task training paradigms (same kell2018 arch, different diet):
    #   audioset  = large sound corpus incl. music;  speaker/word = speech.
    "kell2018_audioset": dict(
        encoder_type="kell2018", model_name="kell2018", task="audioset",
        mode="cochdnn", sr=20000,
        layers=["relu0", "relu1", "relu2", "relu3", "relu4", "relufc"]),
    "kell2018_speaker": dict(
        encoder_type="kell2018", model_name="kell2018", task="speaker",
        mode="cochdnn", sr=20000,
        layers=["relu0", "relu1", "relu2", "relu3", "relu4", "relufc"]),
    "kell2018_word": dict(
        encoder_type="kell2018", model_name="kell2018", task="word",
        mode="cochdnn", sr=20000,
        layers=["relu0", "relu1", "relu2", "relu3", "relu4", "relufc"]),
    # untrained controls (same architecture, random weights) -> H3 test
    "kell2018_word_speaker_audioset_randomize_weights": dict(
        encoder_type="kell2018", model_name="kell2018",
        task="word_speaker_audioset_randomize_weights", mode="cochdnn", sr=20000,
        layers=["relu0", "relu1", "relu2", "relu3", "relu4", "relufc"]),
    "resnet50_word_speaker_audioset_randomize_weights": dict(
        encoder_type="resnet50", model_name="resnet50",
        task="word_speaker_audioset_randomize_weights", mode="cochdnn", sr=20000,
        layers=["layer1", "layer2", "layer3", "layer4"]),
    # (spectemp encoder dropped; input_after_preproc is the low-level anchor.)
    # CLAP audio branch (HTSAT Swin transformer): 4 spatially-pooled stages +
    # the 512-d contrastive projection. Music-aware, high-level.
    "CLAP_htsat_unfused": dict(
        encoder_type="clap", model_name="laion/clap-htsat-unfused", task=None,
        mode="clap", sr=48000,
        layers=["stage0", "stage1", "stage2", "stage3", "proj"]),
}
DEFAULT_MODEL = "kell2018_word_speaker_audioset"


def current_model():
    """(tag, spec) chosen by $REPR_MODEL, defaulting to the kell2018 multi-task net."""
    tag = os.environ.get("REPR_MODEL", DEFAULT_MODEL)
    if tag not in MODELS:
        raise SystemExit(f"unknown REPR_MODEL={tag!r}; choose from {list(MODELS)}")
    return tag, MODELS[tag]


def emb_dir(tag):
    return EMB_ROOT / tag
