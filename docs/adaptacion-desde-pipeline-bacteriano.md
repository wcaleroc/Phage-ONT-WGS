# Adaptación desde un pipeline bacteriano de ONT

Notas para quien ya tiene un flujo de ensamblaje de *Salmonella* y quiere reutilizarlo.

## Lo que se conserva sin cambios

- Basecalling con Dorado y selección de modelo según química
- Demultiplexado
- NanoPlot, seqkit, chopper para control de calidad
- Flye como ensamblador (`--nano-hq` para R10.4.1 con SUP)
- minimap2 + samtools + mosdepth para validación
- Medaka o `dorado polish` para el consenso

## Lo que cambia

### Submuestreo pasa de opcional a obligatorio

Un genoma bacteriano de 5 Mb con 2 Gb de datos queda en 400×, dentro del rango operativo de Flye. Un genoma fágico de 45 kb con los mismos datos queda en más de 40 000×. A esa cobertura Flye fragmenta el ensamblaje, consume memoria de forma desproporcionada y genera contigs espurios.

Es la causa más frecuente de fallos que se atribuyen erróneamente a datos deficientes.

### CheckM2 no aplica

CheckM2 estima completitud a partir de conjuntos de genes universales de copia única. Los virus no poseen un conjunto equivalente. Su uso sobre un genoma fágico no produce error, produce un resultado sin significado.

El reemplazo es CheckV, que estima completitud por comparación con genomas virales de referencia y detecta regiones de origen bacteriano incorporadas al ensamblaje.

### Bakta y Prokka pierden genes

Ambos emplean predictores entrenados sobre genomas bacterianos. Los genomas fágicos presentan densidad codificante superior, genes más cortos, marcos solapantes y codones de inicio atípicos. Pharokka emplea PHANOTATE, que considera estas características.

Conviene además añadir phold, que recupera función en proteínas sin homólogos de secuencia mediante comparación de estructuras predichas.

### La orientación usa otro gen de referencia

`dnaapler chromosome` reorienta al gen dnaA, que no existe en fagos. El modo `dnaapler phage` reorienta a la subunidad grande de la terminasa, que es la convención comunitaria.

### La taxonomía no usa marcadores ribosómicos

GTDB-Tk se apoya en genes marcadores bacterianos. Para fagos se emplean criterios de identidad nucleotídica intergenómica del ICTV: aproximadamente 70 % para género y 95 % para especie, mediante taxmyPHAGE.

### Aparece una etapa sin equivalente bacteriano

El análisis de arquitectura terminal. Repeticiones terminales directas, permutación circular y extremos cohesivos determinan el mecanismo de empaquetamiento y deben establecerse con evidencia propia. La circularidad que reporta el ensamblador es topológica y no resuelve la cuestión.

### El cribado de seguridad es decisorio

En un genoma bacteriano, detectar genes de resistencia es un hallazgo descriptivo. En un fago destinado a biocontrol, es un criterio de exclusión. El paso 07 emite un veredicto explícito y documenta la evidencia que lo sustenta.

## Equivalencia de entornos

| Entorno bacteriano | Entorno de fagos | Cambio |
|---|---|---|
| `ont-qc` | `phage-qc` | Añade mosdepth |
| `ont-asm` | `phage-asm` | Igual |
| `ont-polish` | `phage-polish` | Igual |
| `ont-eval` | `phage-qual` | CheckM2 → CheckV; añade dnaapler |
| `ont-annot` | `phage-annot` + `phage-phold` | Bakta → Pharokka; añade phold |
| — | `phage-tax` | Nuevo: taxmyPHAGE |
| — | `phage-safe` | Nuevo: AMRFinderPlus, BACPHLIP, Kraken2 |
