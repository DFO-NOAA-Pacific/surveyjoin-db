library(dplyr)
dat_ak <- read.csv("ak_taxonomic_classification.csv")
names(dat_ak) <- tolower(names(dat_ak))
dat_ak <- dplyr::select(dat_ak, species_name, common_name) |>
                        dplyr::rename(scientific_name = species_name)
# ak dat has replicated scientific names
dat_ak <- dat_ak |> distinct() |>
  dplyr::mutate(itis_tsn = NA, worms_aphia_id = NA) 

dat_nw <- read.csv("NWFSC_FRAM_db_common_vw_taxa_20250604.csv") |>
  dplyr::select(scientific_name, all_common_names, itis_tsn, worms_aphia_id) |>
  dplyr::rename(common_name = all_common_names)

dat_pbs <- read.csv("PBS_Species_20250617.csv")
names(dat_pbs) <- tolower(names(dat_pbs))
dat_pbs <- dplyr::select(dat_pbs, species_science_name, species_common_name, itis_tsn) |>
  dplyr::rename(scientific_name = species_science_name,
                common_name = species_common_name) |>
  dplyr::mutate(worms_aphia_id = NA)

# Find AK species not in nw -- about 1500 not in nw
ak_not_nw <- which(dat_ak$scientific_name %in% dat_nw$scientific_name == FALSE)
ak_nw <- rbind(dat_nw, dat_ak[ak_not_nw,])

pbs_not_others <- which(tolower(dat_pbs$scientific_name) %in% tolower(ak_nw$scientific_name) == FALSE)

all <- rbind(ak_nw, dat_pbs[pbs_not_others,])

