# 03. QC, filtrado y submuestreo

**Script:** `scripts/03_readqc_filter.sh` · **Manual:** §9-10

## Entrada
FASTQ de 02

## Salida
FASTQ filtrado y submuestreado

## Requisitos
—

## Parámetros

| Parámetro | Valor | Comentario |
|---|---|---|
| `min_qscore` | 10 | Debe corresponder al modelo de basecalling |
| `min_length` | 1000 | No elevar en genomas pequeños |
| `target_coverage` | 100 | Por encima de 200x Flye se degrada |
| `subsample_seed` | 42 | Fija la reproducibilidad |

## Controles de calidad

| Métrica | Criterio | Interpretación |
|---|---|---|
| `cobertura_estimada` | >=60x | PASA |
| `retencion_filtrado_pct` | >50% | Umbral compatible con el modelo |
| `n50_lectura` | >3000 pb | Sin fragmentación del ADN |

## Problemas frecuentes

```
Retención <50%: el umbral Q no corresponde al modelo.
N50 bajo: fragmentación durante la extracción (laboratorio húmedo).
```

## Ejecución

```bash
bash scripts/03_readqc_filter.sh --config config/mi_proyecto.yaml --sample F6
```

Código de salida: `0` PASA · `11` ADVERTENCIA · `10` FALLA
