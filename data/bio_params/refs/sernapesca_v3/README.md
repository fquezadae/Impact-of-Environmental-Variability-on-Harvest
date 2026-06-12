# SERNAPESCA v3 — Desembarques 2000–2024 (todas las artes)

## Procedencia

Solicitud de Acceso a la Información Pública **AH010T0006857** ingresada por
Felipe Quezada-Escalona el **24/04/2025**. Respondida por SERNAPESCA
(Depto. Gestión de la Información, Atención de Usuarios y Estadísticas
Sectoriales) el **05/05/2025** mediante oficio **DN-02040/2025** firmado
por Lisette Catherine Montesi Monje. Oficio archivado en
`ah010t0006857.pdf` en este directorio.

## Archivos fuente (no en repo por tamaño)

Los CSVs/XLSX brutos pesan ~20 MB combinados y se almacenan fuera del
repositorio. Pueden encontrarse en:

- `D:/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/raw/sernapesca/v3/`
  (computadora de Felipe).
- O re-solicitarse a SERNAPESCA con el mismo expediente AH010T0006857.

Archivos:

1. **`BD_desembarque.csv`** (~16 MB; ISO-8859-1; separador `;`).
   Histórico de desembarques totales nacionales 2000–2024, agregado a nivel
   `mes × región × puerto × especie × tipo_agente`. Cubre todas las artes
   y todas las especies. Header: `id;año;aguas;region;cd_puerto;
   puerto_desembarque;mes;cd_especie;especie;toneladas;tipo_agente`.
   Filas: 220.215. Acompañado del README de SERNAPESCA marcado
   "Última actualización: junio 2024 / Anuario Estadístico SERNAPESCA 2023";
   el cierre 2024 fue confirmado en mayo 2025 al momento de la solicitud.

2. **`AH010T0006857_sobre_desembarque_pelagicos_2012_2024.xlsx`** (~3.8 MB).
   Datos vessel-level específicos para anchoveta, sardina común, sardina
   española, sardina austral, y jurel, 2012–2024, en cinco hojas:
   - `ART_2012_2024` — desembarque artesanal por embarcación-puerto-arte
     (~36k filas; 19 columnas con eslora, TRG, capacidad de bodega,
     RPA, matrícula, capitanía, código y nombre de caleta, código y
     nombre de especie, arte de pesca, suma desembarcada).
   - `IND_2012_2024` — desembarque industrial análogo (~3.3k filas;
     18 columnas).
   - `BF_2017_2024` — buques fábrica (jurel; ~144 filas, 18 columnas).
     SERNAPESCA aclara que registra BF "desde 2017 y no en cantidad
     significativa" — coherente con que para anchoveta y sardina común
     no aparece y para jurel CS aparece como ~1% del total.
   - `PRECIOS` — precios de primera transacción por especie/región/año
     (sólo CHD y consumo humano; "no se cuenta con el valor de
     transacción en alta mar o de barcos industriales").
   - `CONSIDERACIONES` — disclaimers metodológicos del Servicio.

## Pipeline de procesamiento

`R/01_data/99b_aggregate_catch_cs_from_sernapesca_v3.R` lee
`BD_desembarque.csv`, filtra:

- regiones Centro-Sur: Valparaíso, O'Higgins, Maule, Ñuble, Bio-bío,
  La Araucanía, Los Ríos, Los Lagos (8 regiones, V–X + XIV + XVI);
- especies: Anchoveta, Sardina común, Jurel;
- tipo de agente: Industrial + Artesanal (excluye Acuicultura y
  Fábrica — esta última se registra aparte y es marginal según el
  oficio de SERNAPESCA);

agrega por `(stock_id, year)`, y produce
`data/bio_params/catch_annual_cs_2000_2024.csv` (3 stocks × 25 años =
75 filas).

## Diferencia respecto a versiones previas

- **v1 (proyecto pre-2026-04-23):** IFOP "4. DESEMBARQUES.xlsx" único
  para toda la serie. Subestima el histórico 2000-2010 hasta -80%
  (anchoveta) y -89% (sardina común) porque IFOP captura sólo pesca
  con cerco; las artes no-cerco (lámpara, redes fijas, chinchorros,
  espineles, lanchas/botes pre-2011) quedaban excluidas. Documentado
  en `project_catch_data_sources.md`.
- **v2 (CSV híbrido 2026-04-23 → 2026-04-29):** SERNAPESCA 2000-2023
  + IFOP-cerco 2024 como placeholder mientras SERNAPESCA no publicaba
  el cierre 2024. Ya contemplado como caveat en Methods §3.1.
- **v3 (este, 2026-04-29 PM):** SERNAPESCA todas las artes 2000-2024.
  Reemplaza directamente el placeholder IFOP-cerco 2024. Diferencia
  numérica respecto a v2 en las 75 celdas: máx 0.0% (172 t en
  882 kt jurel 2024). El placeholder IFOP-cerco resultó ex-post
  esencialmente exacto porque en 2024 cerco representó >99.5% del
  total CS para los 3 stocks.

## Para citar en el paper

> Catch series compiled from the Servicio Nacional de Pesca y
> Acuicultura (SERNAPESCA) official annual landings database for
> 2000–2024, covering all gears (industrial and artisanal). The data
> were obtained through transparency request AH010T0006857 (filed
> 24 April 2025; responded 5 May 2025 via official letter
> DN-02040/2025). For the Centro-Sur small pelagic fishery, landings
> were aggregated from the eight Centro-Sur administrative regions
> (Valparaíso, O'Higgins, Maule, Ñuble, Bio-bío, La Araucanía, Los
> Ríos, Los Lagos) by species (anchoveta, sardina común, jurel) and
> year, excluding aquaculture and factory-vessel registrations.
