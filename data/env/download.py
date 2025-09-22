cd "C:\Users\felip\OneDrive - Universidad de Concepción\FONDECYT Iniciacion\Data\Environmental"
cd "C:\Users\FACEA\OneDrive - Universidad de Concepción\FONDECYT Iniciacion\Data\Environmental"

mamba activate C:\Users\FACEA\miniforge3\envs\cmems_env_py3.12


## GLORYS Monthly
copernicusmarine subset --dataset-id cmems_mod_glo_phy_my_0.083deg_P1M-m --variable so --variable thetao --variable uo --variable vo --start-datetime 2012-01-01T00:00:00 --end-datetime 2021-06-01T00:00:00 --minimum-longitude -81 --maximum-longitude -71.5 --minimum-latitude -42 --maximum-latitude -32 --minimum-depth 0.49402499198913574 --maximum-depth 1.5413750410079956 
copernicusmarine subset --dataset-id cmems_mod_glo_phy_myint_0.083deg_P1M-m --variable so --variable thetao --variable uo --variable vo --start-datetime 2021-07-01T00:00:00 --end-datetime 2025-06-01T00:00:00 --minimum-longitude -81 --maximum-longitude -71.5 --minimum-latitude -42 --maximum-latitude -32 --minimum-depth 0.49402499198913574 --maximum-depth 1.5413750410079956

## GLORYS Daily
copernicusmarine subset --dataset-id cmems_mod_glo_phy_my_0.083deg_P1D-m    --variable so --variable thetao --variable uo --variable vo --start-datetime 2012-01-01T00:00:00 --end-datetime 2021-06-30T00:00:00 --minimum-longitude -81 --maximum-longitude -71.5 --minimum-latitude -42 --maximum-latitude -32 --minimum-depth 0.49402499198913574 --maximum-depth 1.5413750410079956 
copernicusmarine subset --dataset-id cmems_mod_glo_phy_myint_0.083deg_P1D-m --variable so --variable thetao --variable uo --variable vo --start-datetime 2021-07-01T00:00:00 --end-datetime 2025-06-28T00:00:00 --minimum-longitude -81 --maximum-longitude -71.5 --minimum-latitude -42 --maximum-latitude -32 --minimum-depth 0.49402499198913574 --maximum-depth 1.5413750410079956


## Wind 
copernicusmarine subset --dataset-id cmems_obs-wind_glo_phy_my_l4_0.125deg_PT1H --variable eastward_wind --variable northward_wind --start-datetime 2012-01-01T00:00:00 --end-datetime 2025-04-19T23:59:00 --minimum-longitude -81 --maximum-longitude -71.5 --minimum-latitude -42 --maximum-latitude -32

## Chlorophyll
copernicusmarine subset --dataset-id cmems_obs-oc_glo_bgc-plankton_my_l4-gapfree-multi-4km_P1D --variable CHL --start-datetime 2012-01-01T00:00:00 --end-datetime 2025-08-20T00:00:00 --minimum-longitude -81 --maximum-longitude -71.5 --minimum-latitude -42 --maximum-latitude -32