const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { onRequest } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const fetch = require("node-fetch");
const { v4: uuidv4 } = require("uuid");

admin.initializeApp();

const hubApiKey = defineSecret("HUB_API_KEY");

const API_URL =
  "https://europe-west1-evoltech-hub.cloudfunctions.net/hub/api/chatbot/message";

exports.onImageUpload = onObjectFinalized(
  {
    region: "europe-west1",
    secrets: [hubApiKey],
    memory: "256MiB",
    timeoutSeconds: 120,
  },
  async (event) => {
    const object = event.data;

    if (!object.name.startsWith("uploads/")) return;
    if (!object.contentType?.startsWith("image/")) return;

    // Build download URL with token from metadata
    const bucket = admin.storage().bucket(object.bucket);
    const file = bucket.file(object.name);

    // Set a download token if not present
    let token = object.metadata?.firebaseStorageDownloadTokens;
    if (!token) {
      token = uuidv4();
      await file.setMetadata({
        metadata: { firebaseStorageDownloadTokens: token },
      });
    }

    const encodedName = encodeURIComponent(object.name);
    const imageUrl = `https://firebasestorage.googleapis.com/v0/b/${object.bucket}/o/${encodedName}?alt=media&token=${token}`;

    console.log(`Processing image: ${object.name}, URL: ${imageUrl}`);

    // 1. Call API with image
    const apiResponse = await fetch(API_URL, {
      method: "POST",
      headers: {
        "X-API-Key": hubApiKey.value(),
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: "analizza questo report",
        imageUrl: imageUrl,
      }),
    });

    if (!apiResponse.ok) {
      const text = await apiResponse.text();
      console.error(`API error: ${apiResponse.status} - ${text}`);
      await notifyHub(hubApiKey.value(), `Errore API: ${apiResponse.status}`);
      throw new Error(`API returned ${apiResponse.status}`);
    }

    const result = await apiResponse.json();
    console.log("API response:", JSON.stringify(result));

    // 2. Parse response
    const fc = result.functionCall;

    if (!fc || !fc.name || !fc.arguments) {
      console.log("No function call in response, saving raw");
      await admin.firestore().collection("scans").add({
        type: "unknown",
        imagePath: object.name,
        imageUrl,
        rawResponse: result,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      await notifyHub(hubApiKey.value(), "Errore: nessuna function call nella risposta");
      return;
    }

    const functionName = fc.name;
    const args = fc.arguments;

    console.log(`Function: ${functionName}`, JSON.stringify(args));

    // 3. Save to Firestore
    try {
      const doc = buildDocument(functionName, args, object.name, imageUrl, result.conversationID);
      await admin.firestore().collection("reports").add(doc);
      console.log(`Saved ${functionName} to Firestore`);

      // 4. Notify hub: success
      await notifyHub(hubApiKey.value(), "Successo: dati salvati correttamente");
    } catch (err) {
      console.error("Error saving to Firestore:", err);
      await notifyHub(hubApiKey.value(), `Errore salvataggio: ${err.message}`);
      throw err;
    }
  }
);

async function notifyHub(apiKey, message) {
  try {
    await fetch(API_URL, {
      method: "POST",
      headers: {
        "X-API-Key": apiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ message }),
    });
    console.log(`Hub notified: ${message}`);
  } catch (err) {
    console.error("Failed to notify hub:", err);
  }
}

function buildDocument(functionName, args, imagePath, imageUrl, conversationID) {
  const base = {
    type: functionName,
    imagePath,
    imageUrl,
    conversationID: conversationID || null,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  switch (functionName) {
    case "chiusura_pos":
      return {
        ...base,
        data: args.data || null,
        ora: args.ora || null,
        totale: args.totale || 0,
        nomeAzienda: args.nomeAzienda || null,
      };

    case "daily_report_spielo":
      return {
        ...base,
        data: args.data || null,
        totale: args.totale || 0,
        nomeAzienda: args.nomeAzienda || null,
        vlt: args.vlt || [],
      };

    case "report_novoline_range": {
      // Use 'from' as the date for grouping
      const data = args.from || args.date || null;
      // Calculate totale from VLT totalNetWin
      let totale = 0;
      if (args.vlt && Array.isArray(args.vlt)) {
        for (const v of args.vlt) {
          if (v.totalNetWin != null) totale += v.totalNetWin;
        }
      }
      return {
        ...base,
        data,
        from: args.from || null,
        to: args.to || null,
        totale,
        vlt: args.vlt || [],
      };
    }

    default:
      return { ...base, rawArgs: args };
  }
}

/**
 * Image proxy to avoid CORS issues
 * Usage: /imageProxy?path=uploads/filename.jpg
 */
exports.imageProxy = onRequest(
  { region: "europe-west1", memory: "256MiB", timeoutSeconds: 30 },
  async (req, res) => {
    const filePath = req.query.path;
    if (!filePath) {
      res.status(400).send("Missing path parameter");
      return;
    }

    try {
      const bucket = admin.storage().bucket();
      const file = bucket.file(filePath);
      const [metadata] = await file.getMetadata();

      res.set("Access-Control-Allow-Origin", "*");
      res.set("Cache-Control", "public, max-age=86400");
      res.set("Content-Type", metadata.contentType || "image/jpeg");

      const stream = file.createReadStream();
      stream.pipe(res);
    } catch (err) {
      console.error("Proxy error:", err.message);
      res.status(404).send("Image not found");
    }
  }
);
