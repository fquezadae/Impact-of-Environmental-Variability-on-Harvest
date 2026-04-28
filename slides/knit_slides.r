Sys.setenv(RSTUDIO_PANDOC = "C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools")
rmarkdown::render(here::here("slides/slides_PICES.Rmd"), encoding = "UTF-8")
pagedown::chrome_print("slides/slides_PICES.html", output = "slides/slides_PICES.pdf")
# browseURL("slides/slides_PICES.html")