# 06. Arquitectura terminal y orientación

**Script:** `scripts/06_termini_orient.sh` · **Manual:** §14

## Entrada
consensus.fasta + cobertura

## Salida
genoma reorientado

## Requisitos
—

## Parámetros

| Parámetro | Valor | Comentario |
|---|---|---|
| `ventana de comparación` | 10% del genoma, máx 5 kb | Extremos a comparar |
| `dnaapler` | modo phage | Reorienta a terL, no a dnaA |

## Controles de calidad

| Métrica | Criterio | Interpretación |
|---|---|---|
| `arquitectura_terminal` | determinada | DTR o sin DTR |
| `ratio_cobertura_extremo` | ~2 si hay DTR | Evidencia complementaria |
| `reorientacion` | terL | Convención comunitaria |

## Problemas frecuentes

```
Circularidad del ensamblador = topológica, NO biológica.
Si no se localiza terL: dnaapler custom o nearest.
DTR confirmada: representar la repetición UNA sola vez al depositar.
```

## Ejecución

```bash
bash scripts/06_termini_orient.sh --config config/mi_proyecto.yaml --sample F6
```

Código de salida: `0` PASA · `11` ADVERTENCIA · `10` FALLA
