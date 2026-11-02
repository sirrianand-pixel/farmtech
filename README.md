# FarmTech

FarmTech is a Flutter app for mandi prices, crop alerts, disease checking, and
farmer utilities.

## Firebase-Hosted Setup

This project can run with Firebase-hosted disease analysis and scheduled mandi
scraping:

- `analyzePlantDisease` Cloud Function for Gemini-only disease checking
- `nearbyAgroStores` Cloud Function for secure free OpenStreetMap (Overpass API)
  discovery and on-demand contact details
- `syncMandiPrices` scheduled Cloud Function for automatic mandi scraping

Requirements:

- Firebase project on the Blaze plan
- `GEMINI_API_KEY` configured as a Firebase Functions secret
- Google Maps Platform billing enabled (optional, only if using other Maps features; 
  Plant Disease module now uses free OpenStreetMap)
- `GOOGLE_MAPS_SERVER_KEY` (no longer required for store discovery)

Deploy the functions:

```powershell
firebase functions:secrets:set GEMINI_API_KEY
firebase deploy --only functions
```

After deployment:

- the Flutter disease checker uses the hosted Firebase Function by default; it
  never downloads or caches a Gemini key
- mandi prices are scraped automatically by Firebase every 30 minutes
- nearby stores are discovered via free OpenStreetMap/Overpass API data
- you can trigger a manual cloud scrape with `scrapeMandiPricesNow`

## Windows-Only Fallback Without Blaze

This project can also run without upgrading Firebase by using:

- a local Windows scraper that writes directly to Firestore

Disease analysis and store discovery require the deployed Firebase Functions;
FarmTech intentionally has no direct-client or Anthropic fallback.

### 1. Run the Mandi Scraper Manually

Install Python dependencies:

```powershell
pip install requests firebase-admin beautifulsoup4 lxml
```

Place your Firebase service account JSON at:

```text
C:\Users\Anandh\Desktop\Farmtech\scripts\serviceAccountKey.json
```

Then run:

```powershell
python C:\Users\Anandh\Desktop\Farmtech\scripts\mandi_price_scraper.py
```

### 2. Schedule the Scraper on Windows

Register a repeating Windows Task Scheduler job:

```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\Anandh\Desktop\Farmtech\scripts\register_mandi_scraper_task.ps1
```

This creates a task named `FarmTech Mandi Scraper` that runs every 30 minutes.

### Product and dealer data policy

`agricultural_products` documents must contain the exact product/formulation,
official manufacturer or label URL, exact package image URL, verification status
and `last_verified` date. Do not add a product image or a dose without its
source. `agro_stores` is reserved for government/official-directory verified
dealers and must include `verification_status`, `source` and `last_verified`.
OpenStreetMap results are intentionally displayed as unverified business listings.
