---
layout: post
title: "Rails Secrets: Credentials, 1Password, and Cloud Vaults"
description: "A rundown of Rails credentials, environment variables, 1Password CLI, and cloud secret managers like AWS Secrets Manager and Vault, and when to use each."
date:   2024-05-21 14:41:26 +0100
categories: [Rails, Security]
tags: [rails, security, aws, devops]
---
<audio controls preload="metadata" src="/assets/audio/rails-config-secrets-summary.ogg">
  Your browser does not support the audio element.
</audio>


Rails gives you several ways to keep configuration and secrets out of your codebase and version control. Which one fits depends on how many environments you're managing and whether the thing you're storing is a plain setting or something that needs to stay secret.

## 1. Rails Credentials

Rails 5.2 introduced the `credentials` system for storing sensitive information securely.

### Key Features:
- Uses `credentials.yml.enc` for storing encrypted credentials
- Requires `master.key` for decryption
- Supports environment-specific credentials

### Best Practices:
- Use `Rails.credentials` to access encrypted credentials
- Never commit `credentials.yml.enc` or `master.key` to version control
- Rotate secrets regularly and update the `master.key` periodically

### Example Usage:
```ruby
# Accessing a secret
secret_key = Rails.credentials.secret_key_base

# Accessing environment-specific secrets
production_api_key = Rails.credentials.production[:api_key]
```

## 2. Environment Variables

Environment variables are a common and flexible way to manage configuration settings across different environments.

### Best Practices:
- Use a `.env` file to store environment variables locally
- Never commit `.env` files to version control
- Use the `dotenv` gem to load environment variables in development

### Example Usage:
```ruby
# Gemfile
gem 'dotenv-rails', groups: [:development, :test]

# Accessing an environment variable
api_key = ENV['API_KEY']
```

## 3. 1Password CLI for Local Development

For teams using 1Password, the CLI is a solid way to manage secrets in local development without emailing them around.

### Setup:
1. Install 1Password CLI
2. Authenticate with your 1Password account
3. Create a project-specific vault in 1Password

### Best Practices:
- Store development secrets in a dedicated 1Password vault
- Use 1Password CLI to fetch secrets on demand
- Integrate 1Password CLI with your development workflow

### Example Usage:
```bash
# Fetch a secret and export it as an environment variable
export API_KEY=$(op item get "API Key" --fields label=secret)

# Use in your Rails application
api_key = ENV['API_KEY']
```

## 4. Cloud-based Secret Management

For production environments, cloud-based secret management services give you access control and rotation without building it yourself.

### Options:
- AWS Secrets Manager
- Azure Key Vault
- Google Cloud Secret Manager

### Best Practices:
- Use IAM roles and policies to control access
- Enable automatic secret rotation
- Monitor access logs for unusual activity

### Example Usage with AWS Secrets Manager:
```ruby
require 'aws-sdk-secretsmanager'

client = Aws::SecretsManager::Client.new(region: 'us-west-2')

begin
  get_secret_value_response = client.get_secret_value(secret_id: "MySecret")
rescue Aws::SecretsManager::Errors::DecryptionFailure => e
  # Handle decryption errors
rescue Aws::SecretsManager::Errors::InternalServiceError => e
  # Handle AWS service errors
end

secret = JSON.parse(get_secret_value_response.secret_string)
```

## 5. Vault by HashiCorp

HashiCorp Vault works across environments and platforms, not just Rails.

### Key Features:
- Centralized secret management
- Dynamic secrets
- Encryption as a service

### Best Practices:
- Use Vault's access control policies
- Enable audit logging
- Implement secret rotation

### Example Usage with Ruby:
```ruby
require 'vault'

Vault.address = "http://127.0.0.1:8200"
Vault.token   = "abcd-1234"

secret = Vault.logical.read("secret/my-secret")
api_key = secret.data[:api_key]
```

## 6. Config Servers

For microservices architectures or distributed systems, a dedicated config server centralizes configuration management.

### Options:
- Spring Cloud Config
- Consul
- etcd

### Best Practices:
- Secure the config server with authentication and authorization
- Use encryption for sensitive configurations
- Implement a reliable update and rollback mechanism

### Example Usage with Spring Cloud Config (for Rails apps using JRuby):
```ruby
# config/application.rb
require 'jruby/java'
java_import 'org.springframework.cloud.config.client.ConfigServicePropertySourceLocator'

config = ConfigServicePropertySourceLocator.new
config.setUri(java.net.URI.new("http://config-server:8888"))
properties = config.locate(nil)

# Access configurations
database_url = properties.getProperty("database.url")
```

## Which one to use

Rails credentials cover most single-app cases without adding a dependency. Reach for 1Password CLI when the team needs shared local secrets without emailing them around. Reach for AWS, Azure, or GCP secret managers, or Vault, once you need centralized rotation, audit logs, and access control across multiple services, not just one Rails app. What doesn't change across any of these: no secret in version control, least-privilege access, and rotation on a schedule, not just after an incident.
