#!/usr/bin/env bash
# =============================================================================
# common.sh — funciones compartidas por todos los pasos del pipeline
#
# Se carga al inicio de cada script con:
#     source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
#
# Provee: registro con marca de tiempo, carga de configuración, activación de
# entornos conda, reanudación por centinelas, trazabilidad de versiones,
# acumulación de métricas y compuertas de calidad con veredicto.
# =============================================================================

set -euo pipefail

# ---------- Colores (se desactivan si la salida no es una terminal) ----------
if [[ -t 2 ]]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;34m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_RST=""
fi

# ---------- Registro ---------------------------------------------------------
_ts() { date +"%Y-%m-%d %H:%M:%S"; }

log()  { echo "${C_BLU}[$(_ts)] [INFO] ${C_RST} $*" >&2; }
ok()   { echo "${C_GRN}[$(_ts)] [OK]   ${C_RST} $*" >&2; }
warn() { echo "${C_YEL}[$(_ts)] [AVISO]${C_RST} $*" >&2; }
die()  { echo "${C_RED}[$(_ts)] [ERROR]${C_RST} $*" >&2; exit 1; }

# Códigos de salida con significado propio: run_all.sh decide según el código
readonly EXIT_OK=0
readonly EXIT_FAIL=1        # error de ejecución
readonly EXIT_QC_FAIL=10    # el paso corrió pero no superó el criterio de calidad
readonly EXIT_QC_WARN=11    # advertencia: continúa, pero queda registrada

# Captura de errores no previstos con número de línea
trap 'die "Fallo inesperado en ${BASH_SOURCE[0]}, línea ${LINENO}"' ERR

# ---------- Configuración ----------------------------------------------------
# Lector minimalista de YAML plano (clave: valor). Evita dependencias externas
# como yq, que no siempre está disponible en un nodo de cómputo.
load_config() {
  local cfg="${1:?ruta al config.yaml}"
  [[ -f "$cfg" ]] || die "No existe el archivo de configuración: $cfg"
  local key val
  while IFS=':' read -r key val; do
    [[ "$key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${key// }" ]] && continue
    key="$(echo "$key" | tr -d '[:space:]')"
    val="$(echo "${val:-}" | sed -e 's/#.*$//' -e 's/^[[:space:]]*//' \
                                 -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
    [[ -z "$val" ]] && continue
    export "CFG_${key^^}=$val"
  done < "$cfg"
  log "Configuración cargada desde $cfg"
}

# ---------- Entornos conda ---------------------------------------------------
activate_env() {
  local env_name="${1:?nombre del entorno}"
  local conda_base
  if command -v conda >/dev/null 2>&1; then
    conda_base="$(conda info --base)"
  elif [[ -n "${CONDA_EXE:-}" ]]; then
    conda_base="$(dirname "$(dirname "$CONDA_EXE")")"
  else
    die "conda no está disponible en el PATH"
  fi
  # shellcheck disable=SC1091
  source "${conda_base}/etc/profile.d/conda.sh"
  conda activate "$env_name" 2>/dev/null \
    || die "No se pudo activar '$env_name'. Ejecute scripts/00_setup_envs.sh"
  log "Entorno activo: $env_name"
}

require_cmd() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || die "Comando no encontrado: $c"
  done
}

require_file() {
  local f
  for f in "$@"; do
    [[ -s "$f" ]] || die "Archivo ausente o vacío: $f"
  done
}

# ---------- Reanudación ------------------------------------------------------
# Cada paso escribe un centinela .done al terminar. Si existe y no se pasa
# --force, el paso se omite. Permite relanzar el pipeline sin repetir trabajo
# costoso, algo esencial cuando el basecalling tarda horas.
step_done() { [[ -f "$1/.done" ]]; }
mark_done() { date -Iseconds > "$1/.done"; }

maybe_skip() {
  local outdir="$1" name="$2"
  if step_done "$outdir" && [[ "${FORCE:-0}" -ne 1 ]]; then
    warn "Paso '$name' ya completado. Use --force para repetirlo. Omitiendo."
    return 0
  fi
  return 1
}

# ---------- Trazabilidad de versiones ----------------------------------------
# Registra la versión de cada herramienta en el momento exacto de su uso, no al
# final. Si el entorno cambia a mitad de campaña, el registro lo refleja.
init_versions() {
  VERSIONS_TSV="${1:?}"
  mkdir -p "$(dirname "$VERSIONS_TSV")"
  [[ -f "$VERSIONS_TSV" ]] || printf 'timestamp\therramienta\tversion\n' > "$VERSIONS_TSV"
  export VERSIONS_TSV
}

record_version() {
  local tool="$1"; shift
  local ver
  ver="$("$@" 2>&1 | head -1 | tr -d '\r' || echo 'no determinada')"
  printf '%s\t%s\t%s\n' "$(date -Iseconds)" "$tool" "$ver" >> "${VERSIONS_TSV:?}"
  log "  versión $tool: $ver"
}

# Registra la versión de una base de datos a partir de un archivo o cadena
record_db_version() {
  local db="$1" ver="$2"
  printf '%s\tDB:%s\t%s\n' "$(date -Iseconds)" "$db" "$ver" >> "${VERSIONS_TSV:?}"
}

# ---------- Métricas ---------------------------------------------------------
init_metrics() {
  METRICS_TSV="${1:?}"
  mkdir -p "$(dirname "$METRICS_TSV")"
  [[ -f "$METRICS_TSV" ]] || printf 'timestamp\tmetrica\tvalor\testado\n' > "$METRICS_TSV"
  export METRICS_TSV
}

