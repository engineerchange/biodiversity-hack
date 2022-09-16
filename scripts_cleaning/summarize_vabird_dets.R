library(tidyverse)
library(WikipediR)
`%notin%` <- Negate(`%in%`)

# goal of this dataset is to get the wikipedia details about each species/family
bdf = read_csv("data/vabirds.csv")
dict = readxl::read_excel("data/FeederWatch_Data_Dictionary.xlsx",5,skip = 1) %>% janitor::clean_names()

get_html <- function(pg){
  txt = WikipediR::page_content("en","wikipedia",page_name = pg)$parse$text$`*`
  return(txt)
}

get_redirect <- function(html){
  detect = html %>% str_detect(.,"redirectMsg")
  if(detect==TRUE){
    return(TRUE)
  } else{
    return(FALSE)
  }
}

get_redirect_name <- function(html){
  title = html %>% read_html() %>% html_node("a") %>% html_attr("title") %>% str_trim()
  return(title)
}

get_lead <- function(html,val=3){
  paras = html %>% read_html() %>% html_node("body") %>% html_nodes("p")
  lead = paras %>% .[[val]] %>% html_text() %>% str_trim()
  return(lead)
}

get_status <- function(html){
  status = html %>% read_html() %>% toString() %>% str_extract("src.*iucn.*svg.*decoding") %>% str_extract("\\_[A-Z]{1,}\\.svg") %>% str_replace("_","") %>% str_replace(".svg","")
  return(status)
}

bdf = bdf %>%
  mutate(scientific_name = case_when(
    scientific_name == 'Setophaga coronata coronata' ~ 'Setophaga coronata',
    scientific_name == 'Setophaga palmarum palmarum' ~ 'Setophaga palmarum',
    scientific_name == 'Setophaga palmarum hypochrysea' ~ 'Setophaga palmarum',
    TRUE ~ scientific_name
  ))

df = tibble()
for(i in 1:nrow(bdf)){
  name = bdf %>% slice(i) %>% select(scientific_name) %>% pull()
  species_code = bdf %>% slice(i) %>% select(species_code) %>% pull()
  if(!str_detect(name,"\\(family\\/genus\\)")){
    cat(paste0(as.character(i)," - ",name,"\n"))
    
    html = get_html(name)
    rTF = get_redirect(html)
    if(rTF==TRUE){
      name = get_redirect_name(html)
      html = get_html(name)
      cat(paste0("- redirecting... ",name,"\n"))
    }
    url = str_replace_all(name,"\\s","_")
    image_url = html %>% read_html() %>% html_nodes("img") %>% .[[2]] %>% html_attr("src")
    
    lead = get_lead(html)
    status = get_status(html)
    tmp_df = tibble(species_code,common_name=name,lead,status,url,image_url)
    df = rbind(df,tmp_df)
  }
}

# get it with the lead one para before
bdf2 = df %>% mutate(check=str_detect(tolower(lead),paste0("^the ",tolower(common_name)))|str_detect(tolower(lead),paste0("^",tolower(common_name)))) %>% dplyr::filter(check!=TRUE) %>% select(-c(lead,status,url,image_url,check))

df2 = tibble()
for(i in 1:nrow(bdf2)){
  name = bdf2 %>% slice(i) %>% select(common_name) %>% pull()
  species_code = bdf2 %>% slice(i) %>% select(species_code) %>% pull()
  if(!str_detect(name,"\\(family\\/genus\\)")){
    cat(paste0(as.character(i)," - ",name,"\n"))
    
    html = get_html(name)
    rTF = get_redirect(html)
    if(rTF==TRUE){
      name = get_redirect_name(html)
      html = get_html(name)
      cat(paste0("- redirecting... ",name,"\n"))
    }
    url = str_replace_all(name,"\\s","_")
    image_url = html %>% read_html() %>% html_nodes("img") %>% .[[2]] %>% html_attr("src")
    
    lead = get_lead(html,2)
    status = get_status(html)
    tmp_df = tibble(species_code,common_name=name,lead,status,url,image_url)
    df2 = rbind(df2,tmp_df)
  }
}

bdf3 = df2 %>% mutate(check=str_detect(tolower(lead),paste0("^the ",tolower(common_name)))|str_detect(tolower(lead),paste0("^",tolower(common_name)))) %>% dplyr::filter(check!=TRUE) %>% select(-c(lead,status,url,image_url,check))

