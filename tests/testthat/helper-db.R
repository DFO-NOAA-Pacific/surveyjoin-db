library(DBI)
library(RPostgres)
library(withr)
readRenviron(".Renviron")

# connect to db
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("DB_NAME"),
  host = Sys.getenv("DB_HOST"),
  user = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASSWORD"),
  port = Sys.getenv("DB_PORT")
)

# disconnect after tests
withr::defer(dbDisconnect(con), teardown_env())
