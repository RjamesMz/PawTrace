#!/usr/bin/env python3
"""
generate_mask.py

Generates a 'no-signal' / 'low-signal' gray mask GeoJSON for Catanduanes, Philippines.
Source: Speedtest by Ookla Open Data (CC BY-NC-SA 4.0) mobile performance tiles
clipped against the official Catanduanes land boundary from OpenStreetMap.

Output:
- web/gray_mask.geojson
- assets/data/gray_mask.geojson
"""

import os
import json
import logging
from typing import List, Tuple
import requests
import s3fs
import pyarrow.dataset as ds
import pyarrow.compute as pc
import mercantile
from shapely import wkt
from shapely.geometry import box, shape, mapping, MultiPolygon, Polygon
from shapely.ops import unary_union

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
logger = logging.getLogger("generate_mask")

# ─────────────────────────────────────────────────────────────────────────────
# CONFIGURATION & THRESHOLDS
# ─────────────────────────────────────────────────────────────────────────────
# "Good internet" criteria (as required)
MIN_DOWNLOAD_KBPS: int = 5000   # 5 Mbps
MAX_LATENCY_MS: int = 100       # 100 ms

# Catanduanes Bounding Box (EPSG:4326)
BBOX_WEST: float = 123.95
BBOX_SOUTH: float = 13.50
BBOX_EAST: float = 124.45
BBOX_NORTH: float = 14.15

# Geometry tuning
TILE_BUFFER_DEG: float = 0.003       # ~330m buffer to close small inter-tile gaps
SIMPLIFY_TOLERANCE: float = 0.0005   # Simplification tolerance for smooth mobile rendering

# Ookla Open Data S3 Configuration
S3_BUCKET = "ookla-open-data"
S3_BASE_PATH = "ookla-open-data/parquet/performance/type=mobile"
DEFAULT_YEAR = "2026"
DEFAULT_QUARTER = "2"

# Output paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_PATHS = [
    os.path.join(SCRIPT_DIR, "web", "gray_mask.geojson"),
    os.path.join(SCRIPT_DIR, "assets", "data", "gray_mask.geojson"),
]


def find_latest_parquet_file(fs: s3fs.S3FileSystem) -> str:
    """Finds the most recent quarterly parquet file on Ookla's public S3 bucket."""
    logger.info("Checking available years and quarters in S3...")
    try:
        years = sorted([p.split("=")[-1] for p in fs.ls(S3_BASE_PATH) if "year=" in p])
        if not years:
            raise RuntimeError("No year directories found.")
        latest_year = years[-1]
        year_path = f"{S3_BASE_PATH}/year={latest_year}"
        quarters = sorted([p.split("=")[-1] for p in fs.ls(year_path) if "quarter=" in p])
        if not quarters:
            raise RuntimeError(f"No quarters found for year {latest_year}")
        latest_quarter = quarters[-1]
        quarter_path = f"{year_path}/quarter={latest_quarter}"
        files = [f for f in fs.ls(quarter_path) if f.endswith(".parquet")]
        if files:
            logger.info("Found latest Ookla dataset: %s", files[0])
            return files[0]
    except Exception as e:
        logger.warning("Auto-discovery failed (%s). Falling back to %s Q%s.", e, DEFAULT_YEAR, DEFAULT_QUARTER)

    return f"{S3_BASE_PATH}/year={DEFAULT_YEAR}/quarter={DEFAULT_QUARTER}/2026-04-01_performance_mobile_tiles.parquet"


def get_quadkey_prefixes(zoom: int = 10) -> List[str]:
    """Generates quadkey prefixes covering the Catanduanes bounding box."""
    tiles = list(mercantile.tiles(BBOX_WEST, BBOX_SOUTH, BBOX_EAST, BBOX_NORTH, zooms=[16]))
    prefixes = sorted(set(mercantile.quadkey(t)[:zoom] for t in tiles))
    logger.info("Computed %d zoom-%d quadkey prefixes for bbox [%s, %s, %s, %s]",
                len(prefixes), zoom, BBOX_WEST, BBOX_SOUTH, BBOX_EAST, BBOX_NORTH)
    return prefixes


def load_ookla_tiles(s3_path: str, fs: s3fs.S3FileSystem, prefixes: List[str]) -> Tuple[List[Polygon], int, int]:
    """Reads and filters Ookla mobile performance tiles from S3."""
    logger.info("Opening Parquet dataset at s3://%s...", s3_path)
    dataset = ds.dataset(s3_path, filesystem=fs, format="parquet")

    # Build pyarrow expression for prefix matching
    expr = None
    for p in prefixes:
        sub = pc.starts_with(pc.field("quadkey"), p)
        expr = sub if expr is None else (expr | sub)

    logger.info("Executing remote query with column projections...")
    table = dataset.to_table(
        filter=expr,
        columns=["quadkey", "tile", "avg_d_kbps", "avg_u_kbps", "avg_lat_ms", "tests"]
    )
    total_matched = table.num_rows
    logger.info("Retrieved %d raw Ookla tiles within Catanduanes prefix zones", total_matched)

    bbox_poly = box(BBOX_WEST, BBOX_SOUTH, BBOX_EAST, BBOX_NORTH)
    good_polys: List[Polygon] = []

    rows = table.to_pylist()
    for row in rows:
        d_kbps = row.get("avg_d_kbps") or 0
        lat_ms = row.get("avg_lat_ms") or 999
        wkt_str = row.get("tile")
        if not wkt_str:
            continue

        # Check "Good Internet" criteria:
        # avg_d_kbps >= 5000 AND avg_lat_ms <= 100
        if d_kbps >= MIN_DOWNLOAD_KBPS and lat_ms <= MAX_LATENCY_MS:
            try:
                poly = wkt.loads(wkt_str)
                clipped = poly.intersection(bbox_poly)
                if not clipped.is_empty and (isinstance(clipped, (Polygon, MultiPolygon))):
                    good_polys.append(clipped)
            except Exception as ex:
                logger.debug("Failed parsing WKT: %s", ex)

    logger.info("Tiles meeting criteria (d_kbps >= %d, lat_ms <= %d): %d / %d",
                MIN_DOWNLOAD_KBPS, MAX_LATENCY_MS, len(good_polys), total_matched)
    return good_polys, len(good_polys), total_matched


