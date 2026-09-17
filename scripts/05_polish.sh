#!/usr/bin/env bash
# =============================================================================
# 05_polish.sh — pulido del consenso
# Manual §13 · Incluye la verificación de §13.2 (sistemas dnd en Salmonella)
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
usage(){ echo "Uso: 05_polish.sh [--config R] [--sample N] [--force]"; }
parse_common_args "$@"; init_step "Pulido del consenso"

POL="$D_POL"; mkdir -p "$POL"
maybe_skip "$POL" "05_polish" && exit $EXIT_OK

DRAFT="${D_ASM}/assembly.fasta"
READS="${D_FILT}/subsampled.fastq.gz"
require_file "$DRAFT" "$READS"

# --- Advertencia §13.2 ------------------------------------------------------
# Los sistemas dnd (fosforotioato, motivo GTTC) están ampliamente distribuidos
# en Salmonella enterica. El pulido con la opción orientada a bacterias
# introduce errores sistemáticos en ese contexto con modelos v6.0.
BACTERIA_FLAG=""
if [[ "${CFG_DORADO_MODEL:-}" == *"v6"* ]]; then
  warn "Modelo de basecalling de la serie v6 detectado."
  warn "  No se activará la opción orientada a bacterias (ver Manual §13.2)."
  warn "  Motivo: errores sistemáticos en aislados con sistemas dnd (GTTC),"
  warn "  frecuentes en Salmonella enterica."
else
  BACTERIA_FLAG="--bacteria"
fi

activate_env phage-polish
record_version medaka medaka --version

log "Puliendo con Medaka"
medaka_consensus -i "$READS" -d "$DRAFT" -o "$POL" -t "$THREADS" \
  >"${LOGDIR}/medaka.log" 2>&1 || die "Medaka falló"
require_file "${POL}/consensus.fasta"

# --- Verificación del efecto del pulido -------------------------------------
activate_env phage-qc
LEN_PRE=$(fasta_length "$DRAFT"); LEN_POST=$(fasta_length "${POL}/consensus.fasta")
DELTA=$((LEN_POST - LEN_PRE))
record_metric "longitud_prepulido" "$LEN_PRE"
record_metric "longitud_postpulido" "$LEN_POST"
record_metric "delta_longitud_pulido" "$DELTA"
log "Longitud: ${LEN_PRE} → ${LEN_POST} (${DELTA} pb)"

# Un cambio grande de longitud indica un problema, no una mejora
PCT=$(awk -v d="$DELTA" -v l="$LEN_PRE" 'BEGIN{printf "%.2f",100*(d<0?-d:d)/l}')
awk "BEGIN{exit !($PCT > 1)}" && warn "La longitud cambió ${PCT}%. Revise el pulido."

# Diferencias posición a posición
minimap2 -x asm5 --cs "$DRAFT" "${POL}/consensus.fasta" 2>/dev/null \
  > "${POL}/pre_vs_post.paf" || true
NDIFF=$(awk '{for(i=1;i<=NF;i++) if($i~/^NM:i:/){split($i,a,":"); print a[3]}}' \
        "${POL}/pre_vs_post.paf" | head -1)
record_metric "cambios_pulido" "${NDIFF:-0}"
log "Posiciones modificadas por el pulido: ${NDIFF:-0}"

# Verificación específica de contextos GTTC (Manual §13.2)
if [[ "${CFG_DORADO_MODEL:-}" == *"v6"* ]]; then
  GTTC_PRE=$(grep -v '^>' "$DRAFT" | tr -d '\n' | grep -o 'GTTC' | wc -l)
  GTTC_POST=$(grep -v '^>' "${POL}/consensus.fasta" | tr -d '\n' | grep -o 'GTTC' | wc -l)
  record_metric "motivos_gttc_pre" "$GTTC_PRE"
  record_metric "motivos_gttc_post" "$GTTC_POST"
  if [[ "$GTTC_PRE" -ne "$GTTC_POST" ]]; then
    warn "El número de motivos GTTC cambió (${GTTC_PRE} → ${GTTC_POST})."
    warn "  Posible efecto de modificación por fosforotioato. Verifique antes de aceptar."
  fi
fi

timer_end "polish"; mark_done "$POL"
