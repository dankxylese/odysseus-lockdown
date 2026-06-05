# Model Routes

Routes for LLM endpoints, models, cookbook serving, and comparison.

## Model Routes (routes/model_routes.py)

```
GET  /api/models                 — list all available models from all endpoints
GET  /api/model-endpoints        — list configured endpoints
POST /api/model-endpoints        — add endpoint {url, name, api_key}
PUT  /api/model-endpoints/{id}   — update endpoint
DELETE /api/model-endpoints/{id} — remove endpoint
POST /api/model-endpoints/{id}/enable  — enable endpoint
POST /api/model-endpoints/{id}/disable — disable endpoint
POST /api/model-endpoints/probe  — probe all endpoints for available models (SSE)
GET  /api/model-endpoints/default — get default endpoint
PUT  /api/model-endpoints/default — set default endpoint
```

## Model Discovery (src/model_discovery.py)

```python
# Caches /v1/models responses per endpoint
# Probes all configured endpoints and merges model lists
# Dead-endpoint detection: marks unreachable endpoints as disabled after N failures
model_discovery.get_models()          # all models from all active endpoints
model_discovery.get_endpoints()       # endpoint list with health status
model_discovery.probe_endpoint(url)   # test a specific endpoint
```

## Endpoint Resolution (src/endpoint_resolver.py)

```python
# Resolution priority:
# 1. session.endpoint_id (session-specific override)
# 2. user default endpoint (from settings)
# 3. OPENAI_BASE_URL env var
# 4. First enabled endpoint in DB

resolve_endpoint(session, model_override=None)
# Returns: {"url": ..., "model": ..., "api_key": ..., "context_length": N}
```

## Preset Routes (routes/preset_routes.py)

```
GET    /api/presets              — list presets
POST   /api/presets              — create preset {name, system_prompt, temperature, model}
GET    /api/presets/{id}         — get preset
PUT    /api/presets/{id}         — update preset
DELETE /api/presets/{id}         — delete preset
```

Presets are character configurations: system prompt + default model + temperature. Applied per-session.

## Cookbook Routes (routes/cookbook_routes.py)

Model download and local serving management (Ollama/vLLM/llama.cpp):

```
GET  /api/cookbook/state         — current cookbook state (serving, downloads, etc.)
GET  /api/cookbook/servers       — configured cookbook servers (Ollama endpoints)
POST /api/cookbook/setup         — install/configure a cookbook server (SSE stream)
GET  /api/cookbook/models        — list downloadable models from Hugging Face
POST /api/cookbook/download      — start model download
POST /api/cookbook/cancel-download — cancel in-progress download
GET  /api/cookbook/cached        — list locally downloaded models
GET  /api/cookbook/serving       — list currently serving processes
POST /api/cookbook/serve         — start serving a model
POST /api/cookbook/stop          — stop serving
GET  /api/cookbook/serve-output  — tail serve process logs (SSE)
GET  /api/cookbook/presets       — list serve presets
POST /api/cookbook/presets       — save serve preset
```

## Comparison Routes (routes/compare_routes.py)

A/B comparison of two models on the same prompt:

```
POST /api/compare/start     — start comparison {prompt, model_a, model_b, session_id}
GET  /api/compare/{id}      — get comparison results
```

## Hardware Fitting (routes/hwfit_routes.py)

"What Fits?" tab in cookbook — calculates which models fit in available VRAM:

```
GET  /api/hwfit/hardware    — detect GPU/RAM specs
POST /api/hwfit/fit         — {models_list} → [fits: bool, required_vram, ...] per model
```

## Embedding Routes (routes/embedding_routes.py)

```
GET  /api/embedding/models       — list available embedding models
POST /api/embedding/models/pull  — download embedding model
GET  /api/embedding/status       — current embedding model status
```
