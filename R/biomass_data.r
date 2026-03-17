
###------------------------------------------------------###
###               Biomass data                            ### 
###  Interpolation of jack mackerel missing values        ###
###  + Diagnostics and alternative specifications         ###
###------------------------------------------------------###

rm(list = ls())
gc()

# Define directory --------------------------------------------------------

usuario <- Sys.info()[["user"]]
if (usuario == "felip") {
  dirdata <- "C:/Users/felip/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else if (usuario == "FACEA") {
  dirdata <- "C:/Users/FACEA/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else if (usuario == "Felipe") {
  dirdata <- "D:/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else {
  stop("Usuario no reconocido. Defina el directorio correspondiente.")
}
rm(usuario)

library(readxl)
library(tidyverse)


# =========================================================================
# 1. LOAD RAW BIOMASS DATA
# =========================================================================

# --- 1a. Sardine & Anchovy (summer acoustic surveys, "Reclas") -----------

anch_sard_biomass <- read_excel(
  paste0(dirdata, "IFOP/3. ESTIMACIONES CRUCERO ACUSTICO.xlsx"),
  sheet = "SARDINA-ANCHOVETA"
)
anch_sard_biomass <- anch_sard_biomass[, c(1, 2, 3, 4)]
anch_sard_biomass <- anch_sard_biomass[-1, ]
colnames(anch_sard_biomass) <- c("year", "cruise", "sardine_biomass", "anchoveta_biomass")
anch_sard_biomass <- anch_sard_biomass %>%
  filter(str_detect(cruise, "Reclas")) %>%
  dplyr::select(-cruise) %>%
  mutate(across(ends_with("biomass"), as.numeric))
anch_sard_biomass$year <- as.numeric(anch_sard_biomass$year)


# --- 1b. Jack mackerel: Central-South (acoustic surveys) -----------------

jurel_biomass <- read_excel(
  paste0(dirdata, "IFOP/3. ESTIMACIONES CRUCERO ACUSTICO.xlsx"),
  sheet = "JUREL"
)
jurel_biomass <- jurel_biomass[, c(1, 3, 8)]
jurel_biomass <- jurel_biomass[-1, ]
colnames(jurel_biomass) <- c("year", "jurel_biomass_cs", "jurel_biomass_no")
jurel_biomass <- jurel_biomass %>%
  mutate(
    across(c(jurel_biomass_cs, jurel_biomass_no), as.numeric),
    jurel_biomass_cs = ifelse(jurel_biomass_cs == 0, NA, jurel_biomass_cs),
    jurel_biomass_no = ifelse(jurel_biomass_no == 0, NA, jurel_biomass_no)
  )
jurel_biomass$year <- as.numeric(jurel_biomass$year)


# --- 1c. SPRFMO stock assessment (spawning biomass, ZEE Chile-Ecuador-Peru)
#     This is an official assessment covering the transzonal stock.
#     Available annually since 1970 — no gaps.

sprfmo <- read_excel(paste0(dirdata, "IFOP/Datos_estimación biomasa.xlsx")) %>%
  dplyr::rename(
    year            = `Año (calendario/.5 semestral)`,
    reclutas_sprfmo = `Reclutas (millones individuos)`,
    sb_sprfmo       = `Biomasa desovante (t)`
  ) %>%
  dplyr::filter(Especie == "Jurel", year >= 2000) %>%
  dplyr::select(year, sb_sprfmo, reclutas_sprfmo)

jurel_biomass <- left_join(jurel_biomass, sprfmo, by = "year")
rm(sprfmo)


# --- 1d. Harvest data (for SUR: biomass_t+1 + harvest_t) ----------------

harvest <- readRDS("data/harvest/sernapesca_v2.rds") %>%
  filter(specie == "JUREL") %>%
  select(year, total_harvest_sernapesca_v2_centro_sur)
jurel_biomass <- left_join(jurel_biomass, harvest, by = "year")
rm(harvest)


