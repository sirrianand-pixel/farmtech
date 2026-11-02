"""
FarmTech disease checker local proxy.

Runs a small local HTTP server on Windows so the Flutter app can analyze plant
images without Firebase Functions or the Blaze plan.

Setup:
    pip install flask requests

Run:
    set ANTHROPIC_API_KEY=your_key_here
    python scripts/disease_proxy_server.py
"""

from __future__ import annotations

import json
import os
import re

import requests
from flask import Flask, jsonify, request

ANTHROPIC_API_KEY = os.getenv("ANTHROPIC_API_KEY", "")
ANTHROPIC_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-3-5-sonnet-20241022")
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", os.getenv("GOOGLE_API_KEY", ""))
GEMINI_MODEL = os.getenv("GEMINI_MODEL", "gemini-1.5-flash")
PLANT_ML_ENDPOINT = os.getenv("PLANT_ML_ENDPOINT", "")
HOST = os.getenv("FARMTECH_PROXY_HOST", "0.0.0.0")
PORT = int(os.getenv("FARMTECH_PROXY_PORT", "8787"))

PROMPT = (
    "You are an expert agricultural plant disease detector helping Indian farmers.\n"
    "Analyze this plant image and respond ONLY with a JSON object like this:\n"
    "{\n"
    '  "disease": "Disease name or Healthy",\n'
    '  "confidence": "High/Medium/Low",\n'
    '  "symptoms": "Brief description of what you see",\n'
    '  "cause": "Fungal/Bacterial/Viral/Pest/Nutrient deficiency/Healthy",\n'
    '  "severity": "Mild/Moderate/Severe/Healthy",\n'
    '  "treatment": ["Treatment step 1", "Treatment step 2", "Treatment step 3"],\n'
    '  "fertilizers": ["Fertilizer 1 with dosage", "Fertilizer 2 with dosage"],\n'
    '  "recommended_products": [{"name":"Product name","type":"fertilizer or spray","usage":"How to use it","notes":"Why it helps"}],\n'
    '  "prevention": "One line prevention tip",\n'
    '  "crop": "Crop type if identifiable"\n'
    "}\n"
    "Respond with ONLY the JSON, no other text."
)

app = Flask(__name__)


def _fetch_ml_hints(image_base64: str) -> dict | None:
    if not PLANT_ML_ENDPOINT:
        return None
    try:
        response = requests.post(
            PLANT_ML_ENDPOINT,
            json={"imageBase64": image_base64},
            timeout=30,
        )
        response.raise_for_status()
        return response.json()
    except requests.RequestException:
        return None


def _product_image(label: str, kind: str) -> str:
    color = "#6A1B9A" if kind == "spray" else "#2E7D32"
    accent = "#AB47BC" if kind == "spray" else "#66BB6A"
    safe_label = re.sub(r'[<&>"]', "", label or "Recommended")
    safe_kind = re.sub(r'[<&>"]', "", kind or "fertilizer")
    svg = f"""
    <svg xmlns="http://www.w3.org/2000/svg" width="320" height="220" viewBox="0 0 320 220">
      <defs>
        <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
          <stop offset="0%" stop-color="{color}"/>
          <stop offset="100%" stop-color="{accent}"/>
        </linearGradient>
      </defs>
      <rect x="0" y="0" width="320" height="220" rx="28" fill="url(#bg)"/>
      <rect x="34" y="36" width="108" height="148" rx="18" fill="#ffffff" opacity="0.92"/>
      <text x="162" y="84" font-family="Arial, sans-serif" font-size="16" font-weight="700" fill="#ffffff">{safe_kind.upper()}</text>
      <text x="162" y="114" font-family="Arial, sans-serif" font-size="26" font-weight="700" fill="#ffffff">{safe_label}</text>
      <text x="162" y="145" font-family="Arial, sans-serif" font-size="14" fill="#e8f5e9">FarmTech suggestion</text>
    </svg>
    """.strip()
    return "data:image/svg+xml;base64," + __import__("base64").b64encode(svg.encode("utf-8")).decode("utf-8")


