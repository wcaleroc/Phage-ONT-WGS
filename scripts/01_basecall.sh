#!/usr/bin/env bash
# =============================================================================
# 01_basecall.sh — conversión de señal a secuencia con Dorado
# Manual §7 · Requiere GPU
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
usage(){ echo "Uso: 01_basecall.sh [--config R] [--sample N] [--force]"; }
parse_common_args "$@"; init_step "Basecalling"

BC="$D_BC"; mkdir -p "$BC"
maybe_skip "$BC" "01_basecall" && exit $EXIT_OK

POD5="${CFG_POD5_DIR:?defina pod5_dir en config.yaml}"
[[ -d "$POD5" ]] || die "Directorio POD5 no encontrado: $POD5"
DORADO="${CFG_DORADO_BIN:-dorado}"
command -v "$DORADO" >/dev/null 2>&1 || die "Dorado no encontrado: $DORADO"
record_version dorado "$DORADO" --version

# --- Verificación de química (Manual §7.1) ---------------------------------
# El modelo debe corresponder a la química de la corrida. Un modelo mal elegido
# degrada la exactitud sin producir error visible.
SUMMARY=$(find "$POD5" -maxdepth 2 -name 'final_summary_*.txt' | head -1 || true)
if [[ -n "$SUMMARY" ]]; then
  FC=$(grep -ioE 'FLO-[A-Z0-9]+' "$SUMMARY" | head -1 || echo "")
  KIT=$(grep -ioE 'SQK-[A-Z0-9.]+' "$SUMMARY" | head -1 || echo "")
  log "Celda declarada: ${FC:-no detectada} · kit: ${KIT:-no detectado}"
  record_metric "flowcell" "${FC:-NA}"; record_metric "kit" "${KIT:-NA}"
  if [[ "$FC" == *"MIN106"* || "$FC" == *"PRO002"* ]]; then
    warn "Química R9.4.1 detectada. El modelo configurado es para R10.4.1."
    warn "  Verifique dorado_model antes de continuar."
  fi
  [[ -n "$KIT" && "$KIT" != "${CFG_KIT}" ]] && \
    warn "El kit del resumen (${KIT}) difiere del configurado (${CFG_KIT})"
else
  warn "Sin final_summary. No se pudo verificar la química de forma automática."
fi

# --- GPU --------------------------------------------------------------------
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,memory.total --format=csv,noheader | while read -r g; do log "GPU: $g"; done
  DEVICE="cuda:all"
else
  warn "Sin GPU detectada. El basecalling SUP en CPU es impracticable."
  DEVICE="cpu"
fi

MODEL="${CFG_DORADO_MODEL:?defina dorado_model}"
log "Basecalling con modelo ${MODEL}"
"$DORADO" basecaller "$MODEL" "$POD5" \
  --device "$DEVICE" --kit-name "${CFG_KIT}" \
  --emit-summary --recursive \
  > "${BC}/${SAMPLE}_calls.bam" 2>"${LOGDIR}/dorado.log" \
  || die "Dorado falló. Revise ${LOGDIR}/dorado.log"

activate_env phage-qc
samtools quickcheck -v "${BC}/${SAMPLE}_calls.bam" || die "BAM corrupto"
NREADS=$(samtools view -c "${BC}/${SAMPLE}_calls.bam")
record_metric "lecturas_basecalled" "$NREADS"
ok "Lecturas generadas: ${NREADS}"

timer_end "basecall"; mark_done "$BC"
