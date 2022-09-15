library(tidyverse)
library(arrow)


# data ingest for feederwatch ---------------------------------------------

data_2021 = read_csv("data/PFW_2021_public.csv")
data_2020 = read_csv("data/PFW_2016_2020_public.csv")
data_2015 = read_csv("data/PFW_2011_2015_public.csv")
data_2010 = read_csv("data/PFW_2006_2010_public.csv")
data_2005 = read_csv("data/PFW_2001_2005_public.csv")

colnames(data_2021)
colnames(data_2020)
colnames(data_2015)
colnames(data_2010)
colnames(data_2005)

data_va = rbind(data_2021 %>% dplyr::filter(subnational1_code=='US-VA') %>% mutate(PLUS_CODE='') %>% janitor::clean_names(), # add extra column
                data_2020 %>% dplyr::filter(SUBNATIONAL1_CODE=='US-VA') %>% janitor::clean_names(),
                data_2015 %>% dplyr::filter(SUBNATIONAL1_CODE=='US-VA') %>% janitor::clean_names(),
                data_2010 %>% dplyr::filter(SUBNATIONAL1_CODE=='US-VA') %>% janitor::clean_names(),
                data_2005 %>% dplyr::filter(SUBNATIONAL1_CODE=='US-VA') %>% janitor::clean_names())

rm(data_2021,data_2020,data_2015,data_2010,data_2005);gc(T,T)

data_2000 = read_csv("data/PFW_1996_2000_public.csv")
data_1995 = read_csv("data/PFW_1988_1995_public.csv")

colnames(data_2000)
colnames(data_1995)

data_va = rbind(data_va,
                data_2000 %>% dplyr::filter(SUBNATIONAL1_CODE=='US-VA') %>% janitor::clean_names(),
                data_1995 %>% dplyr::filter(SUBNATIONAL1_CODE=='US-VA') %>% janitor::clean_names())

rm(data_2000,data_1995);gc(T,T)

arrow::write_parquet(data_va,"data/all_virginia_1988_to_2021.parquet")

dict = readxl::read_excel("data/FeederWatch_Data_Dictionary.xlsx",5,col_names = TRUE,skip = 1) 


# filter by region

left_long=(-77.54233)
right_long=(-75.74168)
top_lat=37.61191
bottom_lat=36.53989

df = data_va %>% dplyr::filter(subnational1_code=='US-VA') %>% dplyr::filter(longitude>left_long,longitude<right_long,latitude>bottom_lat,latitude<top_lat)

arrow::write_parquet(df,"data/all_hamptonroads_1988_to_2021.parquet")

# species count -----------------------------------------------------------

df %>% group_by(species_code) %>% summarise(nd=n_distinct(month,day,year)) %>% ungroup() %>% arrange(desc(nd)) %>%
  left_join(dict %>% select(SPECIES_CODE,PRIMARY_COM_NAME),by=c("species_code"="SPECIES_CODE")) %>%
  head(25) %>% rename("distinct_days"="nd") %>% gt::gt()


# plot map ----------------------------------------------------------------

va <- map_data("state", region="virginia")
ggplot() + geom_polygon(data = va, aes(x = long, y = lat, group = group),fill='grey80') +
  geom_point(data = df %>% distinct(longitude,latitude),aes(x=longitude,y=latitude),colour='red',size=1)




