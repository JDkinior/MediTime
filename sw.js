// MediTime PWA Service Worker (v2.39.0)
const CACHE_NAME = 'meditime-cache-v2.39.0';

const APP_ASSETS = [
  './',
  './index.html',
  './changelog.html',
  './arquitectura.html',
  './modos.html',
  './styles.css',
  './scripts.js',
  './manifest.webmanifest',
  './images/meditime-icon.png',
  './images/app-screen-receta.png',
  './images/app-screen-calendario.png',
  './images/app-screen-estadisticas.png',
  './images/showcase-receta.jpg',
  './images/showcase-receta-dark.jpg',
  './images/showcase-calendario.jpg',
  './images/showcase-progreso.jpg',
  './images/showcase-receta-light.jpg',
  './images/showcase-calendario-light.jpg',
  './images/showcase-progreso-light.jpg',
  './images/midi_open.png',
  './images/midi_blink.png',
  './images/dispositivo.png',
  './images/qr-code.png',
  './images/calendar-feature.png',
  './images/notifications-feature.png',
  './images/reports-feature.png',
  './images/jorge-delgado.jpg',
  './images/johan-arevalo.jpeg',
  './images/github-icon.png',
  './images/linkedin-icon.png',
  './images/instagram-icon.png'
];

self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(APP_ASSETS);
    })
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => {
      return Promise.all(
        keys.map((k) => {
          if (k !== CACHE_NAME) {
            return caches.delete(k);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (event) => {
  const { request } = event;

  // Never cache external API calls like GitHub Releases or form submissions
  if (request.url.includes('api.github.com') || request.url.includes('formspree.io')) {
    return;
  }

  // Native streaming for videos: allow HTTP 206 Range requests directly to network
  if (request.destination === 'video' || request.url.match(/\.(mp4|webm|ogg)$/i)) {
    return;
  }

  // HTML, CSS, JS: Network first with cache fallback to guarantee instant updates
  const isCodeAsset = request.mode === 'navigate' ||
    (request.headers.get('accept') || '').includes('text/html') ||
    request.destination === 'style' ||
    request.destination === 'script' ||
    request.url.includes('.css') ||
    request.url.includes('.js');

  if (isCodeAsset) {
    event.respondWith(
      fetch(request)
        .then((resp) => {
          if (resp.status === 200 && request.method === 'GET') {
            const copy = resp.clone();
            caches.open(CACHE_NAME).then((c) => c.put(request, copy));
          }
          return resp;
        })
        .catch(() => caches.match(request).then((r) => r || (request.mode === 'navigate' ? caches.match('./index.html') : null)))
    );
    return;
  }

  // Static Media: Cache first with network fallback
  event.respondWith(
    caches.match(request).then((cached) => {
      if (cached) return cached;
      return fetch(request).then((resp) => {
        if (resp.status === 200 && request.method === 'GET') {
          const copy = resp.clone();
          caches.open(CACHE_NAME).then((c) => c.put(request, copy));
        }
        return resp;
      });
    }).catch(() => caches.match('./index.html'))
  );
});
