library(dplyr)
library(worrms)
library(readr)

NWFSC_catch_hooknline_view <- read_csv("data-raw/NWFSC_catch_hooknline_view.csv")

cols <- data.frame(colnames(NWFSC_catch_hooknline_view))

hook_line <- dplyr::select(
  NWFSC_catch_hooknline_view,
  `site_dim$tide_station_name`,
  `site_dim$site_number`,
  operation_type,
  site_whid,
  set_identifier,
  scientific_name,
  common_name,
  datetime_utc_iso,
  cpue_normalized_catch_numbers,
  taxon_rank,
  best_available_taxonomy_whid,
  )

sci <- data.frame(scientific_name = unique(NWFSC_catch_hooknline_view$scientific_name))
AphiaID <- character(nrow(sci))

for (i in 1:nrow(sci)) {

  sci_name <- sci$scientific_name[i]

  id_result <- tryCatch(
    wm_name2id(sci_name, accepted_only = TRUE),
    error = function(e) NA
  )

  if (length(id_result) == 0 || is.na(id_result)) {
    AphiaID[i] <- NA
  } else {
    AphiaID[i] <- as.character(id_result)
  }
}

species_worms <- sci %>%
  mutate(AphiaID = AphiaID)

nwfsc_hook_line <- hook_line %>%
  left_join(species_worms, by = "scientific_name")

saveRDS(nwfsc_hook_line, "data/nwfsc_hook_line.rds")
