---
layout: post
title: "React Dev Proxy Options: package.json vs http-proxy-middleware"
description: "Two ways to avoid CORS errors in local React development: the package.json proxy field for one backend, or http-proxy-middleware for several."
date: "2025-02-09"
categories: [Engineering]
tags: [react, javascript, networking]
---

<audio controls preload="metadata" src="/assets/audio/nodejs-proxy-summary.ogg">
  Your browser does not support the audio element.
</audio>

A React frontend on `localhost:3000` calling a backend on `localhost:5000` runs into CORS the moment the browser checks response headers for `Access-Control-Allow-Origin` and doesn't find a match. The fix during development isn't to configure CORS headers on the backend, it's to make the browser think there's only one origin: proxy the requests through the dev server.

## The `proxy` field in package.json

For a single backend, this is the entire setup:

```json
{
  "name": "my-react-app",
  "scripts": {
    "start": "react-scripts start"
  },
  "proxy": "http://localhost:5000"
}
```

Any request that doesn't match a static asset in `public/` gets forwarded to `http://localhost:5000` with the path appended. Your components just call relative paths:

```javascript
fetch('/api/users')
  .then(response => {
    if (!response.ok) throw new Error(`HTTP error! status: ${response.status}`);
    return response.json();
  })
  .then(setUsers)
  .catch(setError);
```

It has real limits: one target only, no path rewriting, and it only applies to `react-scripts start`, not the production build. For production you still need Nginx, Apache, or another reverse proxy in front of the static files.

## http-proxy-middleware for anything more complex

Multiple backends, path rewriting, or request/response hooks need `http-proxy-middleware`:

```bash
npm install http-proxy-middleware --save-dev
```

Create `src/setupProxy.js` - `react-scripts` picks it up automatically:

```javascript
const { createProxyMiddleware } = require('http-proxy-middleware');

module.exports = function(app) {
  app.use(
    '/api',
    createProxyMiddleware({
      target: 'http://localhost:5000',
      changeOrigin: true,
      logger: console,
    })
  );

  app.use(
    '/auth',
    createProxyMiddleware({
      target: 'https://auth.staging.dev.com',
      changeOrigin: true,
      pathRewrite: {
        '^/auth': '',
      },
      secure: false, // dev only, self-signed certs
      logger: console,
    })
  );
};
```

`changeOrigin: true` rewrites the Host header to match the target, which most virtual-hosted backends require. `pathRewrite` strips or rewrites the prefix before forwarding, so `/auth/login` becomes `/login` on the target. `secure: false` skips TLS verification and should never leave your laptop.

Calls now target whichever context path you defined:

```javascript
fetch('/api/users')      // -> http://localhost:5000/api/users
fetch('/auth/login', { method: 'POST' })  // -> https://auth.staging.dev.com/login
```

## Which one

Use the `proxy` field when there's one backend and no path games to play. Reach for `http-proxy-middleware` the moment you need a second target, a rewritten path, or custom request handling. Either way, it's a development convenience: production traffic still needs a real reverse proxy in front of it.
