---
layout: post
title: "Tightening Hermes Secrets with Bitwarden"
date: 2026-07-31 22:44:18 +0100
author: "Joey Wang"
description: "A practical walkthrough for moving Hermes API keys out of local env files and into Bitwarden Secrets Manager, with verification and cleanup steps."
tags: [ai, agents, security, hermes, bitwarden, secrets]
categories: [AI, Security, Engineering]
---

# Tightening Hermes secrets with Bitwarden

I recently tightened up my Hermes setup by moving the provider and tool tokens out of the local `.env` file and into Bitwarden Secrets Manager.

This was not a big architectural migration. It was the kind of security improvement that is easy to postpone because everything already works. The agent can search the web, call APIs, talk through Telegram, run scheduled jobs, and operate tools. The problem is that those capabilities usually mean one thing: there are API keys somewhere.

For a long-running AI agent, that "somewhere" matters.

A local `.env` file is convenient. It is also easy to back up accidentally, inspect casually, copy into a debug session, or leave with too many secrets after the system has grown. I wanted Hermes to keep only one bootstrap credential locally and hydrate the rest from a real secret manager at startup.

The final shape looks like this:

```text
Hermes process
  -> reads BWS_ACCESS_TOKEN from local .env
  -> asks Bitwarden Secrets Manager for the Hermes project
  -> hydrates provider/tool env vars into the process
  -> tools and scripts read normal env var names
```

That keeps the application interface boring. Scripts still use `GOOGLE_API_KEY`, `FIRECRAWL_API_KEY`, or `MY_APP_API_TOKEN`. The storage and rotation story gets better.

This post is the step-by-step version.

## Starting point

Before the migration, my Hermes host had the usual kind of setup:

```text
~/.hermes/.env
~/.hermes/config.yaml
```

The `.env` file contained provider and integration credentials. The config also had a few local custom-provider `api_key` values. None of this is unusual. Most self-hosted agents start this way because it is simple and debuggable.

But over time the list grows:

```text
GOOGLE_API_KEY
TELEGRAM_BOT_TOKEN
FIRECRAWL_API_KEY
TAVILY_API_KEY
OPENROUTER_API_KEY
SENTRY_AUTH_TOKEN
BUFFER_ACCESS_TOKEN
MY_APP_API_TOKEN
```

That is the point where I prefer to move from "a file with keys" to "a file with one bootstrap token".

## Step 1: enable Hermes' Bitwarden integration

Hermes has a native secrets command group:

```bash
hermes secrets --help
```

For Bitwarden:

```bash
hermes secrets bitwarden --help
```

The built-in setup flow handles the normal pieces: installing/verifying the `bws` CLI, storing the machine-account token, selecting the project, and enabling the integration.

```bash
hermes secrets bitwarden setup
```

On a headless server, I prefer running this directly over SSH rather than pasting the machine-account token into chat. The token is the one secret that must remain local, because Hermes needs it before it can fetch anything else.

After setup, check the status:

```bash
hermes secrets bitwarden status
```

A healthy setup should look conceptually like this:

```text
Bitwarden Secrets Manager
  Enabled:           yes
  Token env var:     BWS_ACCESS_TOKEN
  Token in env:      yes
  Token validation:  passed
  Project ID:        <project-id>
  bws binary:        ~/.hermes/bin/bws
```

I also run a dry sync:

```bash
hermes secrets bitwarden sync
```

That prints the secret names Hermes would export on the next invocation, without printing the values.

## Step 2: decide what belongs in Bitwarden

The rule I used was simple:

- keep `BWS_ACCESS_TOKEN` local;
- move provider keys, API tokens, bot tokens, and tool credentials into Bitwarden;
- replace direct `api_key` values in config with env-var references;
- do not move non-secrets just because they live near secrets.

You can find candidates with a small read-only scan that prints names only:

```bash
python3 - <<'PY'
from pathlib import Path

home = Path.home() / '.hermes'
credential_suffixes = (
    '_API_KEY',
    '_TOKEN',
    '_SECRET',
    '_PASSWORD',
    '_KEY',
)

for line in (home / '.env').read_text().splitlines():
    stripped = line.strip()
    if not stripped or stripped.startswith('#') or '=' not in stripped:
        continue
    name = stripped.split('=', 1)[0].strip()
    if name.endswith(credential_suffixes):
        print(name)
PY
```

That deliberately avoids printing values. For this migration, the candidates were names like:

```text
GOOGLE_API_KEY
TELEGRAM_BOT_TOKEN
FIRECRAWL_API_KEY
TAVILY_API_KEY
SENTRY_AUTH_TOKEN
BUFFER_ACCESS_TOKEN
OPENROUTER_API_KEY
MY_APP_API_TOKEN
```

If your `config.yaml` contains direct API keys, inspect the paths rather than dumping values:

