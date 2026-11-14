# import re
# import time
# from pathlib import Path

# import pandas as pd
# import requests


# PROJECT_ROOT = Path(__file__).resolve().parents[1]
# DATA_DIR = PROJECT_ROOT / "data"
# DATA_DIR.mkdir(exist_ok=True)


# SEASONS = {
#     "1990-1991": "1991",
#     "1991-1992": "1992",
#     "1992-1993": "1993",
#     "1993-1994": "1994",
#     "1994-1995": "1995",
#     "1995-1996": "1996",
#     "1996-1997": "1997",
#     "1997-1998": "1998",
#     "1998-1999": "1999",
# }


# def clean_salary_value(value):
#     if pd.isna(value):
#         return None

#     text = str(value)
#     text = text.replace("$", "")
#     text = text.replace(",", "")
#     text = text.replace("\u00a0", "")
#     text = text.strip()

#     if text in {"", "-", "--", "N/A", "nan", "NaN"}:
#         return None

#     try:
#         return int(float(text))
#     except ValueError:
#         return None


# def scrape_salary_year(url_season, season_label):
#     url = f"https://hoopshype.com/salaries/players/{url_season}/"
#     headers = {
#         "User-Agent": (
#             "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
#             "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
#         )
#     }

#     print(f"Scraping {url_season} from {url}")

#     response = requests.get(url, headers=headers, timeout=30)
#     response.raise_for_status()

#     tables = pd.read_html(response.text)
#     if not tables:
#         raise ValueError(f"No HTML tables found for {url_season}")

#     df = tables[0].copy()

#     expected_columns = ["Rank", "Player", "Team", "Salary"]
#     if df.columns.size < 4:
#         raise ValueError(f"Unexpected table structure on {url_season}")

#     df.columns = [str(col).strip() for col in df.columns[:4]]
#     if df.columns.tolist()[:4] != expected_columns:
#         df = df.iloc[:, :4]
#         df.columns = expected_columns

#     df = df[["Player", "Salary"]].copy()
#     df["Year"] = season_label
#     df["Salary"] = df["Salary"].apply(clean_salary_value)
#     df = df.dropna(subset=["Player", "Salary"]).reset_index(drop=True)

#     return df


# def main():
#     all_frames = []

#     for url_season, season_label in SEASONS.items():
#         try:
#             df = scrape_salary_year(url_season, season_label)
#             all_frames.append(df)
#         except Exception as exc:
#             print(f"Failed for {url_season}: {exc}")
#             continue

#         time.sleep(1)

#     if not all_frames:
#         raise RuntimeError("No salary data was successfully scraped.")

#     combined = pd.concat(all_frames, ignore_index=True)

#     combined = combined[["Player", "Salary", "Year"]].copy()
#     combined = combined.drop_duplicates(subset=["Player", "Year"], keep="last")
#     combined = combined.sort_values(["Year", "Player"]).reset_index(drop=True)

#     output_path = DATA_DIR / "nba_salaries_1991_1999.csv"
#     combined.to_csv(output_path, index=False)

#     print(f"Saved {len(combined)} rows to {output_path}")
#     print(combined.head())


# if __name__ == "__main__":
#     main()












import re
import time
from pathlib import Path

import pandas as pd
import requests


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data"
DATA_DIR.mkdir(exist_ok=True)


SEASONS = {
    "1990-1991": "1991",
    "1991-1992": "1992",
    "1992-1993": "1993",
    "1993-1994": "1994",
    "1994-1995": "1995",
    "1995-1996": "1996",
    "1996-1997": "1997",
    "1997-1998": "1998",
    "1998-1999": "1999",
}


def clean_salary_value(value):
    if pd.isna(value):
        return None

    text = str(value)
    text = text.replace("$", "")
    text = text.replace(",", "")
    text = text.replace("\u00a0", "")
    text = text.strip()

    if text in {"", "-", "--", "N/A", "nan", "NaN"}:
        return None

    try:
        return int(float(text))
    except ValueError:
        return None


def scrape_salary_year(url_season, season_label):
    url = f"https://hoopshype.com/salaries/players/{url_season}/"
    headers = {
        "User-Agent": (
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
            "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36"
        )
    }

    print(f"Scraping {url_season} from {url}")

    response = requests.get(url, headers=headers, timeout=30)
    response.raise_for_status()

    tables = pd.read_html(response.text)
    if not tables:
        raise ValueError(f"No HTML tables found for {url_season}")

    df = tables[0].copy()

    expected_columns = ["Rank", "Player", "Team", "Salary"]
    if df.columns.size < 4:
        raise ValueError(f"Unexpected table structure on {url_season}")

    df.columns = [str(col).strip() for col in df.columns[:4]]
    if df.columns.tolist()[:4] != expected_columns:
        df = df.iloc[:, :4]
        df.columns = expected_columns

    df = df[["Player", "Salary"]].copy()
    df["Year"] = season_label
    df["Salary"] = df["Salary"].apply(clean_salary_value)
    df = df.dropna(subset=["Player", "Salary"]).reset_index(drop=True)

    return df


def main():
    all_frames = []

    for url_season, season_label in SEASONS.items():
        try:
            df = scrape_salary_year(url_season, season_label)
            all_frames.append(df)
        except Exception as exc:
            print(f"Failed for {url_season}: {exc}")
            continue

        time.sleep(1)

    if not all_frames:
        raise RuntimeError("No salary data was successfully scraped.")

    combined = pd.concat(all_frames, ignore_index=True)

    combined = combined[["Player", "Salary", "Year"]].copy()
    combined = combined.drop_duplicates(subset=["Player", "Year"], keep="last")
    combined = combined.sort_values(["Year", "Player"]).reset_index(drop=True)

    output_path = DATA_DIR / "nba_salaries_1991_1999.csv"
    combined.to_csv(output_path, index=False)

    print(f"Saved {len(combined)} rows to {output_path}")
    print(combined.head())


if __name__ == "__main__":
    main()
