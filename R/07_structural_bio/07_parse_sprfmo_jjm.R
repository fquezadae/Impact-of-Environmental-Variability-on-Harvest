# =============================================================================
# FONDECYT -- 07_parse_sprfmo_jjm.R
#
# Parser del archivo SPRFMO JJM `h1_1.07.qs` (Joint Jack Mackerel assessment
# 2024) para extraer:
#   - captura range-wide del jurel (obs, por flota y agregada)
#   - SSB range-wide (estimada por el modelo)
#
# Cierra PEND-2 (parsear h1_1.07.qs) y PEND-8 ruta A (jurel como range-wide).
#
# Inputs:
#   data/bio_params/h1_1.07.qs   (binary qs, ~9.5 MB)
#
# Outputs:
#   data/bio_params/h1_1.07_structure.txt   (dump del str(), por si heurística
#                                            falla y necesito ajustar el parser)
#   data/bio_params/catch_jurel_sprfmo.csv  (year, catch_t, source)
#   data/bio_params/ssb_jurel_sprfmo.csv    (year, ssb_t,  source)
#
# Uso:
#   setwd("<repo root>")
#   source("R/07_structural_bio/07_parse_sprfmo_jjm.R")
#   options(structural_bio.run_main = TRUE); source(...)
#
# Nota: este script es DEFENSIVO -- no conozco a priori la estructura exacta
# del `.qs`. Primero vuelca `str(obj, max.level=3)` a un txt para inspeccion
# si los fallbacks fallan.
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(readr)
  # FLCore registra los metodos S4 (ssb, mat, n, wt, quantSums) que el
  # extractor del OM necesita. Si no esta, el parser cae a fallbacks.
  if (requireNamespace("FLCore", quietly = TRUE)) library(FLCore)
})

# qs fue archivado de CRAN en 2025-01; en R >= 4.5 solo se instala desde
# archive o source. qs2 es el successor (mismo autor). Intentamos en este
# orden: qs2::qs_read() -> qs::qread() -> error con instrucciones.
read_qs_file <- function(path) {
  if (requireNamespace("qs2", quietly = TRUE)) {
    out <- tryCatch(qs2::qs_read(path),
                    error = function(e) structure(e, class = c("qs_err", class(e))))
    if (!inherits(out, "qs_err")) return(out)
    message("qs2::qs_read() fallo: ", conditionMessage(out),
            "\n  -> intentando paquete 'qs' legacy...")
  }
  if (requireNamespace("qs", quietly = TRUE)) {
    return(qs::qread(path))
  }
  stop("No puedo leer ", path, ".\n",
       "Opciones:\n",
       "  1) install.packages('qs2')   # formato nuevo y lee qs >= 0.27\n",
       "  2) remotes::install_version('qs', version='0.27.2', repos='https://cloud.r-project.org')\n",
       "  3) remotes::install_github('traversc/qs')   # requiere Rtools")
}

SPRFMO_QS     <- file.path("data", "bio_params", "h1_1.07.qs")
STRUCT_DUMP   <- file.path("data", "bio_params", "h1_1.07_structure.txt")
OUT_CATCH_CSV <- file.path("data", "bio_params", "catch_jurel_sprfmo.csv")
OUT_SSB_CSV   <- file.path("data", "bio_params", "ssb_jurel_sprfmo.csv")

# ------------------------------------------------------------ helpers ----

# Helper: obtener "slots" de un objeto sea S4 o lista.
# Robusto contra clases S4 cuya definicion no esta cargada: usa attributes()
# como fallback si slotNames() falla.
member_names <- function(x) {
  if (isS4(x)) {
    nms <- tryCatch(methods::slotNames(x), error = function(e) character(0))
    if (length(nms) > 0) return(nms)
    a <- attributes(x)
    return(setdiff(names(a), c("class", ".S3Class", "row.names")))
  }
  if (is.list(x) || is.environment(x)) return(names(x))
  character(0)
}
member_get <- function(x, nm) {
  if (isS4(x)) {
    v <- tryCatch(methods::slot(x, nm), error = function(e) NULL)
    if (!is.null(v)) return(v)
    return(attr(x, nm))
  }
  if (is.list(x) || is.environment(x)) return(x[[nm]])
  NULL
}
is_container <- function(x) {
  isS4(x) || is.list(x) || is.environment(x)
}

