/**
 * push-on-message
 *
 * Triggered via a Supabase Database Webhook on INSERT to public.messages.
 * Fetches the recipient's FCM tokens and sends a push notification via
 * the Firebase Cloud Messaging v1 HTTP API.
 *
 * Environment variables (set in Supabase dashboard → Edge Functions → Secrets):
 *   FIREBASE_PROJECT_ID      — your Firebase project id
 *   FIREBASE_SERVICE_ACCOUNT — JSON string of your Firebase service account key
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_SERVICE_ACCOUNT = Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!;

// ---------------------------------------------------------------------------
// Google OAuth2 token (service account → access token)
// ---------------------------------------------------------------------------

async function getAccessToken(): Promise<string> {
  const sa = JSON.parse(FIREBASE_SERVICE_ACCOUNT);

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: "RS256", typ: "JWT" };
  const payload = {
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const enc = (obj: object) =>
    btoa(JSON.stringify(obj))
      .replace(/=/g, "")
      .replace(/\+/g, "-")
      .replace(/\//g, "_");

  const unsigned = `${enc(header)}.${enc(payload)}`;

  // Import the RSA private key
  const pemKey = sa.private_key as string;
  const keyData = pemKey
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");

  const binaryDer = Uint8Array.from(atob(keyData), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryDer,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(unsigned)
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");

  const jwt = `${unsigned}.${sig}`;

  // Exchange JWT for access token
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const json = await res.json();
  return json.access_token as string;
}

// ---------------------------------------------------------------------------
// Send FCM message
// ---------------------------------------------------------------------------

async function sendFcm(
  token: string,
  title: string,
  body: string,
  data: Record<string, string>
): Promise<void> {
  const accessToken = await getAccessToken();

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token,
          notification: { title, body },
          android: {
            priority: "high",
            notification: {
              channel_id: "notifly_chat",
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: { alert: { title, body }, sound: "default", badge: 1 },
            },
          },
          data,
        },
      }),
    }
  );

  if (!res.ok) {
    const err = await res.text();
    console.error("FCM error:", err);
  }
}

// ---------------------------------------------------------------------------
// Handler
// ---------------------------------------------------------------------------

serve(async (req) => {
  try {
    const payload = await req.json();
    const record = payload.record as {
      id: string;
      conversation_id: string;
      sender_id: string;
      content: string;
    };

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // 1. Get sender's display name
    const { data: sender } = await supabase
      .from("profiles")
      .select("display_name, email")
      .eq("id", record.sender_id)
      .single();

    const senderName =
      (sender?.display_name as string | null) ??
      (sender?.email as string | null) ??
      "Someone";

    // 2. Get all conversation members except the sender
    const { data: members } = await supabase
      .from("conversation_members")
      .select("user_id")
      .eq("conversation_id", record.conversation_id)
      .neq("user_id", record.sender_id);

    if (!members || members.length === 0) {
      return new Response("no recipients", { status: 200 });
    }

    const recipientIds = members.map((m: { user_id: string }) => m.user_id);

    // 3. Get FCM tokens for recipients
    const { data: tokens } = await supabase
      .from("fcm_tokens")
      .select("token")
      .in("user_id", recipientIds);

    if (!tokens || tokens.length === 0) {
      return new Response("no tokens", { status: 200 });
    }

    // 4. Send push to each token
    const body =
      record.content.length > 100
        ? record.content.substring(0, 97) + "..."
        : record.content;

    const data: Record<string, string> = {
      type: "chat_message",
      conversation_id: record.conversation_id,
      sender_id: record.sender_id,
      message_id: record.id,
    };

    await Promise.allSettled(
      tokens.map((t: { token: string }) =>
        sendFcm(t.token, senderName, body, data)
      )
    );

    return new Response("ok", { status: 200 });
  } catch (err) {
    console.error("push-on-message error:", err);
    return new Response("error", { status: 500 });
  }
});
