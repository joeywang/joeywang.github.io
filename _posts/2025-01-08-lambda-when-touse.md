---
layout: post
title: "When AWS Lambda Makes Sense for a Single API Endpoint"
description: "A decision framework for when AWS Lambda fits a single API endpoint, and when a container or dedicated server is the better call instead."
date: "2025-01-08"
categories: [DevOps]
tags: [aws, devops, api, performance]
---

<audio controls preload="metadata" src="/assets/audio/lambda-when-touse-summary.ogg">
  Your browser does not support the audio element.
</audio>

Building one endpoint behind a Lambda function looks like overkill next to spinning up a container. Whether it actually is depends on traffic pattern, latency requirements, and how much operational overhead you're willing to carry for something that runs rarely.

## Why Lambda for one endpoint

- **Simplicity**: deploy and manage without provisioning a server.
- **Auto-scaling**: scales with demand, no capacity planning.
- **Cost at low traffic**: pay-per-invocation beats an idle instance.
- **AWS integration**: wires up cleanly to S3, DynamoDB, EventBridge.
- **Isolation**: one function, one responsibility, nothing else on the box.

The costs that come with it:

- **Cold starts**: added latency on functions that aren't called often.
- **15-minute execution limit**: hard ceiling on runtime.
- **Limited runtime control**: less room to customize the environment.
- **Observability**: tracing a request through a distributed serverless system is harder than through a single process.
- **Throughput ceiling**: high-traffic endpoints often do better on containers or a dedicated instance.

## Where it actually fits

**Low-traffic, utility-style endpoints.** A `/send-email` triggered by a contact form, or `/generate-thumbnail` on image upload. A form submits to API Gateway, which invokes a Lambda that sends through SES, or a photo upload triggers a Lambda that resizes and stores a thumbnail in S3. You pay only when the endpoint is actually used.

**Event-driven triggers.** A `/process-payment` handling a Stripe webhook, or `/new-user-welcome` on signup. Stripe posts to API Gateway, a Lambda updates the database and sends a confirmation. A new signup triggers a Lambda that creates a profile, sends a welcome email, and publishes to EventBridge for the CRM. Lambda fits event-driven flows naturally because the trigger and the function are already decoupled.

**MVPs and experiments.** A `/product-recommendations` endpoint calling a SageMaker model, or a `/beta-feedback` handler writing to DynamoDB. Low setup cost, nothing to maintain, fast to iterate.

**Backend-for-frontend slices.** A `/get-dashboard-data` endpoint that aggregates from RDS, a Redis cache, and an external notifications API into one response for a mobile app. One scalable function replaces backend aggregation logic that would otherwise live in the frontend.

## Where it doesn't

Skip Lambda when the endpoint is latency-sensitive and hit constantly, cold starts show up in user-facing latency at that point. Skip it for persistent connections, WebSockets or streaming don't fit the invoke-and-return model. Skip it for long-running, compute-heavy work that bumps against the 15-minute limit. And skip it if you need tight control over the runtime environment or local testing that mirrors production exactly.

## The decision

Low-traffic, event-driven, or throwaway endpoints: Lambda. High-throughput or low-latency endpoints, or anything with persistent state and long runtimes: a container or dedicated instance. The architecture should follow the traffic pattern, not the trend.
</content>
