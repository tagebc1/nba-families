# NBA prosjekt

Dette prosjektet i econ4170 har som mål å innhente, analysere og presentere data fra den amerikanske basketballligaen NBA, og ta opp ulike spørsmål og forsøke å svare på disse utifra dataanalyse.

## Mål og muligheter

Følgende er flere ideer om ulike retninger som er interessant å undersøke om dataen vi henter inn.

-   Analysere spillerstatistikk på tvers av sesong, altså undersøke utviklingen til en spiller over tid. Undersøkelse av en niche spiller sin karriere.
-   lage prediksjoner basert på historisk data om spillere/lag
-   **Undersøke NBA nepotisme: Gjør spillere med nba foreldre/søsken det bedre og får en lengre karriere enn spillere uten NBA familie?**
    -   **Er fedre bedre enn sønner?**
    -   
-   Blir spillere bedre/dårligere av å bli tradet til en spesifikk by? For eksempel til lakers, knicks, san antonio, boston. Eller dårlig av å bli tradet til wizards eller nets.
-   Om spillere blir bedre eller dårligere når de får lønnsøkning?
-   **Undersøke om spillere produserer mer poeng gitt lønnen sin eller mindre poeng, altså om spilleren er på en billig kontrakt eller dyr kontrakt.**
-   bruke en spillers net rating som hovedsammenligningsverktøy for å måle en spillers prestasjoner.
-   **Sammenligne american native basketballspillere med foreign spillere og karriereutvikling og forventet karrierelengde og lønn.**
-   **bruke dataen for å lage en tibble som viser de ulike lagene og hvor mye de betaler forskjellige spillere fra år til år, vise dette grafisk/visuelt.**
-   veldig mange spillere heter jalen/jaylen/jaylin, hvor mange har en versjon av dette navnet og hva er de forventede box score averagesene til en jalen type spiller?
-   The Round Mound of Rebound Theory: Undersøke om det er sammenheng mellom spillere sin BMI og rebounds. har spillere med høyere BMI flere rebounds? bruke høyde og vekt til å regne BMI sin predicted rebounds per game.

## Data kilder

-   Etter grundig undersøkelse på tilgjengelige datakilder, er det funnet flere muligheter. Det første alternativet jeg vurderte for data var å hente data direkte fra basketballreference.net som er en annerkjent database for basketball statistikk. Men å scrape denne nettsiden for data og statistikk er krevende, og det finnes ingen gratis api for å innhente dataen på en enkel måte. Hvis jeg hadde kjøpt et betalt abonnement kunne det vært mulig, men det alternativet har jeg ikke gått videre med. Derfor har jeg undersøkt andre muligheter og har funnet gratis ferdig scraped datasets på kaggle.com som jeg kan bruke, som inneholder variabler jeg ønsker å undersøke. Følgende er en liste over variabler jeg mener er av interesse for prosjektet:

## Variabler av interesse

-   PlayerID, player name, team, season, seasonal stats such as avg points per game - rebounds etc, games played, minutes played, salary, position, age, height, weight, home country, college, draft year, draft round, draft pick, Net Rating (Viktig!).

## TO DATASETS JEG VIL ENDE OPP MED (05.11.26)

1.  player_bio.csv
    -   Uavhengig tid/sesong, inneholder generell info som spillere for hele karrieren deres.
    -   VIKTIGSTE VARIABLER: playerID, first name, Last name, birthdate, family ID, birthplace,
    -   Variabler: PlayerID, first name, last name, full name, birthdate, height, weight family ID (0 if no NBA family relations), career total stats (games played, total points, rebounds etc), career game average stats(avg career ppg, rpg, apg etc, career net rating and career plus minus), career total earnings (if available), draft info (year, pick, round, college, undrafted dummy, other draft stats),
