# J-ROC AI LLM Gateway

The shared model gateway for J-ROC AI systems: Chairman Suite, AI Hub, AI Brain, AI Factory, AI Workers, and future connected applications.

## What this creates

- OpenAI-compatible `GET /v1/models` and `POST /v1/chat/completions` routes.
- Supabase Auth session verification and approved `workspace_members` membership checks.
- A strict model allow-list controlled by `ALLOWED_MODELS_JSON`.
- Provider keys kept in Cloudflare Worker secrets, not in browser code or Git.
- Request-size/message-count limits, bounded output tokens, no caching, and a health endpoint.
- Configurable OpenAI-compatible providers, including compatible hosted APIs and self-hosted inference endpoints that are reachable from the Worker.

## Important: what an LLM is

This repository implements J-ROC AI's **model access and orchestration layer**, not a newly trained foundation model. Training a competitive foundation model from scratch requires large datasets and substantial compute. The practical first release is a private model gateway that can route to owner-approved open/free-tier models and, later, connect to self-hosted models. J-ROC-specific prompts, tools, retrieval, memory, evaluations, and fine-tuning can be layered on this gateway.

## Deploy to Cloudflare Workers

1. Install Node.js LTS and npm on Windows 11 x64.
2. In this folder run `npm install`.
3. Create a Worker in your Cloudflare account or run `npx wrangler login`, then `npm run deploy`.
4. Set Worker variables:
   - `SUPABASE_ANON_KEY`: the existing Supabase publishable/anon key.
   - `PROVIDERS_JSON`: JSON mapping provider IDs to fixed base URLs and the name of a Worker secret containing the key.
   - `ALLOWED_MODELS_JSON`: only the exact models you approve.
5. Add each provider key as a Cloudflare Worker **secret**, for example `npx wrangler secret put OPENROUTER_API_KEY`.
6. Keep `ALLOWED_ORIGINS` restricted to your real J-ROC AI domain(s). Do not use wildcard CORS for the private workspace.
7. Test `/health`, then test `/v1/models` with a valid Supabase access token. Requests without an approved workspace membership must receive HTTP 401.
8. Test an allowed model, a disallowed model (403), expired session, upstream failure, and token/size limits before connecting other systems.

Example provider configuration (replace the model ID with a currently available model that you explicitly approve):

```json
{
  "openrouter": {
    "base_url": "https://openrouter.ai/api/v1",
    "api_key_env": "OPENROUTER_API_KEY"
  }
}
```

Example allow-list:

```json
[
  {
    "id": "openrouter:APPROVED_MODEL_ID",
    "provider": "openrouter",
    "model": "APPROVED_MODEL_ID"
  }
]
```

Do not assume any provider/model is permanently free. Verify current provider limits and terms before enabling it. A free tier may have quotas, model changes, or rate limits.

## API example

Use a current Supabase access token from the signed-in session:

```http
GET /v1/models
Authorization: Bearer SUPABASE_ACCESS_TOKEN
```

```http
POST /v1/chat/completions
Authorization: Bearer SUPABASE_ACCESS_TOKEN
Content-Type: application/json

{
  "model": "openrouter:APPROVED_MODEL_ID",
  "messages": [{"role": "user", "content": "Hello from J-ROC AI"}],
  "max_tokens": 512
}
```

## Integration architecture

```text
Chairman Suite / AI Hub / AI Factory / AI Workers
                     |
             Supabase session
                     |
          J-ROC AI LLM Gateway
         / auth + membership check \\
        / allow-list + limits       \\
  approved provider adapters / local model bridge
                     |
           response + audit hooks
```

## Production gaps / next phase

- Durable usage metering and audit events (with request IDs, user, model, token counts, provider status; never log secrets or full private prompts by default).
- Per-role model permissions, quotas, rate limiting, and budget guardrails.
- Provider health/fallback routing and circuit breakers.
- Native Ollama/local inference bridge for a Windows 11 workstation, authenticated and bound to localhost/private network only.
- Retrieval/memory with tenant isolation and explicit retention controls.
- Tool calling with schema validation, permission scopes, sandboxing, and Chairman approval for privileged operations.
- Automated integration tests and deployment pipeline.
- Model catalog UI that reads from `/v1/models` rather than a hard-coded list.

This gateway does not execute arbitrary tool calls, operate user devices, or grant an agent privileged access.