# Busca recursivamente un componente por nombre. Soporta S4 (via slot()) y
# lista/env (via [[]]). Devuelve (name_path, value) del primer match.
find_by_name <- function(x, targets, path = character(0), depth = 0,
                         max_depth = 8) {
  if (depth > max_depth) return(NULL)
  nms <- member_names(x)
  if (length(nms) == 0) return(NULL)
  for (nm in nms) {
    full <- c(path, nm)
    val <- tryCatch(member_get(x, nm), error = function(e) NULL)
    if (is.null(val)) next
    if (nm %in% targets) {
      return(list(path = paste(full, collapse = "@"), value = val))
    }
    if (is_container(val)) {
      hit <- find_by_name(val, targets, full, depth + 1, max_depth)
      if (!is.null(hit)) return(hit)
    }
  }
  NULL
}

# Busca TODOS los matches por nombre
find_all_by_name <- function(x, targets, path = character(0), depth = 0,
                             max_depth = 8, acc = list()) {
  if (depth > max_depth) return(acc)
  nms <- member_names(x)
  if (length(nms) == 0) return(acc)
  for (nm in nms) {
    full <- c(path, nm)
    val <- tryCatch(member_get(x, nm), error = function(e) NULL)
    if (is.null(val)) next
    if (nm %in% targets) {
      acc[[length(acc) + 1]] <- list(
        path = paste(full, collapse = "@"),
        value = val
      )
    }
    if (is_container(val)) {
      acc <- find_all_by_name(val, targets, full, depth + 1, max_depth, acc)
    }
  }
  acc
}

# Mapa de clases y slots top-level (sobrevive aunque falten paquetes S4)
describe_top <- function(x, max_slots = 40) {
  cat("class:   ", paste(class(x), collapse = ", "), "\n")
  cat("isS4:    ", isS4(x), "\n")
  nms <- member_names(x)
  cat("slots/names (n=", length(nms), "): ", sep = "")
  cat(paste(head(nms, max_slots), collapse = ", "))
  if (length(nms) > max_slots) cat(" ...(", length(nms) - max_slots, " mas)", sep = "")
  cat("\n")
  # Clase de cada slot (superficial, no recurre)
  for (nm in head(nms, max_slots)) {
    v <- tryCatch(member_get(x, nm), error = function(e) e)
    cls <- if (inherits(v, "error")) paste0("ERR: ", conditionMessage(v))
           else paste(class(v), collapse = ",")
    len <- if (inherits(v, "error")) NA
           else tryCatch(length(v), error = function(e) NA)
    cat(sprintf("  $ %-25s : %s  [len=%s]\n", nm, cls, len))
  }
}

