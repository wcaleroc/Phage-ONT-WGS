#!/usr/bin/env bash
# =============================================================================
# 03_readqc_filter.sh — control de calidad, filtrado y submuestreo de lecturas
#
# Entrada : FASTQ demultiplexado de la muestra
# Salida  : FASTQ filtrado y submuestreado + informe de calidad + métricas
#
# Diferencia clave respecto a un pipeline bacteriano: el submuestreo NO es
# opcional. Un genoma fágico de 45 kb en una corrida normal puede quedar con
# cobertura de miles de veces, y los ensambladores de lectura larga se degradan
# por encima de unas pocas centenas: fragmentan, consumen memoria y generan
# contigs espurios.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'USAGE'
Uso: 03_readqc_filter.sh [opciones]

  --config RUTA     archivo de configuración (por defecto config/config.yaml)
  --sample NOMBRE   identificador de la muestra
  --threads N       número de hilos
  --force           repetir el paso aunque ya esté completado
  --help            esta ayuda

Salidas en <project>/results/<sample>/:
  qc/nanoplot/NanoStats.txt        estadísticos de lecturas crudas
  qc/raw_stats.tsv                 resumen seqkit antes del filtrado
  qc/filt_stats.tsv                resumen seqkit después del filtrado
  reads/filtered.fastq.gz          lecturas filtradas
  reads/subsampled.fastq.gz        lecturas submuestreadas (entrada al ensamblaje)
USAGE
}

parse_common_args "$@"
init_step "QC y filtrado de lecturas"

OUT="$D_QC"
READS="$D_FILT"
mkdir -p "$OUT" "$READS"

maybe_skip "$OUT" "03_readqc_filter" && exit $EXIT_OK

# ---------- Localizar la entrada --------------------------------------------
if [[ -n "${CFG_FASTQ_IN:-}" ]]; then
  IN_FASTQ="$CFG_FASTQ_IN"
else
  IN_FASTQ="${PROJECT}/results/${SAMPLE}/demux/${CFG_BARCODE}.fastq"
  [[ -f "$IN_FASTQ" ]] || IN_FASTQ="${IN_FASTQ}.gz"
fi
require_file "$IN_FASTQ"
log "Entrada: $IN_FASTQ"

activate_env phage-qc
require_cmd NanoPlot seqkit chopper rasusa
record_version NanoPlot NanoPlot --version
record_version seqkit   seqkit version
record_version chopper  chopper --version
record_version rasusa   rasusa --version

# ---------- 1. Estadísticos de lecturas crudas -------------------------------
log "Generando informe de calidad de lecturas crudas"
NanoPlot \
  --fastq "$IN_FASTQ" \
  --outdir "${OUT}/nanoplot" \
  --threads "$THREADS" \
  --N50 --loglength \
  --title "${SAMPLE} — lecturas crudas" \
  --prefix "${SAMPLE}_" \
  >"${LOGDIR}/nanoplot.log" 2>&1

seqkit stats -a -T "$IN_FASTQ" > "${OUT}/raw_stats.tsv"

RAW_READS=$(awk 'NR==2{print $4}' "${OUT}/raw_stats.tsv")
RAW_BASES=$(awk 'NR==2{print $5}' "${OUT}/raw_stats.tsv")
RAW_N50=$(awk 'NR==2{print $13}'  "${OUT}/raw_stats.tsv")
RAW_MEANLEN=$(awk 'NR==2{print $7}' "${OUT}/raw_stats.tsv")

record_metric "lecturas_crudas"      "$RAW_READS"
record_metric "bases_crudas"         "$RAW_BASES"
record_metric "n50_lectura"          "$RAW_N50"
record_metric "longitud_media"       "$RAW_MEANLEN"

# ---------- 2. Cobertura estimada --------------------------------------------
GSIZE="${CFG_GENOME_SIZE_BP:-45000}"
EST_COV=$(awk -v b="$RAW_BASES" -v g="$GSIZE" 'BEGIN{printf "%.1f", b/g}')
log "Cobertura estimada sobre ${GSIZE} pb: ${EST_COV}×"

set +e
qc_gate "cobertura_estimada" "$EST_COV" "${CFG_COV_PASS:-60}" "${CFG_COV_WARN:-30}"
COV_VERDICT=$?
set -e

