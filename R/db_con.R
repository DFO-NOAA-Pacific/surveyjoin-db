if (!require("DBI", quietly = TRUE)) install.packages("DBI")
if (!require("RPostgres", quietly = TRUE)) install.packages("RPostgres")

library(DBI)
library(RPostgres)

# Load credentials from .Renviron in project root
readRenviron(".Renviron")

createDbIfMissing <- function(dbname = Sys.getenv("DB_NAME")) {
  con <- dbConnect(
    Postgres(),
    dbname = "postgres",  # Connect to existing default DB
    host = Sys.getenv("DB_HOST"),
    port = Sys.getenv("DB_PORT"),
    user = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASSWORD")
  )

  dbs <- dbGetQuery(con, "SELECT datname FROM pg_database;")

  if (!(dbname %in% dbs$datname)) {
    dbExecute(con, paste0("CREATE DATABASE ", dbname))
    message("Database '", dbname, "' created.")
  } else {
    message("Database '", dbname, "' already exists.")
  }

  dbDisconnect(con)
}

connectToDB <- function() {
  tryCatch({
    con <- dbConnect(
      Postgres(),
      dbname = Sys.getenv("DB_NAME"),
      host = Sys.getenv("DB_HOST"),
      port = Sys.getenv("DB_PORT"),
      user = Sys.getenv("DB_USER"),
      password = Sys.getenv("DB_PASSWORD")
    )
    message("Successfully connected to the database!")
    return(con)
  },
  error = function(e) {
    message("Failed to connect to the database: ", e$message)
    return(NULL)
  })
}

createDbIfMissing()

con <- connectToDB()
if (is.null(con)) {
  stop("Database connection failed.")
}

create_tables <- list(
  survey = "
    CREATE TABLE IF NOT EXISTS survey (
      survey_id TEXT PRIMARY KEY,
      survey_name TEXT NOT NULL,
      region TEXT NOT NULL,
      start_date DATE NOT NULL,
      latest_date DATE
    );",

  species = "
    CREATE TABLE IF NOT EXISTS species (
      species_id INT PRIMARY KEY,
      itis INT,
      common_name TEXT,
      scientific_name TEXT
    );",

  haul = "
    CREATE TABLE IF NOT EXISTS haul (
      event_id BIGINT PRIMARY KEY,
      survey_id TEXT NOT NULL,
      date DATE NOT NULL,
      pass SMALLINT,
      vessel TEXT,
      lat_start NUMERIC(9, 6),
      lon_start NUMERIC(9, 6),
      lat_end NUMERIC(9, 6),
      lon_end NUMERIC(9, 6),
      depth_m NUMERIC(8, 4),
      effort NUMERIC(12, 11),
      effort_units CHAR(3),
      performance TEXT,
      stratum SMALLINT,
      bottom_temp_c NUMERIC(7, 5),
      CONSTRAINT fk_survey
        FOREIGN KEY (survey_id)
        REFERENCES survey (survey_id)
        ON UPDATE CASCADE
    );",

  catch = "
    CREATE TABLE IF NOT EXISTS catch (
      catch_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      survey_id TEXT NOT NULL,
      event_id BIGINT NOT NULL,
      species_id INT,
      catch_numbers INT,
      catch_weight NUMERIC(8, 3),
      CONSTRAINT fk_haul
        FOREIGN KEY (event_id)
        REFERENCES haul (event_id),
      CONSTRAINT fk_species
        FOREIGN KEY (species_id)
        REFERENCES species (species_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,
      CONSTRAINT fk_catch_survey
        FOREIGN KEY (survey_id)
        REFERENCES survey (survey_id)
        ON UPDATE CASCADE
    );"
)

for (sql in create_tables) {
  dbExecute(con, sql)
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
message(paste("Inserted", nrow(species), "rows into 'species' table."))

# Insert survey data
survey <- readRDS("data/survey.rds")
survey <- as.data.frame(survey[, c("survey_id", "survey_name", "region", "start_date", "latest_date")])
dbWriteTable(con, "survey", survey, append = TRUE, row.names = FALSE)
message(paste("Inserted", nrow(survey), "rows into 'survey' table."))

# Insert haul data
haul <- readRDS("data/haul_data.rds")
haul <- as.data.frame(haul[, c("survey_id", "event_id", "date", "pass", "vessel", "lat_start",
                               "lon_start", "lat_end", "lon_end", "depth_m", "effort", "effort_units",
                               "performance", "stratum", "bottom_temp_c")])
dbWriteTable(con, "haul", haul, append = TRUE, row.names = FALSE)
message(paste("Inserted", nrow(haul), "rows into 'haul' table."))

# Insert catch data (slow)
catch <- readRDS("data/catch_data.rds")
catch <- as.data.frame(catch[, c("survey_id", "event_id", "species_id", "catch_numbers", "catch_weight")])
dbWriteTable(con, "catch", catch, append = TRUE, row.names = FALSE)
message(paste("Inserted", nrow(catch), "rows into 'catch' table."))

# Create indexes after data insert
indexes <- c(
  "CREATE INDEX IF NOT EXISTS idx_catch_survey_species ON catch (survey_id, species_id);",
  "CREATE INDEX IF NOT EXISTS idx_catch_event ON catch (event_id);",
  "CREATE INDEX IF NOT EXISTS idx_catch_species ON catch (species_id);",
  "CREATE INDEX IF NOT EXISTS idx_haul_survey_date ON haul (survey_id, date);"
)

for (i in indexes) {
  dbExecute(con, i)
  message(paste("Created index:", i))
}

message("Database setup successful!")
