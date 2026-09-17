#!/usr/bin/env bash
# =============================================================================
# 04_assemble_validate.sh — ensamblaje de novo, mapeo de validación y CheckV
#
# Entrada : lecturas submuestreadas de 03_readqc_filter.sh
# Salida  : ensamblaje, BAM de validación, perfil de cobertura, informe CheckV
#
# Adaptaciones frente a un pipeline bacteriano:
#   - --genome-size en el rango fágico, no bacteriano
#   - --meta por robustez ante ADN residual del hospedero (cobertura dispar)
#   - CheckV en lugar de CheckM2: los virus carecen de genes universales de
#     copia única, de modo que las herramientas basadas en ellos no aplican
#   - Interpretación explícita de la circularidad: el ensamblador reporta
#     topología, no biología. Un genoma con permutación circular se cierra
#     igual siendo lineal.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'USAGE'
Uso: 04_assemble_validate.sh [opciones]

  --config RUTA / --sample NOMBRE / --threads N / --force / --help

Salidas en <project>/results/<sample>/:
  assembly/assembly.fasta          contigs
  assembly/assembly_info.txt       longitud, cobertura, circularidad
  assembly/assembly_graph.gfa      grafo (inspeccionar con Bandage)
  assembly/aln.bam                 lecturas mapeadas contra el ensamblaje
  qc/depth.regions.bed.gz          cobertura por ventana
  qc/checkv/quality_summary.tsv    completitud y contaminación
USAGE
}

parse_common_args "$@"
init_step "Ensamblaje y validación"

ASM="$D_ASM"
QCD="$D_QC"
mkdir -p "$ASM" "$QCD"

maybe_skip "$ASM" "04_assemble_validate" && exit $EXIT_OK

READS_IN="${D_FILT}/subsampled.fastq.gz"
require_file "$READS_IN"

# ---------- 1. Ensamblaje -----------------------------------------------------
activate_env phage-asm
require_cmd flye
record_version flye flye --version

# Selección del modo según la exactitud del basecalling.
# --nano-hq corresponde a R10.4.1 con modelo SUP. Desde Flye 2.9.6 los
# parámetros de R10 (3 % de error) son los predeterminados de ese modo.
# Usar --nano-raw sobre datos actuales desperdicia exactitud y cómputo.
FLYE_MODE="--nano-hq"
if [[ "${CFG_DORADO_MODEL:-}" == *"fast"* ]]; then
  warn "El modelo de basecalling parece ser 'fast'. Considere --nano-raw"
  warn "  o mejor, reprocesar la señal con un modelo de mayor exactitud."
fi

log "Ensamblando con Flye ${FLYE_MODE}, tamaño esperado ${CFG_GENOME_SIZE:-45k}"
flye \
  "$FLYE_MODE" "$READS_IN" \
  --out-dir "$ASM" \
  --genome-size "${CFG_GENOME_SIZE:-45k}" \
  --threads "$THREADS" \
  --meta \
  >"${LOGDIR}/flye.log" 2>&1 \
  || die "Flye falló. Revise ${LOGDIR}/flye.log"

require_file "${ASM}/assembly.fasta"

# ---------- 2. Evaluación del resultado ---------------------------------------
N_CONTIGS=$(count_fasta "${ASM}/assembly.fasta")
ASM_LEN=$(fasta_length "${ASM}/assembly.fasta")
log "Contigs: ${N_CONTIGS} · longitud total: ${ASM_LEN} pb"

set +e
qc_gate_eq "numero_contigs" "$N_CONTIGS" "${CFG_EXPECTED_CONTIGS:-1}"
CONTIG_VERDICT=$?
set -e

record_metric "longitud_ensamblaje" "$ASM_LEN"

# Interpretación de contigs múltiples según su cobertura relativa.
# Cobertura dispar  → contaminación del hospedero (descartable)
# Cobertura similar → población mixta de fagos (requiere repurificar)
if [[ "$N_CONTIGS" -gt 1 ]]; then
  warn "Más de un contig. Analizando coberturas relativas:"
  awk 'NR>1{printf "    %s\tlong=%s\tcov=%s\tcirc=%s\n", $1,$2,$3,$4}' \
      "${ASM}/assembly_info.txt" >&2

  MAXCOV=$(awk 'NR>1{if($3>m)m=$3}END{print m+0}' "${ASM}/assembly_info.txt")
  MINCOV=$(awk 'NR>1{if(m==""||$3<m)m=$3}END{print m+0}' "${ASM}/assembly_info.txt")
  RATIO=$(awk -v a="$MAXCOV" -v b="$MINCOV" 'BEGIN{if(b>0)printf "%.1f",a/b; else print 999}')

  if awk "BEGIN{exit !($RATIO > 5)}"; then
    warn "Relación de cobertura ${RATIO}× entre contigs: sugiere contaminación"
    warn "  del hospedero. Verifique el contig minoritario por homología antes"
    warn "  de descartarlo."
  else
    warn "Coberturas comparables (relación ${RATIO}×): posible población mixta"
    warn "  de fagos. Considere repurificar el aislado en el laboratorio."
  fi
  record_metric "relacion_cobertura_contigs" "$RATIO"
fi

# Longitud fuera del rango esperado del género
EXP_BP="${CFG_GENOME_SIZE_BP:-45000}"
DEV=$(awk -v a="$ASM_LEN" -v b="$EXP_BP" 'BEGIN{printf "%.0f", 100*(a-b)/b}')
if awk "BEGIN{exit !(($DEV > 25) || ($DEV < -25))}"; then
  warn "La longitud se desvía ${DEV}% del tamaño esperado."
  warn "  Si es mayor: sospeche duplicación de repetición terminal (paso 05)."
  warn "  Si es menor: ensamblaje incompleto."
