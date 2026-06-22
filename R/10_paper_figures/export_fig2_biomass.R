# =============================================================================
# Export Fig 2 (biomass) as standalone files for MRE submission
# =============================================================================
# Generates:
#   - figs/paper_figures/fig2_biomass.pdf  (vector, preferred for MRE)
#   - figs/paper_figures/fig2_biomass.png  (300 dpi raster, fallback)
#
# Usage:
#   source("R/10_paper_figures/export_fig2_biomass.R")
# =============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(tidyr)
  library(ggplot2)
  library(scales)
  library(viridis)
})

# -----------------------------------------------------------------------------
# Load and prepare data (replicates the biomass chunk of the main manuscript)
# -----------------------------------------------------------------------------
biomass <- readRDS("data/biomass/biomass_dt.rds")

biomass_long <- biomass %>%
  tidyr::pivot_longer(
    cols = c(sardine_biomass, anchoveta_biomass, jurel_biomass_cs, jurel_cs_interp_primary),
    names_to  = "species",
    values_to = "biomass"
  ) %>%
  dplyr::filter(!is.na(biomass)) %>%
  dplyr::arrange(species, year)

biomass_long$biomass <- as.numeric(biomass_long$biomass)
biomass_long$year    <- as.numeric(biomass_long$year)
biomass_long$species <- dplyr::recode(
  biomass_long$species,
  sardine_biomass             = "Sardine",
  anchoveta_biomass           = "Anchoveta",
  jurel_biomass_cs            = "Jack mackerel",
  jurel_cs_interp_primary     = "Jack mackerel (interpolated)"
)

biomass2 <- biomass_long %>%
  dplyr::filter(species %in% c("Sardine", "Anchoveta", "Jack mackerel (interpolated)")) %>%
  dplyr::mutate(species = ifelse(
    species == "Jack mackerel (interpolated)", "Jack mackerel", species
  ))

# -----------------------------------------------------------------------------
# Build the plot (matches the inline chunk in the manuscript)
# -----------------------------------------------------------------------------
p_biomass <- ggplot(biomass2,
                    aes(x = year, y = biomass, color = species, group = species)) +
  geom_smooth(se = TRUE, method = "loess", span = 0.4, linetype = "solid") +
  scale_y_continuous(labels = scales::comma) +
  labs(x = "Year",
       y = "Biomass (tons)",
       color = "Species") +
  theme_minimal() +
  theme(
    plot.title    = element_text(hjust = 0.5),
    axis.text.y   = element_text(angle = 0, hjust = 1),
    legend.position = "right"
  ) +
  scale_color_viridis_d(option = "D")

# -----------------------------------------------------------------------------
# Save in the formats MRE accepts
# -----------------------------------------------------------------------------
out_dir <- "figs/paper_figures"
dir.create(out_dir, showWarnings = FALSE, recursive = TRUE)

# Vector PDF (preferred by MRE for line art)
ggsave(file.path(out_dir, "fig2_biomass.pdf"),
       p_biomass, width = 9, height = 5, device = cairo_pdf)

# 300 dpi PNG fallback
ggsave(file.path(out_dir, "fig2_biomass.png"),
       p_biomass, width = 9, height = 5, dpi = 300)

cat(sprintf("[fig2_biomass] saved to %s/\n", out_dir))
cat("  - fig2_biomass.pdf (vector)\n")
cat("  - fig2_biomass.png (300 dpi)\n")
