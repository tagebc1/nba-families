# Build data/nba_siblings_list.csv from the FanSided list of brothers who
# played in the NBA (https://fansided.com/posts/full-list-brothers-play-nba-history).
# The lines below are the list as pasted from the page in November 2026.
#
# Rules: "A, B and C Surname" gives one row per brother with the shared
# surname; one pair (Fisher / Washington) has different surnames and is
# handled explicitly. The curly apostrophe in O’Bannon is replaced by a
# straight one so the name matches the NBA register. Family ids are
# 1001, 1002, ... in list order; person ids are row numbers.
#
# Run from the project root:  Rscript scripts/00_make_siblings_list.R

raw <- c(
  "Shandon and Willie Anderson", "Giannis, Kostas and Thanasis Antetokounmpo",
  "LaMelo and Lonzo Ball", "Brent, Drew and Jon Barry", "Charles and Dudley Bradley",
  "Julian and Justin Champagnie", "Jarron and Jason Collins", "Seth and Stephen Curry",
  "Brad and Mickey Davis", "John and Leon Douglas", "Goran and Zoran Dragic",
  "Derek Fisher and Duane Washington", "Bob and Dick Fitzgerald", "Marc and Pau Gasol",
  "Derrick and George Gervin", "Glen and Grant Gondrezick", "Joey and Stephen Graham",
  "Harvey and Horace Grant", "Jerami and Jerian Grant", "Blake and Taylor Griffin",
  "Al and Matt Guokas", "Ben and Tyler Hansbrough", "Juancho and Willy Hernangomez",
  "Aaron, Jrue and Justin Holiday", "Eric and Vinnie Johnson",
  "Caldwell, Charles, Major and Wil Jones", "Nick and Steve Jones", "Tre and Tyus Jones",
  "Albert and Bernard King", "Carl and Marcus Landry", "Ron and Russ Lee",
  "Brook and Robin Lopez", "Caleb and Cody Martin", "Rodney and Scooter McCray",
  "Jaden and Jalen McDaniels", "Al and Dick McGuire", "Bill and Gary Melchionni",
  "Ed and George Mikan", "Evan and Isaiah Mobley", "Marcus and Markieff Morris",
  "Keegan and Kris Murray", "Calvin and Kenny Natt", "Audie and Sylvester Norris",
  "Charles and Ed O’Bannon", "Bud and Ralph Ogden", "Don and Mac Otten",
  "Jannero and Jeremy Pargo", "Jim and John Paxson", "George and Henry Pearcy",
  "Chuck and Wesley Person", "Mason and Miles Plumlee", "Brent and Mark Price",
  "Jim and Mike Price", "Kenny and Phil Rollins", "Campy, Frank and Walker Russell",
  "Brandon and Kareem Rush", "Steve and Tom Scheffler", "Purvis and Steve Short",
  "Connie and Johnny Simmons", "Chris and J.R. Smith", "Mike and Willie Sojourner",
  "Sam and Tom Stith", "Jeff and Marquis Teague", "Carl and Charles Thomas",
  "Amen and Ausar Thompson", "Klay and Mychel Thompson", "Dick and Tom Van Arsdale",
  "George and John Trapp", "Jay and Sam Vincent", "Franz and Moritz Wagner",
  "Gus and Raw Williams", "Michael and Morlon Wiley", "Dominique and Gerald Wilkins",
  "Delon and Dorell Wright", "Cody, Luke and Tyler Zeller"
)

parse_line <- function(line, family_id) {
  if (line == "Derek Fisher and Duane Washington")
    return(data.frame(family_id = family_id, first_name = c("Derek", "Duane"),
                      last_name = c("Fisher", "Washington")))
  tokens <- trimws(strsplit(gsub(" and ", ", ", line), ",")[[1]])
  last_token <- strsplit(tokens[length(tokens)], " ")[[1]]   # "Thanasis Antetokounmpo"
  data.frame(family_id = family_id,
             first_name = c(tokens[-length(tokens)], last_token[1]),
             last_name = paste(last_token[-1], collapse = " "))  # keeps "Van Arsdale"
}

siblings <- do.call(rbind, Map(parse_line, raw, 1000 + seq_along(raw)))
siblings$last_name <- gsub("’", "'", siblings$last_name)
siblings$full_name <- paste(siblings$first_name, siblings$last_name)
siblings$person_id <- seq_len(nrow(siblings))
siblings <- siblings[, c("person_id", "family_id", "first_name", "last_name", "full_name")]
rownames(siblings) <- NULL

write.csv(siblings, "data/nba_siblings_list.csv", row.names = FALSE, fileEncoding = "UTF-8")
cat(sprintf("Wrote data/nba_siblings_list.csv: %d brothers in %d families\n",
            nrow(siblings), length(unique(siblings$family_id))))
