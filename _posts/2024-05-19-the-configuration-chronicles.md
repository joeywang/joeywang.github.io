---
layout: post
title: "Config Approaches: Files, Env Vars, and Config Servers"
description: "A comparison of YAML config files, Rails encrypted credentials, environment variables, and centralized config servers, with the trade-offs of each approach."
date: 2024-05-19 00:00 +0000
categories: [DevOps, Security]
tags: [devops, security, docker]
---
<audio controls preload="metadata" src="/assets/audio/the-configuration-chronicles-summary.ogg">
  Your browser does not support the audio element.
</audio>


Every app needs the same handful of settings to change between environments: database host, API keys, feature flags. The question isn't whether to externalize them, it's which mechanism fits which kind of setting. Getting this wrong looks like committing a local database password to production, or a config server outage that takes down every service that depends on it at startup.

## Config files (YAML)

YAML is readable, works across languages, and handles nested settings well:

```yaml
database:
  host: ${DB_HOST:-localhost}
  port: ${DB_PORT:-5432}
  name: ${DB_NAME:-codecraft_db}

api:
  timeout: 30
  retry_attempts: 3

feature_flags:
  new_checkout: true
  beta_search: false
```

Environment variable interpolation (`${DB_HOST:-localhost}`) keeps the same file usable across environments. Reading it in Python is a few lines:

```python
import yaml
import os

def load_config():
    with open('config.yml', 'r') as file:
        config = yaml.safe_load(file)

    for section, settings in config.items():
        for key, value in settings.items():
            if isinstance(value, str) and value.startswith('${') and value.endswith('}'):
                env_var = value[2:-1].split(':-')[0]
                default = value[2:-1].split(':-')[1] if ':-' in value else None
                config[section][key] = os.environ.get(env_var, default)

    return config
```

The cost is that YAML files need to exist and stay in sync per environment, and any sensitive value sitting in one still needs separate protection.

## Encrypted credentials (Rails)

Rails' encrypted credentials keep secrets in the repo, encrypted, decrypted only with a key you keep outside version control:

```ruby
# config/credentials.yml.enc (encrypted content)
aws:
  access_key_id: AKIAIOSFODNN7EXAMPLE
  secret_access_key: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY

if Rails.application.credentials.aws[:access_key_id].present?
  puts "AWS configured"
end
```

This keeps secrets close to the app and out of plaintext, but it's Rails-specific, and key management (rotating `master.key`, distributing it to every environment that needs it) is now a process you own.

## A config server (Spring Cloud Config and similar)

Once you're running several services, a config server centralizes settings and can push updates without a redeploy:

```java
@SpringBootApplication
@EnableConfigServer
public class ConfigServerApplication {
    public static void main(String[] args) {
        SpringApplication.run(ConfigServerApplication.class, args);
    }
}

@Configuration
@ConfigurationProperties(prefix = "database")
public class DatabaseConfig {
    private String url;
    private String username;
}
```

Centralization brings versioning and audit trails, but it also turns the config server into a dependency every other service now needs at startup. If it's down, so is everything that reads from it.

## OS-native storage (Windows Registry)

For a Windows desktop app, the registry is the native option:

```csharp
using Microsoft.Win32;

class ConfigManager
{
    public static string GetDatabaseUrl()
    {
        using (RegistryKey key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\CodeCraft"))
        {
            if (key != null)
            {
                Object o = key.GetValue("DatabaseUrl");
                if (o != null) return o.ToString();
            }
        }
        return "default_url";
    }
}
```

It's native and can lean on OS-level permissions, but it only works on Windows and doesn't version control the way a text file does.

## Environment variables (containers)

For containerized apps, env vars are the common denominator:

```dockerfile
FROM node:14
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
CMD ["node", "server.js"]
```

```yaml
# docker-compose.yml
services:
  web:
    build: .
    environment:
      - DATABASE_URL=postgres://user:pass@db:5432/codecraft
      - API_KEY=${API_KEY}
  db:
    image: postgres
```

```javascript
const dbUrl = process.env.DATABASE_URL || 'postgres://localhost/codecraft';
const apiKey = process.env.API_KEY;

if (!apiKey) {
  console.error('API key not set! Exiting...');
  process.exit(1);
}
```

Env vars are simple and language-agnostic, but they're flat strings, so anything structured (nested config, lists) has to be encoded around that limitation, and a large number of them gets unwieldy fast.

## What actually matters

Pick the mechanism by what you're storing and who reads it, not by which one looks most impressive:

- Non-secret settings that vary by environment: YAML or env vars, whichever your deployment tooling already expects.
- Secrets: never in plaintext, never in version control. Rails credentials, a vault, or your cloud provider's secret manager, not a `.env` file checked in by accident.
- Cross-service settings shared by many deployables: only worth a config server once you have enough services that keeping N copies in sync is worse than the server being a dependency.
- Validate configuration at startup and fail loudly if something required is missing; a missing API key should not surface as a 500 an hour later.

Most real systems mix two or three of these: YAML for general settings, encrypted credentials for secrets, environment variables for what changes per deployment. That's not indecision, it's matching the tool to what's actually being stored.