```bash
python3 - <<'PY'
from pathlib import Path
import yaml

cfg = yaml.safe_load((Path.home() / '.hermes/config.yaml').read_text())
secretish = {'api_key', 'token', 'secret', 'password'}

def walk(obj, path=''):
    if isinstance(obj, dict):
        for key, value in obj.items():
            next_path = f'{path}.{key}' if path else str(key)
            if str(key).lower() in secretish and value:
                print(next_path)
            walk(value, next_path)
    elif isinstance(obj, list):
        for index, value in enumerate(obj):
            walk(value, f'{path}[{index}]')

walk(cfg)
PY
```

For local OpenAI-compatible model servers, I had config entries like:

```yaml
fallback_providers:
  - provider: custom
    model: qwen2.5-coder-3b
    base_url: http://127.0.0.1:18081/v1
    api_mode: chat_completions
    api_key: dummy-local-key
```

Even if the value is only a dummy local key, I prefer not to train myself to leave `api_key` literals in config. I moved those to named env vars too.

## Step 3: create the secrets in Bitwarden

The safest manual path is the Bitwarden web UI:

1. Open Bitwarden Secrets Manager.
2. Select the Hermes project.
3. Create one secret per env var.
4. Use the exact env var name as the secret key.
5. Paste the existing value from `.env`.

For example:

```text
Secret key: GOOGLE_API_KEY
Secret value: <existing value>
```

If the machine account has write permission, you can also use `bws`:

```bash
~/.hermes/bin/bws secret create GOOGLE_API_KEY '<value>' '<project-id>' \
  --note 'Used by Hermes Google/Gemini provider and tools'
```

I do not like passing real secret values as command arguments unless I control the shell history and process environment carefully. For one-off migrations, the web UI is less error-prone.

If you automate it, make sure the script never prints values. It should print only names and actions:

```text
created: GOOGLE_API_KEY
created: TELEGRAM_BOT_TOKEN
already_present: OPENROUTER_API_KEY
```

Also expect rate limits. Bitwarden may return:

```text
429 Too Many Requests
```

If that happens, sleep and retry. Do not treat it as a failed secret value.

## Step 4: point Hermes config at env vars

For config entries that had direct keys, change them to env-var references.

Before:

```yaml
custom_providers:
  - name: local-qwen-coder
    base_url: http://127.0.0.1:18081/v1
    model: qwen2.5-coder-3b
    api_mode: chat_completions
    api_key: dummy-local-key
```

After:

```yaml
custom_providers:
  - name: local-qwen-coder
    base_url: http://127.0.0.1:18081/v1
    model: qwen2.5-coder-3b
    api_mode: chat_completions
    api_key: ${LOCAL_QWEN_CODER_API_KEY}
```

Do the same anywhere else Hermes expects a configured `api_key` value:

```yaml
fallback_providers:
  - provider: custom
    model: local-gemma4
    base_url: http://127.0.0.1:18080/v1
    api_mode: chat_completions
    api_key: ${LOCAL_GEMMA4_API_KEY}
```

Then enable Bitwarden in Hermes config:

```yaml
secrets:
  bitwarden:
    enabled: true
    project_id: <project-id>
```

I usually make these edits with `hermes config edit` or a small script that preserves the rest of the file as much as possible. Avoid a full YAML rewrite if your config has a lot of comments or hand-formatting.

## Step 5: remove migrated keys from `.env`

Only remove a key from `.env` after it exists in Bitwarden and `hermes secrets bitwarden sync` can see it.

Target end state:

```text
BWS_ACCESS_TOKEN=<machine-account-token>
```

That token is the bootstrap. Everything else should come from Bitwarden.

A cautious cleanup script can remove only keys known to exist in Bitwarden:

```bash
python3 - <<'PY'
from pathlib import Path

home = Path.home() / '.hermes'
env_path = home / '.env'

migrated = {
    'GOOGLE_API_KEY',
    'TELEGRAM_BOT_TOKEN',
    'FIRECRAWL_API_KEY',
    'TAVILY_API_KEY',
    'OPENROUTER_API_KEY',
    'SENTRY_AUTH_TOKEN',
    'BUFFER_ACCESS_TOKEN',
    'MY_APP_API_TOKEN',
}

new_lines = []
for line in env_path.read_text().splitlines():
    stripped = line.strip()
    if stripped and not stripped.startswith('#') and '=' in stripped:
        name = stripped.split('=', 1)[0].strip()
        if name in migrated:
            continue
    new_lines.append(line)

env_path.write_text('\n'.join(new_lines).rstrip() + '\n')
PY
```

Then check what credential-shaped names remain:

```bash
python3 - <<'PY'
from pathlib import Path

suffixes = ('_API_KEY', '_TOKEN', '_SECRET', '_PASSWORD', '_KEY')
for line in (Path.home() / '.hermes/.env').read_text().splitlines():
    stripped = line.strip()
    if stripped and not stripped.startswith('#') and '=' in stripped:
        name = stripped.split('=', 1)[0].strip()
        if name.endswith(suffixes):
            print(name)
PY
```

For my setup, the only remaining credential-shaped name was:

```text
BWS_ACCESS_TOKEN
```

That is the desired result.

## Step 6: verify Hermes can hydrate secrets

