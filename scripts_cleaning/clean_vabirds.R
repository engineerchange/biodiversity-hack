library(tidyverse)
library(rvest)
library(arrow)

# pull data from feeder watch
df = read_parquet("data/all_hamptonroads_1988_to_2021.parquet")
dict = readxl::read_excel("data/FeederWatch_Data_Dictionary.xlsx",5,skip = 1) %>% janitor::clean_names()
all_birds = df %>% distinct(species_code) %>% left_join(dict,by="species_code")

# pull from Virginia Society of Ornithology
vabirds = read_html('https://www.virginiabirds.org/offical-state-checklist') %>% 
  html_node("body") %>% 
  html_node("div[id='siteWrapper']") %>% html_node("main") %>% html_node("article") %>% html_table() %>% janitor::row_to_names(.,1) %>% janitor::clean_names()

vabirds = vabirds %>%
  mutate(number=number %>% str_replace_all(.,"&nbsp","") %>% str_trim()) %>%
  mutate(species=species %>% str_replace_all(.,"&nbsp","") %>% str_trim()) %>%
  mutate(scientific_name=scientific_name %>% str_replace_all(.,"&nbsp","") %>% str_trim()) %>%
  mutate(state_status=state_status %>% str_replace_all(.,"&nbsp","") %>% str_trim()) %>%
  mutate(spatial_distribution=spatial_distribution %>% str_replace_all(.,"&nbsp","") %>% str_trim()) %>%
  mutate(counts_seasonality=counts_seasonality %>% str_replace_all(.,"&nbsp","") %>% str_trim())

vabirds = vabirds %>% mutate(order = ifelse(str_detect(number,"^Order"),number,NA_character_))
vabirds = vabirds %>% mutate(family = ifelse(str_detect(number,"^Family"),number,NA_character_))

vabirds = vabirds %>% fill(order) %>% fill(family) %>%
  dplyr::filter(!str_detect(number,"^Order")) %>% dplyr::filter(!str_detect(number,"^Family"))

# connect both datasets

# clean up data using a variety of methods
bdf = all_birds %>% select(species_code,sci_name,primary_com_name) %>%
  left_join(vabirds %>% select(scientific_name,order,family),by=c("sci_name"="scientific_name")) %>% 
  # remove extraneous notes in scientific name
  mutate(sci_name2=case_when(
    !is.na(order) ~ '',
    str_detect(sci_name,"\\(") ~ str_replace(sci_name,"\\(.*","") %>% str_trim(),
    str_detect(sci_name,"\\[") ~ str_replace(sci_name,"\\[.*","") %>% str_trim(),
    str_detect(sci_name,"\\/") ~ str_replace(sci_name,"\\/.*","") %>% str_trim(),
    TRUE ~ ''
  )) %>%
  left_join(vabirds %>% select(scientific_name,order,family),by=c("sci_name2"="scientific_name")) %>% 
  mutate(final_order=ifelse(!is.na(order.x),order.x,order.y)) %>%
  mutate(final_family=ifelse(!is.na(family.x),family.x,family.y)) %>% select(-c(order.x,order.y,family.x,family.y)) %>%
  mutate(sci_name2 = case_when(
    sci_name2!='' ~ sci_name2,
    TRUE ~ sci_name
  )) %>% 
  # remove sub sub species name (if present)
  mutate(sci_name3=case_when(
    !is.na(final_order) ~ '',
    str_detect(sci_name2,"^[A-za-z]{1,}\\s[A-Za-z]{1,}$") ~ sci_name2,
    str_detect(sci_name2,"^[A-za-z]{1,}\\s[A-Za-z]{1,}\\s") ~ str_extract(sci_name2,"^[A-za-z]{1,}\\s[A-Za-z]{1,}\\s") %>% str_trim(),
    TRUE ~ sci_name2
  )) %>%
  left_join(vabirds %>% select(scientific_name,order,family),by=c("sci_name3"="scientific_name")) %>%
  mutate(final_order=ifelse(!is.na(order),order,final_order)) %>%
  mutate(final_family=ifelse(!is.na(family),family,final_family)) %>% select(-c(order,family)) %>%
  mutate(scientific_name=ifelse(sci_name3!='',sci_name3,sci_name2)) %>% select(-c(sci_name,sci_name2,sci_name3)) %>%
  select(species_code,scientific_name,primary_com_name,final_order,final_family) %>%
  rename("common_name"="primary_com_name","order"="final_order","family"="final_family") %>%
  # replace "general" species as a "genus"
  mutate(scientific_name=case_when(
    str_detect(scientific_name,"sp\\.") ~ str_replace(scientific_name,"sp\\.","(family/genus)"),
    TRUE ~ scientific_name
  )) %>%
  # native species are those with a match, non-native are those with no match, unknown are those with general family/genus groupings
  mutate(native=case_when(
    !is.na(order) ~ "Native",
    str_detect(scientific_name,"\\(family\\/genus\\)") ~ "Unknown",
    TRUE ~ "Non Native"
  )) %>%
  mutate(order=str_replace(order,"^Order\\s","") %>% str_trim()) %>%
  mutate(family=str_replace(family,"^Family\\s","") %>% str_trim() %>% str_replace("[\\s]{2}"," ") %>% str_trim())

# this dataset represents all birds seen in the dataset linked to whether they are native or not
bdf %>% write_csv("data/vabirds.csv")
