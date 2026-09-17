#!/bin/bash
#SBATCH --job-name=phage-bc
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --time=12:00:00
#SBATCH --output=logs/%x_%A.out
#SBATCH --error=logs/%x_%A.err

set -euo pipefail
cd "${SLURM_SUBMIT_DIR}"
nvidia-smi
bash run_all.sh --config "${CONFIG:-config/config.yaml}" --from 1 --to 2
