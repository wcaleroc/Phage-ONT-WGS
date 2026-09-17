#!/usr/bin/env bash
# =============================================================================
# 07_annotate_screen.sh — anotación, taxonomía y cribado de seguridad
#
# Entrada : genoma final reorientado
# Salida  : anotación Pharokka (+phold), taxonomía ICTV, cribado AMR/virulencia,
#           predicción de estilo de vida y veredicto de aptitud para biocontrol
#
# Este paso es el único del pipeline cuyo resultado es DECISORIO y no
# descriptivo: determina si el aislado puede usarse como agente de control
# biológico. Un resultado positivo confirmado lo excluye con independencia de
# sus características fenotípicas.
#
# Nota sobre la elección de anotador: los predictores entrenados sobre genomas
# bacterianos (Prokka, Bakta) pierden genes en genomas virales por su densidad
# codificante elevada, genes pequeños, marcos solapantes y codones de inicio
# atípicos. Pharokka emplea PHANOTATE, diseñado para fagos.
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

usage() {
  cat <<'USAGE'
Uso: 07_annotate_screen.sh [opciones]

  --config RUTA / --sample NOMBRE / --threads N / --force / --help

Salidas en <project>/results/<sample>/:
  annotation/pharokka/     anotación primaria (gbk, gff, faa, ffn)
  annotation/phold/        anotación estructural (reduce hipotéticas)
  taxonomy/                asignación ICTV con valores de similitud
  safety/amrfinder.tsv     cribado de resistencia
  safety/vfdb_hits.tsv     cribado de virulencia
  safety/lysogeny.txt      marcadores de lisogenia
  safety/veredicto.txt     resumen de aptitud para biocontrol
USAGE
}

parse_common_args "$@"
init_step "Anotación y cribado de seguridad"

ANN="$D_ANN"
TAX="$D_TAX"
SAFE="$D_AMR"      # 11_amr
VIRD="$D_VIR"      # 12_virulence
LIFED="$D_LIFE"    # 13_lifestyle
mkdir -p "$ANN" "$TAX" "$SAFE" "$VIRD" "$LIFED"

maybe_skip "$ANN" "07_annotate_screen" && exit $EXIT_OK

GENOME="${D_FINAL}/${SAMPLE}_genome.fasta"
require_file "$GENOME"
log "Genoma de entrada: $GENOME"

# =============================================================================
# 1. ANOTACIÓN PRIMARIA
# =============================================================================
activate_env phage-annot
require_cmd pharokka.py
record_version pharokka pharokka.py --version

DB_PH="${CFG_DB_PHAROKKA:?defina db_pharokka en config.yaml}"
[[ -d "$DB_PH" ]] || die "Base de datos de Pharokka no encontrada: $DB_PH"
record_db_version "pharokka" "$(basename "$DB_PH")"

log "Anotando con Pharokka (PHANOTATE + PHROGs)"
pharokka.py \
  -i "$GENOME" \
  -o "${ANN}/pharokka" \
  -d "$DB_PH" \
  -t "$THREADS" \
  -p "$SAMPLE" \
  -g prodigal-gv \
  -f \
  >"${LOGDIR}/pharokka.log" 2>&1 \
  || die "Pharokka falló. Revise ${LOGDIR}/pharokka.log"

PH_GBK="${ANN}/pharokka/${SAMPLE}.gbk"
PH_FAA="${ANN}/pharokka/${SAMPLE}.faa"
require_file "$PH_GBK" "$PH_FAA"

N_CDS=$(count_fasta "$PH_FAA")
GLEN=$(fasta_length "$GENOME")
CDS_DENSITY=$(awk -v c="$N_CDS" -v l="$GLEN" 'BEGIN{printf "%.1f", 1000*c/l}')
record_metric "cds_predichos"        "$N_CDS"
record_metric "densidad_cds_por_kb"  "$CDS_DENSITY"
log "CDS predichos: ${N_CDS} · densidad ${CDS_DENSITY} por kb"

# La densidad codificante típica de un fago caudado ronda 1,2-2,0 CDS/kb.
# Valores muy inferiores sugieren fallo de predicción, no biología.
if awk "BEGIN{exit !($CDS_DENSITY < 0.8)}"; then
  warn "Densidad codificante baja (${CDS_DENSITY}/kb). Verifique que el genoma"
  warn "  no contenga secuencia no viral y que el código genético sea el correcto."
fi

N_HYP_PH=$(grep -c "hypothetical" "$PH_GBK" || echo 0)
record_metric "hipoteticas_pharokka" "$N_HYP_PH"

