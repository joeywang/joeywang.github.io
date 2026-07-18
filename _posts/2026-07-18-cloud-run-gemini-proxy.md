---
layout: post
title: "Using Cloud Run as a Gemini Proxy When Your Region Is Not Supported"
date: 2026-07-18 16:46:00 +0100
author: "Joey Wang"
description: "How I used Google Cloud Run as a small AI gateway so clients in an unsupported region can still call Gemini through a supported GCP region."
tags: [gcp, cloud-run, gemini, ai, proxy, infrastructure, llm]
categories: [AI, GCP]
---

# Using Cloud Run as a Gemini Proxy When Your Region Is Not Supported

This is one of those boring infrastructure problems that becomes interesting only after it blocks you.

I wanted to use Gemini from a client running in Hong Kong. For normal web APIs, that would not be a story. Call the endpoint, pass the API key, get a response.

But AI services are not always available everywhere. For my case, Gemini was not available from the place where the client was running, so the direct path did not work.

The workaround was simple: put a tiny service on Google Cloud Run in a supported region, then make all AI calls go through that service.

```text
Client in Hong Kong
  -> Cloud Run service in supported GCP region
     -> Gemini API
     -> response back to client
```

It is not glamorous. It is a proxy. But it is a useful pattern.

## The problem

The client wants to talk to Gemini.

```text
client -> Gemini
```

That is the architecture I wanted. It is also the one that failed.

The reason was not code. It was service availability. The client environment was in a region where Gemini access was not available or not usable for my setup.

There are a few ways this kind of failure can show up:

- the API rejects the request because of location restrictions
- the service is not available for the account or region
- latency or routing behaves differently from what the SDK expects
- the same request works from another region but not from the client environment

The important part is that moving the call to a supported region fixes it.

So the client should not call Gemini directly. It should call my own endpoint.

## The shape of the solution

Cloud Run is a good fit for this because the service is small and stateless.

It only needs to do four things:

1. receive the AI request from my client
2. authenticate the client
3. call Gemini from a supported GCP region
4. stream or return the response

The result looks like this:

```text
┌────────────────────┐
│ Client / App        │
│ Hong Kong side      │
└─────────┬──────────┘
          │ HTTPS
          ▼
┌────────────────────┐
│ Cloud Run proxy     │
│ e.g. us-central1    │
│ or europe-west1     │
└─────────┬──────────┘
          │ Gemini SDK / REST
          ▼
┌────────────────────┐
│ Gemini API          │
└────────────────────┘
```

Cloud Run gives me a public HTTPS endpoint, managed TLS, autoscaling, logs, and a clean deployment story. I do not need to keep a VM alive just to forward API calls.

## Why not just use a VPN?

A VPN can work, but it is the wrong abstraction for this problem.

I do not want the whole machine or network to pretend it is somewhere else. I only need the AI request path to run from a supported region.

A Cloud Run proxy is narrower:

- only AI traffic goes through it
- the service can be locked down
- logs are in one place
- the API key stays server-side
- clients do not need to know anything about Gemini credentials

That last point matters. Once the proxy exists, clients can use my own small API instead of carrying Google credentials around.

## Minimal proxy design

I usually keep the first version painfully small.

A request body comes in:

```json
{
  "model": "gemini-2.5-flash",
  "prompt": "Explain why Redis timeouts happen in Rails."
}
```

The proxy turns that into a Gemini call and returns the text.

In FastAPI, the skeleton looks like this:

```python
import os
from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel
from google import genai

app = FastAPI()

client = genai.Client(api_key=os.environ["GEMINI_API_KEY"])
PROXY_TOKEN = os.environ["PROXY_TOKEN"]

class GenerateRequest(BaseModel):
    model: str = "gemini-2.5-flash"
    prompt: str

@app.post("/generate")
def generate(req: GenerateRequest, authorization: str | None = Header(None)):
    if authorization != f"Bearer {PROXY_TOKEN}":
        raise HTTPException(status_code=401, detail="unauthorized")

    response = client.models.generate_content(
        model=req.model,
        contents=req.prompt,
    )

    return {"text": response.text}
```

That is enough to prove the path works.

