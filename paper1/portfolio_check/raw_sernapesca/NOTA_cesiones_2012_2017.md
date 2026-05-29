# Nota — workbooks SERNAPESCA cuotas 2012–2017 (cesiones)

**Última actualización:** 2026-05-29 (rebuild jurel completado)
**Estado:** las 3 especies del paper (anchoveta V-X, sardina común V-X, jurel V-IX + XIV-X)
están reconstruidas 2013–2017 y publicadas en Tables H.3a y H.3b.

## Estado actual

- **Anchoveta y sardina común V-X, 2013–2017**: reconstruidos desde los workbooks
  industriales (`Pelagicos LTP`, `Pelagicos LMC y LTP` para 2013). Rango verificado
  **12% (anch 2013) a 72% (anch 2017)**. Excepción 2016 sardina común: dirección
  ART→IND (cesión +15.6 kt), cruzada contra workbook artesanal 2016 (cesión neta
  artesanal −19.2 kt). Año atípico genuino, no bug de parseo.
- **Jurel V-IX + XIV-X, 2013–2017** (2026-05-29): reconstruidos desde las mismas
  hojas industriales (sub-bloques `Jurel V-IX` y `Jurel XIV-X`). Rango sumado V-IX +
  XIV-X = **0% (2013) a 14% (2014)**, dirección mixta. Validación 2017 contra
  subtotales raw: V-IX 200,384.8 t / +7,279.2 t cesión; XIV-X 27,905.0 t / +2,406.2 t.
  OK exacto. **Nota:** Panel B de H.3b (2018–2024 consolidated) cubre XV–X
  (incluye Arica-Antofagasta XV–IV), mientras Panel A cubre solo V-IX + XIV-X
  Centro-Sur; la diferencia de cobertura explica el salto en la columna IND assigned
  entre paneles y se declara en la nota de la tabla.
- **Salidas en disco:**
  - `paper1/portfolio_check/cesiones_ind_2013_2017_rebuilt.csv` (20 filas:
    5 años × {anch V-X, sard V-X, jurel V-IX, jurel XIV-X}; columna `zone`)
  - `paper1/portfolio_check/cesiones_consolidated_2013_2024.csv` actualizado
    a 36 filas (12 años × 3 especies; jurel 2013–2017 con suma V-IX + XIV-X,
    `source=industrial_LTP_rebuilt`)
- **Appendix H** (2026-05-29):
  - **H.3a** anch+sard 2013–2024, paneles A (LTP rebuilt 2013–2017) / B (RESUMEN 2018–2024).
  - **H.3b** jurel 2013–2024, paneles A (V-IX + XIV-X) / B (XV–X consolidated).
  - Compactación suave aplicada: `\small` + `\arraystretch{0.95}` + columna
    `Direction` eliminada (el signo de IND cession ya la indica; nota lo explica).

## Pendiente

(ninguno relevante para MRE submit)

## Referencias rápidas

- **Script de rebuild:** `R/01_data_cleaning/build_cesiones_ind_2013_2017.R`
- **CSV verificado:** `paper1/portfolio_check/cesiones_ind_2013_2017_rebuilt.csv`
- **CSV consolidado:** `paper1/portfolio_check/cesiones_consolidated_2013_2024.csv`
- **Workbooks crudos:** esta carpeta. Dos familias: `Control Cuota Artesanal …`
  (artesanal) y `Control Cuotas globales industriales LTP y PEP …` (industrial).
- **Layouts por año (crítico — cada año distinto):**
  - 2013: `Pelagicos LMC y LTP`, cuota LMC col2, cesión col3, 1 fila/armador
  - 2014: `Pelagicos LTP `, asignada col4, cesión col5, 2 filas período
  - 2015–2016: `Pelagicos LTP `, asignada col4, cesión col5, 3 filas período
  - 2017: `Pelagicos LTP`, asignada col3, cesión col4, 2 filas período +
    subtotales por unidad + bloque RESUMEN derecho
- **Fechas internas son artefactos de plantilla** (2014 trae fechas "2007", 2016
  trae fechas 2015). Usar año del título de archivo, no fechas internas.
- **Especies del paper (Centro-Sur):** anchoveta V-X, sardina común V-X, jurel
  V-IX y XIV-X. Sardina española y sardina austral aparecen pero quedan fuera.
