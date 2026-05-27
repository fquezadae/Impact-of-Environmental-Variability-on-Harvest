Sys.setenv(RSTUDIO_PANDOC = "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools")

if (rstudioapi::isAvailable()) rstudioapi::documentSaveAll()

# 1. Main manuscript (paper1)
rmarkdown::render("paper1/paper1_climate_projections.Rmd")

# 2. Online Appendix (supplementary materials)
rmarkdown::render("paper1/paper1_supplementary_materials.Rmd")

# Paper 2: Bioeconomic optimization (when ready)
# rmarkdown::render(here::here("paper2/paper2_bioeconomic_optimization.Rmd"))