# Concordancia entre el manual y el repositorio

El manual y el repositorio son documentos distintos con funciones distintas.

| | Manual | Repositorio |
|---|---|---|
| Función | Obra metodológica registrable | Implementación ejecutable |
| Contenido | Fundamento, criterios, interpretación | Scripts, parámetros, automatización |
| Destino | DINNOVA / SENADI | GitHub |
| Actualización | Por edición formal | Por control de versiones |

**La concordancia se mantiene por numeración de etapas, herramientas y umbrales, no por texto compartido.**

## Advertencia sobre duplicación de texto

Las fichas de `docs/steps/` son deliberadamente operativas: entradas, salidas, parámetros y umbrales. No reproducen la prosa conceptual del manual.

El motivo es concreto. Si el repositorio se publica antes del control antiplagio institucional y las fichas contuvieran la prosa del manual, el manual marcaría similitud contra su propio repositorio. Sería un falso positivo, pero obligaría a explicarlo.

## Tabla de correspondencia

| Etapa | Script | Ficha | Manual |
|---|---|---|---|
| Basecalling | `01_basecall.sh` | `docs/steps/01_basecalling.md` | §7 |
| Demultiplexado | `02_demux.sh` | `docs/steps/02_demultiplexado.md` | §8 |
| QC, filtrado, submuestreo | `03_readqc_filter.sh` | `docs/steps/03_qc_filtrado.md` | §9–10 |
| Ensamblaje y validación | `04_assemble_validate.sh` | `docs/steps/04_ensamblaje.md` | §11–12 |
| Pulido | `05_polish.sh` | `docs/steps/05_pulido.md` | §13 |
| Extremos y orientación | `06_termini_orient.sh` | `docs/steps/06_extremos.md` | §14 |
| Anotación y cribado | `07_annotate_screen.sh` | `docs/steps/07_anotacion_seguridad.md` | §15–21 |
| Informe final | `08_report.sh` | `docs/steps/08_informe.md` | §24 |
| — | — | — | §22 genómica comparativa |
| — | — | — | §23 depósito público |

Las secciones 22 y 23 del manual no tienen script asociado: la selección de genomas de comparación y la preparación del depósito exigen decisiones que no conviene automatizar.

## Umbrales compartidos

Estos valores deben coincidir entre `config/config.yaml` y el manual. Si cambia uno, cambian ambos.

| Parámetro | Valor | Manual |
|---|---|---|
| Cobertura PASA / ADVERTENCIA | 60× / 30× | §9 |
| Q mínimo | 10 | §10.2 |
| Longitud mínima | 1000 pb | §10.2 |
| Cobertura objetivo | 100× | §10.3 |
| Lecturas mapeadas PASA | 90% | §12.1 |
| Contigs esperados | 1 | §11.2 |
| Identidad AMR alta confianza | 90% | §18 |
| Umbral taxonómico género / especie | 70% / 95% | §15.1 |

## Estructura de directorios

El repositorio reproduce la nomenclatura del manual (§24.2):

| Directorio | Contenido | Manual |
|---|---|---|
| `01_raw/` | Archivos de señal | §7 |
| `02_basecalling/` | BAM sin alinear | §7.3 |
| `03_demultiplexed/` | FASTQ por barcode | §8 |
| `04_qc/` | Métricas de lecturas y ensamblaje | §9, §12 |
| `05_filtered/` | FASTQ filtrado y submuestreado | §10 |
| `06_assembly/` | Contigs, grafo, BAM de validación | §11 |
| `07_polishing/` | Consenso pulido | §13 |
| `08_termini/` | Análisis de extremos y reorientación | §14 |
| `09_taxonomy/` | Asignación ICTV y comparación | §15, §22 |
| `10_annotation/` | Pharokka y phold | §16, §17 |
| `11_amr/` | Cribado de resistencia | §18 |
| `12_virulence/` | Cribado de virulencia | §19 |
| `13_lifestyle/` | Estilo de vida y lisogenia | §20 |
| `14_final_genome/` | Genoma liberado | §24 |
| `15_reports/` | Versiones, métricas, veredicto, informe | §24.4 |

**Única diferencia deliberada.** El repositorio antepone `results/<muestra>/` a esta estructura. El manual describe el flujo para una muestra; el nivel adicional permite el procesamiento por lotes de §5.5 sin que dos bacteriófagos de la misma corrida colisionen en las mismas rutas.

## Verificación de concordancia

Antes de publicar una versión del repositorio, comprobar:

```bash
# Las referencias § de scripts y fichas existen en el manual
grep -rhoE '§[0-9]+' scripts/ docs/ | sort -u

# Los umbrales del config coinciden con la tabla de esta página
grep -E '^(cov_pass|cov_warn|min_qscore|min_length|target_coverage|mapped_pass|expected_contigs):' config/config.yaml
```

## Al modificar el manual

1. Si cambia un umbral, actualizar `config/config.yaml` y esta tabla.
2. Si cambia la numeración de secciones, actualizar las referencias `§` de las fichas y los comentarios de cabecera de los scripts.
3. Si se añade una etapa, crear script, ficha y entrada en la tabla de correspondencia.
