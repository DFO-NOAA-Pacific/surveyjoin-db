library(DBI)
library(RPostgres)
library(withr)

# connect to db
con <- dbConnect(
  RPostgres::Postgres(),
  dbname = Sys.getenv("DB_NAME"),
  host = Sys.getenv("DB_HOST"),
  user = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASSWORD"),
  port = 5432
)

# disconnect after tests
withr::defer(dbDisconnect(con), teardown_env())