For production, I would add streaming, request IDs, timeouts, rate limits, and better error shaping. But I would not start there. First make the boring request work.

## Containerizing it

The container can be tiny.

```dockerfile
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080"]
```

`requirements.txt`:

```text
fastapi
uvicorn[standard]
google-genai
pydantic
```

Cloud Run expects the service to listen on port `8080`, so the command uses that.

## Deploying to Cloud Run

Pick a region where Gemini works for your account and project. I tend to choose something boring and well-supported, like `us-central1`, unless there is a latency reason to do otherwise.

```bash
gcloud run deploy gemini-proxy \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars GEMINI_API_KEY="$GEMINI_API_KEY",PROXY_TOKEN="$PROXY_TOKEN"
```

For a quick internal tool, `--allow-unauthenticated` plus a bearer token may be enough. For a stricter setup, I would remove public access and use IAM, IAP, or service-to-service authentication.

The important thing is that the Gemini API key stays inside Cloud Run. The outside client only gets the proxy token.

## Calling it from the client

The client no longer talks to Gemini. It talks to Cloud Run:

```bash
curl -s https://gemini-proxy-xxxxx-uc.a.run.app/generate \
  -H "Authorization: Bearer $PROXY_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "gemini-2.5-flash",
    "prompt": "Give me a short explanation of Cloud Run."
  }'
```

From the client point of view, this is just another HTTPS API.

That is the nice part. Once the proxy is working, the client code becomes simpler, not more complex. It does not need Gemini credentials. It does not care which region Cloud Run uses. It just sends AI requests to the gateway.

## Error handling matters

A proxy like this should not blindly forward every ugly provider error to the client.

There are three errors I care about most:

1. authentication failed between client and proxy
2. Gemini rejected or failed the request
3. the request timed out

I want those to be explicit.

```json
{
  "error": {
    "type": "gemini_request_failed",
    "message": "Gemini returned 429 rate limit",
    "request_id": "req_abc123"
  }
}
```

That `request_id` is worth adding early. When Cloud Run logs and the client both include the same ID, debugging becomes much less annoying.

## Streaming is the next step

The simple version returns one JSON response. That is fine for small prompts, but AI responses often feel bad without streaming.

The next version should support a streaming endpoint:

```text
POST /stream
```

The proxy streams tokens from Gemini back to the client as server-sent events or chunked HTTP.

The shape becomes:

```text
client opens request
  -> Cloud Run calls Gemini streaming API
     -> chunks flow back through Cloud Run
        -> client renders partial response
```

This matters for UX. A ten-second response feels much faster if the first tokens arrive after one second.

## Security notes

This is a small service, but it sits in front of an API that can cost money. Treat it like a real endpoint.

At minimum:

- require authentication from the client
- keep `GEMINI_API_KEY` only in Cloud Run secrets or environment variables
- set request body size limits
- set timeouts
- log request IDs, not full prompts, unless you are comfortable storing them
- add rate limits if more than one client will use it
- consider per-client tokens if multiple apps use the same proxy

The logging point is easy to miss. AI prompts often contain more private data than normal API requests. Do not casually dump them into Cloud Logging forever.

## What this pattern gives me

The proxy solves the region problem, but it also gives me a cleaner architecture.

Before:

```text
Every client needs to know how to call Gemini.
Every client needs credentials.
Every client has to handle provider errors.
```

After:

```text
Clients call one internal AI endpoint.
Gemini credentials stay server-side.
Provider-specific behavior is hidden behind the proxy.
```

That gives me room to change things later. If I want to switch models, add caching, add moderation, log usage, or route some requests to another provider, I can do it in the proxy without changing every client.

That is the real win. The region issue forced the proxy, but the proxy becomes useful for more than region routing.

## Final thoughts

This is not a complicated system. It is a Cloud Run service with a Gemini API key and a small HTTP interface.

But it turns an awkward regional availability problem into a normal engineering boundary.

The client does not need to know why Gemini is unavailable from Hong Kong. It does not need to care which Google region works. It just calls my AI gateway.

Sometimes the best infrastructure is not the clever thing. It is the small boring service that puts the weirdness in one place.
