# 05. Pulido del consenso

**Script:** `scripts/05_polish.sh` · **Manual:** §13

## Entrada
assembly.fasta + lecturas

## Salida
consensus.fasta

## Requisitos
—

## Parámetros

| Parámetro | Valor | Comentario |
|---|---|---|
| `polisher` | medaka | o dorado polish |
| `--bacteria` | desactivado con v6 | Ver §13.2 |

## Controles de calidad

| Métrica | Criterio | Interpretación |
|---|---|---|
| `delta_longitud_pulido` | <1% | Cambio grande = problema |
| `motivos_gttc_pre/post` | iguales | Sin efecto de sistemas dnd |

## Problemas frecuentes

```
ADVERTENCIA §13.2: con modelos v6.0, la opción orientada a bacterias
introduce errores en aislados con sistemas dnd (motivo GTTC), frecuentes
en Salmonella enterica. Verificar contextos GTTC antes de aceptar.
```

## Ejecución

```bash
bash scripts/05_polish.sh --config config/mi_proyecto.yaml --sample F6
```

Código de salida: `0` PASA · `11` ADVERTENCIA · `10` FALLA
