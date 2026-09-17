#!/usr/bin/env bash
# =============================================================================
# 00_setup_envs.sh — creación de entornos conda y descarga de bases de datos
# Ejecutar UNA VEZ desde el nodo de acceso (requiere salida a internet).
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

usage() { echo "Uso: 00_setup_envs.sh [--config RUTA] [--envs-only|--dbs-only]"; }

ENVS_ONLY=0; DBS_ONLY=0
for a in "$@"; do
  case "$a" in
    --envs-only) ENVS_ONLY=1 ;;
    --dbs-only)  DBS_ONLY=1 ;;
    --help|-h)   usage; exit 0 ;;
  esac
done
CONFIG="${CONFIG:-config/config.yaml}"
load_config "$CONFIG"

command -v mamba >/dev/null 2>&1 && SOLVER=mamba || SOLVER=conda
log "Gestor de entornos: $SOLVER"

if [[ $DBS_ONLY -eq 0 ]]; then
  for yml in "${SCRIPT_DIR}/../envs/"*.yml; do
    env_name="$(basename "$yml" .yml)"
    if conda env list | grep -qE "^${env_name}\s"; then
      warn "El entorno ${env_name} ya existe. Omitiendo."
      continue
    fi
    log "Creando entorno ${env_name}"
    $SOLVER env create -f "$yml" || warn "Falló la creación de ${env_name}"
  done
fi

if [[ $ENVS_ONLY -eq 1 ]]; then exit 0; fi

# ---------- Bases de datos ----------------------------------------------------
DB="${CFG_PROJECT}/databases"
mkdir -p "$DB"
log "Descargando bases de datos en ${DB}"
log "Esta operación requiere varias decenas de GB y salida a internet."

activate_env phage-annot && pharokka_install_database.py -o "${DB}/pharokka" || warn "Pharokka DB falló"
activate_env phage-phold && phold install --database "${DB}/phold" || warn "phold DB falló"
activate_env phage-qual  && checkv download_database "$DB" || warn "CheckV DB falló"
activate_env phage-safe  && amrfinder -u || warn "AMRFinderPlus DB falló"
activate_env phage-tax   && taxmyphage install -db "${DB}/taxmyphage" || warn "taxmyphage DB falló"

ok "Configuración completada. Actualice las rutas db_* en ${CONFIG}"
du -sh "${DB}"/* 2>/dev/null || true
