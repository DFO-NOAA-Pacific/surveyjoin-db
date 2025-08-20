library(dplyr)

pbs_haul <- readRDS("data-raw/pbs-haul.rds") %>%
  dplyr::transmute(
    survey_id = paste0("PBS ", survey_name),
    event_id,
    date = as.Date(as.POSIXct(date, format = "%Y-%m-%d", tz = Sys.timezone())),
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
    stratum,
    bottom_temp_c = temperature_C,
  )

pbs_haul$effort <- pbs_haul$effort / 100
pbs_haul$effort_units <- "km2"
pbs_haul$performance <- as.character(pbs_haul$performance)

saveRDS(pbs_haul, "data/pbs_haul.rds")
