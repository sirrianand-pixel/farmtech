"""
FarmTech Cloud Gemini API Key Configurator

Configures and tests the Google Gemini API Key in Cloud Firestore (app_config/ai).
Once configured, ALL farmers using the FarmTech app get automatic AI crop disease
diagnostics on their phones with ZERO setup, ZERO proxy, and ZERO configuration!

Usage:
    python scripts/set_gemini_key.py YOUR_GEMINI_API_KEY
    python scripts/set_gemini_key.py --test
"""

import sys
import requests
import firebase_admin
from firebase_admin import credentials, firestore
from mandi_price_scraper import find_service_account_key

def get_firestore_client():
    key_path = find_service_account_key()
    if not key_path:
        raise FileNotFoundError("Service account JSON key not found.")
    app = firebase_admin.get_app() if firebase_admin._apps else None
    if app is None:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)
    return firestore.client()

def test_gemini_key(api_key: str) -> bool:
    print(f"Testing Gemini API Key: {api_key[:8]}...{api_key[-4:]}")
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={api_key}"
    payload = {
        "contents": [{"parts": [{"text": "Hello! Confirm in 5 words that Gemini Vision API is working."}]}]
    }
    try:
        r = requests.post(url, json=payload, headers={"Content-Type": "application/json"}, timeout=15)
        if r.status_code == 200:
            data = r.json()
            reply = data.get("candidates", [{}])[0].get("content", {}).get("parts", [{}])[0].get("text", "").strip()
            print(f"  [SUCCESS] Gemini API responded: \"{reply}\"")
            return True
        else:
            print(f"  [ERROR] Gemini API returned HTTP {r.status_code}: {r.text}")
            return False
    except Exception as err:
        print(f"  [ERROR] Network error testing Gemini API: {err}")
        return False

def save_to_firestore(api_key: str):
    db = get_firestore_client()
    db.collection("app_config").document("ai").set({
        "gemini_api_key": api_key.strip(),
        "model": "gemini-1.5-flash",
        "updated_at": firestore.SERVER_TIMESTAMP
    }, merge=True)
    print("=" * 65)
    print("  [OK] Gemini API Key saved to Cloud Firestore (app_config/ai)!")
    print("  All farmer phones will now use this cloud key automatically!")
    print("=" * 65)

def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python scripts/set_gemini_key.py YOUR_GEMINI_API_KEY")
        print("  python scripts/set_gemini_key.py --test")
        return

    arg = sys.argv[1].strip()
    if arg == "--test":
        db = get_firestore_client()
        doc = db.collection("app_config").document("ai").get()
        if doc.exists and doc.to_dict().get("gemini_api_key"):
            key = doc.to_dict()["gemini_api_key"]
            test_gemini_key(key)
        else:
            print("No Gemini API key found in Firestore. Set one with: python scripts/set_gemini_key.py YOUR_KEY")
    else:
        if test_gemini_key(arg):
            save_to_firestore(arg)
        else:
            print("\nWould you like to save this key anyway? (Saving to Firestore...)")
            save_to_firestore(arg)

if __name__ == "__main__":
    main()
