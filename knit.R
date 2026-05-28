Sys.setenv(RSTUDIO_PANDOC = "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools")

if (rstudioapi::isAvailable()) rstudioapi::documentSaveAll()

# paper1
rmarkdown::render("paper1/paper1_climate_projections.Rmd")

rmarkdown::render("paper1/paper1_supplementary_materials.Rmd")
# rmarkdown::render("paper1/cover_letter.md")

# Paper 2: Bioeconomic optimization (when ready)
# rmarkdown::render(here::here("paper2/paper2_bioeconomic_optimization.Rmd"))