df3 = tibble()
for(i in 1:nrow(bdf3)){
  name = bdf3 %>% slice(i) %>% select(common_name) %>% pull()
  species_code = bdf3 %>% slice(i) %>% select(species_code) %>% pull()
  if(!str_detect(name,"\\(family\\/genus\\)")){
    cat(paste0(as.character(i)," - ",name,"\n"))
    
    html = get_html(name)
    rTF = get_redirect(html)
    if(rTF==TRUE){
      name = get_redirect_name(html)
      html = get_html(name)
      cat(paste0("- redirecting... ",name,"\n"))
    }
    url = str_replace_all(name,"\\s","_")
    image_url = html %>% read_html() %>% html_nodes("img") %>% .[[2]] %>% html_attr("src")
    
    lead = get_lead(html,4)
    status = get_status(html)
    tmp_df = tibble(species_code,common_name=name,lead,status,url,image_url)
    df3 = rbind(df3,tmp_df)
  }
}

df3 %>% mutate(check=str_detect(tolower(lead),paste0("^the ",tolower(common_name)))|str_detect(tolower(lead),paste0("^",tolower(common_name)))) %>% dplyr::filter(check!=TRUE) %>% select(-c(lead,status,url,image_url,check))


df3 = df3 %>% mutate(lead=case_when(
  common_name=='Merlin (bird)' ~ get_lead(get_html('Merlin (bird)'),4),
  common_name=='American yellow warbler' ~ get_lead(get_html('American yellow warbler'),3),
  common_name=='Northern pintail' ~ get_lead(get_html('Northern pintail'),3),
  TRUE ~ lead
))

final_birds = rbind(df %>% dplyr::filter(species_code %notin% bdf2$species_code),
      df2 %>% dplyr::filter(species_code %notin% bdf3$species_code),
      df3)

final_birds = final_birds %>% rowwise() %>% mutate(image_url=case_when(
  str_detect(image_url,"Status\\_") ~ '',
  TRUE ~ image_url
)) %>% ungroup()

final_birds %>% dplyr::filter(image_url=='')

final_birds = final_birds %>% rowwise() %>% mutate(image_url=case_when(
  image_url=='' ~ get_html(common_name) %>% read_html() %>% html_nodes("img") %>% .[[1]] %>% html_attr("src"),
  TRUE ~ image_url
)) %>% ungroup()

final_birds = final_birds %>% rowwise() %>% mutate(image_url=case_when(
  str_detect(image_url,"Red\\_Pencil\\_Icon\\.png") ~ get_html(common_name) %>% read_html() %>% html_nodes("img") %>% .[[3]] %>% html_attr("src"),
  TRUE ~ image_url
)) %>% ungroup()

final_birds = final_birds %>% mutate(status=case_when(
  species_code=='hoared' ~ "LC",
  species_code=='foxsp1' ~ "LC",
  TRUE ~ status
))


# add statistics ----------------------------------------------------------

bird_stats = read_csv("data/species_summary.csv")

final_birds2 = bird_stats %>%
  left_join(final_birds %>% mutate(species_grp='birds'),by="species_code") %>%
  left_join(bdf %>% select(species_code,scientific_name,order,family,native),by="species_code") %>%
  rename("cons_status"="status") %>% rename("description"="lead") %>%
  mutate(website=paste0("https://en.wikipedia.org/wiki/",common_name %>% str_replace_all("\\s","_") %>% str_replace_all("'","%27"))) %>%
  mutate(image_url=paste0("https:",image_url)) %>%
  select(species_grp,order,family,species_code,common_name,scientific_name,count_2021,count_2020,count_5yr,cons_status,cons_score,
         cons_desc,diff,abs_diff,perc_diff,peak_month,native,description,image_url,website) %>%
  mutate(cons_status=case_when(
    cons_status=="LC" ~ "Least Concern",
    cons_status=="NT" ~ "Near Threatened",
    cons_status=="VU" ~ "Vulnerable",
    TRUE ~ NA_character_
  ))

final_birds2 = final_birds2 %>% left_join(dict %>% select(species_code,order1,family) %>% rename("family1"="family"),by="species_code") %>%
  mutate(order=ifelse(!is.na(order),order,order1),family=ifelse(!is.na(family),family,family1)) %>% select(-c(order1,family1))

final_birds2 = final_birds2 %>% mutate(perc_diff=case_when(
  abs_diff==0 ~ 0,
  is.infinite(perc_diff) ~ 1,
  TRUE ~ perc_diff
))

final_birds2 %>% write_csv("data/out_infobox.csv")


