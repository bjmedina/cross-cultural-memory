#!/bin/bash
#SBATCH -J deck_repro
#SBATCH -p ou_bcs_normal
#SBATCH -t 0-00:40:00
#SBATCH -n 1
#SBATCH -c 2
#SBATCH --mem=8G
#SBATCH -o /orcd/data/jhm/001/om2/bjmedina/cross-cultural-memory/Code/RecognitionMemory/Analysis-Scripts-v2/bolivia_recreation_outputs/logs/deck_repro_%j.out
#SBATCH -e /orcd/data/jhm/001/om2/bjmedina/cross-cultural-memory/Code/RecognitionMemory/Analysis-Scripts-v2/bolivia_recreation_outputs/logs/deck_repro_%j.out
module load matlab/matlab-2023b
cd /orcd/data/jhm/001/om2/bjmedina/cross-cultural-memory/Code/RecognitionMemory/Analysis-Scripts-v2
echo "### host: $(hostname)  matlab: $(which matlab)"
matlab -batch "run_deck_repro"
echo "### DONE sbatch wrapper (exit $?)"
