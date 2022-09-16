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


# filter by region --------------------------------------------------------

df = data_va %>% dplyr::filter(subnational1_code=='US-VA') %>% dplyr::filter(longitude>left_long,longitude<right_long,latitude>bottom_lat,latitude<top_lat)

write_parquet(df,"data/all_hamptonroads_1988_to_2021.parquet")

# species count -----------------------------------------------------------

df = read_parquet("data/all_virginia_1988_to_2021.parquet")
dict = readxl::read_excel("data/FeederWatch_Data_Dictionary.xlsx",5,col_names = TRUE,skip = 1)

df %>% group_by(species_code) %>% summarise(nd=n_distinct(month,day,year)) %>% ungroup() %>% arrange(desc(nd)) %>%
  left_join(dict %>% select(SPECIES_CODE,PRIMARY_COM_NAME),by=c("species_code"="SPECIES_CODE")) %>%
  head(25) %>% rename("distinct_days"="nd") %>% gt::gt()

#sq to right of Wakefield
left_long=(-76.98723)
right_long=(-75.72335)
top_lat=37.23835
bottom_lat=36.54757

# sq to bottom left of Wakefield
left_long=(-77.49898)
right_long=(-76.98723)
top_lat=36.96731
bottom_lat=36.54757

# sq to top left of Wakefield
left_long=(-77.16433)
right_long=(-76.98723)
top_lat=37.23835
bottom_lat=36.96731

# sq above James River
left_long=(-76.92188)
right_long=(-76.98723)
top_lat=37.23835
bottom_lat=36.96731


coords = tribble(
  ~left,~right,~bottom,~top,
  -77.48283,-75.83205,36.54599,36.67845,
  -77.43183,-75.83205,36.54599,36.70645,
  -77.38083,-75.83205,36.54599,36.73445,
  -77.32983,-75.83205,36.54599,36.76245,
  -77.27883,-75.83205,36.54599,36.79045,
  -77.22783,-75.83205,36.54599,36.81845,
  -77.17683,-75.83205,36.54599,36.84645,
  -77.12583,-75.83205,36.54599,36.87445,
  -77.07483,-75.83205,36.54599,36.90245,
  -77.02383,-75.83205,36.54599,36.93045,
  -76.97282,-75.83205,36.54599,36.95832,
  -76.97743,-75.83205,36.95832,37.07345,
  -77.14054,-76.16712,37.07345,37.12089,
  -77.14054,-76.16712,37.12089,37.25155,
  -76.91393,-76.16712,37.23975,37.45874,
  -76.91393,-76.40992,37.23975,37.45874,
  -76.74352,-76.40567,37.24074,37.37332,
  -76.74352,-76.40567,37.35675,37.41886,
  -76.64624,-76.40567,37.41886,37.51812,
  -76.64624,-76.40567,37.51812,37.59284
)

dfs = tibble()
for(i in 1:nrow(coords)){
  c1 = coords %>% slice(i) %>% select(left) %>% pull()
  c2 = coords %>% slice(i) %>% select(right) %>% pull()
  c3 = coords %>% slice(i) %>% select(bottom) %>% pull()
  c4 = coords %>% slice(i) %>% select(top) %>% pull()
  tmp_df = df %>% dplyr::filter(latitude>=c3,latitude<=c4,longitude>=c1,longitude<=c2)
  dfs = rbind(dfs,tmp_df)
}


# plot map ----------------------------------------------------------------

va <- map_data("state", region="virginia")
ggplot() + geom_polygon(data = va, aes(x = long, y = lat, group = group),fill='grey80') +
  geom_point(data = dfs %>% distinct(longitude,latitude),aes(x=longitude,y=latitude),colour='red',size=1)

dfs %>% 
  group_by(latitude,longitude,species_code,year,month,day) %>% 
  summarise(count=sum(how_many,na.rm=TRUE)) %>% ungroup() %>%
  write_csv("data/out_data.csv")

dfs %>% write_parquet("data/out_data.parquet")



