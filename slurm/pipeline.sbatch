#!/bin/bash
#SBATCH --job-name=phage-wgs
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --output=logs/%x_%A.out
#SBATCH --error=logs/%x_%A.err

# Pipeline completo salvo el basecalling (que requiere GPU; ver basecall.sbatch)
set -euo pipefail
cd "${SLURM_SUBMIT_DIR}"
echo "Trabajo ${SLURM_JOB_ID} en $(hostname) — inicio $(date -Iseconds)"
bash run_all.sh --config "${CONFIG:-config/config.yaml}" --skip-basecall --threads "${SLURM_CPUS_PER_TASK}"
echo "Fin $(date -Iseconds)"
