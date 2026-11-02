const admin = require("firebase-admin");
const { onRequest } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");

const GEMINI_API_KEY = defineSecret("GEMINI_API_KEY");
const GEMINI_MODELS = ["gemini-2.5-flash", "gemini-2.0-flash"];
const REGION = "asia-south1";
const db = admin.apps.length ? admin.app().firestore() : (admin.initializeApp(), admin.firestore());
const REQUEST_HEADERS = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/122.0.0.0 Safari/537.36",
  "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
  "Accept-Language": "en-IN,en;q=0.9",
  "Referer": "https://www.commodityonline.com/",
};
const SCRAPE_TIMEOUT_MS = 20000;
const SCRAPE_CONCURRENCY = 4;
const OVERPASS_ENDPOINT = process.env.OVERPASS_ENDPOINT || "https://overpass-api.de/api/interpreter";
const overpassCache = new Map();
const KURNOOL_CROPS = [
  ["groundnut", "Groundnut"],
  ["onion", "Onion"],
  ["cotton", "Cotton"],
  ["maize", "Maize"],
  ["tomato", "Tomato"],
  ["dry-chillies", "Dry Chillies"],
  ["sunflower-seed", "Sunflower Seed"],
  ["castor-seed", "Castor Seed"],
  ["paddy-dhan-common", "Paddy"],
  ["bengal-gram-gram-whole", "Bengal Gram"],
  ["black-gram-urd-beans-whole", "Black Gram"],
  ["arhar-tur-red-gram-whole", "Red Gram"],
  ["bajra-pearl-millet-cumbu", "Bajra"],
  ["jowar-sorghum", "Jowar"],
  ["moong-green-gram-whole", "Moong"],
];
const AP_DISTRICTS = [
  ["Guntur", "guntur"],
  ["Anantapur", "anantapur"],
  ["Chittoor", "chittoor"],
  ["Kadapa", "kadapa"],
  ["Krishna", "krishna"],
  ["Prakasam", "prakasam"],
  ["Nellore", "nellore"],
  ["Visakhapatnam", "visakhapatnam"],
];
const TS_DISTRICTS = [
  ["Hyderabad", "hyderabad"],
  ["Warangal", "warangal"],
  ["Nizamabad", "nizamabad"],
  ["Karimnagar", "karimnagar"],
  ["Khammam", "khammam"],
];
const COMMON_CROPS = [
  ["groundnut", "Groundnut"],
  ["onion", "Onion"],
  ["tomato", "Tomato"],
  ["cotton", "Cotton"],
  ["maize", "Maize"],
  ["paddy-dhan-common", "Paddy"],
  ["dry-chillies", "Dry Chillies"],
];

const analysisPrompt =
  "You are an expert agricultural plant disease detector helping Indian farmers.\n" +
  "Analyze only visible evidence. This is an AI prediction, not a lab or agricultural officer confirmation.\n" +
  "If crop, symptoms, or image quality are unclear, set image_quality to 'insufficient', confidence to 'Low', do not guess a disease, and request a clearer image.\n" +
  "Do not recommend a product, chemical, dose, concentration, or waiting period. Those must come only from the verified product catalogue.\n" +
  "Respond ONLY with a JSON object like this:\n" +
  "{\n" +
  '  "disease": "Disease name or Healthy",\n' +
  '  "disease_category": "Fungal/Bacterial/Viral/Pest/Nutrient deficiency/Healthy/Unknown",\n' +
  '  "confidence": "High/Medium/Low",\n' +
  '  "image_quality": "sufficient/insufficient",\n' +
  '  "needs_clearer_photo": true,\n' +
  '  "visible_indicators": ["only what is visible"],\n' +
  '  "symptoms": "Brief description of what you see",\n' +
  '  "cause": "Fungal/Bacterial/Viral/Pest/Nutrient deficiency/Healthy",\n' +
  '  "severity": "Mild/Moderate/Severe/Healthy",\n' +
  '  "preventive_measures": ["non-chemical measure"],\n' +
  '  "treatment_categories": ["fungicide/insecticide/fertilizer only when appropriate"],\n' +
  '  "crop": "Crop type if identifiable"\n' +
  "}\n" +
  "Respond with ONLY the JSON, no other text.";

