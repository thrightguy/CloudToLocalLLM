'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"icons/Icon-512.png": "1c2eb5d9aab922d65500f3b47bf63aa1",
"icons/Icon-maskable-192.png": "f85cdafba86ebc77a3a6841ba3f6f65d",
"icons/Icon-192.png": "5a1ff504f01e4d89c0fe18a500897d05",
"icons/Icon-maskable-512.png": "e0be3ac97fe4b1fbd19ad4c287af9a67",
"favicon.png": "6761bb9cda3bf0e38a5910a6499f2349",
"main.dart.js": "073876d2d61dc14217da4fa5006dc1c6",
"index.html": "c39ee32ceb33eb55b8b06f832a9affa6",
"/": "c39ee32ceb33eb55b8b06f832a9affa6",
"canvaskit/skwasm.js.symbols": "e72c79950c8a8483d826a7f0560573a1",
"canvaskit/canvaskit.wasm": "7a3f4ae7d65fc1de6a6e7ddd3224bc93",
"canvaskit/canvaskit.js": "728b2d477d9b8c14593d4f9b82b484f3",
"canvaskit/skwasm.wasm": "39dd80367a4e71582d234948adc521c0",
"canvaskit/skwasm.js": "ea559890a088fe28b4ddf70e17e60052",
"canvaskit/chromium/canvaskit.wasm": "f504de372e31c8031018a9ec0a9ef5f0",
"canvaskit/chromium/canvaskit.js": "8191e843020c832c9cf8852a4b909d4c",
"canvaskit/chromium/canvaskit.js.symbols": "b61b5f4673c9698029fa0a746a9ad581",
"canvaskit/canvaskit.js.symbols": "bdcd3835edf8586b6d6edfce8749fb77",
"flutter_bootstrap.js": "48f536345aa98eb4a47f47ee3efc24bf",
"version.json": "e40262267df6ae7e1ad6545f2d2de90e",
"flutter.js": "83d881c1dbb6d6bcd6b42e274605b69c",
"assets/AssetManifest.bin": "042b4668c9ff736ce6926b77897114c2",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin.json": "e73bd2cb3d663f45f30da330973d07a1",
"assets/NOTICES": "7cee5a6d5516537eb15b5e2a251bb78b",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "b93248a553f9e8bc17f1065929d5934b",
"assets/fonts/MaterialIcons-Regular.otf": "e7069dfd19b331be16bed984668fe080",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/AssetManifest.json": "c419f1f4833a424aa937c266f287f3cf",
"assets/assets/images/tray_icon_partial.png": "3ee94c04b42dac60ac6bdaa83f981d9c",
"assets/assets/images/tray_icon_dark_24.png": "2680ab3b03d7b42f6e3d8d15f153d8dd",
"assets/assets/images/tray_icon_contrast_32.png": "3ee94c04b42dac60ac6bdaa83f981d9c",
"assets/assets/images/app_icon.png": "10fda827216c2103015f2434aac6dc8f",
"assets/assets/images/tray_icon_contrast_24.png": "3ee94c04b42dac60ac6bdaa83f981d9c",
"assets/assets/images/tray_icon_mono.png": "6e0334e29a5c0a001240f69aac55e2eb",
"assets/assets/images/tray_icon.png": "3ee94c04b42dac60ac6bdaa83f981d9c",
"assets/assets/images/tray_icon_mono_24.png": "83e3d43caccb54323793298b41177baa",
"assets/assets/images/tray_icon_contrast_16.png": "3ee94c04b42dac60ac6bdaa83f981d9c",
"assets/assets/images/tray_icon_dark.png": "6b06f35149047fee437da269bbff4d50",
"assets/assets/images/tray_icon_disconnected.png": "3ee94c04b42dac60ac6bdaa83f981d9c",
"assets/assets/images/tray_icon_connecting.png": "3ee94c04b42dac60ac6bdaa83f981d9c",
"assets/assets/images/tray_icon_mono_16.png": "aa0c1fa70efed298b0133de1e7844183",
"assets/assets/images/tray_icon_connected.png": "3ee94c04b42dac60ac6bdaa83f981d9c",
"assets/assets/images/tray_icon_16.png": "c1c0df889cf30074e4e50d6741a61faa",
"assets/assets/images/tray_icon_dark_16.png": "610d20162bc4e6413736634f4aa3045a",
"assets/assets/images/tray_icon_24.png": "de18a9ea3d8773ee0aca359d206d8796",
"assets/assets/images/CloudToLocalLLM_logo.jpg": "0302e1c1a40eb362bda8e46c0eb32096",
"assets/assets/images/tray_icon_contrast.png": "605152945bfba1341ff081559f22ddc6",
"assets/assets/version.json": "1601402327678099cd04b0030a53988f",
"manifest.json": "d9fba938f266fd57593936ad28a4fde0"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
