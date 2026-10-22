import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY") || "";
const webhookSecret = Deno.env.get("STRIPE_WEBHOOK_SECRET") || "";
const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
const hex = (bytes: Uint8Array) => Array.from(bytes, b => b.toString(16).padStart(2, "0")).join("");

async function validSignature(raw: string, header: string, secret: string) {
  const values = Object.fromEntries(header.split(",").map(part => part.split("=", 2)).filter(pair => pair.length === 2));
  const timestamp = Number(values.t);
  if (!Number.isFinite(timestamp) || Math.abs(Date.now() / 1000 - timestamp) > 300 || !values.v1) return false;
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  const digest = new Uint8Array(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(values.t + "." + raw)));
  const expected = hex(digest);
  const actual = values.v1;
  if (expected.length !== actual.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) diff |= expected.charCodeAt(i) ^ actual.charCodeAt(i);
  return diff === 0;
}

async function upsertSubscription(sub: any, fallbackMetadata: Record<string, string> = {}) {
  const metadata = { ...(sub.metadata || {}), ...fallbackMetadata };
  const userId = metadata.user_id;
  let planId = metadata.plan_id;
  let productId = metadata.product_id;
  const priceId = sub.items?.data?.[0]?.price?.id;
  let plan: any = null;
  if (planId) {
    const { data } = await admin.from("saas_plans").select("id,product_id").eq("id", planId).maybeSingle();
    plan = data;
  }
  if (!plan && priceId) {
    const { data } = await admin.from("saas_plans").select("id,product_id").eq("provider_price_id", priceId).maybeSingle();
    plan = data;
  }
  if (!plan) throw new Error("No active catalog plan maps to this Stripe subscription.");
  planId = plan.id;
  productId = productId || plan.product_id;
  if (!userId || !productId) throw new Error("Subscription metadata is missing user_id or product_id.");
  const allowed = new Set(["incomplete", "trialing", "active", "past_due", "canceled", "unpaid", "paused", "expired"]);
  const status = allowed.has(sub.status) ? sub.status : (sub.status === "incomplete_expired" ? "expired" : "unpaid");
  const end = sub.current_period_end ? new Date(sub.current_period_end * 1000).toISOString() : null;
  const start = sub.current_period_start ? new Date(sub.current_period_start * 1000).toISOString() : null;
  const { data: record, error } = await admin.from("saas_subscriptions").upsert({
    user_id: userId, product_id: productId, plan_id: planId, provider: "stripe",
    provider_customer_id: typeof sub.customer === "string" ? sub.customer : sub.customer?.id,
    provider_subscription_id: sub.id, status, current_period_start: start, current_period_end: end,
    cancel_at_period_end: Boolean(sub.cancel_at_period_end), updated_at: new Date().toISOString(),
  }, { onConflict: "provider,provider_subscription_id" }).select("id,user_id,product_id,status,current_period_end").single();
  if (error || !record) throw new Error("Subscription database update failed.");
  const enabled = ["active", "trialing"].includes(status) && (!end || new Date(end).getTime() > Date.now());
  const { error: entitlementError } = await admin.from("saas_entitlements").upsert({
    user_id: record.user_id, product_id: record.product_id, subscription_id: record.id,
    feature_key: "product_access", enabled, limits: {}, valid_until: end, updated_at: new Date().toISOString(),
  }, { onConflict: "user_id,product_id,feature_key" });
  if (entitlementError) throw new Error("Entitlement update failed.");
  return { id: record.id, status, enabled };
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return json({ error: "method_not_allowed" }, 405);
  if (!stripeSecret || !webhookSecret) return json({ error: "billing_secrets_not_configured" }, 503);
  const raw = await req.text();
  const signature = req.headers.get("stripe-signature") || "";
  if (!await validSignature(raw, signature, webhookSecret)) return json({ error: "invalid_signature" }, 400);
  let event: any;
  try { event = JSON.parse(raw); } catch { return json({ error: "invalid_event" }, 400); }
  const object = event.data?.object || {};
  const safePayload = {
    object_id: object.id || null,
    customer: typeof object.customer === "string" ? object.customer : object.customer?.id || null,
    subscription: typeof object.subscription === "string" ? object.subscription : object.subscription?.id || null,
    status: object.status || null,
    metadata: object.metadata || {},
  };
  const { error: insertError } = await admin.from("saas_billing_events").insert({
    provider: "stripe", provider_event_id: event.id, event_type: event.type, payload: safePayload,
  });
  if (insertError?.code === "23505") return json({ received: true, duplicate: true });
  if (insertError) return json({ error: "event_record_failed" }, 500);
  const eventRow = await admin.from("saas_billing_events").select("id").eq("provider", "stripe").eq("provider_event_id", event.id).single();
  try {
    if (event.type === "checkout.session.completed") {
      if (object.mode !== "subscription" || !object.subscription) throw new Error("Only subscription checkout is enabled.");
      const response = await fetch("https://api.stripe.com/v1/subscriptions/" + encodeURIComponent(object.subscription), { headers: { Authorization: "Bearer " + stripeSecret } });
      const subscription = await response.json();
      if (!response.ok) throw new Error("Could not retrieve Stripe subscription.");
      await upsertSubscription(subscription, object.metadata || {});
    } else if (event.type === "customer.subscription.created" || event.type === "customer.subscription.updated" || event.type === "customer.subscription.deleted") {
      await upsertSubscription(object);
    }
    await admin.from("saas_billing_events").update({ processing_status: "processed", processed_at: new Date().toISOString() }).eq("provider", "stripe").eq("provider_event_id", event.id);
    return json({ received: true });
  } catch (e) {
    await admin.from("saas_billing_events").update({ processing_status: "failed", processing_error: String(e).slice(0, 500) }).eq("provider", "stripe").eq("provider_event_id", event.id);
    return json({ error: "event_processing_failed" }, 500);
  }
});
