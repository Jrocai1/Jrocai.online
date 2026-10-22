/**
 * J-ROC AI LLM Gateway — Cloudflare Workers
 * OpenAI-compatible API surface with strict model allow-list and Supabase membership checks.
 * No provider keys are sent to or stored by the browser.
 */
const json = (data, status = 200, headers = {}) => new Response(JSON.stringify(data), {
  status, headers: { "content-type": "application/json; charset=utf-8", "cache-control": "no-store", ...headers }
});
function corsHeaders(request, env) {
  const origin = request.headers.get("Origin") || "";
  const allowed = (env.ALLOWED_ORIGINS || "").split(",").map(s => s.trim()).filter(Boolean);
  const headers = { "Vary": "Origin" };
  if (allowed.includes(origin)) {
    headers["Access-Control-Allow-Origin"] = origin;
    headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS";
    headers["Access-Control-Allow-Headers"] = "Authorization, Content-Type";
    headers["Access-Control-Max-Age"] = "600";
  }
  return headers;
}
function parseJson(value, fallback) { try { return value ? JSON.parse(value) : fallback; } catch { return fallback; } }
function bearer(request) {
  const value = request.headers.get("Authorization") || "";
  return value.startsWith("Bearer ") ? value.slice(7).trim() : "";
}
async function authenticate(request, env) {
  const token = bearer(request);
  if (!token || !env.SUPABASE_URL || !env.SUPABASE_ANON_KEY) return null;
  const base = env.SUPABASE_URL.replace(/\/$/, "");
  const userResponse = await fetch(base + "/auth/v1/user", {
    headers: { "apikey": env.SUPABASE_ANON_KEY, "Authorization": "Bearer " + token }
  });
  if (!userResponse.ok) return null;
  const user = await userResponse.json();
  if (!user?.id) return null;
  const membershipUrl = base + "/rest/v1/workspace_members?select=user_id,email,role&user_id=eq." + encodeURIComponent(user.id) + "&limit=1";
  const membershipResponse = await fetch(membershipUrl, {
    headers: { "apikey": env.SUPABASE_ANON_KEY, "Authorization": "Bearer " + token }
  });
  if (!membershipResponse.ok) return null;
  const rows = await membershipResponse.json();
  if (!Array.isArray(rows) || !rows.some(row => row.user_id === user.id && ["owner", "admin", "member"].includes(row.role))) return null;
  return { id: user.id, email: user.email, role: rows[0].role };
}
function configuredModels(env) {
  const providers = parseJson(env.PROVIDERS_JSON, {});
  const allowed = parseJson(env.ALLOWED_MODELS_JSON, []);
  if (!Array.isArray(allowed)) return [];
  return allowed.filter(m => m && typeof m.id === "string" && typeof m.provider === "string" &&
    typeof m.model === "string" && providers[m.provider] && providers[m.provider].base_url &&
    typeof providers[m.provider].api_key_env === "string" && env[providers[m.provider].api_key_env]);
}
function openAiModel(m) {
  return { id: m.id, object: "model", created: 0, owned_by: "jroc-ai", permission: [], root: m.id, parent: null };
}
async function chatCompletion(request, env, modelConfig) {
  const body = await request.json().catch(() => null);
  if (!body || !Array.isArray(body.messages) || body.messages.length < 1) return json({ error: { message: "A non-empty messages array is required.", type: "invalid_request_error" } }, 400);
  if (body.messages.length > 40) return json({ error: { message: "Maximum 40 messages per request.", type: "invalid_request_error" } }, 400);
  const messages = [];
  let totalChars = 0;
  for (const m of body.messages) {
    if (!m || !["system", "user", "assistant"].includes(m.role) || typeof m.content !== "string") {
      return json({ error: { message: "Each message must have role system, user, or assistant and string content.", type: "invalid_request_error" } }, 400);
    }
    totalChars += m.content.length;
    messages.push({ role: m.role, content: m.content });
  }
  if (totalChars > 60000) return json({ error: { message: "Message content exceeds the 60,000-character limit.", type: "invalid_request_error" } }, 413);
  const providers = parseJson(env.PROVIDERS_JSON, {});
  const provider = providers[modelConfig.provider];
  const apiKey = env[provider.api_key_env];
  if (!apiKey) return json({ error: { message: "The selected provider is not configured.", type: "provider_configuration_error" } }, 503);
  const maxTokens = Math.min(Math.max(Number(body.max_tokens || 1024), 1), 4096);
  const endpoint = provider.base_url.replace(/\/$/, "") + "/chat/completions";
  let upstream;
  try {
    upstream = await fetch(endpoint, {
      method: "POST",
      headers: { "Authorization": "Bearer " + apiKey, "Content-Type": "application/json" },
      body: JSON.stringify({
        model: modelConfig.model,
        messages,
        temperature: typeof body.temperature === "number" ? Math.min(Math.max(body.temperature, 0), 2) : 0.4,
        max_tokens: maxTokens,
        stream: false
      }),
      signal: AbortSignal.timeout(60000)
    });
  } catch {
    return json({ error: { message: "Provider request failed or timed out.", type: "upstream_error" } }, 502);
  }
  const raw = await upstream.text();
  if (!upstream.ok) return json({ error: { message: "Model provider returned an error.", type: "upstream_error", status: upstream.status } }, 502);
  let data;
  try { data = JSON.parse(raw); } catch { return json({ error: { message: "Provider returned invalid JSON.", type: "upstream_error" } }, 502); }
  if (!Array.isArray(data.choices)) return json({ error: { message: "Provider response did not contain choices.", type: "upstream_error" } }, 502);
  data.model = modelConfig.id;
  return json(data);
}
export default {
  async fetch(request, env) {
    const cors = corsHeaders(request, env);
    if (request.method === "OPTIONS") return new Response(null, { status: 204, headers: cors });
    const url = new URL(request.url);
    if (url.pathname === "/health" && request.method === "GET") return json({ service: "J-ROC AI LLM Gateway", status: "online", auth: "Supabase membership required for model access", version: "0.1.0" }, 200, cors);
    if (!["/v1/models", "/v1/chat/completions"].includes(url.pathname)) return json({ error: { message: "Not found." } }, 404, cors);
    if (!["GET", "POST"].includes(request.method) || (url.pathname === "/v1/models" && request.method !== "GET") || (url.pathname === "/v1/chat/completions" && request.method !== "POST")) return json({ error: { message: "Method not allowed." } }, 405, cors);
    const member = await authenticate(request, env).catch(() => null);
    if (!member) return json({ error: { message: "Valid sign-in and approved workspace membership are required.", type: "authentication_error" } }, 401, cors);
    const models = configuredModels(env);
    if (url.pathname === "/v1/models") return json({ object: "list", data: models.map(openAiModel) }, 200, cors);
    const body = await request.clone().json().catch(() => null);
    if (!body || typeof body.model !== "string") return json({ error: { message: "A model ID is required.", type: "invalid_request_error" } }, 400, cors);
    const model = models.find(m => m.id === body.model);
    if (!model) return json({ error: { message: "Model is not on the Chairman-approved allow-list.", type: "model_not_allowed" } }, 403, cors);
    const result = await chatCompletion(request, env, model);
    const headers = new Headers(result.headers);
    for (const [k, v] of Object.entries(cors)) headers.set(k, v);
    return new Response(result.body, { status: result.status, headers });
  }
};