fi

# ---------- 3. Mapeo de validación --------------------------------------------
activate_env phage-qc
require_cmd minimap2 samtools mosdepth
record_version minimap2 minimap2 --version
record_version samtools samtools --version
record_version mosdepth mosdepth --version

log "Mapeando lecturas contra el ensamblaje"
minimap2 -ax map-ont -t "$THREADS" \
  "${ASM}/assembly.fasta" "$READS_IN" 2>"${LOGDIR}/minimap2.log" \
  | samtools sort -@ "$THREADS" -o "${ASM}/aln.bam" -
samtools index "${ASM}/aln.bam"
samtools flagstat "${ASM}/aln.bam" > "${QCD}/flagstat.txt"

MAPPED_PCT=$(awk '/mapped \(/{gsub(/[(%]/,"",$5); print $5; exit}' "${QCD}/flagstat.txt")
set +e
qc_gate "lecturas_mapeadas_pct" "$MAPPED_PCT" \
        "${CFG_MAPPED_PASS:-90}" "${CFG_MAPPED_WARN:-75}"
MAP_VERDICT=$?
set -e

# ---------- 4. Perfil de cobertura --------------------------------------------
mosdepth --by 100 --fast-mode "${QCD}/depth" "${ASM}/aln.bam" \
  2>"${LOGDIR}/mosdepth.log"

MEAN_COV=$(zcat "${QCD}/depth.regions.bed.gz" \
  | awk '{s+=$4; n++} END {if(n>0) printf "%.1f", s/n; else print 0}')

set +e
qc_gate "cobertura_media_ensamblaje" "$MEAN_COV" \
        "${CFG_COV_PASS:-60}" "${CFG_COV_WARN:-30}"
COV_VERDICT=$?
set -e

# Uniformidad: el coeficiente de variación detecta colapsos de repeticiones
# y caídas que la media oculta.
CV=$(zcat "${QCD}/depth.regions.bed.gz" | awk '
  {s+=$4; ss+=$4*$4; n++}
  END{ if(n>1){ m=s/n; sd=sqrt(ss/n - m*m); printf "%.2f", sd/m } else print 0 }')
record_metric "coef_variacion_cobertura" "$CV"
log "Coeficiente de variación de la cobertura: ${CV}"

if awk "BEGIN{exit !($CV > 0.5)}"; then
  warn "Cobertura poco uniforme (CV=${CV}). Posible colapso de repetición o"
  warn "  error de ensamblaje. Inspeccione el perfil antes de continuar."
fi

# Regiones de baja cobertura
LOWCOV=$(zcat "${QCD}/depth.regions.bed.gz" | awk '$4 < 20' | wc -l)
record_metric "ventanas_baja_cobertura" "$LOWCOV"
[[ "$LOWCOV" -gt 0 ]] && warn "${LOWCOV} ventanas de 100 pb con cobertura < 20×"

zcat "${QCD}/depth.regions.bed.gz" | awk '$4 < 20' > "${QCD}/low_coverage_regions.bed" || true

# ---------- 5. Calidad del genoma viral ---------------------------------------
activate_env phage-qual
require_cmd checkv
record_version checkv checkv --version

CHECKVDB="${CFG_DB_CHECKV:?defina db_checkv en config.yaml}"
[[ -d "$CHECKVDB" ]] || die "Base de datos CheckV no encontrada: $CHECKVDB"
record_db_version "checkv" "$(basename "$CHECKVDB")"

log "Evaluando calidad del genoma viral con CheckV"
checkv end_to_end "${ASM}/assembly.fasta" "${QCD}/checkv" \
  -t "$THREADS" -d "$CHECKVDB" \
  >"${LOGDIR}/checkv.log" 2>&1 \
  || warn "CheckV terminó con error. Revise ${LOGDIR}/checkv.log"

if [[ -f "${QCD}/checkv/quality_summary.tsv" ]]; then
  COMPLETENESS=$(awk -F'\t' 'NR==2{print $10}' "${QCD}/checkv/quality_summary.tsv")
  CONTAM=$(awk -F'\t' 'NR==2{print $12}' "${QCD}/checkv/quality_summary.tsv")
  QUALITY=$(awk -F'\t' 'NR==2{print $8}'  "${QCD}/checkv/quality_summary.tsv")
  record_metric "completitud_checkv"   "${COMPLETENESS:-NA}"
  record_metric "contaminacion_checkv" "${CONTAM:-NA}"
  record_metric "calidad_checkv"       "${QUALITY:-NA}"
  log "CheckV → completitud ${COMPLETENESS}% · contaminación ${CONTAM}% · ${QUALITY}"

  # CheckV también detecta repeticiones terminales, insumo del paso 05
  TR=$(awk -F'\t' 'NR==2{print $6}' "${QCD}/checkv/quality_summary.tsv")
  [[ -n "${TR:-}" && "$TR" != "NA" ]] && log "Repetición terminal detectada: ${TR}"
fi

# ---------- Cierre -------------------------------------------------------------
timer_end "assembly"
mark_done "$ASM"

# El peor veredicto de los tres determina la salida del paso
WORST=$EXIT_OK
for v in $CONTIG_VERDICT $MAP_VERDICT $COV_VERDICT; do
  [[ $v -gt $WORST ]] && WORST=$v
done

ok "Ensamblaje completado: ${ASM}/assembly.fasta"
exit $WORST
