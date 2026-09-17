# phage-ont-wgs

Pipeline reproducible para el ensamblaje y la caracterización de genomas completos de bacteriófagos a partir de datos de secuenciación Oxford Nanopore.

Derivado del pipeline de ensamblaje de *Salmonella* del grupo, con las adaptaciones necesarias para genomas virales.

---

## Por qué un pipeline separado del bacteriano

Tres herramientas del flujo bacteriano estándar **no son aplicables** a genomas de bacteriófagos. Esta es la diferencia central que justifica el repositorio.

| Etapa | Pipeline bacteriano | Pipeline de fagos | Motivo |
|---|---|---|---|
| Completitud | CheckM2 | **CheckV** | Los virus carecen de genes universales de copia única; los marcadores bacterianos no tienen equivalente |
| Anotación | Bakta / Prokka | **Pharokka** (PHANOTATE) | Prodigal pierde genes pequeños, solapados y con codones de inicio atípicos, frecuentes en fagos |
| Métricas | QUAST | CheckV + mosdepth | QUAST fue concebido para ensamblajes fragmentados; aporta poco sobre un contig único |
| Cobertura | — | **rasusa obligatorio** | Un genoma de 45 kb alcanza coberturas de miles de veces que degradan a Flye |
| Orientación | dnaapler chromosome (dnaA) | **dnaapler phage** (terL) | Convención distinta para el punto de inicio |
| Taxonomía | GTDB-Tk | **taxmyPHAGE** | Criterios ICTV de identidad intergenómica, no marcadores ribosómicos |
| Anotación funcional | — | **phold** | La comparación estructural recupera función en proteínas sin homólogos de secuencia |

---

## Flujo

```
POD5
 ├─ 01  Dorado basecalling (SUP)            → BAM
 ├─ 02  Dorado demux                        → FASTQ por barcode
 ├─ 03  QC + chopper + rasusa               → FASTQ submuestreado   [COMPUERTA]
 ├─ 04  Flye + minimap2 + mosdepth + CheckV → ensamblaje validado   [COMPUERTA]
 ├─ 05  Medaka | dorado polish              → consenso
 ├─ 06  Análisis de extremos + dnaapler     → genoma orientado
 ├─ 07  Pharokka + phold + taxmyPHAGE       → anotación
 │       + AMRFinderPlus + VFDB + BACPHLIP  → veredicto de aptitud  [COMPUERTA]
 └─ 08  Informe final
```

Las compuertas devuelven `0` (PASA), `11` (ADVERTENCIA) o `10` (FALLA). El orquestador detiene el pipeline ante un FALLA salvo que se indique `--continue-on-fail`.

---

## Instalación

```bash
git clone https://github.com/TU_USUARIO_GITHUB/phage-ont-wgs.git
cd phage-ont-wgs
cp config/config.yaml config/mi_proyecto.yaml
# editar rutas, muestra, química y modelo
bash scripts/00_setup_envs.sh --config config/mi_proyecto.yaml
```

Requiere Miniforge/Mamba y, para el basecalling, una GPU NVIDIA con CUDA. Las bases de datos ocupan varias decenas de GB y deben descargarse desde un nodo con salida a internet.

---

## Uso

```bash
# Pipeline completo desde señal cruda
bash run_all.sh --config config/mi_proyecto.yaml

# Desde FASTQ ya basecalled
bash run_all.sh --config config/mi_proyecto.yaml --skip-basecall

# Un rango de pasos
bash run_all.sh --from 3 --to 5 --sample F6

# Lote de muestras
bash run_all.sh --batch config/samples.tsv

# Ver qué se ejecutaría
bash run_all.sh --dry-run
```

Cada paso escribe un centinela `.done` al terminar. Relanzar el pipeline omite lo ya hecho; `--force` lo repite.

---

## Salidas

