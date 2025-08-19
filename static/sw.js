const CACHE_NAME = 'dev-tools-v1.0.0';
const urlsToCache = [
  '/',
  '/static/',
  '/static/password-generator/',
  '/static/uuid-generator/',
  '/static/regex-tester/',
  '/static/base64-converter/',
  '/static/markdown-pdf/',
  '/static/code-formatter/',
  '/static/cheatsheets/',
  '/static/cheatsheets/html-cheatsheet.html',
  '/static/cheatsheets/css-cheatsheet.html',
  '/static/cheatsheets/javascript-cheatsheet.html',
  '/static/cheatsheets/git-cheatsheet.html',
  '/static/cheatsheets/sql-cheatsheet.html',
  '/static/cheatsheets/docker-cheatsheet.html',
  '/static/cheatsheets/regex-cheatsheet.html',
  '/static/cheatsheets/http-status-codes.html'
];

// Install event - cache all static assets
self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('Opened cache');
        return cache.addAll(urlsToCache);
      })
  );
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => {
        // Return cached version if available
        if (response) {
          return response;
        }
        
        // Clone the request because it's a one-use object
        const fetchRequest = event.request.clone();
        
        // Fetch from network
        return fetch(fetchRequest).then(response => {
          // Check if we received a valid response
          if (!response || response.status !== 200 || response.type !== 'basic') {
            return response;
          }
          
          // Clone the response because it's a one-use object
          const responseToCache = response.clone();
          
          // Cache the response for future use
          caches.open(CACHE_NAME)
            .then(cache => {
              cache.put(event.request, responseToCache);
            });
            
          return response;
        });
      })
    );
});

// Activate event - clean up old caches
self.addEventListener('activate', event => {
  const cacheWhitelist = [CACHE_NAME];
  
  event.waitUntil(
    caches.keys().then(cacheNames => {
      return Promise.all(
        cacheNames.map(cacheName => {
          if (cacheWhitelist.indexOf(cacheName) === -1) {
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
});