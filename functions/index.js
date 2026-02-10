const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

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

    const encodedName = encodeURIComponent(object.name);
    const imageUrl = `https://firebasestorage.googleapis.com/v0/b/${object.bucket}/o/${encodedName}?alt=media`;

    console.log(`Processing image: ${object.name}`);

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

    // 2. Parse response - format: { functionCall: { name, arguments, callId }, conversationID, ... }
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

/**
 * Send response back to hub API
 */
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

/**
 * Build Firestore document based on function type
 */
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

    case "report_novoline_range":
      return {
        ...base,
        data: args.date || null,
        from: args.from || null,
        to: args.to || null,
        vlt: args.vlt || [],
      };

    default:
      return { ...base, rawArgs: args };
  }
}
