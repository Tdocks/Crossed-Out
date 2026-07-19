// App Store Server Notifications v2 → subscriptions table.
// STUB: deploy after creating the ASC notification URL + shared secret.
// Docs: https://developer.apple.com/documentation/appstoreservernotifications
//
// Human steps (see HANDOFF_P0_PLUS_WIDGETS_MONITORING.md):
// 1. Create App Store Server Notifications V2 URL pointing here
// 2. Set secrets: APP_STORE_ISSUER_ID, APP_STORE_KEY_ID, APP_STORE_PRIVATE_KEY,
//    SUPABASE_SERVICE_ROLE_KEY
// 3. Verify JWS, map notificationType → status, upsert public.subscriptions
//    by originalTransactionId → user_id (you'll need a mapping table or
//    look up by original_transaction_id stored at first client sync).

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.4";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "content-type",
      },
    });
  }

  // Intentionally not production-ready — returns 501 until ASC + secrets
  // are configured. Client-side StoreKit sync (upsert_own_subscription)
  // already keeps Plus working for the purchasing device.
  return new Response(
    JSON.stringify({
      error: "not_configured",
      message:
        "Wire App Store Server Notifications v2 here. Client StoreKit sync is live.",
    }),
    { status: 501, headers: { "Content-Type": "application/json" } },
  );
});

// Silence unused import until the stub is filled in.
void createClient;