# Coerce un objeto que parece ser "serie anual" (matriz year x col o vector
# nombrado o data.frame) a tibble(year, value).
as_annual_series <- function(obj, value_col = "value") {
  if (is.null(obj)) return(NULL)

  # Caso A: data.frame con columna Year/year
  if (is.data.frame(obj)) {
    yr_col <- intersect(c("Year", "year", "YEAR", "ano", "Ano"), names(obj))[1]
    if (!is.na(yr_col) && ncol(obj) >= 2) {
      num_cols <- setdiff(names(obj), yr_col)
      # Tomar la primera columna numérica que no sea year
      val_col <- num_cols[vapply(num_cols, \(c) is.numeric(obj[[c]]),
                                 logical(1))][1]
      if (!is.na(val_col)) {
        out <- tibble::tibble(year  = as.integer(obj[[yr_col]]),
                              value = as.numeric(obj[[val_col]]))
        names(out)[2] <- value_col
        return(out)
      }
    }
  }

  # Caso B: matriz con rownames year
  if (is.matrix(obj)) {
    rn <- rownames(obj)
    if (!is.null(rn) && all(grepl("^[12][0-9]{3}$", rn))) {
      out <- tibble::tibble(year  = as.integer(rn),
                            value = as.numeric(obj[, 1]))
      names(out)[2] <- value_col
      return(out)
    }
    # Si columnas son años en lugar de filas
    cn <- colnames(obj)
    if (!is.null(cn) && all(grepl("^[12][0-9]{3}$", cn))) {
      # Sumar across rows (por flota) para captura total
      tot <- colSums(obj, na.rm = TRUE)
      out <- tibble::tibble(year  = as.integer(cn),
                            value = as.numeric(tot))
      names(out)[2] <- value_col
      return(out)
    }
  }

  # Caso C: vector nombrado por años
  if (is.numeric(obj) && !is.null(names(obj))) {
    nm <- names(obj)
    if (all(grepl("^[12][0-9]{3}$", nm))) {
      out <- tibble::tibble(year  = as.integer(nm),
                            value = as.numeric(obj))
      names(out)[2] <- value_col
      return(out)
    }
  }

  NULL
}

# ------------------------------------------- FLR-specific extractors ----

# Colapsa un FLQuant (6-D: quant x year x unit x season x area x iter) a
# tibble(year, value). La agregacion es en DOS etapas porque el OM de MSE
# tiene iter=100 (iteraciones Monte Carlo) y iter != otras dims:
#   1) dentro de cada (year, iter), suma sobre quant/unit/season/area
#   2) entre iters, toma mediana (central tendency del MSE)
# Para periodo historico iter es deterministic (mismas values), asi que
# median = mean = cualquier iter.
flquant_to_annual <- function(flq, value_col = "value",
                              agg_within = sum, agg_across_iter = stats::median) {
  if (is.null(flq)) return(NULL)
  arr <- tryCatch(flq@.Data, error = function(e) NULL)
  if (is.null(arr)) return(NULL)
  dn <- dimnames(arr)
  year_dim <- which(names(dn) == "year")
  iter_dim <- which(names(dn) == "iter")
  if (length(year_dim) == 0) year_dim <- 2
  yrs <- dn[[year_dim]]
  if (is.null(yrs) || !all(grepl("^[12][0-9]{3}$", yrs))) return(NULL)

  has_iter <- length(iter_dim) > 0 && dim(arr)[iter_dim] > 1

  if (has_iter) {
    # Etapa 1: (year, iter) reteniendo ambas dims, colapsa las otras
    per_yi <- apply(arr, c(year_dim, iter_dim), agg_within, na.rm = TRUE)
    # per_yi es matriz year x iter (dim 76 x 100 tipicamente)
    # Etapa 2: central tendency entre iters por year
    vals <- apply(per_yi, 1, agg_across_iter, na.rm = TRUE)
  } else {
    vals <- apply(arr, year_dim, agg_within, na.rm = TRUE)
  }
  out <- tibble::tibble(year  = as.integer(yrs),
                        value = as.numeric(vals))
  names(out)[2] <- value_col
  out
}

