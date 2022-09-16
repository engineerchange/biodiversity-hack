library(tidyverse)
library(arrow)

df = read_parquet("data/out_data.parquet")

count_2021 = df %>% dplyr::filter(year==2021) %>%
  group_by(species_code) %>% summarise(count_2021=sum(how_many,na.rm=TRUE)) %>% ungroup()
count_2020 = df %>% dplyr::filter(year==2020) %>%
  group_by(species_code) %>% summarise(count_2020=sum(how_many,na.rm=TRUE)) %>% ungroup()
count_2019 = df %>% dplyr::filter(year==2019) %>%
  group_by(species_code) %>% summarise(count_2019=sum(how_many,na.rm=TRUE)) %>% ungroup()
count_2018 = df %>% dplyr::filter(year==2018) %>%
  group_by(species_code) %>% summarise(count_2018=sum(how_many,na.rm=TRUE)) %>% ungroup()
count_2017 = df %>% dplyr::filter(year==2017) %>%
  group_by(species_code) %>% summarise(count_2017=sum(how_many,na.rm=TRUE)) %>% ungroup()
count_2016 = df %>% dplyr::filter(year==2016) %>%
  group_by(species_code) %>% summarise(count_2016=sum(how_many,na.rm=TRUE)) %>% ungroup()
count_5yr = df %>% dplyr::filter(year %in% c(2021,2020,2019,2018,2017)) %>%
  group_by(species_code) %>% summarise(count_5yr=sum(how_many,na.rm=TRUE)) %>% ungroup()

months = tribble(~no,~month,
        1,"January",
        2,"February",
        3,"March",
        4,"April",
        5,"May",
        6,"June",
        7,"July",
        8,"August",
        9,"September",
        10,"October",
        11,"November",
        12,"December")

top_months = df %>% group_by(species_code,month) %>% summarise(count=sum(how_many,na.rm=TRUE)) %>%
  arrange(species_code,desc(count)) %>% slice(1) %>% ungroup() %>%
  rename("mo"="month") %>% left_join(months,by=c("mo"="no")) %>% select(species_code,month) %>%
  rename("peak_month"="month")

sum_df = df %>% distinct(species_code) %>%
  left_join(count_2021,by="species_code") %>%
  left_join(count_2020,by="species_code") %>%
  left_join(count_2019,by="species_code") %>%
  left_join(count_2018,by="species_code") %>%
  left_join(count_2017,by="species_code") %>%
  left_join(count_2016,by="species_code") %>%
  left_join(count_5yr,by="species_code") %>%
  left_join(top_months,by="species_code") %>%
  mutate_at(vars(count_2021, count_2020, count_2019, count_2018, count_2017, count_2016), ~replace_na(., 0)) %>%
  mutate(abs_diff=count_2021-count_2020) %>%
  mutate(perc_diff=(count_2021-count_2020)/count_2020) %>%
  mutate(diff=ifelse(abs_diff>0,"Positive","Negative")) %>%
  mutate(total_sum=count_2021+count_2020+count_2019+count_2018+count_2017+count_2016) %>%
  mutate(new_sum=count_2021/(count_2021+count_2020+count_2019+count_2018+count_2017+count_2016)) %>%
  mutate(cons_score1=case_when(
    is.na(perc_diff) ~ 0,
    is.infinite(perc_diff) ~ 0,
    perc_diff<(-1) ~ -1,
    perc_diff>(1) ~ 1,
    perc_diff<(-0.8) ~ -0.8,
    perc_diff>(0.8) ~ 0.8,
    perc_diff<(-0.6) ~ -0.6,
    perc_diff>(0.6) ~ 0.6,
    perc_diff<(-0.4) ~ -0.4,
    perc_diff>(0.4) ~ 0.4,
    perc_diff<(-0.2) ~ -0.2,
    perc_diff>(0.2) ~ 0.2,
    TRUE ~ 0
  )) %>%
  mutate(cons_score2=case_when(
    is.na(total_sum) ~ -1,
    is.infinite(total_sum) ~ -1,
    total_sum < 10 ~ 0,
    total_sum < 20 ~ 0.2,
    total_sum < 50 ~ 0.4,
    total_sum < 100 ~ 0.6,
    total_sum < 500 ~ 0.8,
    total_sum < 1000 ~ 1,
    total_sum <= 0 ~ -1,
    TRUE ~ 1
  )) %>%
  mutate(cons_score3=case_when(
    is.na(new_sum) ~ -1,
    is.infinite(new_sum) ~ -1,
    new_sum <=0.07 ~ -0.5,
    new_sum <= 0.16 ~ -0,
    new_sum <= 0.25 ~ 0.25,
    new_sum <= 0.5 ~ 0.5,
    new_sum <= 0.75 ~ 0.75,
    TRUE ~ 1
  )) %>%
  mutate(cons_score=(cons_score1+cons_score2+cons_score3)/3) %>%
  dplyr::filter(total_sum>0) %>%
  mutate(cons_desc1=case_when(
    cons_score1 <=(-1) ~ "Significant decrease in sightings from 2020-2021.",
    cons_score1 <=(-0.2) ~ "Notable decrease in sightings from 2020-2021.",
    cons_score1 <=0 ~ "",#"Little to no decrease in sightings from 2020-2021.",
    cons_score1 <=0.5 ~ "Notable increase in sightings from 2020-2021.",
    cons_score1 <=1 ~ "Significant increase in sightings from 2020-2021.",
    TRUE ~ ''
  )) %>%
  mutate(cons_desc2=case_when(
    cons_score2 <=(-1) ~ "Very low populations reported in last 5 years.",
    cons_score2 <=(-0.5) ~ "",#"Low populations reported in last 5 years.",
    cons_score2 <=0.5 ~ "",#"Moderate populations reported in last 5 years.",
    cons_score2 <=0.9 ~ "High populations reported in last 5 years.",
    cons_score2 <=1 ~ "Very high populations reported in last 5 years.",
    TRUE ~ ''
  )) %>%
  mutate(cons_desc3=case_when(
    cons_score3 <=0 ~ "Notable decrease in population in last 5 years.",
    cons_score3 <=0.4 ~ "",#"Decrease in population in last 5 years.",
    cons_score3 <=0.5 ~ "Moderate increase in population in last 5 years.",
    cons_score3 <=1 ~ "Significant increase in population in last 5 years.",
    TRUE ~ ''
  )) %>%
  mutate(cons_desc=paste0(cons_desc1," ",cons_desc2," ",cons_desc3) %>% str_trim() %>% str_replace("  "," ")) %>% select(-c(cons_desc1,cons_desc2,cons_desc3)) %>%
  select(-c(count_2019,count_2018,count_2017,count_2016,cons_score1,cons_score2,cons_score3,new_sum,total_sum))

sum_df %>% write_csv("data/species_summary.csv")






