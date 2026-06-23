Sys.setenv(RSTUDIO_PANDOC = "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools")

if (rstudioapi::isAvailable()) rstudioapi::documentSaveAll()

# paper1
rmarkdown::render("paper1/paper1_climate_projections.Rmd")

rmarkdown::render("paper1/paper1_supplementary_materials.Rmd")
