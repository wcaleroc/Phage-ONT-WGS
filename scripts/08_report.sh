#!/usr/bin/env bash
# =============================================================================
# 08_report.sh — informe final consolidado
# Manual §24
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
usage(){ echo "Uso: 08_report.sh [--config R] [--sample N]"; }
parse_common_args "$@"; init_step "Informe final"

REP="$D_REP"; mkdir -p "$REP"
M="${D_REP}/metrics.tsv"; require_file "$M"

get(){ awk -F'\t' -v k="$1" '$2==k{v=$3} END{print (v==""?"NA":v)}' "$M"; }
st(){  awk -F'\t' -v k="$1" '$2==k{v=$4} END{print (v==""?"-":v)}' "$M"; }

OUT="${REP}/${SAMPLE}_informe.md"
{
echo "# Informe de análisis genómico — ${SAMPLE}"
echo ""
echo "Generado: $(date -Iseconds) · Host: $(hostname)"
echo ""
echo "## Lista de liberación (Manual §24.1)"
echo ""
echo "| # | Verificación | Valor | Estado |"
echo "|---|---|---|---|"
echo "| 1 | Contigs | $(get numero_contigs) | $(st numero_contigs) |"
echo "| 2 | Cobertura media | $(get cobertura_media_ensamblaje)× | $(st cobertura_media_ensamblaje) |"
echo "| 3 | Lecturas mapeadas | $(get lecturas_mapeadas_pct)% | $(st lecturas_mapeadas_pct) |"
echo "| 4 | Completitud CheckV | $(get completitud_checkv)% | - |"
echo "| 5 | Longitud final | $(get longitud_genoma_final) pb | - |"
echo "| 6 | Arquitectura terminal | $(get arquitectura_terminal) | - |"
echo "| 7 | Reorientación | $(get reorientacion) | - |"
echo "| 8 | Género asignado | $(get genero_asignado) | - |"
echo "| 9 | CDS predichos | $(get cds_predichos) | - |"
echo "| 10 | Resistencia | $(get hits_amr) ($(get hits_amr_alta_confianza) alta conf.) | - |"
echo "| 11 | Virulencia | $(get hits_virulencia) | - |"
echo "| 12 | Lisogenia | $(get marcadores_lisogenia) ($(get marcadores_lisogenia_criticos) críticos) | - |"
echo "| 13 | Contaminación | ver kraken_report.txt | - |"
echo "| 14 | Comparación genómica | ver taxonomy/ | - |"
echo "| 15 | Versiones registradas | software_versions.tsv | - |"
echo ""
echo "## Veredicto de aptitud"
echo ""
echo "**$(get veredicto_biocontrol)**"
echo ""
[[ -f "${D_REP}/veredicto.txt" ]] && { echo '```'; cat "${D_REP}/veredicto.txt"; echo '```'; }
echo ""
echo "## Métricas completas"
echo ""
echo '```'
column -t "$M"
echo '```'
echo ""
echo "## Versiones de software y bases de datos"
echo ""
echo '```'
column -t "${D_REP}/software_versions.tsv" 2>/dev/null || echo "no disponible"
echo '```'
} > "$OUT"

# Versión TSV legible por máquina
{
  printf 'muestra\tmetrica\tvalor\testado\n'
  awk -F'\t' -v s="$SAMPLE" 'NR>1{printf "%s\t%s\t%s\t%s\n",s,$2,$3,$4}' "$M"
} > "${REP}/${SAMPLE}_metricas.tsv"

ok "Informe: $OUT"
command -v pandoc >/dev/null 2>&1 && pandoc "$OUT" -o "${REP}/${SAMPLE}_informe.html" 2>/dev/null && log "HTML generado"
timer_end "report"
