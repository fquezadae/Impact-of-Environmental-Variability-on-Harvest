# Nota — archivos SERNAPESCA de cuotas 2012–2017 (cesiones)

**Fecha:** 2026-05-28
**Para recordar mañana.**

## Qué son estos archivos

Son los reportes de control de cuota que me envió SERNAPESCA, en formato workbook
original. Sirven para **reconstruir la serie de cesiones inter-sectoriales 2013–2017**
de forma fiable (la que hoy está en `../cesiones_consolidated_2013_2024.csv` con
`source=per-titular_transparency` es de mala calidad: valores erráticos, sin jurel,
shares que no calzan).

Carpeta: `paper1/portfolio_check/raw_sernapesca/`

## Por qué importan (tarea pendiente)

1. En el apéndice H quité la cifra **"11–72%"** para cesiones 2013–2017 porque no
   tenía respaldo en ningún dato/script y contradecía el CSV procesado (rango real
   ≈ 0–28%). Con estos workbooks crudos hay que **recomputar el share cedido
   IND→ART real por año/especie 2013–2017** y, si queda comparable, reponer una
   cifra verificada en el texto.
2. Decidir si con estos datos limpios ya se pueden **agregar las filas 2013–2017 a
   la tabla de cesiones (Table H.3)**, hoy excluidas. Falta jurel en varios años.
3. Verificar que la reconstrucción 2013–2017 empate metodológicamente con la serie
   RESUMEN 2019–2024 (mismo concepto de "Movimientos"/cesión por sector).

## Dos familias de archivos

### A. Artesanal — "Control Cuota Artesanal … PELÁGICO" (2012–2017)
Cuotas artesanales y cesiones. Hojas clave para cesiones y especies pelágicas:

| Año | Archivo | Hoja(s) de cesiones | Hojas de especies pelágicas |
|-----|---------|---------------------|------------------------------|
| 2012 | `Control Cuota Artesanal 2012.xlsx` | (Resumen Cuotas Traspasos; Planillas diarias trapasos; trapasos VIII…) | Anchoveta / S.común / RAE Jurel / Jurel / S.española |
| 2013 | `Control Cuota Artesanal 2013 PELÁGICO.xlsx` | **CECIONES Y OTROS**; Resumen Cuotas Traspasos; trapasos VIII… | Anchoveta / S.común / Jurel / S.española / Sardina austral X–XI |
| 2014 | `Control Cuota Artesanal 2014 PELÁGICO.xlsx` | **CECIONES Y OTROS**; Resumen Cuotas Traspasos | Anchoveta / S.común / Jurel / S.española |
| 2015 | `Control Cuota Artesanal 2015 PELÁGICO.xlsx` | **CECIONES Y OTROS**; Resumen Cuotas Traspasos; RESUMEN publicación | Anchoveta / S.común / Jurel / S.española |
| 2016 | `Control Cuota Artesanal 2016 PELAGICO.xlsx` | **RESUMEN CESIONES Y OTROS**; RESUMEN publicación | Anchoveta / S.común / Jurel / Jurel con Línea de mano / S.española |
| 2017 | `Control Cuota Artesanal Peces Pelagicos 2017.xlsx` | **Consumo Cesiones Pelagicos** | ANCHOVETA / SARDINA COMÚN / JUREL / SARDINA ESPAÑOLA / Mixta Sardina y Anchoveta |

Notas:
- 2017 tiene estructura distinta (hojas por especie en mayúscula + "RESUMEN PELAGICOS 2017"
  y "RESUMEN PERIODO PELAGICOS"), más parecida al formato moderno.
- 2012–2016 comparten layout con hojas "Resumen", "Global", "Res. Global" y RAE por especie.

### B. Industrial — "Control Cuotas globales industriales (LTP y PEP)" (2012–2017)
Cuotas globales industriales y asignaciones por titular (LTP/PEP). Para el denominador
industrial (cuota asignada IND) y, en algunos años, la cuantificación IND–ART.

| Año | Archivo | Formato | Hojas relevantes |
|-----|---------|---------|------------------|
| 2012 | `Control Cuotas globales industriales 2012.xls` | .xls (binario antiguo) | — (revisar al abrir) |
| 2013 | `…LTP y PEP 2013.xls` | .xls | — |
| 2014 | `…LTP y PEP 2014.xls` | .xls | — |
| 2015 | `…LTP y PEP 2015.xlsx` | .xlsx | Resumen LTP; **Pelagicos LTP**; Cuotas Globales |
| 2016 | `…LTP y PEP 2016.xlsx` | .xlsx | Resumen LTP-PEP; **Pelagicos LTP**; **CUANTIFICACIÓN CUOTAS IND-ART** |
| 2017 | `…LTP y PEP 2017.xlsx` | .xlsx | Resumen LTP PEP; **Pelagicos LTP** |

Nota: los de 2012–2014 son `.xls` antiguos (hay que leerlos con un lector de xls,
p. ej. `readxl::read_excel` o convertir a xlsx); no pude listar sus hojas automáticamente.

## Especies de interés (pelágicos Centro-Sur del paper)
Anchoveta, Sardina común (= "sardine"), Jurel (= "jack mackerel"). Sardina española
y sardina austral aparecen pero no son los stocks del paper.

## Siguiente paso sugerido
Escribir/actualizar el parser (estilo `R/01_data*`) que lea estos workbooks, extraiga
asignado/cedido/efectivo/capturado por sector y especie 2013–2017, y reescriba las
filas 2013–2017 de `cesiones_consolidated_2013_2024.csv` con `source` etiquetado como
`transparency` donde corresponda.