```
results/<muestra>/
├── 01_raw/              archivos de señal, resumen de la corrida
├── 02_basecalling/      <muestra>_calls.bam
├── 03_demultiplexed/    <barcode>.fastq
├── 04_qc/               NanoPlot, seqkit, flagstat, cobertura, CheckV
├── 05_filtered/         filtered.fastq.gz, subsampled.fastq.gz
├── 06_assembly/         assembly.fasta, assembly_info.txt, grafo, aln.bam
├── 07_polishing/        consensus.fasta
├── 08_termini/          análisis de extremos, genoma reorientado
├── 09_taxonomy/         Summary_taxonomy.tsv
├── 10_annotation/       pharokka/, phold/
├── 11_amr/              amrfinder.tsv, versión de base de datos
├── 12_virulence/        vfdb_hits.tsv
├── 13_lifestyle/        bacphlip.tsv, lysogeny.txt
├── 14_final_genome/     <muestra>_genome.fasta
└── 15_reports/          software_versions.tsv, metrics.tsv, veredicto.txt, informe
```

Nomenclatura concordante con el manual metodológico (§24.2). El nivel adicional `results/<muestra>/` permite el procesamiento por lotes descrito en §5.5 sin colisión entre muestras.

`software_versions.tsv` registra también las versiones de las bases de datos. Es el archivo que hace reproducible el análisis: una búsqueda de homología sobre una base actualizada produce resultados distintos en fechas distintas.

---

## Parámetros que conviene revisar

| Parámetro | Por defecto | Comentario |
|---|---|---|
| `genome_size` | 45k | Ajustar al género esperado (rango Caudoviricetes: 30–200 kb) |
| `target_coverage` | 100 | Por encima de ~200× Flye se degrada |
| `min_qscore` | 10 | Debe corresponder al modelo de basecalling |
| `min_length` | 1000 | No elevar en fagos de genoma pequeño |
| `cov_pass` / `cov_warn` | 60 / 30 | Objetivo interno; la literatura no fija umbral universal |
| `polisher` | medaka | Ver advertencia sobre *Salmonella* más abajo |

---

## Advertencia para fagos propagados en *Salmonella*

Existe un fallo documentado en el repositorio de Dorado: las herramientas de pulido, empleadas con la opción orientada a genomas bacterianos, introducen **errores sistemáticos en aislados con sistemas de modificación por fosforotioato tipo *dnd* (motivo GTTC)**, ampliamente distribuidos en *Salmonella enterica*. Se observó con modelos de basecalling de la serie v6.0 y no con los de la serie v5.

El ADN de un fago propagado en *Salmonella* puede portar estas modificaciones. Si emplea modelos v6.0, no active la opción orientada a bacterias sin verificar: compare el consenso antes y después del pulido y examine las posiciones modificadas en contextos GTTC.

---

## Limitaciones conocidas

- La inferencia de extremos requiere bibliotecas sin amplificación. PCR y amplificación por desplazamiento múltiple destruyen esa información.
- La circularidad que reporta Flye es topológica, no biológica: un genoma con permutación circular se cierra igual siendo lineal.
- El veredicto de aptitud para biocontrol es computacional. Las bases de resistencia se construyeron sobre genes bacterianos y una proteína fágica puede compartir un dominio sin cumplir esa función. Toda coincidencia requiere verificación manual.
- La ausencia de integrasa identificable no demuestra carácter estrictamente lítico, y los fagos líticos pueden mediar transducción generalizada.

---

## Documentación

- `docs/CONCORDANCIA.md` — relación con el manual metodológico y umbrales compartidos
- `docs/adaptacion-desde-pipeline-bacteriano.md` — qué cambia respecto a un flujo de *Salmonella*
- `docs/steps/` — ficha operativa por etapa: entradas, salidas, parámetros y umbrales

## Citación

Si utiliza este pipeline, cite las herramientas que lo componen (ver `docs/referencias.md`) y, si corresponde, el manual metodológico del que deriva.

## Licencia

MIT — ver `LICENSE`.