# =========================================================================
# 2. DIAGNOSTIC: DATA COVERAGE
# =========================================================================

cat("\n====== DATA COVERAGE ======\n")
cat("\nJurel CS observed years:\n")
obs_years <- jurel_biomass %>% filter(!is.na(jurel_biomass_cs)) %>% pull(year)
cat(paste(obs_years, collapse = ", "), "\n")
cat("N observed:", length(obs_years), "\n")

miss_years <- jurel_biomass %>% filter(is.na(jurel_biomass_cs)) %>% pull(year)
cat("\nJurel CS missing years:\n")
cat(paste(miss_years, collapse = ", "), "\n")
cat("N missing:", length(miss_years), "\n")

cat("\nJurel Norte available from:",
    min(jurel_biomass$year[!is.na(jurel_biomass$jurel_biomass_no)]), "\n")
cat("SPRFMO sb available for all years 2000-2024: ",
    all(!is.na(jurel_biomass$sb_sprfmo[jurel_biomass$year >= 2000])), "\n")


# =========================================================================
# 3. INTERPOLATION MODELS
# =========================================================================

# --- 3a. Model A: Parsimonious GLM (Norte only, 2 params) ---------------
#     Only uses Norte biomass (available 2010+)
#     Fewer parameters = more robust with small N

model_A <- glm(
  jurel_biomass_cs ~ jurel_biomass_no,
  family = Gamma(link = "log"),
  data = jurel_biomass
)

# --- 3b. Model B: Norte + Norte^2 (3 params) ----------------------------

model_B <- glm(
  jurel_biomass_cs ~ jurel_biomass_no + I(jurel_biomass_no^2),
  family = Gamma(link = "log"),
  data = jurel_biomass
)

# --- 3c. Model C: SPRFMO sb only (2 params) -----------------------------
#     Uses SPRFMO spawning biomass as proxy for CS abundance.
#     Available for ALL years (no gaps). 
#     Weaker correlation but complete coverage.

model_C <- glm(
  jurel_biomass_cs ~ sb_sprfmo,
  family = Gamma(link = "log"),
  data = jurel_biomass
)

# --- 3d. Model D: Norte + SPRFMO (3 params) -----------------------------

model_D <- glm(
  jurel_biomass_cs ~ jurel_biomass_no + sb_sprfmo,
  family = Gamma(link = "log"),
  data = jurel_biomass
)

# --- 3e. Model E: Original model5 (5 params) ----------------------------
#     INCLUDED ONLY FOR COMPARISON — NOT RECOMMENDED
#     Norte + Norte^2 + SPRFMO^2 + Norte:SPRFMO

model_E <- glm(
  jurel_biomass_cs ~ jurel_biomass_no + I(jurel_biomass_no^2) +
    I(sb_sprfmo^2) + jurel_biomass_no:sb_sprfmo,
  family = Gamma(link = "log"),
  data = jurel_biomass
)

# --- 3f. Linear interpolation (non-parametric) --------------------------
#     Simplest approach: connect observed points with lines.
#     No model assumptions, transparent, but cannot extrapolate.

jurel_for_approx <- jurel_biomass %>%
  filter(!is.na(jurel_biomass_cs)) %>%
  arrange(year)

interp_linear <- approx(
  x = jurel_for_approx$year,
  y = jurel_for_approx$jurel_biomass_cs,
  xout = jurel_biomass$year,
  method = "linear",
  rule = 1  # NA outside observed range
)

jurel_biomass$jurel_cs_linear <- interp_linear$y


# =========================================================================
# 4. MODEL COMPARISON
# =========================================================================

cat("\n====== MODEL COMPARISON ======\n")

# Pseudo R-squared and AIC
r2_glm <- function(model) cor(model$y, model$fitted.values)^2

models <- list(
  A = model_A, B = model_B, C = model_C,
  D = model_D, E = model_E
)