function slugifyTopic(value) {
  return String(value || "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "_")
    .replace(/^_+|_+$/g, "")
    .replace(/_+/g, "_");
}

function priceOf(record) {
  return Number.parseFloat(record?.modal_price ?? "0") || 0;
}

function marketKey(record) {
  return `${record?.commodity || ""}__${record?.market || ""}__${record?.district || ""}`;
}

async function fetchJson(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Request failed (${response.status}): ${text}`);
  }
  return text ? JSON.parse(text) : {};
}

async function fetchText(url, options = {}) {
  const response = await fetch(url, options);
  const text = await response.text();
  if (!response.ok) {
    throw new Error(`Request failed (${response.status}): ${text.slice(0, 200)}`);
  }
  return text;
}

function decodeHtmlEntities(text) {
  return String(text || "")
    .replace(/&nbsp;/gi, " ")
    .replace(/&amp;/gi, "&")
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, "<")
    .replace(/&gt;/gi, ">");
}

function stripHtml(html) {
  return decodeHtmlEntities(
    String(html || "")
      .replace(/<script[\s\S]*?<\/script>/gi, " ")
      .replace(/<style[\s\S]*?<\/style>/gi, " ")
      .replace(/<[^>]+>/g, " ")
      .replace(/\s+/g, " ")
      .trim()
  );
}

function extractTablePrices(html) {
  const tableMatches = html.match(/<table[\s\S]*?<\/table>/gi) || [];
  for (const table of tableMatches) {
    const rowMatches = table.match(/<tr[\s\S]*?<\/tr>/gi) || [];
    for (const row of rowMatches.slice(1)) {
      const cellMatches = row.match(/<t[dh][^>]*>[\s\S]*?<\/t[dh]>/gi) || [];
      const prices = [];
      for (const cell of cellMatches) {
        const raw = stripHtml(cell).replace(/[,\u20b9]/g, "").trim();
        const value = Number.parseFloat(raw);
        if (Number.isFinite(value) && value > 100) {
          prices.push(value);
        }
      }
      if (prices.length >= 2) {
        const minPrice = prices[0];
        const maxPrice = prices[prices.length - 1];
        const modalPrice =
          prices.length > 2 ? prices[1] : Math.round(((minPrice + maxPrice) / 2) * 100) / 100;
        return { minPrice, maxPrice, modalPrice };
      }
    }
  }
  return { minPrice: 0, maxPrice: 0, modalPrice: 0 };
}

function extractPricesFromPage(html) {
  const text = stripHtml(html);
  let modalPrice = 0;
  let minPrice = 0;
  let maxPrice = 0;

  let match = text.match(/costliest[^\d₹]*[₹Rs.]*\s*([\d,]+)\s*\/?\s*Quintal/i);
  if (match) {
    modalPrice = Number.parseFloat(match[1].replace(/,/g, "")) || 0;
    maxPrice = modalPrice;
  }

  match = text.match(/lowest[^\d₹]*[₹Rs.]*\s*([\d,]+)\s*\/?\s*Quintal/i);
  if (match) {
    minPrice = Number.parseFloat(match[1].replace(/,/g, "")) || 0;
  }

  if (modalPrice === 0) {
    return extractTablePrices(html);
  }

  return { minPrice, maxPrice, modalPrice };
}

function todayArrivalDate() {
  const formatter = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Kolkata",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  });
  return formatter.format(new Date());
}

async function mapWithConcurrency(items, limit, worker) {
  const results = new Array(items.length);
  let nextIndex = 0;

  async function runWorker() {
    while (true) {
      const currentIndex = nextIndex;
      nextIndex += 1;
      if (currentIndex >= items.length) {
        return;
      }
      results[currentIndex] = await worker(items[currentIndex], currentIndex);
    }
  }

  const workerCount = Math.min(limit, items.length);
  await Promise.all(Array.from({ length: workerCount }, () => runWorker()));
  return results;
}

async function scrapeOneMandiPrice({
  cropSlug,
  cropName,
  stateSlug,
  districtSlug,
  stateName,
  stateCode,
  districtName,
}) {
  const url = `https://www.commodityonline.com/mandiprices/${cropSlug}/${stateSlug}/${districtSlug}`;
  try {
    const html = await fetchText(url, {
      headers: REQUEST_HEADERS,
      signal: AbortSignal.timeout(SCRAPE_TIMEOUT_MS),
    });
    const { minPrice, maxPrice, modalPrice } = extractPricesFromPage(html);
    if (!(modalPrice > 0)) {
      return null;
    }
    return {
      state: stateName,
      state_code: stateCode,
      district: districtName,
      market: districtName,
      commodity: cropName,
      variety: "Local",
      min_price: minPrice,
      max_price: maxPrice,
      modal_price: modalPrice,
      arrival_date: todayArrivalDate(),
    };
  } catch (error) {
    logger.warn("Mandi scrape failed for page.", {
      cropSlug,
      districtSlug,
      stateCode,
      message: error.message,
    });
    return null;
  }
}

async function scrapeMandiRecords() {
  const apJobs = [
    ...KURNOOL_CROPS.map(([cropSlug, cropName]) => ({
      cropSlug,
      cropName,
      stateSlug: "andhra-pradesh",
      districtSlug: "kurnool",
      stateName: "Andhra Pradesh",
      stateCode: "AP",
      districtName: "Kurnool",
    })),
    ...AP_DISTRICTS.flatMap(([districtName, districtSlug]) =>
      COMMON_CROPS.map(([cropSlug, cropName]) => ({
        cropSlug,
        cropName,
        stateSlug: "andhra-pradesh",
        districtSlug,
        stateName: "Andhra Pradesh",
        stateCode: "AP",
        districtName,
      }))
    ),
  ];
  const tsJobs = TS_DISTRICTS.flatMap(([districtName, districtSlug]) =>
    COMMON_CROPS.map(([cropSlug, cropName]) => ({
      cropSlug,
      cropName,
      stateSlug: "telangana",
      districtSlug,
      stateName: "Telangana",
      stateCode: "TS",
      districtName,
    }))
  );

  const [apResults, tsResults] = await Promise.all([
    mapWithConcurrency(apJobs, SCRAPE_CONCURRENCY, scrapeOneMandiPrice),
    mapWithConcurrency(tsJobs, SCRAPE_CONCURRENCY, scrapeOneMandiPrice),
  ]);

  return {
    apRecords: apResults.filter(Boolean),
    tsRecords: tsResults.filter(Boolean),
  };
}

async function syncScrapedMandiPrices(source = "scheduled-scraper") {
  const { apRecords, tsRecords } = await scrapeMandiRecords();
  const summaries = [];

  if (apRecords.length) {
    summaries.push(await processMandiSnapshot("today_AP", apRecords, source));
  } else {
    logger.warn("No AP mandi records were scraped.");
  }

  if (tsRecords.length) {
    summaries.push(await processMandiSnapshot("today_TS", tsRecords, source));
  } else {
    logger.warn("No TS mandi records were scraped.");
  }

  return {
    apCount: apRecords.length,
    tsCount: tsRecords.length,
    summaries,
  };
}

async function notifyCropTopic(crop, title, body, data = {}) {
  const topic = `crop_${slugifyTopic(crop)}`;
  if (topic === "crop_") return;
  await admin.messaging().send({
    topic,
    notification: { title, body },
    data: Object.fromEntries(
      Object.entries(data).map(([key, value]) => [key, String(value)])
    ),
    android: {
      priority: "high",
      notification: {
        channelId: "price_alert",
      },
    },
  });
}

async function processMandiSnapshot(docId, records, source = "manual") {
  if (!Array.isArray(records)) {
    throw new Error("records must be an array.");
  }

  const ref = db.collection("mandi_prices").doc(docId);
  const previousSnap = await ref.get();
  const previousRecords = Array.isArray(previousSnap.data()?.records)
    ? previousSnap.data().records
    : [];
  const previousMap = new Map(previousRecords.map((record) => [marketKey(record), record]));

  const changes = [];
  for (const record of records) {
    const oldRecord = previousMap.get(marketKey(record));
    const newPrice = priceOf(record);
    const oldPrice = priceOf(oldRecord);
    if (oldRecord && newPrice > 0 && oldPrice > 0 && newPrice !== oldPrice) {
      changes.push({
        crop: record.commodity,
        market: record.market,
        district: record.district,
        oldPrice,
        newPrice,
      });
    }
  }

  await ref.set(
    {
      records,
      source,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      changeCount: changes.length,
    },
    { merge: true }
  );

  for (const change of changes) {
    const direction = change.newPrice > change.oldPrice ? "Increased" : "Decreased";
    await notifyCropTopic(
      change.crop,
      `${change.crop} Price ${direction}`,
      `₹${change.oldPrice} -> ₹${change.newPrice}/qtl | ${change.market}`,
      {
        crop: change.crop,
        market: change.market || "",
        district: change.district || "",
        oldPrice: change.oldPrice,
        newPrice: change.newPrice,
      }
    );
  }

  return { docId, recordCount: records.length, changeCount: changes.length };
}

exports.analyzePlantDisease = onRequest(
  {
    region: REGION,
    cors: true,
    secrets: [GEMINI_API_KEY],
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Use POST for plant disease analysis." });
      return;
    }

    const imageBase64 = req.body?.imageBase64;
    if (typeof imageBase64 !== "string" || imageBase64.length === 0) {
      res.status(400).json({ error: "imageBase64 is required." });
      return;
    }
    // Security: Limit base64 payload to max 5MB to prevent memory exhaustion and token abuse
    if (imageBase64.length > 5 * 1024 * 1024) {
      res.status(413).json({ error: "Image payload exceeds 5MB limit." });
      return;
    }

    try {
      const promptText = analysisPrompt;

      let result = null;

      const geminiKey = GEMINI_API_KEY.value();
      for (const model of GEMINI_MODELS) {
        try {
          const url = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${geminiKey}`;
          const geminiResponse = await fetch(url, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              contents: [{ parts: [
                { inline_data: { mime_type: "image/jpeg", data: imageBase64 } },
                { text: promptText },
              ] }],
              generationConfig: { response_mime_type: "application/json" },
            }),
          });
          if (geminiResponse.ok) {
            const data = await geminiResponse.json();
            const rawText = String(data?.candidates?.[0]?.content?.parts?.[0]?.text ?? "")
              .replace(/```json|```/g, "").trim();
            if (rawText) { result = JSON.parse(rawText); break; }
          }
        } catch (e) {
          logger.warn(`Gemini model ${model} failed.`, e);
        }
      }

      if (!result) {
        res.status(502).json({
          error: "Disease analysis service is unavailable right now. Please try again later.",
        });
        return;
      }

      result.ai_prediction = true;
      res.status(200).json({ result });
    } catch (error) {
      logger.error("Plant disease analysis failed.", error);
      res.status(500).json({
        error: "Disease analysis failed on the server. Please try again.",
      });
    }
  }
);

function validCoordinate(value, min, max) {
  return Number.isFinite(value) && value >= min && value <= max;
}

function overpassElementToStore(element) {
  const tags = element.tags || {};
  const latitude = Number(element.lat ?? element.center?.lat ?? 0);
  const longitude = Number(element.lon ?? element.center?.lon ?? 0);
  return {
    id: `osm-${element.type}-${element.id}`,
    name: tags.name || "Agricultural store",
    address: [tags["addr:housenumber"], tags["addr:street"], tags["addr:city"], tags["addr:district"], tags["addr:postcode"]].filter(Boolean).join(", "),
    latitude,
    longitude,
    phone: tags.phone || tags["contact:phone"] || "",
    openHours: tags.opening_hours || null,
    products: [tags.shop, tags.agricultural, tags["product:agricultural"]].filter(Boolean),
    source: "openstreetmap",
    verification_status: "unverified",
    isVerified: false,
  };
}

// OpenStreetMap is supplemental discovery data, never proof of licence status.
// A self-hosted endpoint can be supplied with OVERPASS_ENDPOINT for larger use.
exports.nearbyAgroStores = onRequest(
  { region: REGION, cors: true, timeoutSeconds: 25 },
  async (req, res) => {
    if (req.method !== "POST") return res.status(405).json({ error: "Use POST." });
    const latitude = Number(req.body?.latitude);
    const longitude = Number(req.body?.longitude);
    const radiusKm = Number(req.body?.radiusKm);
    if (!validCoordinate(latitude, -90, 90) || !validCoordinate(longitude, -180, 180) ||
        !Number.isFinite(radiusKm) || radiusKm < 1 || radiusKm > 100) {
      return res.status(400).json({ error: "Invalid location or radius (1–100 km)." });
    }
    try {
      const cacheKey = `${latitude.toFixed(2)}:${longitude.toFixed(2)}:${radiusKm}`;
      const cached = overpassCache.get(cacheKey);
      if (cached && Date.now() - cached.createdAt < 15 * 60 * 1000) {
        return res.status(200).json({ stores: cached.stores, source: "openstreetmap" });
      }
      const query = `[out:json][timeout:20];(
        nwr["shop"~"agrarian|farm|garden_centre|fertilizer"](around:${radiusKm * 1000},${latitude},${longitude});
        nwr["name"~"agro|fertilizer|pesticide|krishi|seeds",i](around:${radiusKm * 1000},${latitude},${longitude});
      );out center tags 75;`;
      const response = await fetch(OVERPASS_ENDPOINT, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded", "User-Agent": "FarmTech/1.1 (agro-store-discovery)" },
        body: new URLSearchParams({ data: query }),
      });
      if (!response.ok) throw new Error(`Overpass status ${response.status}`);
      const payload = await response.json();
      const stores = (payload.elements || [])
        .map(overpassElementToStore)
        .filter((store) => store.latitude && store.longitude);
      overpassCache.set(cacheKey, { createdAt: Date.now(), stores });
      return res.status(200).json({ stores, source: "openstreetmap" });
    } catch (error) {
      logger.error("OpenStreetMap store search failed", error);
      return res.status(502).json({ error: "Store search is unavailable. Please try again." });
    }
  }
);

exports.ingestMandiPrices = onRequest(
  {
    region: REGION,
    cors: true,
    timeoutSeconds: 60,
    memory: "512MiB",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Use POST for mandi ingestion." });
      return;
    }

    // Security: Protect admin endpoint from unauthorized external callers
    const adminKey = req.headers["x-admin-key"] || req.query.adminKey;
    const expectedKey = process.env.ADMIN_KEY;
    if (expectedKey && adminKey !== expectedKey) {
      res.status(403).json({ error: "Forbidden: Invalid or missing admin credentials." });
      return;
    }

    try {
      const docId = String(req.body?.docId || "");
      const records = req.body?.records;
      const source = String(req.body?.source || "manual");
      if (!docId) {
        res.status(400).json({ error: "docId is required." });
        return;
      }
      if (!Array.isArray(records) || records.length > 2000) {
        res.status(400).json({ error: "records must be an array of at most 2000 items." });
        return;
      }

      const summary = await processMandiSnapshot(docId, records, source);
      res.status(200).json(summary);
    } catch (error) {
      logger.error("Mandi ingestion failed.", error);
      res.status(500).json({ error: error.message || "Mandi ingestion failed." });
    }
  }
);

exports.syncMandiPrices = onSchedule(
  {
    region: REGION,
    schedule: "every 30 minutes",
    timeZone: "Asia/Kolkata",
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async () => {
    const summary = await syncScrapedMandiPrices("scheduled-scraper");
    logger.info("Scheduled mandi scrape completed.", summary);
  }
);

exports.scrapeMandiPricesNow = onRequest(
  {
    region: REGION,
    cors: true,
    timeoutSeconds: 540,
    memory: "1GiB",
  },
  async (req, res) => {
    if (req.method !== "POST") {
      res.status(405).json({ error: "Use POST to trigger mandi scraping." });
      return;
    }

    // Security: Protect expensive long-running trigger from abuse
    const adminKey = req.headers["x-admin-key"] || req.query.adminKey;
    const expectedKey = process.env.ADMIN_KEY;
    if (expectedKey && adminKey !== expectedKey) {
      res.status(403).json({ error: "Forbidden: Invalid or missing admin credentials." });
      return;
    }

    try {
      const summary = await syncScrapedMandiPrices("manual-cloud-scraper");
      res.status(200).json(summary);
    } catch (error) {
      logger.error("Manual mandi scrape failed.", error);
      res.status(500).json({ error: error.message || "Manual mandi scrape failed." });
    }
  }
);
