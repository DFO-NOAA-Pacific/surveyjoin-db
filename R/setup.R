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
      common_name JSONB,
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
      species_id INT NOT NULL,
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
    );",

  specimen = "
    CREATE TABLE IF NOT EXISTS specimen (
      specimen_id BIGSERIAL PRIMARY KEY,
      event_id BIGINT NOT NULL,
      species_id INT NOT NULL,
      length_cm NUMERIC(4,1),
      weight_kg NUMERIC(6,3),
      age SMALLINT,
      sex TEXT CHECK (sex IN ('male','female','unknown')),
      CONSTRAINT fk_haul
        FOREIGN KEY (event_id)
        REFERENCES haul (event_id),
      CONSTRAINT fk_species
        FOREIGN KEY (species_id)
        REFERENCES species (species_id)
        ON UPDATE CASCADE
        ON DELETE SET NULL
    );"
)

for (sql in create_tables) {
  dbExecute(con, sql)
}

# Insert species data
species <- readRDS("data/species_all.rds")
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
catch <- readRDS("data/catch_all.rds")
catch <- as.data.frame(catch[, c("survey_id", "event_id", "species_id", "catch_numbers", "catch_weight")])
dbWriteTable(con, "catch", catch, append = TRUE, row.names = FALSE)
message(paste("Inserted", nrow(catch), "rows into 'catch' table."))

# Insert specimen / biological data (slow)
specimen <- readRDS("data/biol_data.rds")
specimen <- as.data.frame(specimen[, c("event_id", "species_id", "length_cm", "weight_kg", "age", "sex")])
dbWriteTable(con, "specimen", specimen, append = TRUE, row.names = FALSE)
message(paste("Inserted", nrow(specimen), "rows into 'specimen' table."))

# Create views
v1 <- "
CREATE OR REPLACE VIEW vw_catch_full AS
SELECT
  h.*,
  sv.survey_name,
  sv.region,
  s.species_id,
  s.itis,
  s.common_name,
  s.scientific_name,
  COALESCE(c.catch_numbers, 0) AS catch_numbers,
  COALESCE(c.catch_weight, 0)  AS catch_weight
FROM
  haul h
CROSS JOIN
  species s
LEFT JOIN
  catch c
  ON c.event_id = h.event_id
 AND c.species_id = s.species_id
LEFT JOIN
  survey sv
  ON h.survey_id = sv.survey_id;
"

dbExecute(con, v1)
message("Created view 'vw_catch_full'.")

v2 <- "
CREATE OR REPLACE VIEW vw_catch_positive AS
SELECT
  h.*,
  sv.survey_name,
  sv.region,
  c.catch_numbers,
  c.catch_weight,
  s.species_id,
  s.itis,
  s.common_name,
  s.scientific_name
FROM
  haul h
INNER JOIN
  catch c ON h.event_id = c.event_id AND h.survey_id = c.survey_id
INNER JOIN
  species s ON c.species_id = s.species_id
INNER JOIN
  survey sv ON h.survey_id = sv.survey_id;
"

dbExecute(con, v2)
message("Created view 'vw_catch_positive'.")

v3 <- "
CREATE OR REPLACE VIEW vw_specimen AS
SELECT
  h.*,
  sv.survey_name,
  sv.region,
  s.species_id,
  s.itis,
  s.common_name,
  s.scientific_name,
  sp.specimen_id,
  sp.length_cm,
  sp.weight_kg,
  sp.age,
  sp.sex
FROM
  haul h
INNER JOIN
  specimen sp ON h.event_id = sp.event_id
INNER JOIN
  species s ON sp.species_id = s.species_id
INNER JOIN
  survey sv ON h.survey_id = sv.survey_id;
"

dbExecute(con, v3)
message("Created view 'vw_specimen'.")

# Create indexes after data insert
indexes <- c(
  # Species table
  "CREATE INDEX IF NOT EXISTS idx_species_common_name_gin ON species USING gin (common_name);",
  "CREATE INDEX IF NOT EXISTS idx_species_scientific_name ON species (scientific_name);",

  # Catch table
  "CREATE INDEX IF NOT EXISTS idx_catch_species_id ON catch (species_id);",
  "CREATE INDEX IF NOT EXISTS idx_catch_survey_id ON catch (survey_id);",
  "CREATE INDEX IF NOT EXISTS idx_catch_event_id ON catch (event_id);",

  # Haul table
  "CREATE INDEX IF NOT EXISTS idx_haul_date ON haul (date);"
)

for (i in indexes) {
  dbExecute(con, i)
  message(paste("Created index:", i))
}

message("Database setup successful!")
