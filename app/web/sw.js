// Network first; when offline, the copy from the last visit. Only the app's
// own files: the university's API is another origin and is never touched, so
// no response with personal data is ever kept here.
const CACHE = 'volgatech-web';

self.addEventListener('install', () => self.skipWaiting());
self.addEventListener('activate', (event) => event.waitUntil(self.clients.claim()));

// After the app's first start (index.html): the files the page loaded
// before this worker took over, kept too, so even the next start after a
// single visit works without a connection. Still only this site's own.
self.addEventListener('message', (event) => {
  const data = event.data || {};
  if (data.type !== 'keep' || !Array.isArray(data.urls)) return;
  const own = data.urls.filter(
    (url) => new URL(url, self.location.href).origin === self.location.origin);
  event.waitUntil(caches.open(CACHE).then((cache) => Promise.all(own.map(
    (url) => cache.match(url).then((hit) => hit || cache.add(url).catch(() => {}))))));
});

self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET' || new URL(request.url).origin !== self.location.origin) {
    return;
  }
  event.respondWith(
    fetch(request)
      .then((response) => {
        if (response.ok) {
          const copy = response.clone();
          caches.open(CACHE).then((cache) => cache.put(request, copy));
        }
        return response;
      })
      .catch(() => caches.match(request).then((cached) => cached || Response.error())),
  );
});
