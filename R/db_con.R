library(DBI)
library(RPostgres)

db_password <- Sys.getenv("DB_PASSWORD")

connectToDB <- function() {
  tryCatch({
    con <- dbConnect(
      Postgres(),
      dbname = "Trawl survey",
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
