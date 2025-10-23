###----------------------------------------------###
###   Environmental covariates: Merge           ###
###----------------------------------------------###

rm(list = ls())
gc()

library(dplyr)
library(data.table)
library(lubridate)

#-----------------------------
# Load datasets
#-----------------------------
usuario <- Sys.info()[["user"]]
dirdata <- paste0("C:/Users/", usuario, "/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/")

glo_dt <- readRDS("data/env/2000-2011/glorysDaily_2000_2011.rds")    # 0.083° ~ finer than wind
chl_dt <- readRDS("data/env/2000-2011/chlDaily_2000_2011.rds")       # 4 km ~ finest
win_dt <- readRDS("data/env/2000-2011/WindDaily_2000_2011.rds")      # 0.25° ~ coarsest (40km ap)

#-----------------------------
# Define target coarse resolution
#-----------------------------
coarse_res <- 0.25

#-----------------------------
# Function to aggregate any dataset to coarse grid
#-----------------------------
aggregate_to_coarse <- function(dt, vars, coarse_res = 0.25){
  
  dt <- copy(dt)
  dt[, lon_coarse := floor(lon / coarse_res) * coarse_res + coarse_res/2]
  dt[, lat_coarse := floor(lat / coarse_res) * coarse_res + coarse_res/2]
  
  agg_dt <- dt[, c(list(lon = lon_coarse,
                        lat = lat_coarse,
                        date = date),
                   lapply(.SD, mean, na.rm=TRUE)),
               .SDcols = vars,
               by = .(lon_coarse, lat_coarse, date)]
  
  return(agg_dt)
}

#-----------------------------
# Apply aggregation to finer datasets
#-----------------------------
# GLORYS 0.083° -> aggregate to 0.25° grid
glo_vars <- c("sst", "so", "current_speed", "current_direction")
glo_agg <- aggregate_to_coarse(glo_dt, glo_vars, coarse_res)
glo_agg <- glo_agg[, .(lon = lon_coarse,
                       lat = lat_coarse,
                       date,
                       sst, so, current_speed, current_direction)]
# CHL 4 km -> aggregate to 0.25° grid
chl_vars <- c("chl")  # replace with your actual variable names in chl_dt
chl_agg <- aggregate_to_coarse(chl_dt, chl_vars, coarse_res)
chl_agg <- chl_agg[, .(lon = lon_coarse,
                       lat = lat_coarse,
                       date,
                       chl)]

# Wind is already 0.25° -> just select relevant columns
win_vars <- c("speed_mean", "speed_min", "speed_max",
              "dir_mean", "dir_min", "dir_max")
win_dt <- win_dt[, c("lon","lat","date", win_vars), with=FALSE]


#-----------------------------
# Merge all datasets by coarse grid + date
#-----------------------------
setkey(glo_agg, lon, lat, date)
setkey(chl_agg, lon, lat, date)
setkey(win_dt, lon, lat, date)

env_merged <- Reduce(function(x,y) merge(x, y, by=c("lon","lat","date"), all=TRUE),
                     list(win_dt, glo_agg, chl_agg))

#-----------------------------
# Order by lon/lat/date and save
#-----------------------------
setorder(env_merged, lon, lat, date)

max(env_merged$lon)
min(env_merged$lon)
max(env_merged$lat)
min(env_merged$lat)
max(env_merged$date)
min(env_merged$date)

saveRDS(env_merged, file="data/env/2000-2011/EnvMergedDaily_2000_2011_0.25deg.rds")


