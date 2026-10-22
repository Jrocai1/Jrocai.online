import { createClient } from "npm:@supabase/supabase-js@2.57.4";

const allowedOrigins = new Set([
  "https://jrocai.online", "https://www.jrocai.online", "https://jrocai-online.pages.dev",
]);
const isAllowedOrigin = (origin: string) => allowedOrigins.has(origin) || origin.endsWith(".jrocai-online.pages.dev");
const json = (body: unknown, status = 200, origin = "") => new Response(JSON.stringify(body), {
  status,
  headers: {
    "Access-Control-Allow-Origin": isAllowedOrigin(origin) ? origin : "https://jrocai.online",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
    "Content-Type": "application/json",
    "Vary": "Origin",
  },
});
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const admin = createClient(supabaseUrl, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });
const publicClient = createClient(supabaseUrl, anonKey, { auth: { persistSession: false, autoRefreshToken: false } });
const digest = async (value: string) => {
  const bytes = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return Array.from(new Uint8Array(bytes), b => b.toString(16).padStart(2, "0")).join("");
};
const newLicenseKey = () => {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  const token = btoa(String.fromCharCode(...bytes)).replaceAll("+", "-").replaceAll("/", "_").replaceAll("=", "");
  return "JROC-" + token;
};
async function authenticatedUser(req: Request) {
  const header = req.headers.get("Authorization") || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : "";
  if (!token) return null;
  const { data, error } = await publicClient.auth.getUser(token);
  return error ? null : data.user;
}
Deno.serve(async (req: Request) => {
  const origin = req.headers.get("Origin") || "";
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: {
    "Access-Control-Allow-Origin": isAllowedOrigin(origin) ? origin : "https://jrocai.online",
    "Access-Control-Allow-Headers": "authorization, apikey, content-type",
    "Access-Control-Allow-Methods": "GET, POST, OPTIONS", "Vary": "Origin",
  }});
  const url = new URL(req.url);
  const route = url.pathname.split("/").filter(Boolean).at(-1) || "";
  if (req.method === "GET" && route === "status") {
    const paymentsConfigured = Boolean(Deno.env.get("STRIPE_SECRET_KEY") && Deno.env.get("STRIPE_WEBHOOK_SECRET"));
    const checkoutFlag = Deno.env.get("SAAS_CHECKOUT_ENABLED") === "true";
    const { count } = await admin.from("saas_plans").select("id", { count: "exact", head: true }).eq("active", true);
    return json({ payments_configured: paymentsConfigured, active_plan_count: count || 0, checkout_enabled: paymentsConfigured && checkoutFlag && (count || 0) > 0 }, 200, origin);
  }
  if (req.method === "GET" && route === "catalog") {
    const { data: products, error } = await admin.from("saas_products")
      .select("id,slug,name,description,metadata")
      .eq("visibility", "public").in("status", ["preview", "active"]).order("name");
    if (error) return json({ error: "catalog_unavailable" }, 500, origin);
    const ids = (products || []).map((p: { id: string }) => p.id);
    if (!ids.length) return json({ products: [] }, 200, origin);
    const { data: plans, error: planError } = await admin.from("saas_plans")
      .select("id,product_id,slug,name,billing_interval,price_cents,currency,features")
      .in("product_id", ids).eq("active", true).order("price_cents");
    if (planError) return json({ error: "plans_unavailable" }, 500, origin);
    return json({ products: (products || []).map((p: { id: string }) => ({
      ...p, plans: (plans || []).filter((plan: { product_id: string }) => plan.product_id === p.id),
    })) }, 200, origin);
  }
  if (req.method === "GET" && route === "me") {
    const user = await authenticatedUser(req);
    if (!user) return json({ error: "unauthorized" }, 401, origin);
    const [subs, entitlements, licenses] = await Promise.all([
      admin.from("saas_subscriptions").select("id,product_id,plan_id,status,current_period_start,current_period_end,cancel_at_period_end,created_at").eq("user_id", user.id),
      admin.from("saas_entitlements").select("id,product_id,feature_key,enabled,limits,valid_until,created_at").eq("user_id", user.id),
      admin.from("saas_license_records").select("id,product_id,key_prefix,status,max_activations,expires_at,created_at").eq("user_id", user.id),
    ]);
    if (subs.error || entitlements.error || licenses.error) return json({ error: "account_data_unavailable" }, 500, origin);
    return json({ user: { id: user.id, email: user.email }, subscriptions: subs.data, entitlements: entitlements.data, licenses: licenses.data }, 200, origin);
  }
  if (req.method === "POST" && route === "checkout") {
    const user = await authenticatedUser(req);
    if (!user) return json({ error: "unauthorized" }, 401, origin);
    const stripeSecret = Deno.env.get("STRIPE_SECRET_KEY");
    if (!stripeSecret || Deno.env.get("SAAS_CHECKOUT_ENABLED") !== "true") return json({ error: "checkout_disabled", message: "Checkout remains disabled until Stripe secrets are configured and the owner explicitly enables checkout after end-to-end tests." }, 503, origin);
    let body: { plan_id?: string };
    try { body = await req.json(); } catch { return json({ error: "invalid_json" }, 400, origin); }
    if (!body.plan_id || typeof body.plan_id !== "string") return json({ error: "plan_id_required" }, 400, origin);
    const { data: plan, error } = await admin.from("saas_plans")
      .select("id,product_id,billing_interval,provider_price_id,active,saas_products!inner(id,slug,name,visibility,status)")
      .eq("id", body.plan_id).eq("active", true).maybeSingle();
    if (error || !plan || !plan.provider_price_id || !["month", "year"].includes(plan.billing_interval)) return json({ error: "plan_unavailable" }, 409, origin);
    const product = Array.isArray(plan.saas_products) ? plan.saas_products[0] : plan.saas_products;
    if (!product || product.visibility !== "public" || !["preview", "active"].includes(product.status)) return json({ error: "product_unavailable" }, 409, origin);
    const form = new URLSearchParams();
    form.set("mode", "subscription"); form.set("line_items[0][price]", plan.provider_price_id); form.set("line_items[0][quantity]", "1");
    form.set("client_reference_id", user.id); if (user.email) form.set("customer_email", user.email);
    form.set("success_url", "https://jrocai.online/marketplace/?checkout=success&session_id={CHECKOUT_SESSION_ID}");
    form.set("cancel_url", "https://jrocai.online/marketplace/?checkout=cancelled");
    for (const [k, v] of Object.entries({ user_id: user.id, product_id: plan.product_id, plan_id: plan.id })) {
      form.set("metadata[" + k + "]", v); form.set("subscription_data[metadata][" + k + "]", v);
    }
    const response = await fetch("https://api.stripe.com/v1/checkout/sessions", { method: "POST", headers: { Authorization: "Bearer " + stripeSecret, "Content-Type": "application/x-www-form-urlencoded" }, body: form });
    const session = await response.json();
    if (!response.ok || !session.url) return json({ error: "checkout_creation_failed" }, 502, origin);
    return json({ checkout_url: session.url, session_id: session.id }, 200, origin);
  }
  if (req.method === "POST" && route === "license") {
    const user = await authenticatedUser(req);
    if (!user) return json({ error: "unauthorized" }, 401, origin);
    let body: { product_id?: string };
    try { body = await req.json(); } catch { return json({ error: "invalid_json" }, 400, origin); }
    if (!body.product_id) return json({ error: "product_id_required" }, 400, origin);
    const { data: entitlements, error: entitlementError } = await admin.from("saas_entitlements")
      .select("id,enabled,valid_until").eq("user_id", user.id).eq("product_id", body.product_id).eq("feature_key", "product_access");
    if (entitlementError) return json({ error: "entitlement_check_failed" }, 500, origin);
    const eligible = (entitlements || []).some((e: any) => e.enabled && (!e.valid_until || new Date(e.valid_until).getTime() > Date.now()));
    if (!eligible) return json({ error: "active_entitlement_required" }, 403, origin);
    const { data: existing } = await admin.from("saas_license_records").select("id").eq("user_id", user.id).eq("product_id", body.product_id).eq("status", "active").limit(1);
    if (existing?.length) return json({ error: "active_license_exists", message: "Revoke the current license before issuing a replacement." }, 409, origin);
    const key = newLicenseKey();
    const keyHash = await digest(key);
    const prefix = key.slice(0, 10);
    const { data: record, error: recordError } = await admin.from("saas_license_records").insert({
      user_id: user.id, product_id: body.product_id, status: "active", key_prefix: prefix, max_activations: 1,
    }).select("id,product_id,status,key_prefix,max_activations").single();
    if (recordError || !record) return json({ error: "license_issue_failed" }, 500, origin);
    const { error: secretError } = await admin.from("saas_license_secrets").insert({ license_id: record.id, key_hash: keyHash });
    if (secretError) {
      await admin.from("saas_license_records").delete().eq("id", record.id).eq("user_id", user.id);
      return json({ error: "license_issue_failed" }, 500, origin);
    }
    return json({ license: record, license_key: key, warning: "Save this key now. It cannot be retrieved again; revoke and reissue if lost." }, 201, origin);
  }
  if (req.method === "POST" && url.pathname.endsWith("/license/revoke")) {
    const user = await authenticatedUser(req);
    if (!user) return json({ error: "unauthorized" }, 401, origin);
    let body: { license_id?: string };
    try { body = await req.json(); } catch { return json({ error: "invalid_json" }, 400, origin); }
    if (!body.license_id) return json({ error: "license_id_required" }, 400, origin);
    const { data, error } = await admin.from("saas_license_records").update({ status: "revoked", updated_at: new Date().toISOString() })
      .eq("id", body.license_id).eq("user_id", user.id).select("id").maybeSingle();
    if (error) return json({ error: "license_revoke_failed" }, 500, origin);
    if (!data) return json({ error: "license_not_found" }, 404, origin);
    await admin.from("saas_license_activations").update({ deactivated_at: new Date().toISOString() }).eq("license_id", data.id).is("deactivated_at", null);
    return json({ revoked: true, license_id: data.id }, 200, origin);
  }
  if (req.method === "POST" && route === "activate") {
    let body: { license_key?: string; device_fingerprint?: string };
    try { body = await req.json(); } catch { return json({ error: "invalid_json" }, 400, origin); }
    if (!body.license_key || !body.device_fingerprint || body.device_fingerprint.length > 512) return json({ error: "license_key_and_device_fingerprint_required" }, 400, origin);
    const { data: secret, error } = await admin.from("saas_license_secrets").select("license_id").eq("key_hash", await digest(body.license_key.trim())).maybeSingle();
    if (error || !secret) return json({ error: "invalid_license" }, 403, origin);
    const { data: license, error: licenseError } = await admin.from("saas_license_records").select("id,user_id,product_id,status,max_activations,expires_at").eq("id", secret.license_id).maybeSingle();
    if (licenseError || !license || license.status !== "active" || (license.expires_at && new Date(license.expires_at).getTime() <= Date.now())) return json({ error: "license_inactive_or_expired" }, 403, origin);
    const { data: ents } = await admin.from("saas_entitlements").select("enabled,valid_until").eq("user_id", license.user_id).eq("product_id", license.product_id).eq("feature_key", "product_access");
    if (!(ents || []).some((e: any) => e.enabled && (!e.valid_until || new Date(e.valid_until).getTime() > Date.now()))) return json({ error: "entitlement_inactive" }, 403, origin);
    const deviceHash = await digest(body.device_fingerprint);
    const { data: old } = await admin.from("saas_license_activations").select("id").eq("license_id", license.id).eq("device_fingerprint_hash", deviceHash).is("deactivated_at", null).maybeSingle();
    if (old) {
      await admin.from("saas_license_activations").update({ last_seen_at: new Date().toISOString() }).eq("id", old.id);
      return json({ activated: true, activation_id: old.id, existing: true }, 200, origin);
    }
    const { count, error: countError } = await admin.from("saas_license_activations").select("id", { count: "exact", head: true }).eq("license_id", license.id).is("deactivated_at", null);
    if (countError) return json({ error: "activation_check_failed" }, 500, origin);
    if ((count || 0) >= license.max_activations) return json({ error: "activation_limit_reached" }, 409, origin);
    const { data: activation, error: activationError } = await admin.from("saas_license_activations").insert({ license_id: license.id, device_fingerprint_hash: deviceHash }).select("id").single();
    if (activationError || !activation) return json({ error: "activation_failed" }, 500, origin);
    return json({ activated: true, activation_id: activation.id }, 201, origin);
  }
  return json({ error: "not_found" }, 404, origin);
});
