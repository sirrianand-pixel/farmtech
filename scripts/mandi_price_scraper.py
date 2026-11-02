"""
FarmTech Mandi Price Scraper

Scrapes live, real-time mandi prices for Andhra Pradesh (including Kurnool)
and Telangana from commodityonline.com and writes them directly to Firestore.

Features:
- Fast parallel multithreaded scraping (~5-8 seconds total).
- Parses full live commodity market tables with exact arrival dates & varieties.
- Auto-locates Firebase Service Account credentials.
- Pushes instant price change alerts via Firebase Cloud Messaging.
- Supports --watch mode for automated background updates.

Usage:
    python scripts/mandi_price_scraper.py
    python scripts/mandi_price_scraper.py --watch 30
"""

from __future__ import annotations

import argparse
import glob
import io
import os
import re
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime
from typing import Any, Iterable

import requests
from bs4 import BeautifulSoup
import firebase_admin
from firebase_admin import credentials, firestore, messaging

# Ensure unicode characters (like currency symbols) print safely on Windows
if sys.stdout.encoding != "utf-8":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    except Exception:
        pass

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    ),
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-IN,en;q=0.9",
    "Referer": "https://www.commodityonline.com/",
}

MAJOR_CROPS = [
    ("groundnut", "Groundnut"),
    ("onion", "Onion"),
    ("cotton", "Cotton"),
    ("maize", "Maize"),
    ("tomato", "Tomato"),
    ("dry-chillies", "Dry Chillies"),
    ("sunflower-seed", "Sunflower Seed"),
    ("castor-seed", "Castor Seed"),
    ("paddy-dhan-common", "Paddy"),
    ("bengal-gram-gram-whole", "Bengal Gram"),
    ("black-gram-urd-beans-whole", "Black Gram"),
    ("arhar-tur-red-gram-whole", "Red Gram"),
    ("bajra-pearl-millet-cumbu", "Bajra"),
    ("jowar-sorghum", "Jowar"),
    ("moong-green-gram-whole", "Moong"),
    ("turmeric", "Turmeric"),
    ("coriander-seed", "Coriander"),
    ("chana-dal", "Chana"),
]

AP_DISTRICTS = [
    ("kurnool", "Kurnool"),
    ("guntur", "Guntur"),
    ("anantapur", "Anantapur"),
    ("chittoor", "Chittoor"),
    ("kadapa", "Kadapa"),
    ("krishna", "Krishna"),
    ("prakasam", "Prakasam"),
    ("nellore", "Nellore"),
    ("visakhapatnam", "Visakhapatnam"),
]

TS_DISTRICTS = [
    ("hyderabad", "Hyderabad"),
    ("warangal", "Warangal"),
    ("nizamabad", "Nizamabad"),
    ("karimnagar", "Karimnagar"),
    ("khammam", "Khammam"),
]


def find_service_account_key() -> str | None:
    """Find the Firebase service account JSON key in common local locations."""
    custom_env = os.getenv("FARMTECH_SERVICE_ACCOUNT_PATH")
    if custom_env and os.path.exists(custom_env):
        return custom_env

    here = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(here, "serviceAccountKey.json"),
        os.path.join(here, "serviceAccount.json"),
        os.path.join(here, "..", "serviceAccountKey.json"),
    ]

    # Search inside scripts folder for any adminsdk json
    candidates.extend(glob.glob(os.path.join(here, "*adminsdk*.json")))
    candidates.extend(glob.glob(os.path.join(here, "*firebase*.json")))

    # Search in user Downloads folder
    user_home = os.path.expanduser("~")
    downloads = os.path.join(user_home, "Downloads")
    if os.path.exists(downloads):
        candidates.extend(glob.glob(os.path.join(downloads, "*farmtech*adminsdk*.json")))
        candidates.extend(glob.glob(os.path.join(downloads, "*firebase*adminsdk*.json")))

    for path in candidates:
        if os.path.exists(path):
            return os.path.abspath(path)

    return None


def topic_for_crop(crop: str) -> str:
    normalized = re.sub(r"[^a-z0-9]+", "_", crop.lower())
    compact = re.sub(r"_+", "_", normalized).strip("_")
    return f"crop_{compact}"


def record_key(record: dict) -> str:
    return (
        f"{record.get('commodity', '').strip().lower()}__"
        f"{record.get('district', '').strip().lower()}__"
        f"{record.get('market', '').strip().lower()}"
    )


def price_value(record: dict | None) -> float:
    if not record:
        return 0.0
    try:
        return float(record.get("modal_price", 0) or 0)
    except (TypeError, ValueError):
        return 0.0