def _fallback_products(result: dict) -> list[dict]:
    cause = str(result.get("cause", "")).lower()
    if "fung" in cause:
      return [
          {
              "name": "Copper Oxychloride",
              "type": "spray",
              "usage": "Spray as labeled after removing infected leaves.",
              "notes": "Common protective fungicide for many leaf-spot diseases.",
          },
          {
              "name": "Balanced NPK + Micronutrients",
              "type": "fertilizer",
              "usage": "Apply light nutrition support to reduce plant stress.",
              "notes": "Helps recovery after disease pressure.",
          },
      ]
    if "bacter" in cause:
      return [
          {
              "name": "Copper-based Bactericide",
              "type": "spray",
              "usage": "Use as a preventive spray and avoid overhead irrigation.",
              "notes": "Supports bacterial leaf disease management.",
          }
      ]
    return [
        {
            "name": "Neem-based Crop Spray",
            "type": "spray",
            "usage": "Use as a broad preventive support spray.",
            "notes": "Good low-risk first response while confirming diagnosis.",
        }
    ]


def _enrich_products(result: dict) -> list[dict]:
    raw_products = result.get("recommended_products") or _fallback_products(result)
    products = []
    for item in raw_products:
        kind = "spray" if "spray" in str(item.get("type", "")).lower() else "fertilizer"
        name = str(item.get("name") or "Recommended")
        products.append(
            {
                **item,
                "name": name,
                "type": kind,
                "imageDataUri": _product_image(name, kind),
            }
        )
    return products


@app.post("/analyze")
def analyze():
    if not ANTHROPIC_API_KEY and not GEMINI_API_KEY:
        return (
            jsonify(
                {
                    "error": "API Key is missing. Set GEMINI_API_KEY or ANTHROPIC_API_KEY before starting the proxy."
                }
            ),
            500,
        )

    payload = request.get_json(silent=True) or {}
    image_base64 = payload.get("imageBase64")
    if not isinstance(image_base64, str) or not image_base64:
        return jsonify({"error": "imageBase64 is required."}), 400

    ml_hints = _fetch_ml_hints(image_base64)
    prompt = PROMPT
    if ml_hints:
        prompt += (
            "\n\nOptional ML hints from a plant model:\n"
            + json.dumps(ml_hints)
            + "\nUse these only if they match the visible symptoms."
        )

    try:
        if GEMINI_API_KEY:
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent?key={GEMINI_API_KEY}"
            response = requests.post(
                url,
                headers={"Content-Type": "application/json"},
                json={
                    "contents": [
                        {
                            "parts": [
                                {
                                    "inline_data": {
                                        "mime_type": "image/jpeg",
                                        "data": image_base64,
                                    }
                                },
                                {"text": prompt},
                            ]
                        }
                    ],
                    "generationConfig": {"response_mime_type": "application/json"},
                },
                timeout=60,
            )
            response.raise_for_status()
            data = response.json()
            raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
            raw_text = re.sub(r"```json|```", "", raw_text).strip()
            result = json.loads(raw_text)
        else:
            response = requests.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "Content-Type": "application/json",
                    "x-api-key": ANTHROPIC_API_KEY,
                    "anthropic-version": "2023-06-01",
                },
                json={
                    "model": ANTHROPIC_MODEL,
                    "max_tokens": 1024,
                    "messages": [
                        {
                            "role": "user",
                            "content": [
                                {
                                    "type": "image",
                                    "source": {
                                        "type": "base64",
                                        "media_type": "image/jpeg",
                                        "data": image_base64,
                                    },
                                },
                                {
                                    "type": "text",
                                    "text": prompt,
                                },
                            ],
                        }
                    ],
                },
                timeout=60,
            )
            response.raise_for_status()
            data = response.json()
            text = str(data.get("content", [{}])[0].get("text", ""))
            text = re.sub(r"```json|```", "", text).strip()
            result = json.loads(text)

        result["mlHints"] = ml_hints
        result["recommended_products"] = _enrich_products(result)
        return jsonify({"result": result})
    except requests.HTTPError as error:
        return jsonify({"error": f"AI API error: {error.response.text}"}), 502
    except Exception as error:
        return jsonify({"error": f"Disease analysis failed: {error}"}), 500


@app.get("/health")
def health():
    return jsonify({
        "ok": True,
        "geminiConfigured": bool(GEMINI_API_KEY),
        "anthropicConfigured": bool(ANTHROPIC_API_KEY),
    })


if __name__ == "__main__":
    import socket
    hostname = socket.gethostname()
    local_ip = "127.0.0.1"
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
    except Exception:
        pass
    print("==================================================")
    print(f"🌿 FarmTech Disease Checker Proxy Running!")
    print(f"📱 For Phone on same Wi-Fi, use URL:")
    print(f"   http://{local_ip}:{PORT}/analyze")
    print(f"💻 For PC / Localhost, use:")
    print(f"   http://127.0.0.1:{PORT}/analyze")
    print("==================================================")
    app.run(host=HOST, port=PORT, debug=False)
