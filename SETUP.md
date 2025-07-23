# Local Setup Guide for surveyjoin-db

This guide walks you through setting up the `surveyjoin` PostgreSQL database locally on Windows, macOS, or Linux

 **Prerequisites:**

 * R is installed
 * PostgreSQL is installed and running (see below)
 * surveyjoin-db repository is cloned and up to date

---

### 1. Install PostgreSQL

> During installation, you may be asked to set a PostgreSQL superuser password. Make sure to remember this, as you'll need it in your `.Renviron` file. This password is for the PostgreSQL superuser by default.

**Windows**

1. Download the Windows installer: [https://www.postgresql.org/download/windows/](https://www.postgresql.org/download/windows/)
2. During setup, ensure **pgAdmin** is enabled. It's highly recommended to add PostgreSQL’s `bin` directory (e.g., `C:\Program Files\PostgreSQL\14\bin`) to your system `PATH` environment variable. This allows you to run `psql` from any command prompt.

**macOS**

```bash
brew install postgresql
brew services start postgresql
```

**Alternative macOS Installation (Postgres.app)**

1. Go to: [https://postgresapp.com/](https://postgresapp.com/)

2. Download and install the .dmg for your macOS version.

3. After installation, launch Postgres.app once so it sets up everything.

> Note: With Postgres.app, the default PostgreSQL username is your macOS username, and the password is NULL by default. You can leave DB_PASSWORD blank in your .Renviron file if using this method and not setting a password.

**Ubuntu/Debian Linux**

```bash
sudo apt update
sudo apt install postgresql postgresql-contrib
sudo systemctl enable postgresql # Ensure it starts on boot
sudo systemctl start postgresql
```

 **Note:** On some systems, especially Linux, the default Postgres user is `postgres` without an initial password. You may need to set one:

 ```bash
 sudo -u postgres psql
\password postgres
-- Enter your new password twice
\q
 ```

### 2. Configure Environment Variables

In the **root** of your `surveyjoin-db` repo, create an environment file named `.Renviron` with these entries:

```
DB_NAME=surveyjoin        # This can be any name for your local database
DB_HOST=localhost
DB_PORT=5432              # Standard PostgreSQL port
DB_USER=postgres          # Or your Postgres username if you created one
DB_PASSWORD=your_password 
```
> Note: The .Renviron file should not contain comments (#). Remove any comments before saving the file.

To create and edit this project-specific `.Renviron` file conveniently, you can use the `usethis` package within R or RStudio. Ensure you are in the surveyjoin-db project directory, then run:

```r
# If not already installed
# install.packages("usethis")
usethis::edit_r_environ(scope = "project")
```

This command will open the `.Renviron` located at the root of your `surveyjoin-db` project, allowing you to add the variables above. Save and close the file after adding the entries.

To verify that R can access these environment variables, open an R or RStudio session in the surveyjoin-db directory and run:
 ```r
 readRenviron('.Renviron')
 Sys.getenv(c('DB_NAME','DB_HOST','DB_USER','DB_PASSWORD'))
 ```

### 3. Run the Setup Script in R

Open R or RStudio in the `surveyjoin-db` directory and execute:

```r
source('R/db_con.R')
```

The script will:

1. Reload your `.Renviron` to ensure latest credentials are used.
2. Create the database named surveyjoin (or whatever you set DB_NAME to) if it does not already exist.
3. Connect to that database.
4. Create tables (`survey`, `species`, `haul`, `catch`) if missing.
5. Load data from `.rds` files under `data/`.
6. Create indexes on relevant columns.

### 4. Verify the Setup

Using psql (command line):

```sql
-- connect to database
\c surveyjoin

-- Show tables
\dt

-- Check row counts
SELECT COUNT(*) FROM catch;
SELECT COUNT(*) FROM haul;
SELECT COUNT(*) FROM survey;
SELECT COUNT(*) FROM species
```

Using pgAdmin (GUI):

1. Open pgAdmin and connect to your PostgreSQL server (usually localhost).

2. Expand "Databases" and you should see surveyjoin listed (or whatever you set DB_NAME to).

3. Expand surveyjoin -> Schemas -> public -> Tables. You should see survey, species, haul, and catch.

4. Right-click on any table and select "View/Edit Data" -> "All Rows" to see the loaded data, or open a Query Tool (click the SQL icon in the toolbar) and run the SELECT COUNT(*) queries listed above.

### 5. Run Tests (Optional)

After setting up the database and loading data, you can run the included `testthat` tests to ensure everything is working as expected.

In your R or RStudio session, from the `surveyjoin-db` directory, execute:

```r
# Make sure the 'testthat' package is installed
if (!requireNamespace("testthat", quietly = TRUE)) {
  install.packages("testthat")
}

# Run all tests
testthat::test_dir("tests/testthat")
```
---
If you encounter any problems not covered here, feel free to open an issue with a brief explanation.
