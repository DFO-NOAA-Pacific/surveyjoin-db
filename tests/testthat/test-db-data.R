library(testthat)
library(DBI)
library(dplyr)
library(here)

test_that("Row counts match local data frames", {

  survey_local <- readRDS(here("data", "survey.rds"))
  species_local <- readRDS(here("data", "species_all.rds"))
  haul_local    <- readRDS(here("data", "haul_data.rds"))
  catch_local   <- readRDS(here("data", "catch_all.rds"))

  survey_db <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM survey")$n
  species_db <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM species")$n
  haul_db    <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM haul")$n
  catch_db   <- dbGetQuery(con, "SELECT COUNT(*) AS n FROM catch")$n

  expect_equal(nrow(survey_local), as.integer(survey_db))
  expect_equal(nrow(species_local), as.integer(species_db))
  expect_equal(nrow(haul_local), as.integer(haul_db))
  expect_equal(nrow(catch_local), as.integer(catch_db))
})

test_that("Species table matches local data", {

  species_local <- readRDS(here("data", "species_all.rds")) %>%
    select(species_id, itis, scientific_name) %>%
    as_tibble()

  species_db <- dbGetQuery(con, "SELECT species_id, itis, scientific_name FROM species") %>%
    as_tibble()

  expect_equal(
    species_local %>% arrange(species_id),
    species_db %>% arrange(species_id)
  )
})

test_that("All catches reference valid hauls and species", {

  orphan_catch_hauls <- dbGetQuery(con, "
    SELECT COUNT(*) AS n
    FROM catch c
    WHERE c.event_id NOT IN (SELECT event_id FROM haul)
  ")$n
  expect_equal(orphan_catch_hauls, 0)

  invalid_species <- dbGetQuery(con, "
    SELECT COUNT(*) AS n
    FROM catch c
    WHERE c.species_id IS NOT NULL
      AND c.species_id NOT IN (SELECT species_id FROM species)
  ")$n
  expect_equal(invalid_species, 0)
})

test_that("Total catch weight per survey matches local summary", {

  catch_local <- readRDS(here("data", "catch_all.rds")) %>%
    group_by(survey_id) %>%
    summarise(total_weight = sum(catch_weight, na.rm = TRUE)) %>%
    arrange(survey_id)

  catch_db <- dbGetQuery(con, "
    SELECT survey_id, SUM(catch_weight) AS total_weight
    FROM catch
    GROUP BY survey_id
    ORDER BY survey_id
  ")

  expect_equal(
    catch_local$total_weight,
    catch_db$total_weight
  )
})