record_metric() {
  local key="$1" value="$2" status="${3:-}"
  printf '%s\t%s\t%s\t%s\n' "$(date -Iseconds)" "$key" "$value" "$status" \
    >> "${METRICS_TSV:?}"
}

get_metric() {
  awk -F'\t' -v k="$1" '$2==k{v=$3} END{print v}' "${METRICS_TSV:?}"
}

# ---------- Compuerta de calidad ---------------------------------------------
# Compara un valor numérico contra dos umbrales y emite veredicto.
#   qc_gate "cobertura_media" 85 60 30
#     PASA        si valor >= 60
#     ADVERTENCIA si 30 <= valor < 60
#     FALLA       si valor < 30
qc_gate() {
  local name="$1" value="$2" pass_min="$3" warn_min="$4"
  local verdict
  if awk "BEGIN{exit !($value >= $pass_min)}"; then
    verdict="PASA";        ok    "$name = $value (umbral $pass_min) → PASA"
  elif awk "BEGIN{exit !($value >= $warn_min)}"; then
    verdict="ADVERTENCIA"; warn  "$name = $value (entre $warn_min y $pass_min) → ADVERTENCIA"
  else
    verdict="FALLA"
    echo "${C_RED}[$(_ts)] [FALLA]${C_RST} $name = $value (< $warn_min)" >&2
  fi
  record_metric "$name" "$value" "$verdict"
  case "$verdict" in
    PASA)        return "$EXIT_OK" ;;
    ADVERTENCIA) return "$EXIT_QC_WARN" ;;
    FALLA)       return "$EXIT_QC_FAIL" ;;
  esac
}

# Variante para criterios de igualdad exacta (ej.: número de contigs == 1)
qc_gate_eq() {
  local name="$1" value="$2" expected="$3"
  if [[ "$value" == "$expected" ]]; then
    ok "$name = $value (esperado $expected) → PASA"
    record_metric "$name" "$value" "PASA"; return "$EXIT_OK"
  fi
  warn "$name = $value (esperado $expected) → ADVERTENCIA"
  record_metric "$name" "$value" "ADVERTENCIA"; return "$EXIT_QC_WARN"
}

# ---------- Utilidades de secuencia ------------------------------------------
count_fasta()  { grep -c '^>' "$1" 2>/dev/null || echo 0; }
fasta_length() { awk '/^>/{next}{n+=length($0)}END{print n+0}' "$1"; }
fastq_bases()  { awk 'NR%4==2{n+=length($0)}END{print n+0}' "$1"; }
fastq_reads()  { awk 'END{print NR/4}' "$1"; }

human_time() {
  local s=$1
  printf '%dh %02dm %02ds' $((s/3600)) $(((s%3600)/60)) $((s%60))
}

# Cronómetro por paso
timer_start() { _T0=$(date +%s); }
timer_end()   {
  local elapsed=$(( $(date +%s) - _T0 ))
  log "Tiempo del paso: $(human_time $elapsed)"
  record_metric "tiempo_${1:-paso}" "$elapsed" ""
}

# ---------- Argumentos comunes -----------------------------------------------
parse_common_args() {
  FORCE=0
  CONFIG="${CONFIG:-config/config.yaml}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --force)   FORCE=1; shift ;;
      --config)  CONFIG="$2"; shift 2 ;;
      --sample)  SAMPLE="$2"; shift 2 ;;
      --threads) THREADS="$2"; shift 2 ;;
      --help|-h) usage; exit 0 ;;
      *) shift ;;
    esac
  done
  export FORCE CONFIG
}

# ---------- Inicialización estándar de un paso -------------------------------
# Centraliza lo que todos los scripts necesitan: config, rutas, registros.
init_step() {
  local step_name="${1:?}"
  load_config "$CONFIG"
  SAMPLE="${SAMPLE:-${CFG_SAMPLE:?defina sample en config.yaml}}"
  THREADS="${THREADS:-${CFG_THREADS:-8}}"
  PROJECT="${CFG_PROJECT:?defina project en config.yaml}"
  RESULTS="${PROJECT}/results/${SAMPLE}"
  LOGDIR="${PROJECT}/logs/${SAMPLE}"

  # Nomenclatura de directorios concordante con el manual (§24.2).
  # El nivel results/<muestra>/ adicional permite el procesamiento por lotes
  # descrito en el manual (§5.5) sin colisión entre muestras.
  D_RAW="${RESULTS}/01_raw"
  D_BC="${RESULTS}/02_basecalling"
  D_DEMUX="${RESULTS}/03_demultiplexed"
  D_QC="${RESULTS}/04_qc"
  D_FILT="${RESULTS}/05_filtered"
  D_ASM="${RESULTS}/06_assembly"
  D_POL="${RESULTS}/07_polishing"
  D_TERM="${RESULTS}/08_termini"
  D_TAX="${RESULTS}/09_taxonomy"
  D_ANN="${RESULTS}/10_annotation"
  D_AMR="${RESULTS}/11_amr"
  D_VIR="${RESULTS}/12_virulence"
  D_LIFE="${RESULTS}/13_lifestyle"
  D_FINAL="${RESULTS}/14_final_genome"
  D_REP="${RESULTS}/15_reports"
  export D_RAW D_BC D_DEMUX D_QC D_FILT D_ASM D_POL D_TERM D_TAX D_ANN \
         D_AMR D_VIR D_LIFE D_FINAL D_REP

  mkdir -p "$RESULTS" "$LOGDIR" "$D_QC" "$D_REP"
  init_versions "${D_REP}/software_versions.tsv"
  init_metrics  "${D_REP}/metrics.tsv"
  export SAMPLE THREADS PROJECT RESULTS LOGDIR
  timer_start
  log "═══ PASO: ${step_name} · muestra: ${SAMPLE} ═══"
}