2.  Player_seasons.csv
    -   Hver observasjon er en spiller i en gitt sesong.

    -   VIKTIGSTE VARIABLER: playerID som matcher andre csven season year(1998-1999 for eksempel), postion, salary, games played, points per game, team, net rating,

    -   andre Variabler: height, weight, teamID, teamcity, team name, team abbreviation, jersey number, true shooting, games started, minutes played, FGM, FGA, FG%, 3pm, 3pa, effective field goal %, FTA, FTM, FT%, ORB,DRB,TRB, AST, STL, BLK, TOV, PTS,

## Kaggle datasets og andre lenker/kilder:

-   <https://www.kaggle.com/datasets/justinas/nba-players-data/data>

    -   Ligger i data folder og heter all_seasons.csv
    -   virker som det er godt dokumentert data, hentet fra stats.nba.com
    -   Har spiller data fra 1996-97 til og med 2022-23 sesongen
    -   Mange gode box score stats variabler siden 1996.
    -   Svakheter: mangler salary

-   <https://www.kaggle.com/datasets/ratin21/nba-player-stats-and-salaries-2010-2025>

    -   flere datfiler fra denne kilden. ligger i datafolder og heter NBA Player Stats and Salaries_2010-2025.csv, NBA Player Stats and Salaries_2000-2025.csv, NBA Player Salaries_2000-2025.csv
    -   han bruker faktisk NBA-salaries.csv fra en annen bruker og bygger på denne. de nyeste årene 2020-2025 scrappes fra hoopshype.
    -   Inkluderer spesifikt salary variablen fra og med år 2000
    -   det står mer på kaggle siden og er lenket til github repo med enda mer info. i github er det en oversiktlig readme fil med info om dataprossesseringen.

-   NBA-salaries.csv

    -   Hentet fra dette github repoet: <https://github.com/erikgregorywebb/datasets/blob/master/nba-salaries.csv>
    -   Svakheter: Ukjent hvor forfatteren scrapet fra og hvordan dataen er filtrert og prossessert. Må være kritisk til kilden og hvor nøyaktig dataen er.
    -   Når det står season: 2000 betyr det 1999-2000.

-   Flere potensielle datakilder hvis nødvendig:

    -   https://github.com/chardensoft/nbasalary/blob/main/stats/salary_prepped.csv lenken over inneholder flere datasets med team lønn fra 1991 til 2018.

-   Kilder for familieforbindelser i NBA:

    -   Brødre kilde 1 nba_siblings_list laget med claude kommando: https://fansided.com/posts/full-list-brothers-play-nba-history
    - I tillegg utledes søskenrelasjoner når to sønner i father_son_list.csv har samme far.
    -   Far og sønn relasjoner, må scrapes: https://en.wikipedia.org/wiki/List_of_second-generation_NBA_players
    -   liste over mindre kjente family relasjoner (og uncle/nephew): https://www.thesportster.com/basketball/15-basketball-players-you-might-not-know-are-related/
    -   

-   Hvis jeg må scrape basketball reference: https://www.basketball-reference.com/friv/birthplaces.fcgi?

-   liste over abbreviations: https://shrpsports.com/nba/explain.htm
lastet ned denne nettsiden for abbreviations, den ligger i data. forsøkte å lage et script som scraper infoen og lager en csv med ryddig lag navn og tilhørende abbreviation og endringer over tid i lagets struktur, men selve abbreviationsene i denne listen ser jeg ikke matcher med de andre listene fordi noen abbreviations er 2 bokstaver istedenfor 3. Så dropper denne fullstendig. 


## metode og plan for gjennomføring

1.  Data innhenting, kildeverifisering
2.  Datawrangling og filtrering
3.  Data Analyse, forsøke å besvare de ulike spørsmålene
4.  Visualisering av funn
5.  Overordnet rapportering av funn og tolkning

## Timeline

-   Start Date: 24.10.26
-   End Date: 17. november 2026 at time 14.00!

## Creator of this project is Tage Christiansen