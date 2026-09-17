# 07. Anotación, taxonomía y cribado

**Script:** `scripts/07_annotate_screen.sh` · **Manual:** §15-21

## Entrada
genoma final

## Salida
Anotación + veredicto de aptitud

## Requisitos
GPU opcional para phold

## Parámetros

| Parámetro | Valor | Comentario |
|---|---|---|
| `anotador` | Pharokka (PHANOTATE) | NO Prokka/Bakta |
| `-g` | prodigal-gv | Códigos genéticos alternativos |
| `phold` | activado | Recupera hipotéticas por estructura |

## Controles de calidad

| Métrica | Criterio | Interpretación |
|---|---|---|
| `densidad_cds_por_kb` | 1.2-2.0 | Rango típico de fagos |
| `hits_amr_alta_confianza` | 0 | identidad y cobertura >=90% |
| `marcadores_lisogenia_criticos` | 0 | integrasa/excisionasa |
| `veredicto_biocontrol` | APTO | Decisorio |

## Problemas frecuentes

```
Densidad baja: verificar código genético y ausencia de secuencia no viral.
Toda coincidencia de AMR requiere revisión manual: las bases se
construyeron sobre genes bacterianos.
```

## Ejecución

```bash
bash scripts/07_annotate_screen.sh --config config/mi_proyecto.yaml --sample F6
```

Código de salida: `0` PASA · `11` ADVERTENCIA · `10` FALLA
