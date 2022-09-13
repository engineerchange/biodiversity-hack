library(tidyverse)
library(rFIA)
library(DBI)

#  va <- getFIA(states = 'VA')

# script following direction on: https://github.com/hunter-stanke/rFIA/issues/29#issuecomment-1122353192
# download sqlite instead of above from https://apps.fs.usda.gov/fia/datamart/datamart_sqlite.html
path_db <- "data/fia/"
path_out <- "data/fia-csvs/"
con <- dbConnect(RSQLite::SQLite(), 
                 paste0(path_db, "FIADB_VA.db"))
db_table_names <- dbListTables(con)
lapply(db_table_names, function(x) {
  write.csv(dbReadTable(x, conn = con),
            file = paste0(path_db, "VA_", x, ".csv"))
})
dbDisconnect(con)