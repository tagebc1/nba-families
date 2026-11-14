# Endringer og arbeidslogg #
## - 05.11.26 - ##
Jeg fant tidligere flere datasett fra kaggle som hadde god info, blant annet all_seasons.csv, NBA player stats and salaries 2000-2025.csv, og flere andre datasett. Men ingen av datasettene hadde fødselsdato til spillere som er et problem, fordi når jeg skal gjennomføre en udnersøkelse om søsken forhold er det interessant å vite hvem som er eldre/yngre og tvillinger av brødre i NBA og undersøke om dette har en effekt på hvor godt de gjør det på banen. Jeg tenkte at løsningen kanskje var å scrape basketball-reference.com for å hente denne spillerinfoen med fødselsdato, men nettsiden blokkerer deg hvis du sender for mange forespørsler. APIer til andre datainnhentingsider koster penger så jeg undersøker andre løsninger. til slutt fant jeg et dataset på kaggle som faktisk innehold birthdate, denne dataen ligger i mappen archive_wyatt/csv/player.csv.
### Hull i dataen ###
Etter videre undersøkelse viser det seg at denne dataen har mange hull, og ikke er nøyaktig. Marc Gasol, Brook Lopez, Marcus Morris, Jerami og Jerian Grant, Franz og Moritz Wagner, Jaden McDaniels og Tyler Zeller finnes ikke, selv om de debuterte før 2023.
### løsning ###
Jeg lager et script med hjelp av AI som sammenligner de ulike datafilene jeg har hentet inn og sjekker om det er inconcistencies i dataen. se script/validate_player_data. mulig jeg bruker denne og gpr videre her men inntil videre undersøker jeg andre løsninger.
målet mitt videre er å slå sammen de ulike datasettene mine slik at jeg får to ulike datasets, ett som er spiller info uavhengig av tid, et annet som er spiller i spesifike sesonger.

### VEI VIDERE ###
legg til far sønn relasjoner i en csv fil slik at vi kan bruke far sønn relasjoner i nba og brødre relasjoner i analyse. etter vi har disse to csv filene kan vi begynne å slå all dataen vår sammen til to ulike datafiler, player_bio.csv og player_season.csv. når vi har dette på plass er det bare å lese dataen inn i R fra csv filene og gjennomføre analyse vi ønsker. 



## TODO ##
- lag 2 csv filer; player_bio.csv, player_seasons.csv
- lag/hent family relations csv filer og merge variabler inn i player_bio.csv
    - har laget nbasiblingslist.csv og fathersonlist.csv som bare må merges inn i player_Bio.csv
- sjekk for duplikater av samme navn når du merger data, og at navn er stavet forskjellig kanskje?
**Når du skal lage familier, bare sjekk om det finnes flere mennesker med samme navnet! Og hvis det finnes flere med navnet det er snakk om så kan du flagge dette og legge disse duplikat navnene til en manuell liste. Som du kan sortere selv!**
**Gjør testen slik at den tester uten jr, sr og sånt i navent kanskje? for å være på den sikre siden.**
- **DATA CHECK SALARIES FILENE er viktig å gjøre, passe på at de matcher greit i guess?**
- 

## 07.11.26 ##

Jeg begynte å reviewe father_son.csv listen som jeg lagde ved å scrape en wikipedia-page med liste over second generation forhold i NBA. etter en kvalitetssjekk virker det som om csv listen matcher wikipedia tabellen. Det er mulig at wikipediatabellen mangler noen entries eller har 1-2 feil, som er viktig å huske på videre når vi kommer videre og skal tolke resultater fra analyse, men det er en grei error mener jeg.

- lag to csv filer. Først player bio som er player-karriere nivå, og player seasons som er player-season nivå. Hvilken fil skal vi ta utgangspunkt i? hva hvis jeg bruker alle csv filene mine med spiller data? 

- Jeg undersøkte de forskjellige salary filene og hvordan forfatterne kom fram til dataen, jeg ser jeg kan følge deres metode på å scrappe fra hoopshype slik at jeg kan få salaries fra og med 1990-91 sesongen. da har jeg mer info for å kunne sammenligne mellom far og sønn data med tanke på salary. 

