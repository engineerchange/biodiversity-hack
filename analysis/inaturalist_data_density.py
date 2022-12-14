"""inaturalist_data_density.py
Script to find the density of bird species per location given in `AREA`
"""
from collections import defaultdict
from itertools import product
from pathlib import Path
from typing import Union

import pandas as pd

for dim in ("rows", "columns"): pd.set_option(f"display.max_{dim}", None)


def main(areas: dict, filepath: Union[str, Path], out: Union[str, Path]) -> None:
    inaturalist_data = pd.read_csv(filepath, low_memory=False, encoding="utf-8")
    print(df := get_density(inaturalist_data, areas, put_csv=True, filepath=out), df.columns, df.shape, sep="\n")


def get_density(frame: pd.DataFrame, areas: dict, put_csv: bool = False,
                filepath: Union[str, Path] = None) -> pd.DataFrame:
    base_data = frame[(iden := ["common_name", "scientific_name"])].drop_duplicates(ignore_index=True)
    collector = defaultdict(list)
    for city, guess in product(areas, frame["place_guess"].values):
        collector[f"{city}_g"].append(False if isinstance(guess, float) else city in guess)
    frame = pd.concat([frame, pd.DataFrame(collector)], axis=1)
    for guess in frame.columns:
        if guess.endswith("_g"):
            city: str = guess[:-2]
            sub = frame[frame[guess]].value_counts(subset=[iden[0]])
            base_data = base_data.merge(sub.rename(city_count := f"{city}_count"), how="left", on=iden[0])
            base_data[f"{city}_density"] = base_data[city_count] / areas[city]
    base_data.dropna(how="all", subset=[c for c in base_data.columns if c not in iden], inplace=True)
    base_data.columns = _format_colnames(base_data.columns)
    if put_csv: base_data.to_csv(filepath, index=False, encoding="utf-8")
    return base_data


def _format_colnames(colnames: list) -> list: return [c.replace(" ", "_") for c in colnames]


if __name__ == "__main__":
    AREAS = {"Chesapeake"    : 351,
             "Franklin"      : 8.36,
             "Gloucester"    : 7.182,
             "Hampton"       : 136.3,
             "Isle of Wight" : 363,
             "Newport News"  : 119.6,
             "Norfolk"       : 96.4,
             "Poquoson"      : 78.46,
             "Smithfield"    : 10.65,
             "Southampton"   : 602,
             "Suffolk"       : 429,
             "Surry"         : 0.826562,
             "Virginia Beach": 497,
             "Williamsburg"  : 9.1,
             "York"          : 215}
    BASE: str = r"/Volumes/GoogleDrive/My Drive/hampton_rds_datathon/inaturalist/observations-259859.csv.zip (Unzipped Files)"
    FILEPATH, OUT = Path(BASE, r"observations-259859.csv"), Path(BASE, r"observations-259859_DENSITY.csv")
    main(AREAS, FILEPATH, OUT)