# tRNA y CRISPR: informativos sobre adaptación al hospedero
if [[ -f "${ANN}/pharokka/${SAMPLE}_cds_functions.tsv" ]]; then
  cp "${ANN}/pharokka/${SAMPLE}_cds_functions.tsv" "${ANN}/funciones_pharokka.tsv"
  log "Distribución funcional:"
  column -t "${ANN}/funciones_pharokka.tsv" | head -15 >&2
fi

# =============================================================================
# 2. ANOTACIÓN ESTRUCTURAL (opcional pero recomendada)
# =============================================================================
# La comparación de estructuras detecta homologías que la secuencia no revela,
# porque la estructura se conserva más que la secuencia. Es especialmente útil
# en fagos, donde una fracción sustancial de proteínas carece de homólogos
# identificables por secuencia.
FINAL_GBK="$PH_GBK"

if [[ "${CFG_USE_PHOLD:-true}" == "true" ]]; then
  activate_env phage-phold
  if command -v phold >/dev/null 2>&1; then
    record_version phold phold --version
    DB_PHOLD="${CFG_DB_PHOLD:?defina db_phold en config.yaml}"
    record_db_version "phold" "$(basename "$DB_PHOLD")"

    GPU_FLAG=""
    if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
      log "GPU detectada: activando aceleración de Foldseek"
      GPU_FLAG="--foldseek_gpu"
    else
      warn "Sin GPU. phold funcionará con mayor tiempo de cómputo."
    fi

    log "Anotación estructural con phold (ProstT5 + Foldseek)"
    # shellcheck disable=SC2086
    phold run \
      -i "$PH_GBK" \
      -o "${ANN}/phold" \
      -d "$DB_PHOLD" \
      -t "$THREADS" \
      -p "$SAMPLE" \
      $GPU_FLAG \
      >"${LOGDIR}/phold.log" 2>&1 \
      && FINAL_GBK="${ANN}/phold/${SAMPLE}.gbk" \
      || warn "phold falló; se continúa con la anotación de Pharokka"

    if [[ -f "${ANN}/phold/${SAMPLE}.gbk" ]]; then
      N_HYP_PHOLD=$(grep -c "hypothetical" "${ANN}/phold/${SAMPLE}.gbk" || echo 0)
      record_metric "hipoteticas_phold" "$N_HYP_PHOLD"
      GAIN=$(( N_HYP_PH - N_HYP_PHOLD ))
      ok "phold asignó función a ${GAIN} proteínas antes hipotéticas"
      record_metric "ganancia_anotacion_phold" "$GAIN"
    fi
  else
    warn "phold no está instalado; se omite la anotación estructural"
  fi
fi

FINAL_FAA="${ANN}/phold/${SAMPLE}.faa"
[[ -f "$FINAL_FAA" ]] || FINAL_FAA="$PH_FAA"

# =============================================================================
# 3. TAXONOMÍA
# =============================================================================
# Marco vigente: el ICTV suprimió el orden Caudovirales y las familias
# morfológicas (Myoviridae, Siphoviridae, Podoviridae) por parafiléticas.
# La clase aplicable es Caudoviricetes. Umbrales: ~70 % de identidad
# intergenómica para género, ~95 % para especie.
activate_env phage-tax
if command -v taxmyphage >/dev/null 2>&1; then
  record_version taxmyphage taxmyphage --version
  DB_TAX="${CFG_DB_TAXMYPHAGE:?defina db_taxmyphage en config.yaml}"
  record_db_version "taxmyphage" "$(basename "$DB_TAX")"

  log "Asignando taxonomía (criterios ICTV)"
  taxmyphage run \
    -i "$GENOME" \
    -o "$TAX" \
    -db "$DB_TAX" \
    -t "$THREADS" \
    >"${LOGDIR}/taxmyphage.log" 2>&1 \
    || warn "taxmyphage falló. Revise ${LOGDIR}/taxmyphage.log"

  if [[ -f "${TAX}/Summary_taxonomy.tsv" ]]; then
    column -t "${TAX}/Summary_taxonomy.tsv" | head -5 >&2
    GENUS=$(awk -F'\t' 'NR==2{print $(NF-1)}' "${TAX}/Summary_taxonomy.tsv")
    record_metric "genero_asignado" "${GENUS:-no determinado}"
  fi
  warn "Verifique la versión del recurso de metadatos del ICTV empleada: una"
  warn "  asignación próxima al umbral puede cambiar entre versiones."
else
  warn "taxmyphage no disponible; omitiendo asignación taxonómica"
fi

# =============================================================================
# 4. CRIBADO DE SEGURIDAD
# =============================================================================
activate_env phage-safe