comparison <- tibble(
  Model = names(models),
  Description = c(
    "Norte (2 params)",
    "Norte + Norte^2 (3 params)",
    "SPRFMO sb (2 params)",
    "Norte + SPRFMO (3 params)",
    "Norte + Norte^2 + SPRFMO^2 + Norte:SPRFMO (5 params)"
  ),
  N_obs = sapply(models, function(m) length(m$y)),
  N_params = sapply(models, function(m) length(coef(m))),
  AIC = sapply(models, AIC),
  pseudo_R2 = sapply(models, r2_glm)
)

print(comparison, n = 10, width = 120)

cat("\nNOTE: Models A, B, D, E use Norte (N=", length(model_A$y),
    "obs, only 2010+)\n")
cat("      Model C uses SPRFMO (N=", length(model_C$y), "obs, 2000+)\n")

# Stargazer table
library(stargazer)
stargazer(model_A, model_B, model_C, model_D, model_E,
          type = "text",
          title = "GLM Gamma(log) models for Jack Mackerel CS biomass",
          column.labels = c("A", "B", "C", "D", "E (original)"),
          digits = 4, no.space = TRUE)


# =========================================================================
# 5. GENERATE PREDICTIONS
# =========================================================================

jurel_biomass <- jurel_biomass %>%
  mutate(
    # GLM predictions (type = "response" gives back original scale)
    jurel_cs_modA = predict(model_A, newdata = ., type = "response"),
    jurel_cs_modB = predict(model_B, newdata = ., type = "response"),
    jurel_cs_modC = predict(model_C, newdata = ., type = "response"),
    jurel_cs_modD = predict(model_D, newdata = ., type = "response"),
    jurel_cs_modE = predict(model_E, newdata = ., type = "response")
  ) %>%
  mutate(
    # Set predictions to NA where predictors are missing
    # (Norte is NA before 2010 and in 2022)
    jurel_cs_modA = ifelse(is.na(jurel_biomass_no), NA, jurel_cs_modA),
    jurel_cs_modB = ifelse(is.na(jurel_biomass_no), NA, jurel_cs_modB),
    jurel_cs_modD = ifelse(is.na(jurel_biomass_no), NA, jurel_cs_modD),
    jurel_cs_modE = ifelse(is.na(jurel_biomass_no), NA, jurel_cs_modE),
    # Flag biologically implausible predictions (> 10x max observed)
    max_obs = max(jurel_biomass_cs, na.rm = TRUE),
    jurel_cs_modA = ifelse(jurel_cs_modA > 10 * max_obs, NA, jurel_cs_modA),
    jurel_cs_modB = ifelse(jurel_cs_modB > 10 * max_obs, NA, jurel_cs_modB),
    jurel_cs_modC = ifelse(jurel_cs_modC > 10 * max_obs, NA, jurel_cs_modC),
    jurel_cs_modD = ifelse(jurel_cs_modD > 10 * max_obs, NA, jurel_cs_modD),
    jurel_cs_modE = ifelse(jurel_cs_modE > 10 * max_obs, NA, jurel_cs_modE)
  ) %>%
  select(-max_obs)


# =========================================================================
# 6. BUILD INTERPOLATED SERIES
# =========================================================================
#
# Strategy: Use Model B (Norte + Norte^2) as primary interpolation 
#   where Norte is available. For years where Norte is missing but
#   SPRFMO is available, fall back to linear interpolation.
#   
# This avoids the overfitting of Model E (5 params, ~9 obs) and
# the weak correlation of SPRFMO alone (r = 0.107 with CS observed).

jurel_biomass <- jurel_biomass %>%
  mutate(
    # Primary: Model B where available
    jurel_cs_interp_primary = case_when(
      !is.na(jurel_biomass_cs) ~ jurel_biomass_cs,      # observed: use as-is
      !is.na(jurel_cs_modB)    ~ jurel_cs_modB,          # Norte available: use GLM
      !is.na(jurel_cs_linear)  ~ jurel_cs_linear,        # fallback: linear interp
      TRUE                     ~ NA_real_
    ),
    # Flag: is this observed or interpolated?
    jurel_cs_source = case_when(
      !is.na(jurel_biomass_cs) ~ "observed",
      !is.na(jurel_cs_modB)    ~ "GLM (Norte)",
      !is.na(jurel_cs_linear)  ~ "linear interp",
      TRUE                     ~ "missing"
    )
  )


