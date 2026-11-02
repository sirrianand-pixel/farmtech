"""
Publish a new app update record to Firestore so installed APKs
see the update prompt on next launch.

Usage:
    python scripts/publish_update.py [--download-url URL]

The script writes to the Firestore collection 'app_updates', doc 'latest'.
Old APKs compare their embedded build_number against this document and
show an update dialog if a newer build exists.
"""

from __future__ import annotations

import argparse
import json

import firebase_admin
from firebase_admin import credentials, firestore


def main() -> None:
    parser = argparse.ArgumentParser(description="Publish FarmTech update to Firestore")
    parser.add_argument(
        "--download-url",
        default="",
        help="Direct APK download URL (e.g. GitHub Releases, Firebase Hosting, or Google Drive link)",
    )
    parser.add_argument(
        "--mandatory",
        action="store_true",
        help="Make this update mandatory (users cannot dismiss the dialog)",
    )
    args = parser.parse_args()

    cred = credentials.Certificate("scripts/serviceAccountKey.json")
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    update_data = {
        "latest_version": "1.1.0",
        "build_number": 2,
        "release_notes": (
            "🌿 Disease Checker v2 - Major Update!\n\n"
            "• AI-powered crop identification (auto-detects rice, tomato, cotton, etc.)\n"
            "• Free Google Gemini integration (no paid API needed)\n"
            "• Improved disease detection with treatment dosages\n"
            "• Recommended fertilizers & spray products\n"
            "• Works offline with built-in knowledge base\n"
            "• Better error handling & connectivity"
        ),
        "download_url": args.download_url,
        "mandatory": args.mandatory,
    }

    db.collection("app_updates").document("latest").set(update_data)
    print("[OK] Update record published to Firestore!")
    print(json.dumps(update_data, indent=2))


if __name__ == "__main__":
    main()
