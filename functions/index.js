const { onObjectFinalized } = require("firebase-functions/v2/storage");
const { defineSecret } = require("firebase-functions/params");
const admin = require("firebase-admin");
const fetch = require("node-fetch");

admin.initializeApp();

const hubApiKey = defineSecret("HUB_API_KEY");

const API_URL =
  "https://europe-west1-evoltech-hub.cloudfunctions.net/hub/api/chatbox/message";

exports.onImageUpload = onObjectFinalized(
  {
    region: "europe-west1",
    secrets: [hubApiKey],
    memory: "256MiB",
  },
  async (event) => {
    const object = event.data;

    // Only process images in uploads/
    if (!object.name.startsWith("uploads/")) return;
    if (!object.contentType?.startsWith("image/")) return;

    // Get download URL
    const bucket = admin.storage().bucket(object.bucket);
    const file = bucket.file(object.name);
    const [url] = await file.getSignedUrl({
      action: "read",
      expires: Date.now() + 1000 * 60 * 60, // 1 hour
    });

    console.log(`Processing image: ${object.name}, URL: ${url}`);

    // Call external API
    const response = await fetch(API_URL, {
      method: "GET",
      headers: {
        "X-API-Key": hubApiKey.value(),
        "Content-Type": "application/json",
      },
      // GET with query params since body not standard for GET
    });

    // Actually, the API expects message and imageUrl - let's use POST-style or query params
    // Re-reading: "Nel body message e imageUrl" - likely expects POST with JSON body
    const apiResponse = await fetch(API_URL, {
      method: "POST",
      headers: {
        "X-API-Key": hubApiKey.value(),
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: "analizza questo report",
        imageUrl: url,
      }),
    });

    if (!apiResponse.ok) {
      console.error(`API error: ${apiResponse.status} ${apiResponse.statusText}`);
      const text = await apiResponse.text();
      console.error(`Response: ${text}`);
      throw new Error(`API returned ${apiResponse.status}`);
    }

    const result = await apiResponse.json();
    console.log("API response:", JSON.stringify(result));

    // Save raw response to Firestore
    await admin.firestore().collection("scans").add({
      imagePath: object.name,
      imageUrl: url,
      apiResponse: result,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    console.log("Saved to Firestore");
  }
);