def fetch_catanduanes_boundary() -> Polygon:
    """Fetches Catanduanes land boundary polygon from OpenStreetMap Nominatim / Overpass."""
    logger.info("Fetching Catanduanes official administrative boundary from OpenStreetMap...")
    nominatim_url = (
        "https://nominatim.openstreetmap.org/search?"
        "q=Catanduanes,Philippines&format=geojson&polygon_geojson=1"
    )
    headers = {"User-Agent": "PawTrace-NoSignalMask-Generator/1.0 (contact: support@pawtrace.app)"}

    try:
        resp = requests.get(nominatim_url, headers=headers, timeout=20)
        resp.raise_for_status()
        geojson_data = resp.json()
        features = geojson_data.get("features", [])
        if features:
            geom = shape(features[0]["geometry"])
            if geom.is_valid and not geom.is_empty:
                logger.info("Successfully fetched Catanduanes boundary polygon: %s", geom.geom_type)
                return geom
    except Exception as e:
        logger.warning("Nominatim fetch error: %s. Trying Overpass API...", e)

    # Overpass fallback
    overpass_url = "https://overpass-api.de/api/interpreter"
    overpass_query = """
    [out:json][timeout:30];
    relation["ISO3166-2"="PH-CAT"];
    out geom;
    """
    resp = requests.post(overpass_url, data={"data": overpass_query}, timeout=30)
    resp.raise_for_status()
    # If overpass succeeds or if both fail, handle or clip with bbox
    raise RuntimeError("Could not retrieve Catanduanes land boundary.")


def main():
    logger.info("=== Starting Catanduanes 'No Signal' Mask Generation ===")
    fs = s3fs.S3FileSystem(anon=True)
    parquet_path = find_latest_parquet_file(fs)
    prefixes = get_quadkey_prefixes(zoom=10)

    # 1 & 2. Load & filter good internet tiles
    good_polys, good_count, total_count = load_ookla_tiles(parquet_path, fs, prefixes)
    if not good_polys:
        raise RuntimeError("No good signal tiles found in Ookla dataset. Check thresholds or bbox.")

    # 3. Unary union & buffer ~0.003 degrees to close gaps
    logger.info("Merging and buffering %d good signal tiles by ~%.4f degrees...", len(good_polys), TILE_BUFFER_DEG)
    good_coverage = unary_union(good_polys).buffer(TILE_BUFFER_DEG)

    # 4. Fetch Catanduanes land boundary
    catanduanes_land = fetch_catanduanes_boundary()

    # Clip land boundary to the Catanduanes bbox
    bbox_poly = box(BBOX_WEST, BBOX_SOUTH, BBOX_EAST, BBOX_NORTH)
    catanduanes_land = catanduanes_land.intersection(bbox_poly)

    # Gray mask = Land minus Good Internet Coverage
    logger.info("Computing Gray Mask (Catanduanes Land MINUS Good Internet Coverage)...")
    gray_mask_geom = catanduanes_land.difference(good_coverage)

    # 5. Simplify geometry for fast mobile & web performance
    logger.info("Simplifying geometry (tolerance=%.5f)...", SIMPLIFY_TOLERANCE)
    simplified_mask = gray_mask_geom.simplify(SIMPLIFY_TOLERANCE, preserve_topology=True)

    # 6. Export GeoJSON
    geojson_out = {
        "type": "FeatureCollection",
        "name": "Catanduanes_No_Signal_Overlay",
        "crs": {
            "type": "name",
            "properties": {"name": "urn:ogc:def:crs:OGC:1.3:CRS84"}
        },
        "metadata": {
            "region": "Catanduanes, Philippines",
            "source": "Speedtest by Ookla Open Data (CC BY-NC-SA 4.0)",
            "license": "https://creativecommons.org/licenses/by-nc-sa/4.0/",
            "min_download_kbps": MIN_DOWNLOAD_KBPS,
            "max_latency_ms": MAX_LATENCY_MS,
            "good_tiles_count": good_count,
            "total_tiles_scanned": total_count,
            "note": "Gray areas indicate weak or unconfirmed mobile internet connectivity. Areas with no recorded tests appear gray."
        },
        "features": [
            {
                "type": "Feature",
                "properties": {
                    "zone": "no_signal_or_unconfirmed",
                    "label": "Low or No Signal Area",
                    "description": "Mobile internet coverage is weak, unverified, or unavailable.",
                    "fill": "#777777",
                    "fill-opacity": 0.55,
                    "stroke": False
                },
                "geometry": mapping(simplified_mask)
            }
        ]
    }

    for path in OUTPUT_PATHS:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(geojson_out, f, indent=2)
        size_kb = os.path.getsize(path) / 1024
        logger.info("Exported GeoJSON -> %s (%.1f KB)", path, size_kb)

    logger.info("=== Mask Generation Complete! ===")


if __name__ == "__main__":
    main()
