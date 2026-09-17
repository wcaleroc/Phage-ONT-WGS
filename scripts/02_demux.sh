#!/usr/bin/env bash
# =============================================================================
# 02_demux.sh — separación por código de barras
# Manual §8
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
usage(){ echo "Uso: 02_demux.sh [--config R] [--sample N] [--force]"; }
parse_common_args "$@"; init_step "Demultiplexado"

DX="$D_DEMUX"; mkdir -p "$DX"
maybe_skip "$DX" "02_demux" && exit $EXIT_OK

BAM="${D_BC}/${SAMPLE}_calls.bam"
require_file "$BAM"
DORADO="${CFG_DORADO_BIN:-dorado}"

# El identificador de kit debe ser idéntico al del basecalling: es la causa
# más frecuente de que todos los códigos de barras salgan vacíos.
log "Demultiplexando con kit ${CFG_KIT}"
"$DORADO" demux --output-dir "$DX" --kit-name "${CFG_KIT}" \
  --emit-fastq --emit-summary "$BAM" \
  >"${LOGDIR}/demux.log" 2>&1 || die "Demux falló"

activate_env phage-qc
seqkit stats -a -T "${DX}"/*.fastq > "${D_QC}/barcode_stats.tsv" 2>/dev/null || true
column -t "${D_QC}/barcode_stats.tsv" >&2 || true

TOTAL=$(awk 'NR>1{s+=$4}END{print s+0}' "${D_QC}/barcode_stats.tsv")
UNCL=$(awk '$1~/unclassified/{print $4}' "${D_QC}/barcode_stats.tsv" || echo 0)
if [[ "${TOTAL:-0}" -gt 0 ]]; then
  PCT=$(awk -v u="${UNCL:-0}" -v t="$TOTAL" 'BEGIN{printf "%.1f",100*u/t}')
  record_metric "sin_clasificar_pct" "$PCT"
  awk "BEGIN{exit !($PCT > 20)}" && warn "Sin clasificar: ${PCT}%. Revise la biblioteca."
fi

MYBC="${DX}/${CFG_BARCODE}.fastq"
[[ -f "$MYBC" ]] || die "No se generó ${CFG_BARCODE}.fastq. Verifique el código configurado."
record_metric "lecturas_muestra" "$(fastq_reads "$MYBC")"

timer_end "demux"; mark_done "$DX"
