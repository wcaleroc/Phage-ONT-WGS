# phage-ont-wgs

Repositorio de scripts y archivos de configuración para el procesamiento bioinformático de genomas completos de bacteriófagos obtenidos mediante secuenciación Oxford Nanopore.

El repositorio acompaña al Manual 1.0:

> Calero-Cáceres, W. R. (2026). *Procesamiento bioinformático de genomas completos de bacteriófagos: flujo de trabajo bioinformático a partir de datos de secuenciación de tercera generación mediante tecnología Oxford Nanopore*. Manual técnico-científico. Universidad Técnica de Ambato.

El manual se encuentra disponible de forma privada y constituye el documento metodológico de referencia para este flujo de trabajo.

---

## Sobre este repositorio

Este proyecto reúne los scripts desarrollados para llevar a la práctica el procedimiento descrito en el Manual 1.0. La organización del código sigue la secuencia de trabajo utilizada para procesar los datos de un bacteriófago desde los archivos de señal generados por Oxford Nanopore hasta la obtención de un genoma ensamblado, pulido, orientado y anotado.

El flujo fue desarrollado inicialmente para bacteriófagos líticos de *Salmonella enterica* y está pensado para su ejecución en sistemas Linux, incluyendo infraestructura de cómputo de alto rendimiento (HPC).

El repositorio contiene el código y la configuración necesaria para reproducir el análisis. Los datos de secuenciación y los genomas obtenidos durante los proyectos de investigación no forman parte de este repositorio.

---

## Flujo de análisis

El procesamiento se divide en ocho etapas principales:

1. **Basecalling**  
   Conversión de los datos de señal almacenados en POD5 a secuencias mediante Dorado.

2. **Demultiplexado**  
   Separación de las lecturas según los códigos de barras utilizados durante la preparación de la biblioteca.

3. **Control de calidad y filtrado**  
   Evaluación de longitud, calidad y rendimiento de las lecturas, seguida del filtrado y control de cobertura.

4. **Ensamblaje y validación**  
   Ensamblaje de novo con Flye y evaluación mediante mapeo de lecturas, cobertura y herramientas específicas para genomas virales.

5. **Pulido del consenso**  
   Corrección de errores residuales mediante realineamiento de las lecturas contra el ensamblaje.

6. **Extremos y orientación**  
   Revisión de la arquitectura terminal y establecimiento de una orientación reproducible del genoma.

7. **Anotación y caracterización**  
   Anotación de genes, asignación funcional, clasificación taxonómica y cribado de características relevantes para la evaluación del bacteriófago.

8. **Informe final**  
   Consolidación de métricas, versiones de software, parámetros y resultados obtenidos durante el análisis.

---

## Una consideración importante sobre los genomas de fagos

El flujo no utiliza directamente un pipeline diseñado para genomas bacterianos.

Los genomas de bacteriófagos presentan características que requieren herramientas y criterios específicos, entre ellas:

- alta densidad de regiones codificantes;
- genes de pequeño tamaño;
- genes solapantes;
- codones de inicio no convencionales;
- ausencia de marcadores universales equivalentes a los utilizados para evaluar genomas celulares;
- arquitecturas terminales particulares;
- elevada proporción de proteínas cuya función no puede determinarse únicamente mediante homología de secuencia.

Por este motivo, el procedimiento incorpora herramientas específicas para genomas virales, entre ellas CheckV, Pharokka/PHANOTATE, phold, taxmyPHAGE, dnaapler y BACPHLIP.

La adaptación del flujo respecto del análisis de genomas bacterianos se describe con mayor detalle en:

`docs/adaptacion-desde-pipeline-bacteriano.md`

---

## Estructura del repositorio

```text
phage-ont-wgs/
│
├── README.md
├── CITATION.cff
├── LICENSE
├── run_all.sh
│
├── config/
│   ├── config.yaml
│   └── samples.tsv
│
├── docs/
│   ├── CONCORDANCIA.md
│   ├── adaptacion-desde-pipeline-bacteriano.md
│   └── steps/
│       ├── 01_basecalling.md
│       ├── 02_demultiplexado.md
│       ├── 03_qc_filtrado.md
│       ├── 04_ensamblaje.md
│       ├── 05_pulido.md
│       ├── 06_extremos.md
│       ├── 07_anotacion_seguridad.md
│       └── 08_informe.md
│
├── envs/
│   ├── phage-annot.yml
│   ├── phage-asm.yml
│   ├── phage-phold.yml
│   ├── phage-polish.yml
│   ├── phage-qc.yml
│   ├── phage-qual.yml
│   ├── phage-safe.yml
│   └── phage-tax.yml
│
├── scripts/
│   ├── 00_setup_envs.sh
│   ├── 01_basecall.sh
│   ├── 02_demux.sh
│   ├── 03_readqc_filter.sh
│   ├── 04_assemble_validate.sh
│   ├── 05_polish.sh
│   ├── 06_termini_orient.sh
│   ├── 07_annotate_screen.sh
│   ├── 08_report.sh
│   └── lib/
│       └── common.sh
│
└── slurm/
    ├── array.sbatch
    ├── basecall.sbatch
    └── pipeline.sbatch
