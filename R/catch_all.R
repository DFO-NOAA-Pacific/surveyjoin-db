# Pipeline to transform the catch-all datasets and create a species table
library(dplyr)
library(readr)
library(tidyr)
library(purrr)
library(jsonlite)

master_species <- read_csv("MasterSpeciesTableWithAphiaID.csv")
pbs_catch_all <- readRDS("data-raw/pbs-catch-all.rds")
nwfsc_catch_all <- readRDS("data-raw/nwfsc-catch-all.rds")
afsc_catch_all <- readRDS("data-raw/afsc-catch-all.rds")
haul <- readRDS("data/haul_data.rds")

# PBS
pbs_catch <- pbs_catch_all %>%
  left_join(
    master_species %>%
      filter(
        ssid == "bc",
        !is.na(aphiaID),
        !aphiaID %in% c(1, 2, 126175, 152352)
      ) %>%
      select(species_code, TSN, aphiaID),
    by = "species_code"
  ) %>%
  drop_na(aphiaID) %>%
  rename(
    common_name = species_common_name,
    scientific_name = species_science_name,
    itis = TSN,
    species_id = aphiaID
  ) %>%
  mutate(catch_numbers = replace_na(catch_numbers, 0)) %>%
  mutate(
    common_name = ifelse(species_id == 106738, "right handed hermits", common_name),
    scientific_name = ifelse(species_id == 106738, "paguridae", scientific_name)
  )

# NWFSC

# Handle duplicate (event_id, itis) pairs
dupes <- nwfsc_catch_all %>%
  filter(!is.na(itis)) %>%
  group_by(event_id, itis) %>%
  filter(n() > 1) %>%
  slice_max(catch_wt, with_ties = FALSE) %>%  # keep only max catch_wt (https://github.com/DFO-NOAA-Pacific/surveyjoin-db/issues/30)
  ungroup()

non_dupes <- nwfsc_catch_all %>%
  filter(is.na(itis) | !(paste(event_id, itis) %in% paste(dupes$event_id, dupes$itis)))

nwfsc_catch <- bind_rows(non_dupes, dupes)

nwfsc_catch <- nwfsc_catch %>%
  left_join(
    master_species %>%
      filter(
        !is.na(aphiaID),
        !is.na(TSN),
        !aphiaID %in% c(1, 2, 126175, 152352)
      ) %>%
      group_by(TSN) %>%
      slice(1) %>%
      ungroup() %>%
      select(TSN, aphiaID),
    by = c("itis" = "TSN")
  ) %>%
  drop_na(aphiaID)

# AFSC
afsc_catch <- afsc_catch_all %>%
  filter(!is.na(itis) | !is.na(scientific_name)) %>%
  mutate(scientific_name = tolower(scientific_name)) %>%

  # First pass to fill NA itis using scientific name
  left_join(
    master_species %>%
      mutate(raw_species = tolower(raw_species)) %>%
      group_by(raw_species) %>%
      slice_head(n = 1) %>%
      ungroup() %>%
      select(TSN, raw_species),
    by = c("scientific_name" = "raw_species")
  ) %>%
  mutate(itis = coalesce(itis, TSN)) %>%
  select(-TSN) %>%

  # Second pass to get aphiaID from itis
  left_join(
    master_species %>%
      filter(
        !is.na(aphiaID),
        !is.na(TSN),
        !aphiaID %in% c(1, 2, 126175, 152352)
      ) %>%
      group_by(TSN) %>%
      slice_head(n = 1) %>%
      ungroup() %>%
      select(TSN, aphiaID),
    by = c("itis" = "TSN")
  ) %>%

  # Third pass: Fallback to get aphiaID from scientific name if it's still NA
  left_join(
    master_species %>%
      filter(
        !is.na(aphiaID),
        !is.na(raw_species),
        !aphiaID %in% c(1, 2, 126175, 152352)
      ) %>%
      mutate(raw_species = tolower(raw_species)) %>%
      group_by(raw_species) %>%
      slice_head(n = 1) %>%
      ungroup() %>%
      select(raw_species, aphiaID),
    by = c("scientific_name" = "raw_species"),
    suffix = c("", ".y")
  ) %>%
  mutate(
    # combine the results from the two aphiaID joins
    aphiaID = coalesce(aphiaID, aphiaID.y),
    scientific_name = if_else(aphiaID == 106898, "chionoecetes", scientific_name),
    catch_numbers = replace_na(catch_numbers, 0),
  ) %>%
  drop_na(aphiaID) %>%
  select(-aphiaID.y)

# Combine all species data from the three regions
all_species_raw <- bind_rows(
  pbs_catch %>%
    rename(aphiaID = species_id) %>%
    select(aphiaID, itis, scientific_name) %>%
    distinct(),
  nwfsc_catch %>%
    select(aphiaID, itis) %>%
    mutate(scientific_name = as.character(NA)) %>%
    distinct(),
  afsc_catch %>%
    select(aphiaID, itis, scientific_name) %>%
    distinct()
)

# Create a unified species table
species_table <- all_species_raw %>%
  group_by(aphiaID) %>%
  summarise(
    itis = first(itis[!is.na(itis)], default = NA),
    scientific_name = first(scientific_name[!is.na(scientific_name)], default = NA)
  ) %>%
  ungroup() %>%
  arrange(aphiaID) %>%
  left_join(
    master_species %>%
      group_by(aphiaID) %>%
      summarise(
        TSN = first(TSN[!is.na(TSN)], default = NA),
        raw_species = tolower(first(raw_species[!is.na(raw_species)], default = NA_character_))
      ) %>%
      ungroup(),
    by = "aphiaID"
  ) %>%
  mutate(
    itis = coalesce(itis, TSN),
    scientific_name = coalesce(scientific_name, raw_species)
  ) %>%
  select(aphiaID, itis, scientific_name)

# Add common names as a JSON array
species_table <- species_table %>%
  left_join(
    master_species %>%
      filter(!is.na(raw_common)) %>%
      mutate(raw_common = tolower(raw_common)) %>%
      group_by(aphiaID) %>%
      summarise(common_name_list = list(unique(raw_common))) %>%
      ungroup(),
    by = "aphiaID"
  ) %>%
  mutate(common_name_list = replace_na(common_name_list, list(list()))) %>%
  mutate(
    common_name = map_chr(common_name_list, ~ toJSON(.x, auto_unbox = TRUE)),
  ) %>%
  select(-common_name_list) %>%
  rename(species_id = aphiaID) %>%
  arrange(common_name)

# Clean up
nwfsc_catch <- nwfsc_catch %>%
  left_join(haul %>% select(event_id, survey_id), by = "event_id") %>%
  select(
    event_id,
    survey_id,
    catch_numbers,
    catch_weight = catch_wt,
    itis,
    species_id = aphiaID
  )

afsc_catch <- afsc_catch %>%
  left_join(haul %>% select(event_id, survey_id), by = "event_id") %>%
  select(
    event_id,
    survey_id,
    catch_numbers,
    catch_weight,
    itis,
    species_id = aphiaID,
  )

pbs_catch <- pbs_catch %>%
  left_join(haul %>% select(event_id, survey_id), by = "event_id") %>%
  select(
    event_id,
    survey_id,
    catch_numbers,
    catch_weight,
    itis,
    species_id,
  )

catch_all <- bind_rows(
  pbs_catch,
  nwfsc_catch,
  afsc_catch
) %>%
  arrange(survey_id)

saveRDS(species_table,"data/species_all.rds")
saveRDS(catch_all, "data/catch_all.rds")
