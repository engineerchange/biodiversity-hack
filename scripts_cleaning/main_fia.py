import json
from argparse import ArgumentParser, Namespace
from functools import reduce
from pathlib import Path
from typing import Union, Tuple

import geopandas as gpd
import pandas as pd
from geopy.distance import distance

"""
https://www.srs.fs.usda.gov/sustain/data/fia/eastwideguide.htm
https://www.fs.usda.gov/rm/pubs/rmrs_p056/rmrs_p056_03_shaw.pdf

The Forest Vegetation Simulator (FVS) is a national system of forest
growth models maintained by the USDA Forest Service. It is the official tool for stand
growth projection on National Forest lands, but it is also used widely on other
ownerships. Model extensions and post-processors permit FVS users to perform a broad
range of functions, including silvicultural manipulations, wildlife habitat analyses, and
fuel treatment evaluations. Because FIA data were made available in FVS-ready format
through the FIA Mapmaker interface, an increasing number of users have been using
FVS as their tool of choice for compilation of FIA data at the plot level. With the
transition from Mapmaker to FIDO, users who have built analysis systems around this
data availability have lost access to new data. Due to the need to update FIA-FVS data
translation, there is an opportunity to re-design the system to eliminate prior limitations
and take advantage of recent developments in FIA and FVS. Select capabilities of FVS,
and potential modifications and enhancements to the FIA-FVS linkage are discussed. 
"""
for dim in ("rows", "columns"):
    pd.set_option(f"display.max_{dim}", None)


def main(args) -> None:
    sets_w_coords: list = ["VA_FVS_PLOTINIT_PLOT", "VA_FVS_STANDINIT_COND", "VA_FVS_STANDINIT_PLOT", "VA_OZONE_PLOT",
                           "VA_OZONE_PLOT_SUMMARY", "VA_PLOT", "VA_PLOTGEOM", "VA_PLOTSNAP"]
    with open(Path(args.local_source, args.fields)) as h:
        (fields := json.load(h))

    # SUBSETS
    fields_geo = {doc: meta for doc, meta in fields.items() if doc in sets_w_coords}
    selected: set = {"VA_COND", "VA_FVS_STANDINIT_COND", "VA_FVS_STANDINIT_PLOT", "VA_FVS_TREEINIT_PLOT", "VA_TREE"}
    _refs: set = {"VA_REF_FOREST_TYPE_GROUP", "VA_REF_FOREST_TYPE", "VA_REF_HABTYP_DESCRIPTION",
                  "VA_REF_INVASIVE_SPECIES", "VA_REF_PLANT_DICTIONARY", "VA_REF_SPECIES"}

    # Do the selected datasets have any variables in common? Yes, but nothing useful.
    # print(get_common_vars(selected, fields))
    """{'CREATED_IN_INSTANCE', 'MODIFIED_BY', 'CREATED_DATE', 'MODIFIED_IN_INSTANCE', 'MODIFIED_DATE', 'CREATED_BY',
     'Unnamed: 0'}"""

    # Selected datasets with most records
    # print(order_dataset_by_most_records(fields, selected))
    """{'VA_FVS_TREEINIT_PLOT': (1150280, 57), 'VA_TREE': (1102717, 208), 'VA_COND': (52173, 160), 
    'VA_FVS_STANDINIT_COND': (50185, 90), 'VA_FVS_STANDINIT_PLOT': (42659, 90), 'VA_REF_INVASIVE_SPECIES': (53, 17)} """

    df = get_csv(fields["VA_FVS_STANDINIT_COND"]["filepath"]).head(10000)
    df = clean(df)
    df = df[df["is_in_hampton_roads"]]
    if len(set(state := df["STATE"].tolist())) == 1 and 51 in state:
        print("+ All records are in Virginia")
    else:
        print(f"+ State codes: {set(state)}")
    print(df["BASAL_AREA_FACTOR"].unique())
    print(df["BRK_DBH"].unique())
    """
    BRK_DBH - Basal area is the cross-sectional area of trees at breast height (1.3m or 4.5 ft above ground). It is a common " \
    "way to describe stand density. In forest management, basal area usually refers to merchantable timber and is " \
    "given on a per hectare or per acre basis. If you cut down all the merchantable trees on an acre at 4 ½ feet off " \
    "the ground and measured the square inches on the top of each stump (πr*r), added them all together and divided " \
    "by square feet (144 sq inches per square foot), that would be the basal area on that acre. In forest ecology, " \
    "basal area is used as a relatively easily-measured surrogate of total forest biomass and structural complexity," \
    "[1] and change in basal area over time is an important indicator of forest recovery during succession[2] .
    
    * https://www.frames.gov/documents/projects/firemon/TDv3_Methods.pdf
    the number of measured trees can be
    lowered by raising the breakpoint diameter. A large breakpoint diameter will exclude the
    individual measurement of the many small trees on the macroplot. Next, age estimates of
    individual trees can be simplified by taking age in broad diameter and species classes. 
    """
    put_csv(df, Path(args.local_source) / "_cleaned/__VA_FVS_STANDINIT_COND.csv")