def parse_date(date_str: str) -> datetime:
    try:
        return datetime.strptime(date_str.strip(), "%d/%m/%Y")
    except Exception:
        try:
            return datetime.strptime(date_str.strip(), "%Y-%m-%d")
        except Exception:
            return datetime.min


def send_price_alert(change: dict) -> None:
    direction = "Increased" if change["new_price"] > change["old_price"] else "Decreased"
    topic = topic_for_crop(change["commodity"])
    body = (
        f"₹{int(change['old_price'])} -> ₹{int(change['new_price'])}/qtl | "
        f"{change['market']} ({change['district']})"
    )

    message = messaging.Message(
        topic=topic,
        notification=messaging.Notification(
            title=f"{change['commodity']} Price {direction}",
            body=body,
        ),
        data={
            "crop": str(change["commodity"]),
            "market": str(change["market"]),
            "district": str(change["district"]),
            "oldPrice": str(int(change["old_price"])),
            "newPrice": str(int(change["new_price"])),
            "type": "mandi_price_change",
        },
    )
    messaging.send(message)


def scrape_table_page(
    session: requests.Session,
    url: str,
    default_state: str,
    state_code: str,
    default_crop_name: str = "",
    default_district: str = "",
) -> list[dict]:
    records: list[dict] = []
    try:
        response = session.get(url, headers=HEADERS, timeout=12)
        if response.status_code != 200:
            return []

        soup = BeautifulSoup(response.text, "lxml")

        # 1. Parse structured tables
        for table in soup.find_all("table"):
            rows = table.find_all("tr")
            for tr in rows[1:]:
                cells = [td.get_text(" ", strip=True) for td in tr.find_all(["td", "th"])]
                if len(cells) >= 9:
                    comm = cells[0] or default_crop_name
                    arrival = cells[1]
                    variety = cells[2] or "Local"
                    state = cells[3] or default_state
                    district = cells[4] or default_district or "Local"
                    market = cells[5] or district
                    min_p = float(re.sub(r"[^\d.]", "", cells[6]) or 0)
                    max_p = float(re.sub(r"[^\d.]", "", cells[7]) or 0)
                    avg_p = float(re.sub(r"[^\d.]", "", cells[8]) or 0)

                    if avg_p > 100:
                        records.append({
                            "commodity": comm,
                            "variety": variety,
                            "state": state,
                            "state_code": state_code,
                            "district": district,
                            "market": market,
                            "min_price": min_p,
                            "max_price": max_p,
                            "modal_price": avg_p,
                            "arrival_date": arrival,
                        })

        # 2. If table empty, check summary highlight box
        if not records and default_crop_name and default_district:
            text = soup.get_text(" ", strip=True)
            match = re.search(
                r"costliest[^\d₹]*(?:₹|Rs\.?)?\s*([\d,]+)\s*/?\s*Quintal",
                text,
                re.IGNORECASE,
            )
            modal = float(match.group(1).replace(",", "")) if match else 0.0

            match_low = re.search(
                r"lowest[^\d₹]*(?:₹|Rs\.?)?\s*([\d,]+)\s*/?\s*Quintal",
                text,
                re.IGNORECASE,
            )
            min_p = float(match_low.group(1).replace(",", "")) if match_low else modal

            if modal > 100:
                today = datetime.now().strftime("%d/%m/%Y")
                records.append({
                    "commodity": default_crop_name,
                    "variety": "Local",
                    "state": default_state,
                    "state_code": state_code,
                    "district": default_district,
                    "market": default_district,
                    "min_price": min_p,
                    "max_price": modal,
                    "modal_price": modal,
                    "arrival_date": today,
                })

    except Exception:
        pass

    return records