# =========================================================================
# 7. DIAGNOSTICS: IN-SAMPLE FIT
# =========================================================================

cat("\n====== IN-SAMPLE DIAGNOSTICS ======\n")

# Leave-one-out cross-validation for Model B
if (sum(!is.na(jurel_biomass$jurel_biomass_cs) & !is.na(jurel_biomass$jurel_biomass_no)) > 3) {
  
  loo_df <- jurel_biomass %>%
    filter(!is.na(jurel_biomass_cs), !is.na(jurel_biomass_no))
  
  loo_preds <- numeric(nrow(loo_df))
  for (i in seq_len(nrow(loo_df))) {
    train <- loo_df[-i, ]
    fit_loo <- glm(
      jurel_biomass_cs ~ jurel_biomass_no + I(jurel_biomass_no^2),
      family = Gamma(link = "log"),
      data = train
    )
    loo_preds[i] <- predict(fit_loo, newdata = loo_df[i, ], type = "response")
  }
  
  loo_r2 <- cor(loo_df$jurel_biomass_cs, loo_preds)^2
  loo_rmse <- sqrt(mean((loo_df$jurel_biomass_cs - loo_preds)^2))
  
  cat("\nModel B Leave-One-Out CV:\n")
  cat("  LOO R²:  ", round(loo_r2, 3), "\n")
  cat("  LOO RMSE:", round(loo_rmse, 0), "tons\n")
  cat("  In-sample R²:", round(r2_glm(model_B), 3), "\n")
  cat("  Difference suggests",
      ifelse(r2_glm(model_B) - loo_r2 > 0.15, "OVERFITTING", "acceptable fit"), "\n")
}


# =========================================================================
# 8. DIAGNOSTIC PLOT
# =========================================================================

library(ggplot2)
library(tidyr)

plot_df <- jurel_biomass %>%
  select(year, jurel_biomass_cs, jurel_cs_interp_primary,
         jurel_cs_modB, jurel_cs_modC, jurel_cs_linear, jurel_cs_source) %>%
  pivot_longer(
    cols = c(jurel_biomass_cs, jurel_cs_interp_primary,
             jurel_cs_modB, jurel_cs_modC, jurel_cs_linear),
    names_to = "series",
    values_to = "biomass"
  ) %>%
  mutate(series = recode(series,
    jurel_biomass_cs       = "Observed (acoustic)",
    jurel_cs_interp_primary = "Primary (B + linear fallback)",
    jurel_cs_modB           = "Model B (Norte + Norte²)",
    jurel_cs_modC           = "Model C (SPRFMO only)",
    jurel_cs_linear         = "Linear interpolation"
  ))

p_interp <- ggplot(plot_df, aes(x = year, y = biomass / 1e6, color = series)) +
  geom_line(linewidth = 0.8, na.rm = TRUE) +
  geom_point(
    data = plot_df %>% filter(series == "Observed (acoustic)"),
    size = 2.5, na.rm = TRUE
  ) +
  scale_y_continuous(labels = scales::comma) +
  labs(
    title = "Jack Mackerel CS: Observed vs Interpolated Biomass",
    subtitle = "Comparing interpolation strategies",
    x = "Year", y = "Biomass (millions of tons)", color = "Series"
  ) +
  theme_minimal(base_size = 12) +
  theme(legend.position = "bottom", legend.direction = "vertical")

print(p_interp)

ggsave("figs/jurel_interpolation_comparison.png", p_interp,
       width = 10, height = 6, dpi = 150)


# =========================================================================
# 9. PRINT SUMMARY TABLE
# =========================================================================

