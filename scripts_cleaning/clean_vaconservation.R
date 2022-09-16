library(tidyverse)

# data ingest for species in hampton roads region -------------------------------

# https://vanhde.org/species-search - filter by 'Hampton Roads' under Planning District

# pull in data - see above for how to access
species = read_csv("data/attributes_2022_09_12_191055.csv") %>% janitor::clean_names()
species = species %>% dplyr::filter(common_name_natural_community!='Hampton Roads') # filter out extra row
# get the "species groups"
species = species %>% mutate(species_group_tmp = ifelse(str_detect(common_name_natural_community,"^[A-Z\\s]{2,}$"),common_name_natural_community,'')) %>%
  mutate(rownum=1:n()) %>% ungroup()

# loop over dataframe to apply groups to all species
species_last=''
species_df=tibble()
for(i in 1:nrow(species)){
  species_current = species %>% slice(i) %>% select(species_group_tmp) %>% pull()
  rownum = species %>% slice(i) %>% select(rownum) %>% pull()
  if(species_current!=''){
    species_val = species_current
  } else{
    species_val = species_last
  }
  tmp_df = tibble(rownum,species_val)
  species_df = rbind(species_df,tmp_df)
  species_last = species_val
}
# bind output dataframe to original dataframe
species = species %>% left_join(species_df,by="rownum")

# filter out more data
species = species %>%
  # filter out 'groups' rows
  dplyr::filter(!is.na(virginia_coastal_zone)) %>%
  # filter out streams, colonies, and cave
  dplyr::filter(str_detect(scientific_name_linked,"a href"))

# split column into 2
species = species %>%
  mutate(scientific_name_clean=str_extract(scientific_name_linked,"\\>.*\\<") %>% str_replace(.,"<","") %>% str_replace(.,">","")) %>%
  mutate(scientific_name_url=str_extract(scientific_name_linked,'\\".*\\"\\s') %>% str_replace(.,'"',"") %>% str_replace(.,'"',"") %>% str_trim()) %>%
  select(-c(scientific_name,scientific_name_linked,species_group_tmp,rownum)) %>% rename("scientific_name"="scientific_name_clean")

# rename and export
species = species %>% rename("common_name"="common_name_natural_community","species_grp"="species_val") %>%
  select(common_name,scientific_name,scientific_name_url,species_grp,everything())
write_csv(species,"data/native_species_VAconservation.csv")