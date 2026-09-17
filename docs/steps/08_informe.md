# 08. Informe final

**Script:** `scripts/08_report.sh` · **Manual:** §24

## Entrada
metrics.tsv + software_versions.tsv

## Salida
Informe md/html + TSV

## Requisitos
—

## Parámetros

| Parámetro | Valor | Comentario |
|---|---|---|
| `—` | — | Sin parámetros |

## Controles de calidad

| Métrica | Criterio | Interpretación |
|---|---|---|
| `lista de liberación` | 15 verificaciones | Ninguna en FALLA |

## Problemas frecuentes

```
Si faltan métricas, el paso correspondiente no se ejecutó o falló.
```

## Ejecución

```bash
bash scripts/08_report.sh --config config/mi_proyecto.yaml --sample F6
```

Código de salida: `0` PASA · `11` ADVERTENCIA · `10` FALLA
