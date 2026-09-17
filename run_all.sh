#!/usr/bin/env bash
# =============================================================================
# run_all.sh — orquestador del pipeline completo
#
# Ejecuta los pasos en orden y decide según el código de salida de cada uno:
#   0  PASA          → continúa
#   11 ADVERTENCIA   → continúa y registra
#   10 FALLA         → detiene el pipeline (salvo --continue-on-fail)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/lib/common.sh"

usage() {
  cat <<'USAGE'
Uso: run_all.sh [opciones]

  --config RUTA          archivo de configuración
  --sample NOMBRE        procesar una sola muestra
  --batch RUTA           procesar el lote definido en un TSV
  --from N               comenzar desde el paso N
  --to N                 detenerse en el paso N
  --skip-basecall        partir de FASTQ en lugar de POD5
  --continue-on-fail     no detenerse ante un FALLA
  --force                repetir pasos ya completados
  --dry-run              mostrar los pasos sin ejecutarlos
USAGE
}

FROM=1; TO=99; SKIP_BC=0; CONT_FAIL=0; DRY=0; BATCH=""
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    --to) TO="$2"; shift 2 ;;
    --batch) BATCH="$2"; shift 2 ;;
    --skip-basecall) SKIP_BC=1; shift ;;
    --continue-on-fail) CONT_FAIL=1; shift ;;
    --dry-run) DRY=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

declare -a STEPS=(
  "01:01_basecall.sh"
  "02:02_demux.sh"
  "03:03_readqc_filter.sh"
  "04:04_assemble_validate.sh"
  "05:05_polish.sh"
  "06:06_termini_orient.sh"
  "07:07_annotate_screen.sh"
  "08:08_report.sh"
)

run_sample() {
  local sample_args=("$@")
  local overall=0
  for entry in "${STEPS[@]}"; do
    local num="${entry%%:*}" script="${entry#*:}"
    local n=$((10#$num))
    (( n < FROM || n > TO )) && continue
    (( SKIP_BC == 1 && n <= 2 )) && { warn "Omitiendo paso $num (--skip-basecall)"; continue; }
    [[ -f "${SCRIPT_DIR}/scripts/${script}" ]] || { warn "No existe ${script}; omitiendo"; continue; }

    log "┌─ Paso ${num}: ${script}"
    if [[ $DRY -eq 1 ]]; then log "│  (dry-run)"; continue; fi

    set +e
    bash "${SCRIPT_DIR}/scripts/${script}" "${sample_args[@]}"
    local rc=$?
    set -e

    case $rc in
      0)  ok   "└─ Paso ${num} PASA" ;;
      11) warn "└─ Paso ${num} con ADVERTENCIA"; overall=11 ;;
      10) echo "└─ Paso ${num} FALLA" >&2
          overall=10
          [[ $CONT_FAIL -eq 0 ]] && { die "Pipeline detenido en el paso ${num}."; } ;;
      *)  die "└─ Paso ${num} terminó con error de ejecución (código ${rc})" ;;
    esac
  done
  return $overall
}

if [[ -n "$BATCH" ]]; then
  [[ -f "$BATCH" ]] || die "No existe el archivo de lote: $BATCH"
  while IFS=$'\t' read -r s b g notes; do
    [[ "$s" =~ ^# ]] && continue; [[ -z "${s:-}" ]] && continue
    log "════════ MUESTRA: $s ════════"
    run_sample "${ARGS[@]}" --sample "$s" || warn "La muestra $s terminó con incidencias"
  done < "$BATCH"
else
  run_sample "${ARGS[@]}"
fi
