Sys.setenv(RSTUDIO_PANDOC = "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools")
if (rstudioapi::isAvailable()) rstudioapi::documentSaveAll()

rmarkdown::render("paper/paper1_climate_projections.Rmd")
rmarkdown::render("paper/paper1_supplementary_materials.Rmd")
