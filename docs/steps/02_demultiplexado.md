# 02. Separación por código de barras

**Script:** `scripts/02_demux.sh` · **Manual:** §8

## Entrada
BAM de 01

## Salida
FASTQ por barcode

## Requisitos
—

## Parámetros

| Parámetro | Valor | Comentario |
|---|---|---|
| `kit` | SQK-NBD114.24 | Debe coincidir con 01 |
| `--emit-fastq` | activado | Salida directa a FASTQ |

## Controles de calidad

| Métrica | Criterio | Interpretación |
|---|---|---|
| `sin_clasificar_pct` | <20% | Proporción razonable |
| `lecturas_muestra` | >0 | El barcode esperado existe |

## Problemas frecuentes

```
Todos los barcodes vacíos: el kit de 01 y 02 no coincide.
El archivo de barcodes NO demuestra identidad: verificar tras el ensamblaje.
```

## Ejecución

```bash
bash scripts/02_demux.sh --config config/mi_proyecto.yaml --sample F6
```

Código de salida: `0` PASA · `11` ADVERTENCIA · `10` FALLA
