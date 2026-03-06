library(dplyr)
library(readr)
library(tidyr)

species <- readRDS("data/species_all.rds")
haul <- readRDS("data/haul_data.rds")

# biological data from shared google drive
afsc <- readRDS("data-raw/afsc-specimen.rds")
nwfsc_combo <- readRDS("data-raw/nwfsc_nwfsccombo_age_and_length.rds")
nwfsc_slope <- readRDS("data-raw/nwfsc_nwfscslope_age_and_length.rds")

afsc <- afsc %>%
  semi_join(haul, by = "event_id") %>%
  semi_join(species, by = c("worms" = "species_id")) %>%
  transmute(
    event_id,
    species_id = worms,
    length_cm = length_mm / 10,
    sex,
    age,
    weight_kg = weight_g / 1000,
    sex = case_when(
      sex == c(1) ~ "male",
      sex == c(2) ~ "female",
      sex == c(3) ~ "unknown"
    )
  ) %>%
  filter(
    !if_all(c(length_cm, weight_kg, sex, age), is.na)
  )


nwfsc_combo <- nwfsc_combo %>%
  mutate(Trawl_id = as.double(Trawl_id)) %>%
  semi_join(haul, by = c("Trawl_id" = "event_id")) %>%
  mutate(scientific_name = tolower(Scientific_name)) %>%
  semi_join(
    species %>% mutate(scientific_name = tolower(scientific_name)),
    by = "scientific_name"
  ) %>%
  left_join(
    species %>% mutate(scientific_name = tolower(scientific_name)),
    by = "scientific_name"
  ) %>%
  transmute(
    event_id = Trawl_id,
    weight_kg = Weight_kg,
    age = Age_years,
    length_cm = Length_cm,
    species_id,
    sex = Sex,
    sex = case_when(
      sex == c('M') ~ "male",
      sex == c('F') ~ "female",
      sex == c('U') ~ "unknown"
    )
  ) %>%
  filter(
    !if_all(c(length_cm, weight_kg, sex, age), is.na)
  )

nwfsc_slope <- nwfsc_slope %>%
  mutate(Trawl_id = as.double(Trawl_id)) %>%
  semi_join(haul, by = c("Trawl_id" = "event_id")) %>%
  mutate(scientific_name = tolower(Scientific_name)) %>%
  semi_join(
    species %>% mutate(scientific_name = tolower(scientific_name)),
    by = "scientific_name"
  ) %>%
  left_join(
    species %>% mutate(scientific_name = tolower(scientific_name)),
    by = "scientific_name"
  ) %>%
  transmute(
    event_id = Trawl_id,
    weight_kg = Weight_kg,
    age = Age_years,
    length_cm = Length_cm,
    species_id,
    sex = Sex,
    sex = case_when(
      sex == c('M') ~ "male",
      sex == c('F') ~ "female",
      sex == c('U') ~ "unknown"
    )
  ) %>%
  filter(
    !if_all(c(length_cm, weight_kg, sex, age), is.na)
  )

biol_data <- bind_rows(afsc, nwfsc_combo, nwfsc_slope)
saveRDS(biol_data, "data/biol_data.rds")