def run_1() -> dict:
    # Find needed/interesting data
    paths: dict = get_all_fields(args.local_source, dump_json=True)
    geo_fields: Tuple[str, ...] = ("LAT", "LATITUDE", "LON", "LONGITUDE")
    _fields_geo: set = {k for k, v in paths.items() if any(geo in v["cols"] for geo in geo_fields)}
    return {k: v for k, v in paths.items() if k in _fields_geo}


def get_common_vars(selected, datasets) -> set:
    search_space = [metadata.get("cols") for data, metadata in datasets.items() if data in selected]
    return set.intersection(*[set(sub) for sub in search_space])


def get_dataset_with_var(fields: dict, col: str) -> list:
    res = []
    for k, v in fields.items():
        res.extend(k for arr in v.get("cols") if col in arr)
    return res


def order_dataset_by_most_records(fields: dict, selected: set) -> dict:
    data = {k: get_csv(v.get("filepath")).shape for k, v in fields.items() if k in selected}
    return dict(sorted(data.items(), key=lambda item: item[1], reverse=True))


def get_all_fields(local_source: str, pat: str = "*.csv", dump_json: bool = False) -> dict:
    utf8 = "utf-8"
    data_paths = list(Path(local_source).rglob(pat))
    fields = {f.stem: {"cols": sorted(get_csv(f).columns, key=str.casefold), "filepath": str(f)} for f in data_paths}
    if dump_json:
        with open(Path(local_source, "_docs/_fields.json"), "w", encoding=utf8) as j:
            json.dump(fields, j, indent=4)
    return fields


def clean(frame: pd.DataFrame) -> pd.DataFrame:
    if frame.empty:
        print("!! NO DATA - CHECK INPUT")
        return frame
    frame.drop(columns="Unnamed: 0", inplace=True, errors="ignore")
    return clean_temporal(frame).pipe(clean_geo)


def clean_geo(frame: pd.DataFrame) -> pd.DataFrame:
    lon, lat = "LON", "LAT"
    frame.rename(columns={"LATITUDE": "LAT", "LONGITUDE": "LON"}, inplace=True, errors="ignore")
    hr_lon_lat = {k: [(f[0], f[1])] * len(frame) for k, f in HAMPTON_ROADS.items()}
    for k, v in hr_lon_lat.items(): frame[k] = pd.Series(v)
    tree_coords = zip(frame[lat].values, frame[lon].values)
    distances = [[distance(area, coord).miles for area in HAMPTON_ROADS.values()] for coord in tree_coords]
    frame["is_in_hampton_roads"] = [any(x < 25 for x in locations) for locations in distances]
    return pd.DataFrame(gpd.GeoDataFrame(frame, geometry=gpd.points_from_xy(frame[lon], frame[lat])))


def clean_temporal(frame: pd.DataFrame) -> pd.DataFrame:
    datetime_col, datetime_parts = "CREATED_DATE", ["YEAR", "MONTH", "DAY", "HOUR"]
    frame[datetime_col] = pd.to_datetime(frame[datetime_col], errors="coerce")
    # if all(col for col in datetime_parts if col not in frame.columns):
    frame[f"{datetime_col}_EPOCH"] = _convert2epoch(frame[datetime_col])
    frame[datetime_parts] = frame[datetime_col].apply(lambda x: (x.year, x.month, x.day, x.hour)).apply(pd.Series)
    return frame


def _convert2epoch(datetime_col: pd.Series) -> pd.Series:
    return datetime_col.apply(lambda x: pd.NA if pd.isna(x) else x.timestamp()).astype("Int64")


def get_csv(filepath: Union[str, Path], **kwargs) -> pd.DataFrame:
    return pd.read_csv(filepath, low_memory=False, encoding="utf-8", **kwargs)


def put_csv(frame: pd.DataFrame, filepath: Union[str, Path], **kwargs) -> None:
    frame.to_csv(filepath, index=False, encoding="utf-8", **kwargs)


if __name__ == "__main__":
    # DEFAULTS ---------------------------------------------------------------------------------------------------------
    LOCAL_SOURCE: str = r"/Volumes/GoogleDrive/My Drive/hampton_rds_datathon/FIA"
    FIELDS: str = r"_docs/_fields.json"
    HAMPTON_ROADS: dict = {"chesapeake"   : (36.768208, -76.287491), "franklin": (36.677849, -76.922661),
                           "hampton"      : (37.028271, -76.342339), "newport news": (37.087082, -76.473015),
                           "norfolk"      : (36.8968052, -76.2602336), "poquoson": (37.1241861, -76.3921461),
                           "suffolk"      : (36.7282096, -76.5835703), "virginia beach": (36.8529841, -75.9774183),
                           "williamsburg" : (37.2708788, -76.7074042), "gloucester": (37.4452288, -76.5594479),
                           "isle of wight": (36.8953677, -76.7248143), "southampton": (36.6959378, -77.1586002),
                           "surry"        : (37.1118778, -76.895924), "smithfield": (36.9823313, -76.6310242),
                           "york"         : (37.2230374, -76.5156945)}
    parser = ArgumentParser(description="rFIA")
    parser.add_argument("--local_source", default=LOCAL_SOURCE)
    parser.add_argument("--fields", default=FIELDS)

    args: Namespace = parser.parse_args()
    main(args)
