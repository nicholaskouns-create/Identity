const CACHE='e47-proof-observatory-v1';
const ASSETS=['./','./index.html','./math.mjs','./icon.svg','./manifest.webmanifest'];
self.addEventListener('install',event=>{event.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(ASSETS)));self.skipWaiting();});
self.addEventListener('activate',event=>{event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))));self.clients.claim();});
self.addEventListener('fetch',event=>{
 const url=new URL(event.request.url);
 if(event.request.method!=='GET'||url.origin!==self.location.origin) return;
 event.respondWith(caches.match(event.request).then(hit=>hit||fetch(event.request).then(resp=>{
   if(resp.ok) {const clone=resp.clone();caches.open(CACHE).then(cache=>cache.put(event.request,clone));}
   return resp;
 })));
});