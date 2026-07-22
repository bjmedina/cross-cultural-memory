#!/bin/bash
#SBATCH -J repr_analysis
#SBATCH -p ou_bcs_normal
#SBATCH -t 0-00:40:00
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=12G
#SBATCH -o slurm_logs/%x_%A.out
#SBATCH -e slurm_logs/%x_%A.err
# ----------------------------------------------------------------------
# run_analysis.sh -- kNN-confusability vs human FA analysis (CPU).
# Consumes representation/embeddings/*.npz; writes results/ CSVs + figures.
#   sbatch run_analysis.sh
# ----------------------------------------------------------------------
set -euo pipefail
module load miniforge/25.11.0-0
conda activate mem

REPR_DIR=/orcd/data/jhm/001/om2/bjmedina/cross-cultural-memory/Code/RecognitionMemory/Analysis-Scripts-v2/representation
cd "$REPR_DIR"
echo "host: $(hostname)"
python run_representation_analysis.py
