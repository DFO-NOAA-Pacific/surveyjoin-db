# Function to query the `catch_full` view from the database.
# Usage:
#   1. First, load this script:
#        source('R/get_data.R')
#   2. Then call the function, for example:
#        df <- get_data(species_id = 123, survey_id = "NWFSC Slope")
#
# Available Parameters:
#   - common_name
#   - scientific_name
#   - species_id
#   - itis
#   - region
#   - survey_id
#   - date
#   - year
#   - fuzzy_match

if (!require("DBI", quietly = TRUE)) install.packages("DBI")
if (!require("RPostgres", quietly = TRUE)) install.packages("RPostgres")

library(DBI)
library(RPostgres)

readRenviron(".Renviron")

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

# Function to query the catch_full view
get_data <- function(
    con = NULL,
    common_name = NULL,
    scientific_name = NULL,
    species_id = NULL,
    itis = NULL,
    region = NULL,
    survey_id = NULL,
    date = NULL,
    year = NULL,
    fuzzy_match = FALSE
) {
  # Manage database connection
  local_con_created <- FALSE
  if (is.null(con)) {
    con <- connectToDB()
    if (is.null(con)) {
      stop("Failed to establish database connection within get_data().")
    }
    local_con_created <- TRUE
  }

  on.exit({
    if (local_con_created && !is.null(con) && DBI::dbIsValid(con)) {
      DBI::dbDisconnect(con)
      message("Database connection disconnected by get_data().")
    }
  })

  # Build the SQL query dynamically
  base_query <- "SELECT * FROM catch_full"
  where_clauses <- c()

  add_filter <- function(clause) {
    if (nchar(clause) > 0) {
      where_clauses <<- c(where_clauses, clause)
    }
  }

  # Construct WHERE clauses based on parameters

  # common_name filter
  if (!is.null(common_name)) {
    if (fuzzy_match) {
      common_name_filters <- sapply(common_name, function(name) {
        name_escaped <- gsub("'", "''", name, fixed = TRUE)
        paste0("common_name::text ILIKE '%", name_escaped, "%'")
      })
      add_filter(paste0("(", paste(common_name_filters, collapse = " OR "), ")"))
    } else {
      common_name_array_str <- paste0("ARRAY[", paste0("'", common_name, "'", collapse = ", "), "]::text[]")
      add_filter(paste0("common_name ?| ", common_name_array_str))
    }
  }

  # scientific_name filter
  if (!is.null(scientific_name)) {
    if (fuzzy_match) {
      scientific_name_filters <- sapply(scientific_name, function(name) {
        name_escaped <- gsub("'", "''", name, fixed = TRUE)
        paste0("scientific_name ILIKE '%", name_escaped, "%'")
      })
      add_filter(paste0("(", paste(scientific_name_filters, collapse = " OR "), ")"))
    } else {
      scientific_name_quoted <- paste0("'", scientific_name, "'", collapse = ", ")
      add_filter(paste0("scientific_name IN (", scientific_name_quoted, ")"))
    }
  }

  # species_id
  if (!is.null(species_id)) {
    species_id_str <- paste(species_id, collapse = ", ")
    add_filter(paste0("species_id IN (", species_id_str, ")"))
  }

  # itis
  if (!is.null(itis)) {
    itis_str <- paste(itis, collapse = ", ")
    add_filter(paste0("itis IN (", itis_str, ")"))
  }

  # region
  if (!is.null(region)) {
    region_quoted <- paste0("'", region, "'", collapse = ", ")
    add_filter(paste0("region IN (", region_quoted, ")"))
  }

  # survey_id
  if (!is.null(survey_id)) {
    survey_id_quoted <- paste0("'", survey_id, "'", collapse = ", ")
    add_filter(paste0("survey_id IN (", survey_id_quoted, ")"))
  }

  # # Ensure only one of 'date' or 'year' is provided
  if (!is.null(date) && !is.null(year)) {
    stop("Please provide either 'date' OR 'year', not both.")
  }

  if (!is.null(date)) {
    if (length(date) == 1) {
      date_quoted <- DBI::dbQuoteLiteral(con, date[1])
      add_filter(paste0("date = ", date_quoted))
    } else if (length(date) == 2) {
      start_date <- date[1]
      end_date <- date[2]
      date_clause_parts <- c()
      if (!is.na(start_date)) {
        date_clause_parts <- c(date_clause_parts, paste0("date >= ", DBI::dbQuoteLiteral(con, start_date)))
      }
      if (!is.na(end_date)) {
        date_clause_parts <- c(date_clause_parts, paste0("date <= ", DBI::dbQuoteLiteral(con, end_date)))
      }
      if (length(date_clause_parts) > 0) {
        add_filter(paste0("(", paste(date_clause_parts, collapse = " AND "), ")"))
      } else {
        stop("date must be a single Date, a Date vector of length 2 (with or without NA), or NULL.")
      }
    } else {
      stop("date must be a single Date or a Date vector of length 2.")
    }
  }

  if (!is.null(year)) {
    if (length(year) == 1 && !is.na(year[1])) {
      add_filter(paste0("EXTRACT(YEAR FROM date) = ", year[1]))
    } else if (length(year) == 2) {
      start_year <- year[1]
      end_year <- year[2]
      year_clause_parts <- c()
      if (!is.na(start_year)) {
        year_clause_parts <- c(year_clause_parts, paste0("EXTRACT(YEAR FROM date) >= ", start_year))
      }
      if (!is.na(end_year)) {
        year_clause_parts <- c(year_clause_parts, paste0("EXTRACT(YEAR FROM date) <= ", end_year))
      }
      if (length(year_clause_parts) > 0) {
        add_filter(paste0("(", paste(year_clause_parts, collapse = " AND "), ")"))
      } else {
        stop("year must be a single year, a year vector of length 2 (with or without NA), or NULL.")
      }
    } else {
      stop("year must be a single year or a year vector of length 2.")
    }
  }

  # Assemble the final SQL query
  final_query <- base_query
  if (length(where_clauses) > 0) {
    final_query <- paste0(final_query, " WHERE ", paste(where_clauses, collapse = " AND "))
  }

  message(paste("Executing query:\n", final_query))

  # Execute query and fetch results
  results <- DBI::dbGetQuery(con, final_query)

  return(results)
}
