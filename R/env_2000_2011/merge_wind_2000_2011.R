###----------------###
###   Merge WIND   ### 
###----------------###

rm(list = ls())
gc()

library(dplyr)
library(data.table)
library(lubridate)

# Load both datasets
usuario <- Sys.info()[["user"]]
dirdata <- paste0("C:/Users/", paste0(usuario, "/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"))
g1 <- readRDS("data/env/2000-2011/WindDaily_2000_2009.rds")
g2 <- readRDS("data/env/2000-2011/WindDaily_2009_2011.rds")

# Define coarser grid
coarse_res <- 0.25

# Assign coarse grid coordinates to g2 (the 0.125° one)
g2[, lon_coarse := floor(lon / coarse_res) * coarse_res + coarse_res/2]
g2[, lat_coarse := floor(lat / coarse_res) * coarse_res + coarse_res/2]

# Aggregate g2 → 0.25°
vars <- setdiff(names(g2), c("lon","lat","lon_coarse","lat_coarse","date","year","month"))
g2_agg <- g2[, c(list(lon = lon_coarse,
                      lat = lat_coarse,
                      date = date,
                      year = year,
                      month = month),
                 lapply(.SD, mean, na.rm=TRUE)),
             .SDcols = vars,
             by = .(lon_coarse, lat_coarse, date, year, month)]

g2_agg <- g2_agg[, c("lon","lat","date", "year", "month", vars), with=FALSE]

# Combine with g1 (already 0.25°)
winds <- rbindlist(list(g1, g2_agg), use.names=TRUE, fill=TRUE)
winds <- unique(winds, by=c("lon","lat","date"))
setorder(winds, lon, lat, date)

# Save combined
saveRDS(winds, file = "data/env/2000-2011/WindDaily_2000_2011.rds")