if [[ $COV_VERDICT -eq $EXIT_QC_FAIL ]]; then
  die "Rendimiento insuficiente para ensamblar. Repita la corrida o revise la biblioteca."
fi

# Diagnóstico retrospectivo del laboratorio húmedo: la distribución de
# longitudes refleja el estado del ADN que entró a la preparación de biblioteca.
if awk "BEGIN{exit !($RAW_N50 < 3000)}"; then
  warn "N50 de lectura bajo (${RAW_N50} pb). Posible fragmentación del ADN"
  warn "  durante la extracción. Revise la intensidad de la lisis mecánica."
fi

# ---------- 3. Filtrado -------------------------------------------------------
Q="${CFG_MIN_QSCORE:-10}"
L="${CFG_MIN_LENGTH:-1000}"
log "Filtrando: Q >= ${Q}, longitud >= ${L} pb"

# chopper lee de stdin; se maneja entrada comprimida o plana
if [[ "$IN_FASTQ" == *.gz ]]; then
  zcat "$IN_FASTQ"
else
  cat "$IN_FASTQ"
fi | chopper -q "$Q" -l "$L" --threads "$THREADS" 2>"${LOGDIR}/chopper.log" \
   | pigz -p "$THREADS" > "${READS}/filtered.fastq.gz"

seqkit stats -a -T "${READS}/filtered.fastq.gz" > "${OUT}/filt_stats.tsv"
FILT_READS=$(awk 'NR==2{print $4}' "${OUT}/filt_stats.tsv")
FILT_BASES=$(awk 'NR==2{print $5}' "${OUT}/filt_stats.tsv")
record_metric "lecturas_filtradas" "$FILT_READS"
record_metric "bases_filtradas"    "$FILT_BASES"

RETAIN=$(awk -v a="$FILT_BASES" -v b="$RAW_BASES" 'BEGIN{printf "%.1f", 100*a/b}')
log "Retención tras el filtrado: ${RETAIN}% de las bases"
record_metric "retencion_filtrado_pct" "$RETAIN"

# Una pérdida masiva indica que el umbral es incompatible con el modelo de
# basecalling empleado, no que las lecturas sean malas.
if awk "BEGIN{exit !($RETAIN < 50)}"; then
  warn "Se descartó más de la mitad de las bases. Verifique que el umbral Q=${Q}"
  warn "  corresponde al modelo de basecalling utilizado."
fi

# ---------- 4. Submuestreo ----------------------------------------------------
TARGET="${CFG_TARGET_COVERAGE:-100}"
SEED="${CFG_SUBSAMPLE_SEED:-42}"
log "Submuestreando a ${TARGET}× (semilla ${SEED}) sobre ${CFG_GENOME_SIZE:-45k}"

rasusa reads \
  --coverage "$TARGET" \
  --genome-size "${CFG_GENOME_SIZE:-45k}" \
  --seed "$SEED" \
  -o "${READS}/subsampled.fastq.gz" \
  "${READS}/filtered.fastq.gz" \
  2>"${LOGDIR}/rasusa.log"

seqkit stats -a -T "${READS}/subsampled.fastq.gz" > "${OUT}/sub_stats.tsv"
SUB_BASES=$(awk 'NR==2{print $5}' "${OUT}/sub_stats.tsv")
SUB_COV=$(awk -v b="$SUB_BASES" -v g="$GSIZE" 'BEGIN{printf "%.1f", b/g}')
record_metric "cobertura_submuestreada" "$SUB_COV"
ok "Cobertura tras submuestreo: ${SUB_COV}×"

# ---------- Cierre ------------------------------------------------------------
{
  echo "muestra	${SAMPLE}"
  echo "lecturas_crudas	${RAW_READS}"
  echo "bases_crudas	${RAW_BASES}"
  echo "n50_lectura	${RAW_N50}"
  echo "cobertura_estimada	${EST_COV}"
  echo "lecturas_filtradas	${FILT_READS}"
  echo "retencion_pct	${RETAIN}"
  echo "cobertura_final	${SUB_COV}"
} > "${OUT}/resumen_lecturas.tsv"

timer_end "readqc"
mark_done "$OUT"
ok "Paso completado. Entrada al ensamblaje: ${READS}/subsampled.fastq.gz"
exit $COV_VERDICT
