library(DBI)
library(RPostgres)

db_password <- Sys.getenv("DB_PASSWORD")

connectToDB <- function() {
  tryCatch({
    con <- dbConnect(
      Postgres(),
      dbname = "surveyjoin",
      host = "localhost",
      port = 5432,
      user = "postgres",
      password = db_password
    )
    message("Successfully connected to the database!")
    return(con)
  },
  error = function(e) {
    message("Failed to connect to the database: ", e$message)
    return(NULL)
  })
}

con <- connectToDB()
if (is.null(con)) {
  stop("Database connection failed.")
}

checkTables <- function(con) {
  tables <- dbListTables(con)
  required_tables <- c("survey", "haul", "species", "catch")

  if (all(required_tables %in% tolower(tables))) {
    message("All required tables exist!")
    return(TRUE)
  } else {
    message("Missing tables detected.")
    return(FALSE)
  }
}

# Insert species data
species <- readRDS("data/species.rds")
species <- as.data.frame(species[, c("species_id", "itis", "common_name", "scientific_name")])
dbWriteTable(con, "species", species, append = TRUE, row.names = FALSE)

# Insert survey data
survey <- readRDS("data/survey.rds")
survey <- as.data.frame(survey[, c("survey_id", "survey_name", "region", "start_date", "latest_date")])
dbWriteTable(con, "survey", survey, append = TRUE, row.names = FALSE)

# Insert haul data
haul <- readRDS("data/haul_data.rds")
haul <- as.data.frame(haul[, c("survey_id", "event_id", "date", "pass", "vessel", "lat_start",
                               "lon_start", "lat_end", "lon_end", "depth_m", "effort", "effort_units",
                               "performance", "stratum", "bottom_temp_c")])
dbWriteTable(con, "haul", haul, append = TRUE, row.names = FALSE)

# Insert catch data
catch <- readRDS("data/catch_data.rds")
catch <- as.data.frame(catch[, c("survey_id", "event_id", "species_id", "catch_numbers", "catch_weight")])
dbWriteTable(con, "catch", catch, append = TRUE, row.names = FALSE)