# SSB range-wide desde el Operating Model (la "verdad" del assessment)
#   om$biols[[1]] = FLBiol con @n (age x year), @wt, @mat
#   SSB_y = sum_age( n[a,y] * wt[a,y] * mat[a,y] )
extract_ssb_from_om <- function(obj) {
  om    <- tryCatch(obj$om, error = function(e) NULL)
  if (is.null(om)) { message("No hay $om en el objeto"); return(NULL) }
  biols <- tryCatch(methods::slot(om, "biols"), error = function(e) NULL)
  if (is.null(biols) || length(biols) == 0) {
    message("No hay om@biols o esta vacio"); return(NULL)
  }
  biol <- biols[[1]]

  # --- Ruta 1: FLCore::ssb(FLBiol) -- hace todo internamente (mat via predictModel)
  ssb_flq <- tryCatch(FLCore::ssb(biol), error = function(e) {
    message("FLCore::ssb(biol) fallo: ", conditionMessage(e))
    NULL
  })

  # --- Ruta 2 (fallback): producto explicito usando accesors, no slots crudos
  if (is.null(ssb_flq)) {
    ssb_flq <- tryCatch({
      n_flq   <- FLCore::n(biol)
      wt_flq  <- FLCore::wt(biol)
      mat_flq <- FLCore::mat(biol)            # evalua predictModel si hace falta
      # FLQuant tiene * sobrecargado; quantSums sum sobre la 1era dim (age)
      FLCore::quantSums(n_flq * wt_flq * mat_flq)
    }, error = function(e) {
      message("Calculo manual n*wt*mat fallo: ", conditionMessage(e))
      NULL
    })
  }

  if (is.null(ssb_flq)) return(NULL)

  df <- flquant_to_annual(ssb_flq, value_col = "ssb_t")
  if (is.null(df)) { message("No pude colapsar SSB FLQuant"); return(NULL) }

  # Unidades: n en '1e6' (millones de individuos) x wt en 'kg'
  #   -> n*wt = 1e6 * kg = 1e6 kg = 1000 t = kt
  # Para output en tonnes (consistente con otros CSVs del repo) x 1000.
  df <- df %>% dplyr::mutate(ssb_t = ssb_t * 1000)

  df %>%
    dplyr::mutate(
      stock_id = "jurel_sprfmo_rangewide",
      source   = "SPRFMO JJM h1_1.07 (om@biols[[1]]), iter=median(1:100), x1000 para tonnes",
      path_qs  = "om@biols[[1]] via FLCore::ssb()"
    ) %>%
    dplyr::select(stock_id, year, ssb_t, source, path_qs)
}

# Catch total range-wide sumando las 4 flotas del OM
#   om@fisheries = FLFisheries (4 flotas). Cada FLFishery tiene @.Data que es
#   lista de FLCatch; cada FLCatch tiene landings.n, landings.wt, discards.n,
#   discards.wt (FLQuants). Catch biomasa = landings + discards agregada por
#   flota, luego sumada.
extract_catch_from_om_fleets <- function(obj) {
  om <- tryCatch(obj$om, error = function(e) NULL)
  if (is.null(om)) return(NULL)
  fisheries <- tryCatch(methods::slot(om, "fisheries"),
                        error = function(e) NULL)
  if (is.null(fisheries) || length(fisheries) == 0) return(NULL)

  annual_per_fleet <- list()
  for (i in seq_along(fisheries)) {
    fish <- fisheries[[i]]
    # FLFishery contains FLCatches (list of FLCatch)
    catches <- tryCatch(methods::slot(fish, ".Data"),
                        error = function(e) NULL)
    if (is.null(catches)) catches <- as.list(fish)
    for (j in seq_along(catches)) {
      cat_obj <- catches[[j]]
      ln  <- tryCatch(methods::slot(cat_obj, "landings.n"),
                      error = function(e) NULL)
      lwt <- tryCatch(methods::slot(cat_obj, "landings.wt"),
                      error = function(e) NULL)
      dn  <- tryCatch(methods::slot(cat_obj, "discards.n"),
                      error = function(e) NULL)
      dwt <- tryCatch(methods::slot(cat_obj, "discards.wt"),
                      error = function(e) NULL)
      if (is.null(ln) || is.null(lwt)) next
      # catch biomass FLQuant per age x year
      catch_bio <- tryCatch({
        L <- ln * lwt
        if (!is.null(dn) && !is.null(dwt)) L + dn * dwt else L
      }, error = function(e) NULL)
      if (is.null(catch_bio)) next
      # Sum over age dim
      annual <- tryCatch(FLCore::quantSums(catch_bio),
                         error = function(e) NULL)
      if (is.null(annual)) next
      df <- flquant_to_annual(annual, value_col = "catch_t")
      if (!is.null(df)) {
        df$fleet_idx <- i
        annual_per_fleet[[length(annual_per_fleet) + 1]] <- df
      }
    }
  }
  if (length(annual_per_fleet) == 0) return(NULL)
  # Agregar por year
  all_fleets <- dplyr::bind_rows(annual_per_fleet)
  total <- all_fleets %>%
    dplyr::group_by(year) %>%
    dplyr::summarise(catch_t = sum(catch_t, na.rm = TRUE), .groups = "drop") %>%
    dplyr::mutate(
      # Misma convencion de unidades: landings.n en 1e6, landings.wt en kg
      # -> producto en kt. x 1000 a tonnes.
      catch_t  = catch_t * 1000,
      stock_id = "jurel_sprfmo_rangewide",
      period   = ifelse(catch_t > 0, "historical", "projection"),
      source   = "SPRFMO JJM h1_1.07 (om@fisheries, sum 4 flotas), iter=median, x1000",
      path_qs  = "om@fisheries[[i]][[j]]@landings + @discards"
    ) %>%
    dplyr::select(stock_id, year, catch_t, period, source, path_qs)
  total
}