Run:

```bash
hermes secrets bitwarden sync
```

You should see names, not values:

```text
Bitwarden Secrets Manager: applied 13 secrets

Name                     Action
BUFFER_ACCESS_TOKEN      would export
FIRECRAWL_API_KEY        would export
GOOGLE_API_KEY           would export
OPENROUTER_API_KEY       would export
MY_APP_API_TOKEN      would export
TELEGRAM_BOT_TOKEN       would export
```

Then check Hermes config:

```bash
hermes config check
```

And status:

```bash
hermes status
```

The useful thing in `hermes status` is not the key value. It is that providers and integrations show as configured after Bitwarden hydration:

```text
OpenRouter       ✓
Google / Gemini  ✓
Firecrawl        ✓
Tavily           ✓
Telegram         ✓ configured
```

If you are running Hermes through a gateway process, restart the gateway after migration. The current process may not inherit newly hydrated values until the next Hermes invocation.

```bash
hermes gateway restart
```

Or, if you run it through systemd/docker, restart the service in the way you normally do.

## Step 7: test one real integration

A secret migration is not finished until at least one real call works.

For example, I can use a small application API smoke test. The token lives in Bitwarden as `MY_APP_API_TOKEN`, but the test code reads it like a normal env var.

```bash
python3 - <<'PY'
import json
import os
import urllib.request
import urllib.error

url = 'https://my-app.example.com/api/health'
token = os.environ['MY_APP_API_TOKEN']

request = urllib.request.Request(
    url,
    headers={
        'X-AUTH-METHOD': 'token',
        'X-API-TOKEN': token,
        'Accept': 'application/vnd.api+json',
        'Content-Type': 'application/vnd.api+json',
        'User-Agent': 'Hermes admin API smoke test',
    },
)

try:
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = json.loads(response.read().decode('utf-8'))
        print('status:', response.status)
        print('content_type:', response.headers.get('Content-Type'))
        print('records:', len(payload.get('data', [])))
        if payload.get('data'):
            first = payload['data'][0]
            print('first_type:', first.get('type'))
            print('first_id:', first.get('id'))
except urllib.error.HTTPError as error:
    print('status:', error.code)
    print(error.read().decode('utf-8')[:500])
    raise
PY
```

The endpoint expects JSON:API headers even for `GET`. Without this header:

```http
Content-Type: application/vnd.api+json
```

it returns:

```text
415 unsupported_content_type
```

With the correct headers and Bitwarden-hydrated token, the request should return `200` and a small JSON response.

That kind of smoke test is useful after any future API deployment. It proves both halves of the setup:

- Hermes can hydrate the token securely.
- The deployed API still accepts the token and returns the expected shape.

## Step 8: commit the safe config change, not the secrets

After the migration, the only code/config change worth committing is the non-secret config wiring:

```bash
git diff -- config.yaml
```

The diff should show env-var references, not secret values:

```diff
-    api_key: dummy-local-key
+    api_key: ${LOCAL_QWEN_CODER_API_KEY}
```

Run a secret scan over staged changes if you have one:

```bash
git add config.yaml
git commit -m "Configure Hermes Bitwarden secret refs"
```

In my case, the staged secret scan passed and the commit only changed `config.yaml`.

Do not commit `.env`. Do not commit generated migration scripts if they contain secret-handling assumptions you do not want to maintain. Keep the durable part small: Bitwarden is the source of truth, Hermes config names the variables, and `.env` holds only the bootstrap token.

## Failure modes I hit

### The machine account could read but not write

At first, `bws secret list` worked but `bws secret create` failed with a `404 Resource not found` response. In practice that meant the machine account could read the project but could not create secrets in it.

The fix was to update the machine account permissions in Bitwarden Secrets Manager. After that, a harmless write test succeeded:

```bash
~/.hermes/bin/bws secret create HERMES_MIGRATION_WRITE_TEST test '<project-id>'
~/.hermes/bin/bws secret delete '<secret-id>'
```

### Bitwarden rate-limited bulk creation

During migration, Bitwarden returned:

```text
429 Too Many Requests
```

The right response is boring: sleep and retry. Do not rerun a script blindly if it might create duplicates. List existing secret names first, skip those, then create only missing ones.

### Current processes may still have old env

`hermes secrets bitwarden sync` tells you what a new Hermes invocation will pick up. A long-running gateway may need a restart before its child processes inherit the new secret set.

## The security trade-off

This setup does not make secrets magically disappear. It moves the risk to a smaller and more deliberate place.

Before:

```text
local .env contains every provider key
```

After:

```text
local .env contains one bootstrap token
Bitwarden contains provider and tool secrets
Hermes hydrates env vars at startup
```

That is easier to audit. It is easier to rotate one provider key without editing server files. It is harder to accidentally publish a pile of credentials in a config diff. It also gives the agent a cleaner boundary: use the env var, never display the value.

For an AI agent that can run commands, call APIs, and keep background workflows alive, this is the kind of boring security work I want more of. Not a new capability. Just less loose credential material lying around.