def scrape_all_mandi_data() -> tuple[list[dict], list[dict]]:
    """Scrapes AP and TS mandi prices in parallel using a worker pool."""
    session = requests.Session()
    session.headers.update(HEADERS)

    jobs = []

    # 1. State-level crop pages (returns all active mandis across the whole state)
    for crop_slug, crop_name in MAJOR_CROPS:
        jobs.append((
            f"https://www.commodityonline.com/mandiprices/{crop_slug}/andhra-pradesh",
            "Andhra Pradesh",
            "AP",
            crop_name,
            "",
        ))
        jobs.append((
            f"https://www.commodityonline.com/mandiprices/{crop_slug}/telangana",
            "Telangana",
            "TS",
            crop_name,
            "",
        ))

    # 2. Kurnool district dedicated pages
    for crop_slug, crop_name in MAJOR_CROPS:
        jobs.append((
            f"https://www.commodityonline.com/mandiprices/{crop_slug}/andhra-pradesh/kurnool",
            "Andhra Pradesh",
            "AP",
            crop_name,
            "Kurnool",
        ))

    # 3. Key AP and TS district queries
    for dist_slug, dist_name in AP_DISTRICTS:
        for crop_slug, crop_name in MAJOR_CROPS[:6]:
            jobs.append((
                f"https://www.commodityonline.com/mandiprices/{crop_slug}/andhra-pradesh/{dist_slug}",
                "Andhra Pradesh",
                "AP",
                crop_name,
                dist_name,
            ))

    for dist_slug, dist_name in TS_DISTRICTS:
        for crop_slug, crop_name in MAJOR_CROPS[:6]:
            jobs.append((
                f"https://www.commodityonline.com/mandiprices/{crop_slug}/telangana/{dist_slug}",
                "Telangana",
                "TS",
                crop_name,
                dist_name,
            ))

    all_scraped: list[dict] = []
    with ThreadPoolExecutor(max_workers=12) as executor:
        futures = [
            executor.submit(scrape_table_page, session, url, state, sc, crop, dist)
            for url, state, sc, crop, dist in jobs
        ]
        for future in as_completed(futures):
            try:
                res = future.result()
                if res:
                    all_scraped.extend(res)
            except Exception:
                pass

    # Deduplicate by (commodity, district, market) keeping the most recent date
    dedup_map: dict[str, dict] = {}
    for record in all_scraped:
        k = record_key(record)
        existing = dedup_map.get(k)
        if not existing:
            dedup_map[k] = record
        else:
            if parse_date(record["arrival_date"]) > parse_date(existing["arrival_date"]):
                dedup_map[k] = record

    ap_records = [
        r for r in dedup_map.values()
        if r.get("state_code") == "AP" or "andhra" in r.get("state", "").lower()
    ]
    ts_records = [
        r for r in dedup_map.values()
        if r.get("state_code") == "TS" or "telangana" in r.get("state", "").lower()
    ]

    return ap_records, ts_records


def topic_for_crop(crop_name: str) -> str:
    """Generates the standardized FCM topic name for a crop (e.g. crop_groundnut)."""
    normalized = re.sub(r"[^a-z0-9]+", "_", crop_name.lower())
    compact = re.sub(r"_+", "_", normalized).strip("_")
    return f"crop_{compact}"


def send_price_alert(change: dict) -> None:
    """Sends an FCM push notification ONLY to farmers who followed this specific crop."""
    comm = change.get("commodity", "").strip()
    old_p = int(round(change.get("old_price", 0)))
    new_p = int(round(change.get("new_price", 0)))
    market = change.get("market", "").strip()
    district = change.get("district", "").strip()

    if old_p == new_p or new_p <= 0 or not comm:
        return

    diff = new_p - old_p
    direction = f"📈 Increased (+₹{diff})" if diff > 0 else f"📉 Decreased (-₹{abs(diff)})"
    topic = topic_for_crop(comm)

    msg = messaging.Message(
        notification=messaging.Notification(
            title=f"⭐ {comm} Price {direction}",
            body=f"₹{old_p:,} → ₹{new_p:,}/qtl at {market} ({district})",
        ),
        data={
            "commodity": comm,
            "old_price": str(old_p),
            "new_price": str(new_p),
            "market": market,
            "district": district,
            "topic": topic,
            "type": "price_alert",
        },
        topic=topic,
    )

    messaging.send(msg)


def save_to_firestore(
    db: firestore.Client,
    doc_id: str,
    state_code: str,
    state_name: str,
    records: list[dict],
) -> int:
    valid = [r for r in records if r["modal_price"] > 0]
    if not valid:
        print(f"  ⚠️ Warning: No valid records to save for {state_code}", flush=True)
        return 0

    valid.sort(key=lambda r: (r["commodity"], r["district"], r["market"]))

    # Check for price changes
    doc_ref = db.collection("mandi_prices").document(doc_id)
    previous = doc_ref.get()
    previous_records = previous.to_dict().get("records", []) if previous.exists else []
    previous_map = {record_key(r): r for r in previous_records}

    changes = []
    for r in valid:
        old_r = previous_map.get(record_key(r))
        old_p = price_value(old_r)
        new_p = price_value(r)
        if old_p > 0 and new_p > 0 and old_p != new_p:
            changes.append({
                "commodity": r["commodity"],
                "district": r["district"],
                "market": r["market"],
                "old_price": old_p,
                "new_price": new_p,
            })

    latest_date = max((r.get("arrival_date", "") for r in valid), default="")
    if not latest_date:
        latest_date = datetime.now().strftime("%d/%m/%Y")

    doc_ref.set({
        "records": valid,
        "state_code": state_code,
        "state": state_name,
        "arrival_date": latest_date,
        "count": len(valid),
        "updated_at": datetime.now().isoformat(),
        "source": "fast-multithreaded-scraper",
    })

    print(f"  ✅ Saved {len(valid)} {state_code} records to Firestore (Latest Date: {latest_date})", flush=True)
    if changes:
        print(f"  📢 Detected {len(changes)} price changes in {state_code}", flush=True)

    for change in changes:
        try:
            send_price_alert(change)
            print(
                f"    📲 Push Alert: {change['commodity']} "
                f"₹{int(change['old_price'])} -> ₹{int(change['new_price'])} ({change['market']})",
                flush=True,
            )
        except Exception as err:
            pass

    return len(valid)


