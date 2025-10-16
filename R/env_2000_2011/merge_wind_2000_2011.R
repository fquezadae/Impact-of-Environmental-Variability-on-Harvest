###----------------###
###   Merge GLORYS ### 
###----------------###

rm(list = ls())
gc()

library(dplyr)
library(data.table)
library(lubridate)

# Load both datasets
usuario <- Sys.info()[["user"]]
dirdata <- paste0("C:/Users/", paste0(usuario, "/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"))
g1 <- readRDS("data/env/glorysDaily_2012_2021.rds")
g2 <- readRDS("data/env/glorysDaily_2021_2025.rds")

# Combine
glorys <- rbindlist(list(g1, g2), use.names = TRUE, fill = TRUE)

# Order by date (safe)
setorder(glorys, lon, lat, date)

# Save combined
saveRDS(glorys, file = "data/env/glorysDaily_2012_2025.rds")
