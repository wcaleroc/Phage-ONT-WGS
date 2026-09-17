# 01. Conversión de señal a secuencia

**Script:** `scripts/01_basecall.sh` · **Manual:** §7

## Entrada
POD5 + modelo Dorado

## Salida
BAM sin alinear + resumen

## Requisitos
GPU NVIDIA con CUDA

## Parámetros

| Parámetro | Valor | Comentario |
|---|---|---|
| `dorado_model` | dna_r10.4.1_e8.2_400bps_sup@v5.2.0 | Debe corresponder a la química |
| `kit` | SQK-NBD114.24 | Idéntico al usado en el demux |
| `--device` | cuda:all | cpu es impracticable con SUP |

## Controles de calidad

| Métrica | Criterio | Interpretación |
|---|---|---|
| `flowcell` | FLO-MIN114 o PRO114 | R10.4.1 |
| `lecturas_basecalled` | >0 | BAM no vacío |

## Problemas frecuentes

```
Modelo no reconocido: tomar el nombre de `dorado download --list`.
CUDA out of memory: reducir lote o pedir GPU mayor.
```

## Ejecución

```bash
bash scripts/01_basecall.sh --config config/mi_proyecto.yaml --sample F6
```

Código de salida: `0` PASA · `11` ADVERTENCIA · `10` FALLA
