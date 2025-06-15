remotes::install_github("nwfsc-assess/nwfscSurvey")
library(dplyr)
library(nwfscSurvey)

haul_nwfsc_combo <- nwfscSurvey::pull_haul(survey = "NWFSC.Combo")
haul_nwfsc_combo$survey_name <- "NWFSC Combo"

haul_nwfsc_slope <- nwfscSurvey::pull_haul(survey = "NWFSC.Slope")
haul_nwfsc_slope$survey_name <- "NWFSC Slope"

haul_nwfsc_shelf <- nwfscSurvey::pull_haul(survey = "NWFSC.Shelf")
haul_nwfsc_shelf$survey_name <- "NWFSC Shelf"

haul_nwfsc_hypox <- nwfscSurvey::pull_haul(survey = "NWFSC.Hypoxia")
haul_nwfsc_hypox$survey_name <- "NWFSC Hypoxia"

haul_nwfsc_tri <- nwfscSurvey::pull_haul(survey = "Triennial")
haul_nwfsc_tri$survey_name <- "AFSC NWFSC Triennial"

haul <- rbind(
  haul_nwfsc_combo,
  haul_nwfsc_slope,
  haul_nwfsc_shelf,
  haul_nwfsc_hypox,
  haul_nwfsc_tri
)

haul$date <- haul$date_formatted

haul <- dplyr::rename(haul,
  "effort" = "area_swept_ha_der",
  "lat_start" = "vessel_start_latitude_dd",
  "lon_start" = "vessel_start_longitude_dd",
  "lat_end" = "vessel_end_latitude_dd",
  "lon_end" = "vessel_end_longitude_dd",
  "depth_m" = "depth_hi_prec_m",
  "event_id" = "trawl_id",
  "bottom_temp_c" = "temperature_at_gear_c_der"
)

haul$effort <- haul$effort / 100  # Changed from hectare(ha)
haul$effort_units <- "km2"
haul$date <- as.POSIXct.Date(nwfsc_haul$date)

nwfsc_haul <- dplyr::select(
  haul,
  survey_name,
  event_id,
  date,
  pass,
  vessel,
  lat_start,
  lon_start,
  lat_end,
  lon_end,
  depth_m,
  effort,
  effort_units,
  performance,
  bottom_temp_c,
)

saveRDS(nwfsc_haul, "data/nwfsc_haul.rds")
