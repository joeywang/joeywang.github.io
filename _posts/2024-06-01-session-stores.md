---
layout: post
title:  "Rails Session Stores: Cookie, ActiveRecord, and Redis"
description: "A comparison of Rails session stores: cookie sessions, ActiveRecord, and Redis, including how to share sessions across subdomains and multiple apps."
date:   2024-06-01 14:41:26 +0100
categories: [Rails]
tags: [rails, ruby, security, redis]
---
<audio controls preload="metadata" src="/assets/audio/session-stores-summary.ogg">
  Your browser does not support the audio element.
</audio>


Rails supports several ways to store session data, and they trade off differently on security, capacity, and how much control you have over ending a session early.

## Cookie Session Store

The cookie session store encodes and encrypts session information into a cookie saved on the client's side. It's easy to manage: every piece of session data travels with each request, so stateless app pods can handle authentication and authorization without a shared session store. The encryption key changes with each response to keep it secure.

### Pros

- **Easy to Implement**: Straightforward to set up with Ruby on Rails.
- **Complete Information**: Includes all necessary session data.
- **No Server Cost**: Information is stored client-side, not incurring additional server costs.

### Cons

- **Security Risks**: Information is client-side, and despite encryption, it could potentially be compromised.
- **Key Rotation Issues**: If the encryption key is changed on the server, existing keys become invalid.
- **Cookie Size Limitations**: Limited storage capacity for session data.
- **No Session Expiry Control**: There's no straightforward way to forcibly end a user's session.

If you require more control over session management, consider using a Redis or ActiveRecord store.

## Shared Session Between Apps with Cookie Session Store

For applications that require shared sessions, such as subdomains that need to access the same session data, the cookie session store can be configured accordingly.

### Requirements for Shared Sessions

- **Subdomain Cookie Access**: Ensures that different subdomains (e.g., a.example.com and b.example.com) can share session data.
- **Consistent Encryption Key**: All systems must use the same encryption key to maintain session integrity.
- **Uniform Session Key**: The cookie key must be consistent across all applications.

### Server Solution for Shared Sessions

- **Unified Redis Server**: All application servers connect to the same Redis server, for example, `rds://redis1.db/1`.
- **Shared Session Key**: Use a common session key, such as `example_session`, to prevent overwriting between apps.

### Considerations

- **Avoid Overwrites**: Ensure that setting a `user_id` in one app does not conflict with another app's `user_id` if they represent different entities.

## ActiveRecord Store into the DB

Another option for session management is storing session data directly in the database using ActiveRecord. This method provides a centralized location for session data, which can be beneficial for applications that require high levels of session data management and control.

## Redis Store as Cache

Using Redis as a cache for session data offers high performance and scalability. It's particularly useful for applications with high traffic or those that require quick access to session data.

## Which one to use

Cookie sessions are the default for a reason: no server-side storage, no extra infrastructure. Reach for ActiveRecord or Redis once you need to forcibly end a session, store more than a cookie can hold, or share session state across more services than a shared encryption key comfortably supports.