def init_firestore() -> firestore.Client:
    key_path = find_service_account_key()
    if not key_path:
        raise FileNotFoundError(
            "Service account JSON key not found. Place serviceAccountKey.json in the scripts/ folder."
        )

    print(f"  🔑 Using service account key: {os.path.basename(key_path)}", flush=True)
    app = firebase_admin.get_app() if firebase_admin._apps else None
    if app is None:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
    return firestore.client()


def run_scraper_once() -> int:
    print("=" * 65, flush=True)
    print(f"  🌱 FarmTech Mandi Scraper — {datetime.now().strftime('%d/%m/%Y %H:%M:%S')}", flush=True)
    print("=" * 65, flush=True)

    try:
        db = init_firestore()
        print("  ⚡ Firestore connected successfully", flush=True)
    except Exception as e:
        print(f"  ❌ Firestore initialization error: {e}", flush=True)
        return 0

    print("\n🔍 Fetching live market prices in parallel...", flush=True)
    start_time = time.time()
    ap_records, ts_records = scrape_all_mandi_data()
    duration = time.time() - start_time
    total_scraped = len(ap_records) + len(ts_records)
    print(f"  ⏱️  Scraped {total_scraped} total unique market records in {duration:.1f}s", flush=True)

    total_saved = 0
    print("\n💾 Updating Cloud Firestore...", flush=True)
    total_saved += save_to_firestore(db, "today_AP", "AP", "Andhra Pradesh", ap_records)
    total_saved += save_to_firestore(db, "today_TS", "TS", "Telangana", ts_records)

    # Also sync into MySQL Workbench (farmtech database)
    print("\n💾 Updating Local MySQL (farmtech database)...", flush=True)
    try:
        from mysql_sync import save_mandi_records_to_mysql
        mysql_count = save_mandi_records_to_mysql(ap_records + ts_records)
        print(f"  ✅ Saved {mysql_count} records to MySQL `farmtech.mandi_prices` and history.", flush=True)
    except Exception as mysql_err:
        print(f"  ⚠️ MySQL Sync Note: {mysql_err}", flush=True)

    # Highlight Kurnool prices
    kurnool = [r for r in ap_records if "kurnool" in r.get("district", "").lower() or "kurnool" in r.get("market", "").lower()]
    if kurnool:
        print("\n" + "-" * 50, flush=True)
        print("  📍 KURNOOL LIVE PRICES TODAY (Min / Modal / Max):", flush=True)
        print("-" * 50, flush=True)
        for r in sorted(kurnool, key=lambda x: x["commodity"])[:12]:
            print(
                f"     {r['commodity']:20} {r['market']:12} "
                f"Min: ₹{r['min_price']:>6.0f} | Mid: ₹{r['modal_price']:>6.0f} | Max: ₹{r['max_price']:>6.0f} ({r['arrival_date']})",
                flush=True,
            )

    print("\n" + "=" * 65, flush=True)
    if total_saved > 0:
        print(f"  🎉 SUCCESS! {total_saved} records published to Firestore & MySQL.", flush=True)
        print("  📱 Open FarmTech on your phone to see instant fresh mandi prices!", flush=True)
    else:
        print("  ⚠️ No records were published. Check internet connection.", flush=True)
    print("=" * 65 + "\n", flush=True)

    return total_saved


def main() -> None:
    parser = argparse.ArgumentParser(description="FarmTech Mandi Scraper")
    parser.add_argument(
        "--watch",
        type=int,
        metavar="MINUTES",
        help="Run continuously every N minutes (e.g. --watch 30)",
    )
    args = parser.parse_args()

    if args.watch and args.watch > 0:
        print(f"🕒 Watch mode enabled: Running scraper every {args.watch} minutes.")
        while True:
            try:
                run_scraper_once()
            except Exception as e:
                print(f"❌ Error during scrape iteration: {e}", flush=True)
            print(f"⏳ Sleeping for {args.watch} minutes... (Press Ctrl+C to stop)\n", flush=True)
            time.sleep(args.watch * 60)
    else:
        run_scraper_once()


if __name__ == "__main__":
    main()
