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

## HALLAZGOS de la revisión (2026-05-28)

**Fuente correcta para cesión industrial Centro-Sur = workbook INDUSTRIAL, hoja
`Pelagicos LTP`.** Por unidad de pesquería hay filas por titular con columna de
cesión (col 5, "Traspaso/Cesión"). Unidades Centro-Sur relevantes:
`Anchoveta V-X`, `Sardina Común V-X`, `Jurel V-IX`, `Jurel XIV-X`.

**2017 (industrial, leído directo) — confirma el "72%":**
- Anchoveta V-X: asignada **12.56 kt**, cesión **−9.03 kt** → **72%** cedido.
- Sardina Común V-X: asignada **72.4 kt**, cesión **−48.9 kt** → **67.5%** cedido.
- Jurel V-IX: asignada 200.4 kt, cesión +7.28; Jurel XIV-X: 27.9 kt, +2.41.

Esto **coincide exacto** con `cesiones_ind_2013_2017_raw.csv` (2017). Es decir, el
**"11–72%" que borré del apéndice SÍ tenía respaldo en esta fuente industrial.**
El que está mal es `cesiones_consolidated_2013_2024.csv` (shares 0–28%, valores
erráticos tipo 3673 kt) — ese fue una agregación buggy. **Revisar si hay que
reponer "11–72%" en el texto.**

**Pendiente para cerrar el rango exacto (2013–2016):**
- 2013–2014 industriales son `.xls` antiguos → convertir (libreoffice/`readxl`) antes de parsear.
- 2015 y 2016 (`Pelagicos LTP`) tienen layout por titular con **3 filas de período**
  (Ene-Abr/May-Ago/Sep-Dic) y **sin fila de subtotal limpia** → hay que sumar por titular.
- OJO: el archivo rotulado **2016** trae filas con fechas **2015** (posible desfase de
  rótulo/año en estos LTP). Verificar a qué año corresponde cada workbook antes de usar.
- 2017 sí trae filas de subtotal por unidad (layout distinto a 2015/2016).
- Recomendado: script R en `R/01_data*` que (i) detecte la unidad por encabezado,
  (ii) sume cesión y asignada por titular para V-X / V-IX / XIV-X, (iii) escriba
  `cesiones_ind_2013_2017_raw.csv` corregido y reescriba las filas 2013–2017 del consolidated.

## Mapa de layouts industriales (Pelagicos LTP) — CRÍTICO

Cada año tiene layout distinto; **NO sirve un parser único** (probado: dio 172% en 2017).
**Las fechas internas son artefactos de plantilla (2014 trae fechas "2007") → usar el AÑO DEL TÍTULO.**

| Año | Hoja | Asignada (col) | Cesión (col) | Estructura | Notas |
|-----|------|----------------|--------------|------------|-------|
| 2013 | `Pelagicos LMC y LTP` | Cuota LMC (col2) | Cesiones o traspasos (col3) | 1 fila por armador | Año de transición LMC↔LTP; definir qué cuota es "asignada" |
| 2014 | `Pelagicos LTP ` | Cuota Asignada (col4) | Traspaso,Cesión (col5) | 2 filas período (Inicial/Final) | fechas "2007" = plantilla |
| 2015 | `Pelagicos LTP ` | col4 | col5 | 3 filas período | — |
| 2016 | `Pelagicos LTP ` | col4 | col5 | 3 filas período | título "2016", fechas 2015 = plantilla |
| 2017 | `Pelagicos LTP` | col3 | col4 | 2 filas período **+ filas SUBTOTAL** y bloque RESUMEN derecho | sub-bloque combinado "Anchoveta-Sardina Común V-X" |

**Método fiable:** usar las **filas de subtotal por unidad** (donde existen) o el bloque
**RESUMEN derecho** (`unidad | zona | Cuota Global | Período | autorizada | Cesiones | efectiva`),
NO sumar por titular (doble cuenta / mezcla sub-bloques).

### RESUELTO (2026-05-28) — tabla VERIFICADA
Script `R/01_data_cleaning/build_cesiones_ind_2013_2017.R` (validó OK contra 2017).
Salida en `paper1/portfolio_check/cesiones_ind_2013_2017_rebuilt.csv`:

| Año | Especie | Asignada (t) | Cesión (t) | Share |
|-----|---------|-------------:|-----------:|------:|
| 2013 | anchoveta | 25528 | −3083 | 12.1% |
| 2013 | sardina común | 128462 | −31117 | 24.2% |
| 2014 | anchoveta | 7727 | −3909 | 50.6% |
| 2014 | sardina común | 104811 | −46601 | 44.5% |
| 2015 | anchoveta | 6273 | −2509 | 40.0% |
| 2015 | sardina común | 65213 | −21834 | 33.5% |
| 2016 | anchoveta | 7288 | −2138 | 29.3% |
| 2016 | sardina común | 59819 | **+15645** | 26.2% (dirección ART→IND, signo +) |
| 2017 | anchoveta | 12558 | −9034 | 71.9% |
| 2017 | sardina común | 72402 | −48885 | 67.5% |

**RANGO = 12% a 72%** → el "11–72%" original era correcto (piso real 12% = anchoveta 2013;
techo 72% = anchoveta 2017). Ya repuesto en el texto de H.3 como "$12\%$ to $72\%$".
Casi todo es IND→ART (cesión negativa); **excepción 2016 sardina común** (cesión +, ART→IND).

### HECHO (2026-05-28, sesión 2)
- **`cesiones_consolidated_2013_2024.csv` reescrito** para 2013–2017 (source=`industrial_LTP_rebuilt`);
  2018–2024 intactos. Texto H.3 con rango verificado "12%–72%".
- **2013 → se usó LMC** (col "Cuota LMC" / "Cesiones o traspasos"): da anch 12.1% / sard 24.2%,
  dirección IND→ART. Se descartó LTP porque las cesiones IND→ART de 2013 están en el período LMC;
  el LTP (arriendos ago–dic) da signo + (ART→IND), inconsistente con la serie.
- **2016 sardina cesión + (ART→IND) VERIFICADA**: cruce con workbook artesanal 2016
  ("RESUMEN publicación", col "CESIONES Y DESCUENTOS") → sardina común V-X artesanal neto −19.168 t
  (sale del artesanal) vs +15.645 t que entra al industrial. Signos opuestos ⇒ 2016 fue año atípico
  de cesión neta ART→IND en sardina (como el jurel). No es bug de parseo.

### Pendiente (opcional)
- Jurel V-IX / XIV-X 2013–2017 no se reconstruyó (no se necesita para la frase); se puede agregar igual.
- Si en algún momento se quiere agregar 2013–2017 a la tabla H.3, ya están los valores limpios.

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
