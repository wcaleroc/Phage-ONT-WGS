#!/bin/bash
#SBATCH --job-name=phage-array
#SBATCH --partition=cpu
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=24:00:00
#SBATCH --array=1-2
#SBATCH --output=logs/%x_%A_%a.out

# Procesamiento paralelo de varias muestras, una por tarea del array.
# Ajustar --array al número de filas de datos en samples.tsv
set -euo pipefail
cd "${SLURM_SUBMIT_DIR}"
SAMPLES=config/samples.tsv
SAMPLE=$(grep -v '^#' "$SAMPLES" | sed -n "$((SLURM_ARRAY_TASK_ID+1))p" | cut -f1)
[[ -n "$SAMPLE" ]] || { echo "Sin muestra para la tarea ${SLURM_ARRAY_TASK_ID}"; exit 0; }
echo "Procesando ${SAMPLE}"
bash run_all.sh --sample "$SAMPLE" --skip-basecall --threads "${SLURM_CPUS_PER_TASK}"
