library(dplyr)
library(httr)
library(jsonlite)

dat <- data.frame()

for (i in seq(0, 500000, 10000)){
  # query the API link
  res <- httr::GET(url = paste0('https://apps-st.fisheries.noaa.gov/ods/foss/afsc_groundfish_survey_haul/',
                                "?offset=",i,"&limit=10000"))

  if (httr::status_code(res) != 200) {
    warning("Request failed at offset ", i)
    break
  }

  # convert from JSON format
  data <- jsonlite::fromJSON(base::rawToChar(res$content))

  # if there are no data, stop the loop
  if (is.null(nrow(data$items))) {
    break
  }

  # bind sub-pull to dat data.frame
  dat <- dplyr::bind_rows(dat,
                          data$items %>%
                          dplyr::select(-links)) # necessary for API accounting, but not part of the dataset)
}

afsc_haul <- dat %>%
  dplyr::select(
    survey_id = srvy,
    event_id = hauljoin,
    date = date_time,
    vessel = vessel_name,
    lat_start = latitude_dd_start,
    lon_start = longitude_dd_start,
    lat_end = latitude_dd_end,
    lon_end = longitude_dd_end,
    depth_m,
    performance,
    stratum,
    area_swept_km2,
    bottom_temp_c = bottom_temperature_c
  ) %>%
  dplyr::mutate(
    survey_id = paste0("AFSC ", survey_id),
    date = as.POSIXct(date, format = "%Y-%m-%d", tz = Sys.timezone()),
    pass = NA_integer_,
    effort = area_swept_km2,
    effort_units = "km2"
  )%>%
  dplyr::select(
    survey_id,
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
    stratum,
    bottom_temp_c
  )

saveRDS(afsc_haul, "data/afsc_haul.rds")
