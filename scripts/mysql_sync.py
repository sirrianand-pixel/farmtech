"""
FarmTech MySQL Database Manager & Synchronizer

Connects to MySQL Workbench / Server (user: root, password: anand)
and provides permanent local storage & backup for:
- Live Mandi Prices (with Min, Mid/Modal, Max rates & arrival dates)
- Historical Price Trends
- Farmer Users & Profiles
- Open Market / Marketplace Listings
- Followed Crop Watchlists
- Disease Diagnostic Scans

Usage:
    python scripts/mysql_sync.py --init
    python scripts/mysql_sync.py --sync-firestore
    python scripts/mysql_sync.py --status
"""

from __future__ import annotations

import argparse
import glob
import io
import os
import re
import sys
from datetime import datetime
from typing import Any

import pymysql
import pymysql.cursors

# Unicode safe console on Windows
if sys.stdout.encoding != "utf-8":
    try:
        sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    except Exception:
        pass

MYSQL_HOST = os.getenv("FARMTECH_MYSQL_HOST", "localhost")
MYSQL_PORT = int(os.getenv("FARMTECH_MYSQL_PORT", "3306"))
MYSQL_USER = os.getenv("FARMTECH_MYSQL_USER", "root")
MYSQL_PASSWORD = os.getenv("FARMTECH_MYSQL_PASSWORD", "anand")
MYSQL_DB = os.getenv("FARMTECH_MYSQL_DB", "farmtech")


def get_mysql_connection(use_database: bool = True) -> pymysql.Connection:
    """Connect to MySQL server."""
    return pymysql.connect(
        host=MYSQL_HOST,
        port=MYSQL_PORT,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        database=MYSQL_DB if use_database else None,
        charset="utf8mb4",
        cursorclass=pymysql.cursors.DictCursor,
        autocommit=True,
    )


