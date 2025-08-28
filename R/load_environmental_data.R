# Install if not yet
install.packages("ncdf4")

# Load package
library(ncdf4)

# Open NetCDF file
ncfile <- nc_open("C:/GitHub/Impact of Environment on Harvest/data/env/cmems_mod_glo_phy_my_0.083deg_P1M-m_so-thetao-uo-vo_78.00W-71.50W_42.00S-32.00S_0.49-1.54m_2012-01-01-2021-06-01.nc")

# Print metadata (variables, dimensions, attributes)
print(ncfile)

# Example: extract variable "thetao" (temperature)
thetao <- ncvar_get(ncfile, "thetao")

# Close file when done
nc_close(ncfile)
