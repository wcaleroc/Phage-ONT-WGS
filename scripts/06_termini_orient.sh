#!/usr/bin/env bash
# =============================================================================
# 06_termini_orient.sh — arquitectura terminal y reorientación
# Manual §14
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
usage(){ echo "Uso: 06_termini_orient.sh [--config R] [--sample N] [--force]"; }
parse_common_args "$@"; init_step "Extremos y orientación"

TRM="$D_TERM"; FIN="$D_FINAL"
mkdir -p "$TRM" "$FIN"
maybe_skip "$TRM" "06_termini_orient" && exit $EXIT_OK

CONS="${D_POL}/consensus.fasta"
[[ -f "$CONS" ]] || CONS="${D_ASM}/assembly.fasta"
require_file "$CONS"

activate_env phage-qc
# --- Detección de repetición terminal directa (§14.2) -----------------------
# Un alineamiento entre extremos + cobertura doble en esa región es evidencia
# de repetición terminal. La circularidad del ensamblador es topológica y no
# resuelve esta cuestión.
GLEN=$(fasta_length "$CONS")
WIN=$(( GLEN / 10 )); [[ $WIN -gt 5000 ]] && WIN=5000
seqkit subseq -r "1:${WIN}"   "$CONS" > "${TRM}/ini.fa"
seqkit subseq -r "-${WIN}:-1" "$CONS" > "${TRM}/fin.fa"
minimap2 -x asm5 "${TRM}/ini.fa" "${TRM}/fin.fa" > "${TRM}/dtr.paf" 2>/dev/null || true

if [[ -s "${TRM}/dtr.paf" ]]; then
  DTR_LEN=$(awk '{print $11}' "${TRM}/dtr.paf" | sort -rn | head -1)
  warn "Posible repetición terminal directa de ~${DTR_LEN} pb"
  record_metric "dtr_longitud" "$DTR_LEN"
  record_metric "arquitectura_terminal" "posible_DTR"
  warn "Verifique la cobertura en esa región: debe ser aproximadamente doble."
  warn "Si se confirma, la repetición debe representarse UNA SOLA VEZ al depositar."
else
  log "Sin alineamiento significativo entre extremos"
  record_metric "arquitectura_terminal" "sin_DTR_detectada"
fi

# Cobertura en los extremos, como evidencia complementaria
if [[ -f "${D_QC}/depth.regions.bed.gz" ]]; then
  zcat "${D_QC}/depth.regions.bed.gz" | head -10 > "${TRM}/cobertura_inicio.txt"
  zcat "${D_QC}/depth.regions.bed.gz" | tail -10 > "${TRM}/cobertura_final.txt"
  COV_MED=$(zcat "${D_QC}/depth.regions.bed.gz" | awk '{s+=$4;n++}END{print s/n}')
  COV_INI=$(awk '{s+=$4;n++}END{print s/n}' "${TRM}/cobertura_inicio.txt")
  RATIO=$(awk -v a="$COV_INI" -v b="$COV_MED" 'BEGIN{if(b>0)printf "%.2f",a/b; else print 0}')
  record_metric "ratio_cobertura_extremo" "$RATIO"
  awk "BEGIN{exit !($RATIO > 1.6)}" && \
    warn "Cobertura en el extremo ${RATIO}× la media: consistente con repetición terminal."
fi

# --- Reorientación (§14.3) ---------------------------------------------------
# Convención: el genoma inicia en la subunidad grande de la terminasa.
# Debe ejecutarse ANTES de la anotación definitiva.
activate_env phage-qual
record_version dnaapler dnaapler --version
log "Reorientando al gen de la terminasa grande"
if dnaapler phage -i "$CONS" -o "${TRM}/reoriented" -p "$SAMPLE" -t "$THREADS" -f \
     >"${LOGDIR}/dnaapler.log" 2>&1; then
  cp "${TRM}/reoriented/${SAMPLE}_reoriented.fasta" "${FIN}/${SAMPLE}_genome.fasta"
  ok "Genoma reorientado"
  record_metric "reorientacion" "terL"
else
  warn "No se localizó la terminasa. Se conserva la orientación original."
  warn "  Alternativas: dnaapler custom (referencia del género) o dnaapler nearest."
  cp "$CONS" "${FIN}/${SAMPLE}_genome.fasta"
  record_metric "reorientacion" "no_aplicada"
fi

require_file "${FIN}/${SAMPLE}_genome.fasta"
record_metric "longitud_genoma_final" "$(fasta_length "${FIN}/${SAMPLE}_genome.fasta")"
timer_end "termini"; mark_done "$TRM"
