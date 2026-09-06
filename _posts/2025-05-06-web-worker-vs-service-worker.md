---
layout: post
title: "Web Workers vs Service Workers: What Each One Is For"
description: "The difference between Web Workers and Service Workers: one offloads CPU work, the other intercepts network requests, and most apps eventually need both."
date: 2025-05-06
categories: [Engineering]
tags: [javascript, frontend, performance]
---

<audio controls preload="metadata" src="/assets/audio/web-worker-vs-service-worker-summary.ogg">
  Your browser does not support the audio element.
</audio>

JavaScript is single-threaded: a heavy computation on the main thread freezes the UI, stops animations, and leaves the page unresponsive. Two browser APIs solve this, but they solve different problems, and confusing them is common.

## Web Workers: offloading computation

A Web Worker runs a script on a background thread, entirely separate from the UI thread. It's for CPU-intensive work: processing a large array, complex calculations, image or video processing, real-time audio analysis.

**Main thread (`main.js`):**

```javascript
const primeWorker = new Worker('prime-worker.js');

primeWorker.onmessage = (event) => {
  const primes = event.data;
  document.getElementById('result').textContent = `Finished. Found ${primes.length} primes.`;
};

primeWorker.postMessage({ command: 'findPrimes', upTo: 10000000 });
// This line runs immediately; the main thread stays responsive.
```

**Worker (`prime-worker.js`).** No DOM access here:

```javascript
self.onmessage = (event) => {
  const { command, upTo } = event.data;
  if (command === 'findPrimes') {
    self.postMessage(findPrimes(upTo));
  }
};

function findPrimes(max) {
  const isPrime = new Array(max + 1).fill(true);
  isPrime[0] = isPrime[1] = false;
  for (let i = 2; i * i <= max; i++) {
    if (isPrime[i]) {
      for (let j = i * i; j <= max; j += i) {
        isPrime[j] = false;
      }
    }
  }
  const primes = [];
  for (let i = 2; i <= max; i++) {
    if (isPrime[i]) primes.push(i);
  }
  return primes;
}
```

If you'd rather not manage a separate worker file, say for a self-contained component, build one from a string with a `Blob`:

```javascript
class AudioRecorder {
  constructor() {
    const workerCode = `
      self.onmessage = (e) => {
        // worker logic
      };
    `;
    const workerBlob = new Blob([workerCode], { type: 'application/javascript' });
    const workerUrl = URL.createObjectURL(workerBlob);
    this.worker = new Worker(workerUrl);
  }

  start() {
    this.worker.postMessage({ command: 'init' });
  }
}
```

## Service Workers: the network layer

A Service Worker sits between the app and the network, intercepting and handling requests and serving responses from a cache. Its lifecycle is independent of any open tab; the browser can wake it for an event even when the site isn't open.

It's for offline support (caching assets so the app loads without a connection), push notifications, and background sync.

**Registering it (`app.js`):**

```javascript
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/sw.js')
      .then(reg => console.log('registered', reg.scope))
      .catch(err => console.log('registration failed', err));
  });
}
```

**The worker itself (`sw.js`):**

```javascript
const CACHE_NAME = 'my-awesome-app-v1';
const URLS_TO_CACHE = ['/', '/index.html', '/styles.css', '/app.js', '/logo.png'];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME).then(cache => cache.addAll(URLS_TO_CACHE))
  );
});

self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request).then(response => response || fetch(event.request))
  );
});
```

## Side by side

| Feature | Web Worker | Service Worker |
| :--- | :--- | :--- |
| Purpose | Heavy computation, multithreading | Network proxy, offline caching, push notifications |
| Lifecycle | Tied to the tab that created it | Independent, event-driven, runs without an open tab |
| Scope | None | Controls pages under a specific path |
| DOM access | No | No |
| Key APIs | `postMessage` | `fetch`, `push`, Cache API, notifications |
| Created with | `new Worker()` | `navigator.serviceWorker.register()` |
| Instances | Many, simultaneously | One active per scope |

## Using both together

They're not competing for the same job. A Service Worker manages the app shell, offline capability, and push notifications; a Web Worker handles a large file upload, a data analysis pass, or a 3D render without freezing the UI. A non-trivial PWA typically ends up using both, for exactly the reasons above: one keeps the app loading fast and working offline, the other keeps the UI responsive during real work.