# Catch observado desde el OEM (lo que el fitting model 'vio')
#   oem$observations[[1]]$stk = FLStock con @catch (FLQuant ya agregado)
extract_catch_from_oem <- function(obj) {
  oem <- tryCatch(obj$oem, error = function(e) NULL)
  if (is.null(oem)) { message("No hay $oem"); return(NULL) }
  obs <- tryCatch(methods::slot(oem, "observations"),
                  error = function(e) NULL)
  if (is.null(obs) || length(obs) == 0) {
    message("oem@observations vacio"); return(NULL)
  }
  first_obs <- obs[[1]]
  stk <- tryCatch(first_obs$stk, error = function(e) NULL)
  if (is.null(stk)) {
    # A veces la observacion es lista con $stk, $idx, $biol etc; probar slot
    stk <- tryCatch(methods::slot(first_obs, "stk"), error = function(e) NULL)
  }
  if (is.null(stk)) {
    message("No encontre stk dentro de oem@observations[[1]]"); return(NULL)
  }
  catch_flq <- tryCatch(methods::slot(stk, "catch"), error = function(e) NULL)
  if (is.null(catch_flq)) {
    message("FLStock sin slot catch"); return(NULL)
  }
  df <- flquant_to_annual(catch_flq, value_col = "catch_t")
  if (is.null(df)) {
    message("No pude colapsar FLQuant catch a serie anual"); return(NULL)
  }
  # Unidades: catch@units = '1000 t' (kt). Multiplicar por 1000 para tonnes.
  df <- df %>% dplyr::mutate(catch_t = catch_t * 1000)

  # Marcar periodo: el OM tiene ventana de proyeccion donde catch=0 (reservada
  # para simulacion MSE pero aun no corrida). Split historico / projection para
  # que el consumidor (hindcast Schaefer) filtre trivialmente.
  df %>%
    dplyr::mutate(
      stock_id = "jurel_sprfmo_rangewide",
      period   = ifelse(catch_t > 0, "historical", "projection"),
      source   = "SPRFMO JJM h1_1.07 (oem@observations[[1]]$stk@catch), iter=median, x1000",
      path_qs  = "oem@observations[[1]]$stk@catch"
    ) %>%
    dplyr::select(stock_id, year, catch_t, period, source, path_qs)
}

# ------------------------------------------------------------ main ----

