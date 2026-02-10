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

    // Build public download URL
    const encodedName = encodeURIComponent(object.name);
    const imageUrl = `https://firebasestorage.googleapis.com/v0/b/${object.bucket}/o/${encodedName}?alt=media`;

    console.log(`Processing image: ${object.name}`);

    // Call external API
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
      throw new Error(`API returned ${apiResponse.status}`);
    }

    const result = await apiResponse.json();
    console.log("API response:", JSON.stringify(result));

    // Parse tool calls from response
    const toolCalls = extractToolCalls(result);

    if (!toolCalls || toolCalls.length === 0) {
      console.log("No tool calls found, saving raw response");
      await admin.firestore().collection("scans").add({
        type: "unknown",
        imagePath: object.name,
        imageUrl,
        rawResponse: result,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return;
    }

    for (const toolCall of toolCalls) {
      const { name, args } = toolCall;
      console.log(`Processing tool call: ${name}`, JSON.stringify(args));

      const doc = buildDocument(name, args, object.name, imageUrl);
      await admin.firestore().collection("reports").add(doc);
      console.log(`Saved ${name} to Firestore`);
    }
  }
);

/**
 * Extract tool calls from API response
 * Handles OpenAI-style responses
 */
function extractToolCalls(response) {
  const calls = [];

  // Try response.choices[0].message.tool_calls (OpenAI format)
  if (response.choices?.[0]?.message?.tool_calls) {
    for (const tc of response.choices[0].message.tool_calls) {
      const args =
        typeof tc.function.arguments === "string"
          ? JSON.parse(tc.function.arguments)
          : tc.function.arguments;
      calls.push({ name: tc.function.name, args });
    }
    return calls;
  }

  // Try response.tool_calls directly
  if (response.tool_calls) {
    for (const tc of response.tool_calls) {
      const args =
        typeof tc.function?.arguments === "string"
          ? JSON.parse(tc.function.arguments)
          : tc.function?.arguments || tc.arguments;
      calls.push({ name: tc.function?.name || tc.name, args });
    }
    return calls;
  }

  // Try response.function_call (single call)
  if (response.function_call) {
    const args =
      typeof response.function_call.arguments === "string"
        ? JSON.parse(response.function_call.arguments)
        : response.function_call.arguments;
    calls.push({ name: response.function_call.name, args });
    return calls;
  }

  return calls;
}

/**
 * Build Firestore document based on function type
 */
function buildDocument(functionName, args, imagePath, imageUrl) {
  const base = {
    type: functionName,
    imagePath,
    imageUrl,
    rawArgs: args,
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
        totale: null, // calcolato dal frontend
        vlt: args.vlt || [],
      };

    default:
      return base;
  }
}