- forsøkte å scrape hoopshype ved hjelp av python script ""salary_scraping_1991_1999" slik som det blir gjort i github repo til datakilden. Men ble blokkert grunnet en paywall som viser seg å stoppe datascrapingen. Jeg legger vekk å forsøke å hente salary information for 1990-2000 enn så lenge og fokuserer på resten av data mergingen.

-  må gjøre all wranglingen i en fil slik at det lagres og dokumenteres hvordan. All merging av data skal være klart dokumentert. Helst i en qmd fil, slik at man kan runne og se resultat i ulike chunks og rendre resultatet enkelt. 


- NBA player stats og salaries_2000-2025.csv har 10472 observasjoner, mens NBA player salaries_2000-2025.csv har 12385 observasjoner. kanskje observasjoner måtte bli droppet når flere variabler skulle med i stats csv filen? uklart hvorfor. kan gå gjennom og hente ut hvilke som mangler.



## 08.11.26 ##
Hvilke csv filer inneholder hvilke variabler?
har fått oversikt og laget flere filer som illustrerer hvilke csv filer som inneholder hvilke variabler og hva slags datasett det er, hvilke år som er inkludert og liknende. **se under.**

# Sender dette til AI assistent:
jeg vil at du skal gjøre to ting:

1. Jeg vil at du skal skrive kode som henter kolonnenavnene fra alle csv filene i data folderen, bortsett fra wyatt data folderen hvor bare common:player_info.csv er viktig. altså variablel navnene, som er tilgjengelige i hver csv fil slik at man får en oversikt. i wyatt data folderen trenger du bare å hente fra common_player_info.csv, mens i den overordnede data folderen henter du variabler fra alle csv filene.

2. fra alle csv filene, hvis tilgjenglig variabel, hent den eldste og nyeste sesongen, og hent det samme med draft year. 

3. lag en oversikt over de ulike datasettene i en ny md fil som beskriver om det er player-career nivå eller player-season, hvilke variabler de inneholder, hvor mange observasjoner det er, og den eldste/nyeste sesongen og draft year de eventuelt inneholder.

til AI assisant etterpå:
Da er det på tide å merge data. les filen 2026-11-07-1730-plan.md for instruksjoner. Les gjennom hele filen, men start med å skrive kode for punkt 1 først og ikke de andre punktene enda. 



ny prompt kl 18.22 - 08.11.26
les html filen jeg lastet ned som heter NBA timeline and abbreviations.html. Jeg vil du skal lage en csv fil som har variabler for team\_city, team\_abbreviation, team\_full\_name, full\_team\_info. team\_full\_name skal bare ha det fulle team navnet inkludert byen, men uten tidsframen i parantes. full\_team_info skal inkludere fulle navnet og parantes og annen info som finnes i den kolonnen i html siden.

lagre csv filen i data mappen.




## 09.11.26 ##

`data_merging.qmd` og `scripts/player_data_merging.R` er kjørt. De nye outputene
har 4 777 spillere og 15 418 spiller-sesong-rader, med sesongsluttår
1997--2025. Det mangler lønn i 3 060 sesongrader og fødselsdato i 649
spillerrader. 41 normaliserte navn er tvetydige, 26 salary-nøkler har konflikter,
og familie-listene har 57 far--sønn- og 47 søskenreferanser som ikke kunne
kobles sikkert. Kontrollfilene ligger i `results/`. Team-by/fullt navn og flere
avanserte rater er beholdt som `NA` fordi de ikke finnes sikkert i de valgte
kildene. Ingen analyse er utført.

gjorde ferdig prompten som lager merging scriptet med ai assistent. den spesifikke prompten jeg runnet var 2026-11-08-player-data-merging-prompt.qmd. detaljene for datamerging ligger blant annet i player_merge_report.csv og de tre kontrollfilene i results/ mappen.