# ---------- 4a. Resistencia a antimicrobianos --------------------------------
if command -v amrfinder >/dev/null 2>&1; then
  record_version amrfinder amrfinder --version
  AMR_DB_VER="$(amrfinder --database_version 2>&1 | head -1 || echo 'no determinada')"
  record_db_version "amrfinderplus" "$AMR_DB_VER"

  log "Cribado de resistencia con AMRFinderPlus"
  amrfinder \
    -p "$FINAL_FAA" \
    -n "$GENOME" \
    -o "${SAFE}/amrfinder.tsv" \
    --plus --threads "$THREADS" \
    >"${LOGDIR}/amrfinder.log" 2>&1 \
    || warn "AMRFinderPlus terminó con error"

  N_AMR=$(($(wc -l < "${SAFE}/amrfinder.tsv") - 1))
  [[ $N_AMR -lt 0 ]] && N_AMR=0
  record_metric "hits_amr" "$N_AMR"

  if [[ "$N_AMR" -gt 0 ]]; then
    warn "${N_AMR} coincidencias con la base de resistencia. REQUIEREN REVISIÓN MANUAL."
    # Se separan las coincidencias de identidad y cobertura altas, que son las
    # que sustentan una exclusión, de las parciales, que no.
    awk -F'\t' 'NR>1 && $17>=90 && $16>=90 {print}' "${SAFE}/amrfinder.tsv" \
      > "${SAFE}/amr_alta_confianza.tsv" || true
    N_AMR_HC=$(wc -l < "${SAFE}/amr_alta_confianza.tsv")
    record_metric "hits_amr_alta_confianza" "$N_AMR_HC"
    column -t "${SAFE}/amrfinder.tsv" | head -10 >&2
  else
    ok "Sin coincidencias de resistencia"
  fi
else
  warn "AMRFinderPlus no disponible"; N_AMR=0; N_AMR_HC=0
fi

# ---------- 4b. Virulencia ----------------------------------------------------
VFDB_SRC="${ANN}/pharokka/${SAMPLE}_top_hits_vfdb.tsv"
if [[ -f "$VFDB_SRC" ]]; then
  cp "$VFDB_SRC" "${VIRD}/vfdb_hits.tsv"
  N_VF=$(($(wc -l < "${VIRD}/vfdb_hits.tsv") - 1))
  [[ $N_VF -lt 0 ]] && N_VF=0
else
  echo -e "gene\tidentity\tcoverage\tannotation" > "${VIRD}/vfdb_hits.tsv"
  N_VF=0
fi
record_metric "hits_virulencia" "$N_VF"
[[ "$N_VF" -gt 0 ]] && warn "${N_VF} coincidencias con la base de virulencia" \
                    || ok "Sin coincidencias de virulencia"

# ---------- 4c. Marcadores de lisogenia --------------------------------------
log "Buscando marcadores de lisogenia"
grep -iE "integrase|recombinase|repressor|excisionase|transposase|antirepressor|parA|parB" \
  "$FINAL_GBK" > "${LIFED}/lysogeny.txt" 2>/dev/null || true
N_LYS=$(wc -l < "${LIFED}/lysogeny.txt")
record_metric "marcadores_lisogenia" "$N_LYS"

# El represor y la integrasa son los marcadores decisivos; transposasa y
# recombinasa pueden aparecer en fagos líticos sin implicar lisogenia.
N_LYS_CRIT=$(grep -icE "integrase|excisionase" "${LIFED}/lysogeny.txt" 2>/dev/null || echo 0)
record_metric "marcadores_lisogenia_criticos" "$N_LYS_CRIT"

if [[ "$N_LYS_CRIT" -gt 0 ]]; then
  warn "${N_LYS_CRIT} marcadores críticos (integrasa/excisionasa) detectados"
  cat "${LIFED}/lysogeny.txt" >&2
elif [[ "$N_LYS" -gt 0 ]]; then
  warn "${N_LYS} marcadores no críticos. Verificar anotación individualmente."
else
  ok "Sin marcadores de lisogenia"
fi

# ---------- 4d. Predicción de estilo de vida ---------------------------------
if command -v bacphlip >/dev/null 2>&1; then
  record_version bacphlip bacphlip --version
  cp "$GENOME" "${LIFED}/tmp_genome.fasta"
  bacphlip -i "${LIFED}/tmp_genome.fasta" --force_overwrite \
    >"${LOGDIR}/bacphlip.log" 2>&1 || warn "BACPHLIP falló"
  if [[ -f "${SAFE}/tmp_genome.fasta.bacphlip" ]]; then
    mv "${SAFE}/tmp_genome.fasta.bacphlip" "${LIFED}/bacphlip.tsv"
    P_VIR=$(awk -F'\t' 'NR==2{print $2}' "${LIFED}/bacphlip.tsv")
    P_TEMP=$(awk -F'\t' 'NR==2{print $3}' "${LIFED}/bacphlip.tsv")
    record_metric "prob_virulento" "${P_VIR:-NA}"
    record_metric "prob_temperado" "${P_TEMP:-NA}"
    log "BACPHLIP → virulento ${P_VIR} · temperado ${P_TEMP}"
  fi
  rm -f "${LIFED}/tmp_genome.fasta"
