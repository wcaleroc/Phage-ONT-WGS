# 04. Ensamblaje y validación

**Script:** `scripts/04_assemble_validate.sh` · **Manual:** §11-12

## Entrada
FASTQ submuestreado

## Salida
assembly.fasta + BAM + CheckV

## Requisitos
—

## Parámetros

| Parámetro | Valor | Comentario |
|---|---|---|
| `modo Flye` | --nano-hq | R10.4.1 con SUP |
| `--meta` | activado | Tolera cobertura dispar del hospedero |
| `genome_size` | 45k | Ajustar al género esperado |

## Controles de calidad

| Métrica | Criterio | Interpretación |
|---|---|---|
| `numero_contigs` | 1 | PASA |
| `lecturas_mapeadas_pct` | >=90% | PASA |
| `cobertura_media_ensamblaje` | >=60x | PASA |
| `coef_variacion_cobertura` | <0.5 | Cobertura uniforme |

## Problemas frecuentes

```
Fragmentado con cobertura alta: falta submuestreo (paso 03).
Varios contigs de cobertura similar: población mixta, repurificar.
Cobertura dispar: contaminación del hospedero, verificar y descartar.
```

## Ejecución

```bash
bash scripts/04_assemble_validate.sh --config config/mi_proyecto.yaml --sample F6
```

Código de salida: `0` PASA · `11` ADVERTENCIA · `10` FALLA