def init_database() -> None:
    """Creates the farmtech database and all required relational tables."""
    print("Connecting to MySQL server...")
    conn = get_mysql_connection(use_database=False)
    with conn.cursor() as cur:
        cur.execute(f"CREATE DATABASE IF NOT EXISTS {MYSQL_DB} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
        cur.execute(f"USE {MYSQL_DB};")

        # 1. Current Live Mandi Prices
        cur.execute("""
        CREATE TABLE IF NOT EXISTS mandi_prices (
            id INT AUTO_INCREMENT PRIMARY KEY,
            commodity VARCHAR(100) NOT NULL,
            variety VARCHAR(100) DEFAULT 'Local',
            state VARCHAR(100) NOT NULL,
            state_code VARCHAR(10) NOT NULL,
            district VARCHAR(100) NOT NULL,
            market VARCHAR(100) NOT NULL,
            min_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
            max_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
            modal_price DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
            arrival_date VARCHAR(50) NOT NULL,
            source VARCHAR(100) DEFAULT 'commodityonline',
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY uq_crop_dist_mkt (commodity, district, market)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """)

        # 2. Historical Price Log (Daily / Hourly price tracking)
        cur.execute("""
        CREATE TABLE IF NOT EXISTS mandi_price_history (
            id INT AUTO_INCREMENT PRIMARY KEY,
            commodity VARCHAR(100) NOT NULL,
            variety VARCHAR(100) DEFAULT 'Local',
            state VARCHAR(100) NOT NULL,
            state_code VARCHAR(10) NOT NULL,
            district VARCHAR(100) NOT NULL,
            market VARCHAR(100) NOT NULL,
            min_price DECIMAL(10, 2) NOT NULL,
            max_price DECIMAL(10, 2) NOT NULL,
            modal_price DECIMAL(10, 2) NOT NULL,
            arrival_date VARCHAR(50) NOT NULL,
            recorded_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_comm_date (commodity, arrival_date)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """)

        # 3. Farmer Users
        cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            uid VARCHAR(128) UNIQUE NOT NULL,
            name VARCHAR(150),
            phone VARCHAR(20),
            email VARCHAR(150),
            state VARCHAR(100) DEFAULT 'Andhra Pradesh',
            district VARCHAR(100) DEFAULT 'Kurnool',
            village VARCHAR(100),
            land_acres DECIMAL(6, 2) DEFAULT 0.00,
            role VARCHAR(50) DEFAULT 'Farmer',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """)

        # 4. Open Market / Marketplace Listings
        cur.execute("""
        CREATE TABLE IF NOT EXISTS marketplace_listings (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT,
            title VARCHAR(200) NOT NULL,
            category VARCHAR(50) NOT NULL,
            price VARCHAR(50) NOT NULL,
            price_num DECIMAL(12, 2) DEFAULT 0.00,
            seller VARCHAR(150) NOT NULL,
            phone VARCHAR(20) NOT NULL,
            location VARCHAR(150) NOT NULL,
            description TEXT,
            status ENUM('active', 'sold', 'expired') DEFAULT 'active',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """)

        # 5. Followed Crops Watchlist
        cur.execute("""
        CREATE TABLE IF NOT EXISTS followed_crops (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT,
            crop_name VARCHAR(100) NOT NULL,
            target_min_price DECIMAL(10, 2) DEFAULT 0.00,
            target_max_price DECIMAL(10, 2) DEFAULT 0.00,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """)

        # 6. Disease Diagnostic Scans
        cur.execute("""
        CREATE TABLE IF NOT EXISTS disease_scans (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT,
            crop VARCHAR(100) NOT NULL,
            disease VARCHAR(200) NOT NULL,
            severity VARCHAR(50) DEFAULT 'Moderate',
            confidence DECIMAL(5, 2) DEFAULT 0.00,
            treatment TEXT,
            image_url VARCHAR(500),
            scanned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
        """)

    conn.close()
    print(f"  [OK] Database '{MYSQL_DB}' and all tables initialized successfully in MySQL Workbench.")


def save_mandi_records_to_mysql(records: list[dict[str, Any]]) -> int:
    """Inserts/Updates mandi price records in MySQL table `mandi_prices` and history."""
    if not records:
        return 0

    try:
        conn = get_mysql_connection()
    except Exception as err:
        print(f"  [!] MySQL connection warning: {err}")
        return 0

    inserted_count = 0
    with conn.cursor() as cur:
        for r in records:
            comm = r.get("commodity", "").strip()
            variety = r.get("variety", "Local").strip() or "Local"
            state = r.get("state", "Andhra Pradesh").strip()
            state_code = r.get("state_code", "AP").strip()
            district = r.get("district", "Kurnool").strip()
            market = r.get("market", district).strip()
            min_p = float(r.get("min_price", 0.0) or 0.0)
            max_p = float(r.get("max_price", 0.0) or 0.0)
            modal_p = float(r.get("modal_price", 0.0) or 0.0)
            arrival = r.get("arrival_date", "").strip() or datetime.now().strftime("%d/%m/%Y")
            source = r.get("source", "commodityonline")

            if modal_p <= 0:
                continue

            if min_p <= 0:
                min_p = modal_p
            if max_p <= 0:
                max_p = modal_p

            # Upsert into mandi_prices
            sql_upsert = """
            INSERT INTO mandi_prices 
                (commodity, variety, state, state_code, district, market, min_price, max_price, modal_price, arrival_date, source)
            VALUES 
                (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
                variety = VALUES(variety),
                state = VALUES(state),
                state_code = VALUES(state_code),
                min_price = VALUES(min_price),
                max_price = VALUES(max_price),
                modal_price = VALUES(modal_price),
                arrival_date = VALUES(arrival_date),
                source = VALUES(source),
                updated_at = CURRENT_TIMESTAMP;
            """
            cur.execute(
                sql_upsert,
                (comm, variety, state, state_code, district, market, min_p, max_p, modal_p, arrival, source),
            )

            # Insert into history log
            sql_hist = """
            INSERT INTO mandi_price_history
                (commodity, variety, state, state_code, district, market, min_price, max_price, modal_price, arrival_date)
            VALUES
                (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s);
            """
            cur.execute(
                sql_hist,
                (comm, variety, state, state_code, district, market, min_p, max_p, modal_p, arrival),
            )
            inserted_count += 1

    conn.close()
    return inserted_count


def sync_firestore_to_mysql() -> int:
    """Reads all current Firestore mandi records and writes them to MySQL."""
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore
        from mandi_price_scraper import find_service_account_key
    except ImportError:
        print("  [!] firebase-admin not installed.")
        return 0

    key_path = find_service_account_key()
    if not key_path:
        print("  [!] Service account key not found.")
        return 0

    app = firebase_admin.get_app() if firebase_admin._apps else None
    if app is None:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)

    db = firestore.client()
    print("Fetching documents from Cloud Firestore...")
    all_recs = []

    for doc_id in ["today_AP", "today_TS"]:
        snap = db.collection("mandi_prices").document(doc_id).get()
        if snap.exists:
            recs = snap.to_dict().get("records", [])
            all_recs.extend(recs)
            print(f"  - Loaded {len(recs)} records from Firestore/{doc_id}")

    # Sync marketplace listings from Firestore into MySQL
    conn = get_mysql_connection()
    with conn.cursor() as cur:
        try:
            m_docs = db.collection("marketplace").get()
            print(f"  - Loaded {len(m_docs)} marketplace listings from Firestore")
            for doc in m_docs:
                d = doc.to_dict()
                title = d.get("title", "")
                cat = d.get("category", "Produce")
                price = d.get("price", "")
                seller = d.get("seller", "Farmer")
                phone = d.get("phone", "")
                loc = d.get("location", "Kurnool")
                desc = d.get("description", "")
                p_num = float(re.sub(r"[^\d.]", "", price) or 0)

                cur.execute(
                    """
                    INSERT INTO marketplace_listings 
                        (title, category, price, price_num, seller, phone, location, description) 
                    VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE 
                        price = VALUES(price),
                        description = VALUES(description);
                    """,
                    (title, cat, price, p_num, seller, phone, loc, desc),
                )
        except Exception as m_err:
            print(f"  [!] Note on marketplace sync: {m_err}")

        # If still empty, seed sample listings
        cur.execute("SELECT COUNT(*) as c FROM marketplace_listings;")
        if cur.fetchone()["c"] == 0:
            sample_listings = [
                ("Tractor (Second Hand)", "Equipment", "₹1,20,000", 120000.0, "Ravi Kumar", "9876543210", "Kurnool", "Good condition tractor, used 3 years. Engine serviced recently."),
                ("Drip Irrigation Kit", "Equipment", "₹8,500", 8500.0, "AgriSupply Co.", "9845012345", "Nandyal", "Full drip kit for 1 acre, brand new unused."),
                ("Paddy Seeds (50kg)", "Seeds", "₹2,200", 2200.0, "Suresh Farms", "9700112233", "Ongole", "High-yield paddy seeds, govt certified. MTU-1010 variety."),
                ("Organic Fertilizer", "Fertilizer", "₹950", 950.0, "Green Earth", "9988776655", "Kurnool", "100% organic compost, 50kg bag. Great for groundnut."),
            ]
            for title, cat, price, p_num, seller, phone, loc, desc in sample_listings:
                cur.execute(
                    "INSERT INTO marketplace_listings (title, category, price, price_num, seller, phone, location, description) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)",
                    (title, cat, price, p_num, seller, phone, loc, desc),
                )
            print("  - Seeded initial Open Market / Marketplace listings into MySQL.")
    conn.close()

    total = save_mandi_records_to_mysql(all_recs)
    print(f"  [OK] Synchronized {total} mandi records into MySQL database '{MYSQL_DB}'.")
    return total


def print_database_status() -> None:
    """Displays a formatted overview of all tables and record counts in MySQL."""
    try:
        conn = get_mysql_connection()
    except Exception as err:
        print(f"Could not connect to MySQL: {err}")
        return

    print("=" * 65)
    print(f"  FarmTech MySQL Database Status ({MYSQL_DB})")
    print("=" * 65)

    with conn.cursor() as cur:
        for table in ["mandi_prices", "mandi_price_history", "users", "marketplace_listings", "followed_crops", "disease_scans"]:
            cur.execute(f"SELECT COUNT(*) as cnt FROM {table};")
            cnt = cur.fetchone()["cnt"]
            print(f"  Table {table:25} : {cnt:>6} rows")

        # Show sample recent Kurnool prices
        print("\n  Live Kurnool Crops in MySQL (Min / Mid / Max):")
        print("  " + "-" * 60)
        cur.execute("""
            SELECT commodity, market, min_price, modal_price, max_price, arrival_date
            FROM mandi_prices
            WHERE district LIKE '%Kurnool%' OR market LIKE '%Kurnool%'
            ORDER BY commodity
            LIMIT 12;
        """)
        rows = cur.fetchall()
        for r in rows:
            print(
                f"   {r['commodity']:20} | Min: Rs.{r['min_price']:>6.0f} | "
                f"Mid: Rs.{r['modal_price']:>6.0f} | Max: Rs.{r['max_price']:>6.0f} | {r['arrival_date']}"
            )

    conn.close()
    print("=" * 65)


def main() -> None:
    parser = argparse.ArgumentParser(description="FarmTech MySQL Synchronizer")
    parser.add_argument("--init", action="store_true", help="Initialize MySQL database schema")
    parser.add_argument("--sync-firestore", action="store_true", help="Sync Firestore data into MySQL")
    parser.add_argument("--status", action="store_true", help="Print MySQL database status and row counts")
    args = parser.parse_args()

    init_database()
    if args.sync_firestore or not (args.init or args.status):
        sync_firestore_to_mysql()
    print_database_status()


if __name__ == "__main__":
    main()
