

###----------------------------------------------###
###              Logbook data                   ### 
###----------------------------------------------###

rm(list = ls())
gc()

# Define directory

usuario <- Sys.info()[["user"]]
# computador <- Sys.info()[["nodename"]]  # Alternativamente puedes usar esto
if (usuario == "felip") {
  dirdata <- "C:/Users/felip/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else if (usuario == "FACEA") {
  dirdata <- "C:/Users/FACEA/OneDrive - Universidad de Concepción/FONDECYT Iniciacion/Data/"
} else {
  stop("Usuario no reconocido. Defina el directorio correspondiente.")
}
rm(usuario)

# Load packages 

library(readxl)
library(tidyverse)

### Load logbooks information for central-south Chile
logbooks <- 
  read_excel(paste0(dirdata, "IFOP/1. BITACORA CENTRO SUR.xlsx"), 
             sheet = "bIt_2001_2024_comercial") %>%
  filter(REGION %in% c(5,6,7,8,9,10,14,16))

### Get species name in logbooks
species <- 
  read_excel(
    paste0(dirdata, "IFOP/1. BITACORA CENTRO SUR.xlsx"), 
    sheet = "PESQUERIAS_MAESTRO_ESPECIE") %>%
  dplyr::select(c('COD_ESPECIE', 'NOMBRE_ESPECIE'))
logbooks <- left_join(logbooks, species, by = "COD_ESPECIE") 
logbooks$year <- year(logbooks$FECHA_HORA_RECALADA)
logbooks$month <- month(logbooks$FECHA_HORA_RECALADA)  
rm(list = c("species"))

### Save logbooks
saveRDS(logbooks, "data/logbooks/logbooks.rds")


### Check longitude by latitude

# logbooks_filtered <- logbooks %>%
#   filter(year > 2011) %>%
#   filter(NOMBRE_ESPECIE %in% c("JUREL")) %>%
#   group_by(LATITUD) %>%
#   summarize(mean_long = mean(LONGITUD, na.rm = TRUE)) %>%
#   arrange(LATITUD)  # Ordena por latitud ascendente
# 
# # Ejemplo de plot
# ggplot(logbooks_filtered, aes(x = LATITUD, y = mean_long)) +
#   geom_line()


