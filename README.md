# pawtrace_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

---

## Catanduanes "No Signal" Coverage Mask

PawTrace includes a mobile network signal mask overlay for Catanduanes, Philippines. This layer grays out areas with weak, unverified, or zero mobile connectivity so pet owners and administrators know where live collar tracking is likely to lose cellular internet connection.

### Data Source & Attribution
* **Data Source:** [Speedtest by Ookla Open Data](https://github.com/teamookla/ookla-open-data)
* **License:** Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International ([CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/))
* **Attribution:** Speedtest by Ookla (CC BY-NC-SA 4.0)
* **Important Note:** Gray areas represent zones with low speeds, high latency, or where **no speed tests were recorded**. In rural, forest, and mountain zones, gray unconfirmed areas correlate closely with dead zones.

---

### Running the Generator Script (`generate_mask.py`)

1. **Install Python dependencies:**
   ```bash
   pip install shapely mercantile pyarrow s3fs requests
   ```

2. **Execute the generator:**
   ```bash
   python generate_mask.py
   ```
   The script automatically:
   * Connects anonymously to Ookla's public AWS S3 bucket (`s3://ookla-open-data/`).
   * Queries Zoom-16 mobile performance tiles for the Catanduanes bounding box (`W=123.95, S=13.50, E=124.45, N=14.15`).
   * Filters tiles meeting the "Good Internet" criteria.
   * Merges and buffers good signal areas.
   * Fetches the official Catanduanes land boundary from OpenStreetMap.
   * Subtracts coverage from the land boundary (avoiding graying out the ocean).
   * Simplifies geometry for fast mobile & web rendering.
   * Exports `gray_mask.geojson` to both `web/gray_mask.geojson` and `assets/data/gray_mask.geojson`.

---

### Refreshing for Newer Quarters

`generate_mask.py` automatically scans S3 for the newest available year and quarter directory. To pin a specific quarter manually, edit the constants in `generate_mask.py`:

```python
DEFAULT_YEAR = "2026"
DEFAULT_QUARTER = "2"
```

---

### Tuning Coverage Thresholds

At the top of `generate_mask.py`, adjust the signal criteria:

```python
# Minimum download speed (in kbps) required to count as "good internet" (default: 5 Mbps)
MIN_DOWNLOAD_KBPS = 5000

# Maximum latency (in ms) allowed (default: 100 ms)
MAX_LATENCY_MS = 100

# Buffer around confirmed tiles (degrees) to close inter-cell gaps (default: ~330m)
TILE_BUFFER_DEG = 0.003

# Geometry simplification tolerance for smooth mobile 60fps rendering
SIMPLIFY_TOLERANCE = 0.0005
```

---

### Frontend Map Integrations

* **Web Map (Leaflet + Turf.js):** Located at [`web/tracking_map.html`](file:///c:/Users/63938/Downloads/stitch_pawtrace_mobile_ui_app/pawtrace_app/web/tracking_map.html). Uses dedicated Leaflet pane `noSignalPane` (`zIndex: 350`, `pointer-events: none`) so markers remain clickable. Automatically triggers a non-intrusive warning banner when a device crosses into low-signal zones using `turf.booleanPointInPolygon`.
* **Flutter Mobile App:** Integrated into [`AdminPetTrackingMapScreen`](file:///c:/Users/63938/Downloads/stitch_pawtrace_mobile_ui_app/pawtrace_app/lib/screens/admin/pets/admin_pet_tracking_map_screen.dart) using [`NoSignalMaskService`](file:///c:/Users/63938/Downloads/stitch_pawtrace_mobile_ui_app/pawtrace_app/lib/services/geo/no_signal_mask_service.dart) via `flutter_map` `PolygonLayer`.

