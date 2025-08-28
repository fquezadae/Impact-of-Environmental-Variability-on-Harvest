cd "C:\GitHub\Impact of Environment on Harvest\data\env"
mamba activate C:\Users\FACEA\miniforge3\envs\cmems_env_py3.12


## Monthly
copernicusmarine subset --dataset-id cmems_mod_glo_phy_my_0.083deg_P1M-m --variable so --variable thetao --variable uo --variable vo --start-datetime 2012-01-01T00:00:00 --end-datetime 2021-06-01T00:00:00 --minimum-longitude -78 --maximum-longitude -71.5 --minimum-latitude -42 --maximum-latitude -32 --minimum-depth 0.49402499198913574 --maximum-depth 1.5413750410079956 

copernicusmarine subset --dataset-id cmems_mod_glo_phy_myint_0.083deg_P1M-m --variable so --variable thetao --variable uo --variable vo --start-datetime 2021-07-01T00:00:00 --end-datetime 2025-06-01T00:00:00 --minimum-longitude -78 --maximum-longitude -71.5 --minimum-latitude -42 --maximum-latitude -32 --minimum-depth 0.49402499198913574 --maximum-depth 1.5413750410079956


## Daily
copernicusmarine subset --dataset-id cmems_mod_glo_phy_my_0.083deg_P1D-m --variable so --variable thetao --variable uo --variable vo --start-datetime 2012-01-01T00:00:00 --end-datetime 2021-06-30T00:00:00 --minimum-longitude -78 --maximum-longitude -71.5 --minimum-latitude -42 --maximum-latitude -32 --minimum-depth 0.49402499198913574 --maximum-depth 1.5413750410079956 

copernicusmarine subset --dataset-id cmems_mod_glo_phy_myint_0.083deg_P1D-m --variable so --variable thetao --variable uo --variable vo --start-datetime 2021-07-01T00:00:00 --end-datetime 2025-06-28T00:00:00 --minimum-longitude -78 --maximum-longitude -71.5 --minimum-latitude -42 --maximum-latitude -32 --minimum-depth 0.49402499198913574 --maximum-depth 1.5413750410079956