parse_sprfmo_jjm <- function(path = SPRFMO_QS) {

  if (!file.exists(path)) stop("No encuentro ", path)

  cat("Leyendo ", path, " ... ", sep = "")
  obj <- read_qs_file(path)
  cat("OK (", format(object.size(obj), units = "MB"), ")\n", sep = "")

  # ---- 1. Dump de estructura (defensivo: sobrevive S4 sin paquete cargado) ----
  dir.create(dirname(STRUCT_DUMP), showWarnings = FALSE, recursive = TRUE)
  sink(STRUCT_DUMP)
  cat("=== top-level ===\n")
  describe_top(obj)
  cat("\n=== descend 1 level per slot ===\n")
  nms <- member_names(obj)
  for (nm in nms) {
    v <- tryCatch(member_get(obj, nm), error = function(e) e)
    if (inherits(v, "error")) {
      cat("## ", nm, "  [ERR: ", conditionMessage(v), "]\n", sep = "")
      next
    }
    if (is_container(v)) {
      cat("## ", nm, "  (", paste(class(v), collapse = ","), ")\n", sep = "")
      sub <- member_names(v)
      if (length(sub) > 0) {
        for (sn in head(sub, 25)) {
          vv <- tryCatch(member_get(v, sn), error = function(e) e)
          if (inherits(vv, "error")) {
            cat(sprintf("    - %-22s : ERR %s\n", sn, conditionMessage(vv)))
          } else {
            cat(sprintf("    - %-22s : %s  [len=%s]\n",
                        sn,
                        paste(class(vv), collapse = ","),
                        tryCatch(length(vv), error = function(e) NA)))
          }
        }
        if (length(sub) > 25) cat("    ...(", length(sub) - 25, " mas)\n", sep = "")
      }
    }
  }
  cat("\n=== str() attempt (puede fallar si falta paquete S4) ===\n")
  tryCatch(
    utils::str(obj, max.level = 3, give.attr = FALSE),
    error = function(e) cat("str() fallo: ", conditionMessage(e), "\n", sep = "")
  )
  sink()
  cat("Structure dump -> ", STRUCT_DUMP, "\n", sep = "")

  # ---- DIAG: imprimir unidades y nombres para detectar escala ----
  tryCatch({
    om_name <- methods::slot(obj$om, "name")
    cat("OM name: '", om_name, "'\n", sep = "")
    biol <- methods::slot(obj$om, "biols")[[1]]
    cat("Biol name: '", methods::slot(biol, "name"), "'\n", sep = "")
    cat("Biol desc: '", methods::slot(biol, "desc"), "'\n", sep = "")
    n_u  <- methods::slot(methods::slot(biol, "n"),  "units")
    wt_u <- methods::slot(methods::slot(biol, "wt"), "units")
    cat("n@units   : '", n_u,  "'  (n es numero de individuos: NA=raw, 1000=miles, etc)\n", sep = "")
    cat("wt@units  : '", wt_u, "'  (peso por individuo: kg tipicamente)\n", sep = "")
    # unidades del catch del OEM
    stk <- tryCatch(methods::slot(obj$oem, "observations")[[1]]$stk,
                    error = function(e) NULL)
    if (!is.null(stk)) {
      c_u <- methods::slot(methods::slot(stk, "catch"), "units")
      cat("oem catch@units: '", c_u, "'\n", sep = "")
    }
    # Range del OM
    rng <- methods::slot(biol, "range")
    cat("Biol range: "); print(rng)
    # Dims de n y catch (detectar season/unit multiples)
    n_flq <- methods::slot(biol, "n")
    cat("dim(n@.Data):    ", paste(dim(n_flq@.Data), collapse=" x "),
        "  (quant, year, unit, season, area, iter)\n")
    cat("dimnames(n):\n")
    print(lapply(dimnames(n_flq@.Data), \(x) if (length(x) > 6) c(head(x,3),"...",tail(x,2)) else x))
    if (!is.null(stk)) {
      c_flq <- methods::slot(stk, "catch")
      cat("dim(catch@.Data):", paste(dim(c_flq@.Data), collapse=" x "), "\n")
    }
  }, error = function(e) cat("Diagnostico fallo: ", conditionMessage(e), "\n"))

  # ---- 2. Extraer SSB y Catch via rutas FLR conocidas ----
  # Basado en la estructura del objeto (ver h1_1.07_structure.txt):
  #   obj$om  = FLombf  -> $biols (FLBiols, 1 stock) -> n, wt, mat -> SSB
  #              -> $fisheries (FLFisheries, 4 flotas) -> sum catch total
  #   obj$oem = FLoem   -> $observations[[1]]$stk (FLStock) -> catch (agregado)
  ssb_df         <- extract_ssb_from_om(obj)
  cat_oem_df     <- extract_catch_from_oem(obj)
  cat_fleets_df  <- extract_catch_from_om_fleets(obj)

  # Elegir la de mayor magnitud (sospechamos que oem@...@catch puede ser
  # parcial -- solo una flota). Si la suma por flotas es > que la oem,
  # preferir la primera.
  cat_df <- cat_oem_df
  if (!is.null(cat_fleets_df) && !is.null(cat_oem_df)) {
    tot_oem <- sum(cat_oem_df$catch_t[cat_oem_df$period == "historical"])
    tot_fl  <- sum(cat_fleets_df$catch_t[cat_fleets_df$period == "historical"])
    cat(sprintf("Comparacion totales historicos (t): OEM=%.0f  vs  fleets=%.0f\n",
                tot_oem, tot_fl))
    if (tot_fl > 1.2 * tot_oem) {
      cat("  -> Elegiendo suma-por-flotas (mas completa)\n")
      cat_df <- cat_fleets_df
    }
  }

  # ---- 4. Escribir CSVs (si extraccion exitosa) ----
  if (!is.null(ssb_df)) {
    readr::write_csv(ssb_df, OUT_SSB_CSV)
    cat("SSB range-wide -> ", OUT_SSB_CSV, " (", nrow(ssb_df),
        " filas, ", min(ssb_df$year), "-", max(ssb_df$year), ")\n", sep = "")
  } else {
    warning("SSB no extraido. Revisar ", STRUCT_DUMP,
            " y ajustar nombres candidatos en el parser.")
  }

  if (!is.null(cat_df)) {
    readr::write_csv(cat_df, OUT_CATCH_CSV)
    cat("Catch range-wide -> ", OUT_CATCH_CSV, " (", nrow(cat_df),
        " filas, ", min(cat_df$year), "-", max(cat_df$year), ")\n", sep = "")
  } else {
    warning("Catch no extraido. Revisar ", STRUCT_DUMP,
            " y ajustar nombres candidatos.")
  }

  invisible(list(
    obj    = obj,
    ssb    = ssb_df,
    catch  = cat_df,
    struct = STRUCT_DUMP
  ))
}

