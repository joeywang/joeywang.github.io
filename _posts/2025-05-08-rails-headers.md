---
title: "Custom HTTP Headers in Rails: Picking the Right Format"
date: 2025-05-08
description: "Rails normalizes headers to HTTP_-prefixed names, which decides whether Accept, a legacy X- prefix, or a plain name is right for a custom API header."
tags: [rails, http, api, security]
categories: [Rails]
---

When designing an API in Rails, you often need to pass custom metadata. A common case is an alternative authentication mechanism, like an API token, sent in a header. But which format is correct?

* `HTTP_X_AUTH_METHOD`
* `X-AUTH-METHOD`
* `ACCEPT`

## How Rails Reads HTTP Headers

When a client sends an HTTP request, the webserver (like Puma) and Rack normalize the headers before your application sees them. The rules are:

1. Prepend `HTTP_` to the header name.
2. Convert all hyphens (`-`) to underscores (`_`).
3. Uppercase the entire name.

If a client sends `Auth-Method: token`, your Rails controller reads it as `request.headers['HTTP_AUTH_METHOD']`. That one translation step is the key to debugging and understanding any custom header.

## Deconstructing the Header Options

<audio controls preload="metadata" src="/assets/audio/rails-headers-summary.ogg">
  Your browser does not support the audio element.
</audio>

### `ACCEPT`
The `Accept` header has a single, well-defined purpose: content negotiation. The client uses it to tell the server what content format it can understand.

* **Example:** `Accept: application/json` tells the server, "I want a JSON response." `Accept: text/html` says, "I want a full HTML page."
* **Verdict:** Never use `Accept` for authentication. Overloading it for a custom purpose violates the HTTP specification, breaks caching, and will confuse other developers and tools that rely on its standard behavior.

### `X-AUTH-METHOD` (the "X-" prefix)
The `X-` prefix was historically used to signify a non-standard, "experimental" header, to avoid clashes with future standard HTTP headers.

That practice was deprecated in 2012 by RFC 6648. It became a problem because many `X-` headers (like `X-Forwarded-For`) became de facto standards, making a later transition to a standard header without the `X-` painful.

* **Verdict:** The `X-` prefix is legacy. It works, but avoid it in new applications. It signals an outdated design.

### A descriptive name
The current best practice is a header named descriptively, with no special prefix. If you want to specify an authentication method, `Auth-Method` is a good name.

* **Client sends:** `Auth-Method: token`
* **Rails accesses:** `request.headers['HTTP_AUTH_METHOD']`
* **Verdict:** This is the recommended approach. It's clean, compliant with modern standards, and self-documenting.

## The Winner and Why

| Client Sends | Rails Accesses Via | Purpose | Recommendation |
| :--- | :--- | :--- | :--- |
| `Accept: token` | `request.headers['HTTP_ACCEPT']` | Content negotiation | Wrong. Do not use. |
| `X-Auth-Method: token` | `request.headers['HTTP_X_AUTH_METHOD']` | Custom (legacy) | Avoid. Deprecated practice. |
| `Auth-Method: token` | `request.headers['HTTP_AUTH_METHOD']` | Custom (modern) | Correct. Use this. |

A simple name like `Auth-Method`, with no prefix, keeps the API clear and aligned with current standards.
