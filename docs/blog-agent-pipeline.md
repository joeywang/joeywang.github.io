# Role-based blog agent pipeline

This is the operating model for turning Joey's ideas and source material into a verified blog post, promotion assets, and audio. The roles are bounded subagents, not additional Telegram bots.

## Principles

- The primary Hermes orchestrates and keeps the durable state.
- Each role receives only the context it needs and returns a structured handoff.
- Research claims carry source URLs and confidence; unverified claims do not enter the final article.
- Joey's voice, experience, opinions, and approval boundaries remain authoritative.
- No role publishes, posts socially, queues Buffer content, merges, or deploys without an explicit approval token.
- Secrets, customer data, credentials, private URLs, and unnecessary PII are never copied into public drafts.

## Pipeline

```text
Joey brief / notes / links
        |
        v
[1] Research scout (light)
        |
        v
[2] Article writer (high reasoning)
        |
        v
[3] Independent quality reviewer (fresh context)
        |
        v
[4] Humanizer + privacy/PII reviewer
        |
        v
[5] Publication verifier (light, gated)
        |
        +--> verified public URL
        |       |
        |       +--> [6] Social summary agent (light)
        |       |
        |       +--> [7] Voice summary agent (Piper TTS)
        |
        v
Joey approval gates: draft -> publish -> social/audio delivery
```

## Role contracts

### 1. Research scout — light

**Input:** topic, initial links, target audience, questions to answer.

**Work:** use web search/extraction to find primary sources, official documentation, release notes, benchmarks, and useful counterpoints. Do not write the article. Do not browse private systems unless explicitly scoped.

**Output:** `research/` handoff containing source URL, claim supported, quoted/derived evidence, date checked, confidence, and caveats. Flag sources that are project-reported or not independently verified.

**Recommended route:** DeepSeek free/OpenCode Zen; local Nemotron for simple extraction. Web tools do the retrieval; the model should not invent sources.

### 2. Article writer — high reasoning

**Input:** Joey's brief, personal experience, research handoff, and blog style rules.

**Work:** write the article in `_drafts/`, preserve Joey's first-person experience, distinguish fact from opinion, include practical examples, and avoid generic AI prose. Do not silently invent personal experiences, numbers, customer details, or outcomes.

**Output:** draft article plus a short claim/source map.

**Recommended route:** Claude Code CLI or Codex/high-reasoning model. Current Codex availability must be checked before routing.

### 3. Quality reviewer — independent

**Input:** full draft, research handoff, and acceptance checklist; not the writer's hidden reasoning.

**Work:** review technical accuracy, logical flow, usefulness, evidence, links, code examples, SEO metadata, and whether claims exceed the sources. Review all execution paths and edge cases in technical instructions.

**Output:** blocking issues, warnings, exact suggested fixes, and readiness verdict: `needs_revision`, `ready_for_privacy_review`, or `not_publishable`.

**Recommended route:** a separate Claude/Codex context from the writer. Never treat the writer's own self-review as independent review.

### 4. Humanizer + privacy/PII reviewer

**Input:** reviewed draft and Joey's known public voice preferences.

**Work:** remove AI slop, repetitive structures, fake certainty, invented anecdotes, unnecessary operational detail, credentials, customer identifiers, internal hostnames, private URLs, email addresses, phone numbers, and identifying personal data. Preserve genuine specificity when it is safe and useful. Run deterministic secret/PII checks in addition to model review.

**Output:** sanitized draft, redaction log, unresolved questions, and a final privacy verdict.

**Recommended route:** local Nemotron for bounded mechanical review plus the humanizer skill; deterministic scanners remain authoritative for obvious secrets/PII.

### 5. Publication verifier — light and gated

**Input:** sanitized draft and Joey's explicit publish approval.

**Work:** move the approved file from `_drafts/` to `_posts/`, run front-matter/build/link/secret checks, create a focused branch/PR, and verify the deployed URL only after merge/deployment. Leave unrelated drafts untouched.

**Output:** commit/PR, check results, canonical URL, deployment verification, and caveats.

**Hard boundary:** prepare and verify publication; do not merge or trigger sensitive deployment unless Joey's approval explicitly covers that action.

### 6. Social summary agent — light

**Input:** final article and verified canonical URL.

**Work:** create concise X/Twitter and expanded LinkedIn drafts grounded in the article. Include useful takeaways, not hype. Check character limits and remove sensitive details. Prepare Buffer drafts/queue payloads only when requested.

**Output:** `static/twitter-<slug>.md`, `static/linkedin-<slug>.md`, character counts, and a sanitized promotion note.

**Hard boundary:** generation is separate from posting. Posting or queueing requires explicit approval.

### 7. Voice summary agent — deterministic TTS

**Input:** final article or approved summary.

**Work:** generate a short spoken summary with Piper, store it under `assets/audio/`, add the verified audio player reference to the post, and check that the file is readable and within delivery limits.

**Output:** audio file, duration/format/size check, and the summary script used.

**Recommended route:** configured local Piper voice; no cloud model is necessary.

## Approval gates

| Gate | Required approval | Evidence before proceeding |
|---|---|---|
| Draft creation | Normal request to write | Joey brief and source boundary |
| Research complete | No extra approval | Source list and claim map |
| Draft -> review | Automatic | Draft exists and parses |
| Review -> privacy | Reviewer verdict allows it | No blocking quality issues |
| Privacy -> publication | Explicit Joey publish approval | Sanitized draft + redaction log |
| Publication -> social/audio | Explicitly requested or approved | Canonical URL and deployment check |
| Social -> external posting | Separate explicit approval | Final copy and target channels |

## Durable artifacts

For each article, keep only useful state:

- blog repository: draft/post, research handoff, review, sanitized version, social drafts, audio;
- `re-work`: decision, source links, current state, GitHub/Jira references, evidence, and next action;
- Life OS/QMD: reusable study/resource notes when the article has durable learning value.

Never store secrets, raw private conversations, or unnecessary PII in these artifacts.

## Suggested invocation

```text
/blog-pipeline <topic or notes>
```

The orchestrator should return a compact status table after every stage and stop at the next approval gate rather than continuing silently.
