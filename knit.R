Sys.setenv(RSTUDIO_PANDOC = "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools")

if (rstudioapi::isAvailable()) rstudioapi::documentSaveAll()

# Paper 1: Climate projections (biomass + effort)
rmarkdown::render(here::here("paper1/paper1_climate_projections.Rmd"))

# Paper 2: Bioeconomic optimization (when ready)
# rmarkdown::render(here::here("paper2/paper2_bioeconomic_optimization.Rmd"))