library(dplyr)

haul <- readRDS("data/haul_data.rds")

haul <- dplyr::select(
  haul,
  survey_id,
  date,
)

survey <- haul %>%
  group_by(survey_id) %>%
  summarise(
    start_date = as.Date(min(date, na.rm = TRUE)),
    latest_date = as.Date(max(date, na.rm = TRUE))
  ) %>%
  ungroup()

survey <- survey %>%
  mutate(
    region = case_when(
      survey_id == "AFSC NWFSC Triennial" ~ "nwfsc",
      startsWith(survey_id, "NWFSC") ~ "nwfsc",
      startsWith(survey_id, "AFSC") ~ "afsc",
      startsWith(survey_id, "PBS") ~ "pbs"
    ),
    survey_name = case_when(
      survey_id == "AFSC AI" ~ "Aleutian Islands Bottom Trawl Survey",
      survey_id == "AFSC BSS" ~ "Eastern Bering Sea Upper Continental Slope Bottom Trawl Survey",
      survey_id == "AFSC EBS" ~ "Eastern Bering Sea Bottom Trawl Survey",
      survey_id == "AFSC GOA" ~ "Gulf of Alaska Bottom Trawl Survey",
      survey_id == "AFSC NBS" ~ "Northern Bering Sea Bottom Trawl Survey",
      survey_id == "AFSC NWFSC Triennial" ~ "Alaska Fisheries Science Center/Northwest Fisheries Science Center Triennial Shelf Survey",
      survey_id == "NWFSC Combo" ~ "Northwest Fisheries Science Center West Coast Groundfish Bottom Trawl Survey",
      survey_id == "NWFSC Hypoxia" ~ "NWFSC Hypoxia study",
      survey_id == "NWFSC Shelf" ~ "Northwest Fisheries Science Center Shelf Survey",
      survey_id == "NWFSC Slope" ~ "Northwest Fisheries Science Center Slope Survey",
      survey_id == "PBS SYN HS" ~ "Hecate Strait Synoptic Bottom Trawl Survey",
      survey_id == "PBS SYN QCS" ~ "Queen Charlotte Sound Synoptic Bottom Trawl Survey",
      survey_id == "PBS SYN WCHG" ~ "West Coast Haida Gwaii Synoptic Bottom Trawl Survey",
      survey_id == "PBS SYN WCVI" ~ "West Coast Vancouver Island Synoptic Bottom Trawl Survey"
    )
  )

saveRDS(survey, "data/survey.rds")