else
  warn "BACPHLIP no disponible"; P_VIR="NA"
fi

# =============================================================================
# 5. VEREDICTO DE APTITUD
# =============================================================================
# La clasificación exige convergencia de tres líneas de evidencia. Ninguna
# basta por sí sola: la ausencia de integrasa no demuestra carácter lítico, y
# las predicciones computacionales son probabilísticas.
VERDICT="APTO"
REASONS=()

if [[ "${N_AMR_HC:-0}" -gt 0 ]]; then
  VERDICT="NO APTO"; REASONS+=("resistencia confirmada (${N_AMR_HC} genes)")
elif [[ "${N_AMR:-0}" -gt 0 ]]; then
  VERDICT="REVISIÓN MANUAL"; REASONS+=("coincidencias parciales de resistencia (${N_AMR})")
fi

if [[ "${N_VF:-0}" -gt 0 ]]; then
  [[ "$VERDICT" == "APTO" ]] && VERDICT="REVISIÓN MANUAL"
  REASONS+=("coincidencias de virulencia (${N_VF})")
fi

if [[ "${N_LYS_CRIT:-0}" -gt 0 ]]; then
  VERDICT="NO APTO"; REASONS+=("marcadores de lisogenia críticos (${N_LYS_CRIT})")
elif [[ "${N_LYS:-0}" -gt 0 ]]; then
  [[ "$VERDICT" == "APTO" ]] && VERDICT="REVISIÓN MANUAL"
  REASONS+=("marcadores de lisogenia no críticos (${N_LYS})")
fi

if [[ "${P_VIR:-NA}" != "NA" ]] && awk "BEGIN{exit !(${P_VIR:-0} < 0.8)}"; then
  [[ "$VERDICT" == "APTO" ]] && VERDICT="REVISIÓN MANUAL"
  REASONS+=("probabilidad de carácter virulento inferior a 0,8 (${P_VIR})")
fi

{
  echo "MUESTRA: ${SAMPLE}"
  echo "FECHA:   $(date -Iseconds)"
  echo ""
  echo "VEREDICTO DE APTITUD PARA BIOCONTROL: ${VERDICT}"
  echo ""
  if [[ ${#REASONS[@]} -gt 0 ]]; then
    echo "Motivos:"
    printf '  - %s\n' "${REASONS[@]}"
  else
    echo "Sin hallazgos que impidan su consideración como candidato."
  fi
  echo ""
  echo "EVIDENCIA"
  echo "  CDS predichos:                  ${N_CDS}"
  echo "  Coincidencias de resistencia:   ${N_AMR:-0} (alta confianza: ${N_AMR_HC:-0})"
  echo "  Coincidencias de virulencia:    ${N_VF:-0}"
  echo "  Marcadores de lisogenia:        ${N_LYS:-0} (críticos: ${N_LYS_CRIT:-0})"
  echo "  Probabilidad virulento:         ${P_VIR:-NA}"
  echo ""
  echo "ADVERTENCIAS METODOLÓGICAS"
  echo "  - Las bases de resistencia se construyeron sobre genes bacterianos."
  echo "    Una proteína fágica puede compartir un dominio sin cumplir esa función."
  echo "    Toda coincidencia requiere verificación manual antes de excluir."
  echo "  - La ausencia de integrasa identificable no demuestra carácter"
  echo "    estrictamente lítico."
  echo "  - Los fagos líticos pueden mediar transducción generalizada; el"
  echo "    análisis del genoma del fago no descarta esa capacidad."
  echo "  - Este veredicto es computacional y requiere confirmación fenotípica."
} > "${D_REP}/veredicto.txt"

cat "${D_REP}/veredicto.txt" >&2
record_metric "veredicto_biocontrol" "$VERDICT"

timer_end "annotate_screen"
mark_done "$ANN"

case "$VERDICT" in
  "APTO")            exit $EXIT_OK ;;
  "REVISIÓN MANUAL") exit $EXIT_QC_WARN ;;
  *)                 exit $EXIT_QC_FAIL ;;
esac
