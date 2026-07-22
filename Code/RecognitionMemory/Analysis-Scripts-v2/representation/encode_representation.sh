#!/bin/bash
#SBATCH -J encode_repr
#SBATCH -p ou_bcs_normal
#SBATCH -t 0-01:30:00
#SBATCH -n 1
#SBATCH -c 4
#SBATCH --mem=32G
#SBATCH --gres=gpu:1
#SBATCH -o slurm_logs/%x_%A.out
#SBATCH -e slurm_logs/%x_%A.err
# ----------------------------------------------------------------------
# encode_representation.sh -- encode the 80 stimuli/condition at every
# kell2018 layer on a GPU node. Writes representation/embeddings/<Cond>__<L>.npz
#
# Usage (from Analysis-Scripts-v2/representation/):
#   sbatch encode_representation.sh
# ----------------------------------------------------------------------
set -euo pipefail
source /orcd/data/jhm/001/bjmedina/miniconda3/etc/profile.d/conda.sh
conda activate /orcd/data/jhm/001/bjmedina/miniconda3/envs/asr_312_312

REPR_DIR=/orcd/data/jhm/001/om2/bjmedina/cross-cultural-memory/Code/RecognitionMemory/Analysis-Scripts-v2/representation
cd "$REPR_DIR"

echo "host: $(hostname)"
python -c "import torch; print('cuda avail:', torch.cuda.is_available(), '| device:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'NONE')"
python encode_representation.py
