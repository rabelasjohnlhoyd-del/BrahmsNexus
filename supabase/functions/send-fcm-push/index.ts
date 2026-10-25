// Supabase Edge Function: send-fcm-push
// Dispatches Google FCM v1 Push Notifications at 100% Zero-Cost (No Credit Card required)
// Uses official Google Auth library via Deno npm specifier for authentic RS256 JWT signing

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { JWT } from "npm:google-auth-library@9.14.1";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface PushPayload {
  topic?: string;
  targetUserId?: string;
  fcmToken?: string;
  tokens?: string[];
  title: string;
  body: string;
  data?: Record<string, string>;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: PushPayload = await req.json();
    const { topic, fcmToken, tokens, title, body, data } = payload;

    if (!title || !body) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: title and body" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      console.warn("FCM: FIREBASE_SERVICE_ACCOUNT secret missing in Supabase.");
      return new Response(
        JSON.stringify({ success: false, message: "FIREBASE_SERVICE_ACCOUNT secret missing in Supabase." }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const serviceAccount = JSON.parse(serviceAccountJson);
    const projectId = serviceAccount.project_id;

    // Official Google OAuth2 signing using private key
    const jwtClient = new JWT(
      serviceAccount.client_email,
      undefined,
      serviceAccount.private_key,
      ["https://www.googleapis.com/auth/firebase.messaging"]
    );

    const authTokens = await jwtClient.authorize();
    const accessToken = authTokens.access_token;

    if (!accessToken) {
      throw new Error("Failed to retrieve Google OAuth2 access token for FCM.");
    }

    // Sanitize topic name: Google FCM strictly requires topics to match: ^[a-zA-Z0-9-_.~%]+$ (no spaces!)
    let cleanTopic = (topic || "all_staff")
      .trim()
      .replace(/\s+/g, "_")
      .replace(/[^a-zA-Z0-9-_.~%]/g, "")
      .toLowerCase();
    if (!cleanTopic) cleanTopic = "all_staff";

    // Embed title and body into data payload as fallback for background handlers
    const stringData: Record<string, string> = {
      title: title,
      body: body,
      message: body,
      ...(data || {}),
    };

    // Build the robust Android high-priority notification configuration
    const baseMessage = {
      notification: {
        title: title,
        body: body,
      },
      android: {
        priority: "high",
        notification: {
          channel_id: "brahms_operational_alerts",
          icon: "ic_launcher",
          sound: "default",
          notification_priority: "PRIORITY_MAX",
          visibility: "PUBLIC",
        },
      },
      data: stringData,
    };

    const sendFcmMessage = async (target: { topic?: string; token?: string }) => {
      const msg: Record<string, unknown> = { ...baseMessage };
      if (target.token) {
        msg.token = target.token;
      } else if (target.topic) {
        msg.topic = target.topic;
      }

      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
        {
          method: "POST",
          headers: {
            Authorization: `Bearer ${accessToken}`,
            "Content-Type": "application/json",
          },
          body: JSON.stringify({ message: msg }),
        }
      );
      const json = await res.json();
      return { ok: res.ok, status: res.status, result: json };
    };

    const dispatches: Promise<unknown>[] = [];

    // 1. Always dispatch to topic broadcast
    dispatches.push(sendFcmMessage({ topic: cleanTopic }));

    // 2. Dispatch to single specific token if provided
    if (fcmToken) {
      dispatches.push(sendFcmMessage({ token: fcmToken }));
    }

    // 3. Dispatch directly to all registered hardware device tokens (instant delivery)
    if (tokens && Array.isArray(tokens)) {
      for (const t of tokens) {
        if (t && typeof t === "string" && t !== fcmToken) {
          dispatches.push(sendFcmMessage({ token: t }));
        }
      }
    }

    const results = await Promise.allSettled(dispatches);
    console.log(`FCM Dispatched ${dispatches.length} push jobs. Results:`, JSON.stringify(results));

    return new Response(JSON.stringify({ success: true, totalDispatched: dispatches.length, results }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (err: unknown) {
    const errorMsg = err instanceof Error ? err.message : String(err);
    console.error("FCM Edge Function Error:", errorMsg);
    return new Response(JSON.stringify({ error: errorMsg }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
