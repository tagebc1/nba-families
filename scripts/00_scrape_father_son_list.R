### Scraper far–sønn-listen fra Wikipedia og skriver data/father_son_list.csv.
### Kjøres fra prosjektroten: Rscript scripts/00_scrape_father_son_list.R
### Listen i data/ ble hentet 7. november 2026; kjør på nytt bare hvis du vil oppdatere den.

library(tidyverse)
library(rvest)

url <- "https://en.wikipedia.org/wiki/List_of_second-generation_NBA_players"
page <- read_html(url)

# Flere sønner i én celle er skilt med <br>. Legg inn en synlig markør,
# ellers smelter navnene sammen til ett. (Endrer `page` direkte.)
page |> html_elements("br") |> xml2::xml_add_sibling("span", " | ")

tabeller <- page |> html_elements("table.wikitable") |> html_table()
map(tabeller, names) # sjekk hvilken tabell som er far-sønn

father_son <- tabeller[[1]] |>                     # anta at den første er far-sønn
  select(father = 1, sons = 2) |>                  # velg etter posisjon, ikke navn
  separate_longer_delim(sons, delim = regex("\\s*\\|\\s*|\\n")) |>
  mutate(across(everything(), ~ str_squish(str_remove_all(.x, "\\[.*?\\]")))) |>
  filter(father != "", sons != "")

write_csv(father_son, "data/father_son_list.csv")