# --------------------------------------------------------------- main() ----

if (isTRUE(getOption("structural_bio.run_main", FALSE))) {
  cat(strrep("=", 70), "\n")
  cat("SPRFMO JJM parser -- h1_1.07.qs -> captura y SSB range-wide jurel\n")
  cat(strrep("=", 70), "\n\n")
  res <- parse_sprfmo_jjm()

  cat("\n--- Sanity check (ultimos 10 anos HISTORICOS) ---\n")
  last_hist_yr <- if (!is.null(res$catch))
    max(res$catch$year[res$catch$period == "historical"], na.rm = TRUE) else NA
  if (!is.null(res$ssb)) {
    cat("SSB jurel (ultimos 10 anos historicos):\n")
    print(res$ssb %>%
          dplyr::filter(year > last_hist_yr - 10, year <= last_hist_yr) %>%
          dplyr::select(year, ssb_t) %>%
          as.data.frame(),
          row.names = FALSE)
  }
  if (!is.null(res$catch)) {
    cat("\nCaptura jurel (ultimos 10 anos historicos):\n")
    print(res$catch %>%
          dplyr::filter(period == "historical",
                        year > last_hist_yr - 10) %>%
          dplyr::select(year, catch_t) %>%
          as.data.frame(),
          row.names = FALSE)
  }
  cat(strrep("=", 70), "\n")
}