Kvalitetssjekker
Ingen duplikate playerID i player_bio.csv
Ingen duplikate playerID + season i player_seasons.csv
Ingen sesongrader uten matchende spiller i player_bio.csv
nba_team_abbreviations.csv ble ikke brukt
3 060 sesongrader mangler lønn
649 spillere mangler fødselsdato
41 tvetydige normaliserte navn
26 salary-konflikter
57 far-/sønnreferanser kunne ikke matches
47 søskenreferanser kunne ikke matches



skrev ny prompt og jobbet med nytt script for merging, denne gangen til kun player bio csv filen fordi forrige hadde flere feil. 

*TODO*: Lage player_seasons.csv utifra to filer, all_seasons.csv og nba player salaries_2000-2025. 

gjort todoen over.

*TODO*: legg til brothers csv filen til player bio og koble slik at brødre er koblet opp. men fiks først far sønn greiene tenker jeg

Kjørte `scripts/create_player_bio.R` og rendret `create_player_bio.qmd`.
Prosessen bruker bare `all_seasons.csv`, `common_player_info.csv` og
`NBA Player Salaries_2000-2025.csv`; familie-, høyde- og vektfiler er ikke
lest. `data/player_bio.csv` har 4 911 spillere og det eksakte bio-skjemaet.
Kontrollrapporten `results/player_bio_review.csv` har 2 320 rader: 699
umatchbare navn, 740 manglende/ugyldige fødselsdatoer, 100 skolekonflikter og
41 normaliserte navneduplikater. 125 spillere har `same_name_flag = 1`, og
808 har `other_flag = 1` (primært umatchbare navn). Alle familievariabler er
nullstilt til 0. Umatchbare spillere får deterministiske fallback-ID-er.

`scripts/create_player_bio.R` leser nå `data/father_son_list.csv`. Alle navn i
familielisten kontrolleres mot `player_bio`; navn som mangler i de øvrige
datakildene legges til som blanke bio-rader med deterministiske ID-er. Far- og
sønndummyer samt tilknyttede `familyID`-verdier settes fra familielisten.
Kjøringen ga 4 587 spillere, 218 unike far-/sønnnavn og ingen familielistenavn
uten rad i `player_bio.csv`. 50 navn ble lagt til som blanke rader og er
registrert i `results/player_bio_review.csv`.
I tillegg lager scriptet `results/father_son_verification.csv` med én
verifikasjonsrad per relasjon. Kjøringen stopper dersom far eller sønn mangler,
mangler korrekt dummy eller ikke deler en ikke-null `familyID`. Tvetydige
navn får status `linked_ambiguous_name` og beholdes som et eksplisitt
manuelt kontrollpunkt.

`create_player_bio.R` lager nå også `data/family_relations.csv`. Tabellen har
én rad per far--sønn- eller søskenkobling, en deterministisk `relation_ID`,
person-ID-er og navn på begge endepunkter, `relation_type`, `familyID`, kilde
og koblingsstatus. `familyID` er felles for hele familien, mens
`relation_ID` identifiserer én konkret relasjon. Far--sønn lagres
retningsbestemt, og søskenpar lagres bare én gang. Kontrollfilen
`results/family_relations_verification.csv` dokumenterer at alle endepunkter
finnes, deler `familyID` og at ingen søskenpar er duplisert.

Søskenrelasjoner utledes også når to sønner i `father_son_list.csv` har samme
far. Disse får `brother_dummy = 1` og en søskenrad i
`family_relations.csv`; `source` viser at koblingen er utledet fra felles far.
Dette gjør at for eksempel Ron Harper Jr. og Dylan Harper registreres som
brødre selv om de ikke står i `nba_siblings_list.csv`.



etter mye triksing og endring på script som merger og lager player bio har vi fått til et greit script som ordner player_bio.csv. det viktigste med denne filen er at den inneholder mange spillere, men navn, playerID og familierelasjon informasjon. det gjør den nå etter mye frem og tilbake. 







## TODO NESTE GANG ##
*todo*: lag player_seasons.csv oppdatert ved å runne prompten 