cat("\n====== INTERPOLATED SERIES ======\n")
jurel_biomass %>%
  select(year, jurel_biomass_cs, jurel_cs_interp_primary, jurel_cs_source) %>%
  mutate(
    across(where(is.numeric), ~ round(., 0))
  ) %>%
  print(n = 30)


# =========================================================================
# 10. MERGE AND SAVE
# =========================================================================

# Select columns for final dataset
jurel_final <- jurel_biomass %>%
  select(
    year,
    jurel_biomass_cs,              # observed CS (with NAs)
    jurel_biomass_no,              # observed Norte
    sb_sprfmo,                     # SPRFMO spawning biomass
    jurel_cs_interp_primary,       # primary interpolated series
    jurel_cs_source,               # flag: observed/GLM/linear/missing
    jurel_cs_modB,                 # Model B predictions (for robustness)
    jurel_cs_modC,                 # Model C predictions (for robustness)
    jurel_cs_linear                # linear interpolation (for robustness)
  )

# Merge with sardine/anchovy
biomass <- full_join(anch_sard_biomass, jurel_final, by = "year") %>%
  arrange(year)

# Report final coverage for SUR
cat("\n====== SUR SAMPLE SIZE IMPLICATIONS ======\n")

# Option 1: Only observed years (no interpolation)
sur_obs <- biomass %>%
  filter(!is.na(sardine_biomass), !is.na(jurel_biomass_cs)) %>%
  arrange(year) %>%
  mutate(has_next = lead(year) %in% year[!is.na(sardine_biomass) & !is.na(jurel_biomass_cs)])
n_sur_obs <- sum(sur_obs$has_next, na.rm = TRUE)
cat("SUR with observed jurel CS only:", n_sur_obs, "obs\n")

# Option 2: With primary interpolation
sur_interp <- biomass %>%
  filter(!is.na(sardine_biomass), !is.na(jurel_cs_interp_primary)) %>%
  arrange(year) %>%
  mutate(has_next = lead(year) %in% year[!is.na(sardine_biomass) & !is.na(jurel_cs_interp_primary)])
n_sur_interp <- sum(sur_interp$has_next, na.rm = TRUE)
cat("SUR with primary interpolation: ", n_sur_interp, "obs\n")

# Option 3: Two-species SUR (sardine + anchovy only)
sur_2sp <- biomass %>%
  filter(!is.na(sardine_biomass)) %>%
  arrange(year) %>%
  mutate(has_next = lead(year) %in% year[!is.na(sardine_biomass)])
n_sur_2sp <- sum(sur_2sp$has_next, na.rm = TRUE)
cat("SUR sardine+anchovy only:       ", n_sur_2sp, "obs\n")

cat("\nRECOMMENDATION:\n")
cat("  Main spec: 3-species SUR with primary interpolation (", n_sur_interp, " obs)\n")
cat("  Robustness 1: 3-species SUR with observed jurel only (", n_sur_obs, " obs)\n")
cat("  Robustness 2: 2-species SUR, jurel as exogenous (", n_sur_2sp, " obs)\n")


# Save
rm(list = c("anch_sard_biomass", "jurel_final", "jurel_biomass",
            "jurel_for_approx", "interp_linear", "plot_df",
            "model_A", "model_B", "model_C", "model_D", "model_E",
            "models", "comparison", "sur_obs", "sur_interp", "sur_2sp"))

saveRDS(biomass, file = "data/biomass/biomass_dt.rds")

cat("\n✓ Saved: data/biomass/biomass_dt.rds\n")
cat("  Columns:", paste(names(biomass), collapse = ", "), "\n")




# Export for students (Excel)
library(writexl)

biomass_for_students <- biomass %>%
  select(year, sardine_biomass, anchoveta_biomass,
         jurel_biomass_cs, jurel_cs_interp_primary, jurel_cs_source)

write_xlsx(biomass_for_students, path = "data/biomass/biomass_for_students.xlsx")

cat("✓ Saved: data/biomass/biomass_for_students.xlsx\n")

rm(biomass_for_students)

