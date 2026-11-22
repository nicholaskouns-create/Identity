/* KKP-GRID-DOOR-1 · the Grid doorway on every City surface.
 * The <a id="kkp-grid-door"> is static HTML and works without this script.
 * This script only places it in a free corner, shows a live reading from the
 * Grid relay when one exists, and hides it inside embeds. */
(function () {
  'use strict';
  var a = document.getElementById('kkp-grid-door');
  if (!a) return;
  if (window.top !== window.self) { a.style.display = 'none'; return; }
  var RELAY = 'https://raw.githubusercontent.com/nicholaskouns-create/Identity/grid-live/door.json';
  var spots = [
    { name: 'bl', mid: false, css: { left: '12px', bottom: '12px', right: 'auto', top: 'auto', transform: 'none' } },
    { name: 'br', mid: false, css: { right: '12px', bottom: '12px', left: 'auto', top: 'auto', transform: 'none' } },
    { name: 'tr', mid: false, css: { right: '12px', top: '12px', left: 'auto', bottom: 'auto', transform: 'none' } },
    { name: 'tl', mid: false, css: { left: '12px', top: '12px', right: 'auto', bottom: 'auto', transform: 'none' } },
    { name: 'rm', mid: true, css: { right: '12px', top: '50%', left: 'auto', bottom: 'auto', transform: 'translateY(-50%)' } },
    { name: 'lm', mid: true, css: { left: '12px', top: '50%', right: 'auto', bottom: 'auto', transform: 'translateY(-50%)' } },
  ];
  var CONTROL = 'a,button,input,select,textarea,label,summary,[role=button],[role=tab],[role=slider],[tabindex]';
  var MEDIA = { CANVAS: 1, VIDEO: 1, IFRAME: 1, IMG: 1, svg: 1, SVG: 1 };
  var expanded = false;
  function area(el) { var r = el.getBoundingClientRect(); return r.width * r.height; }
  function screenArea() { return window.innerWidth * window.innerHeight; }
  function cs(el) { return ((el.ownerDocument && el.ownerDocument.defaultView) || window).getComputedStyle(el); }
  // A fixed or sticky ancestor that is not a full-page backdrop: it stays put while the page scrolls.
  function overlay(el) {
    var body = el.ownerDocument && el.ownerDocument.body;
    for (var n = el, d = 0; n && n !== body && n.nodeType === 1 && d < 14; n = n.parentElement, d++) {
      var p = cs(n).position;
      if ((p === 'fixed' || p === 'sticky') && area(n) < 0.5 * screenArea()) return true;
    }
    return false;
  }
  // Same-origin embeds (the flight labs host their instruments in one) are read through.
  function inner(el) {
    if (!el || el.tagName !== 'IFRAME') return null;
    try { return el.contentDocument && el.contentDocument.body ? el.contentDocument : null; } catch (e) { return null; }
  }
  function hitAt(doc, x, y, depth) {
    var el = doc.elementFromPoint(x, y), d = depth < 3 && inner(el);
    if (d) { var r = el.getBoundingClientRect(); return hitAt(d, x - r.left - el.clientLeft, y - r.top - el.clientTop, depth + 1) || el; }
    return el;
  }
  // A page that scrolls lets ordinary content pass under the doorway; a full-screen app does not.
  function isApp() {
    var de = document.documentElement, b = document.body || de;
    var tall = Math.max(de.scrollHeight, b.scrollHeight) > window.innerHeight * 1.3;
    var lock = getComputedStyle(b).overflowY === 'hidden' || getComputedStyle(de).overflowY === 'hidden';
    return !tall || lock;
  }
  // Every visible fixed panel, including ones that ignore the pointer (GPS cards, HUDs, captions).
  function collect(doc, dx, dy, depth, out) {
    var all = doc.body ? doc.body.getElementsByTagName('*') : [], S = screenArea();
    for (var i = 0; i < all.length && i < 12000; i++) {
      var el = all[i];
      if (el === a || a.contains(el)) continue;
      var sub = depth < 3 && inner(el);
      if (sub) { var fr = el.getBoundingClientRect(); collect(sub, dx + fr.left + el.clientLeft, dy + fr.top + el.clientTop, depth + 1, out); continue; }
      if (el.offsetParent !== null) continue;
      var st = cs(el);
      if (st.position !== 'fixed' || st.visibility === 'hidden' || +st.opacity < 0.05) continue;
      var r = el.getBoundingClientRect();
      if (r.width < 2 || r.height < 2 || r.width * r.height > 0.5 * S) continue;
      out.push({ left: r.left + dx, right: r.right + dx, top: r.top + dy, bottom: r.bottom + dy });
    }
    return out;
  }
  function layers() { return collect(document, 0, 0, 0, []); }
  // Score a spot as [strong, weak]: strong = something that stays under the doorway (fixed panels,
  // controls of a full-screen app); weak = page content that happens to be there before scrolling.
  function busy(css, w, h, app, lay) {
    var W = window.innerWidth, H = window.innerHeight;
    var x0 = css.left !== 'auto' ? 12 : W - 12 - w;
    var y0 = css.top === '50%' ? H / 2 - h / 2 : css.top !== 'auto' ? 12 : H - 12 - h;
    var strong = 0, weak = 0;
    for (var j = 0; j < lay.length; j++) {
      var r = lay[j];
      if (r.left < x0 + w + 4 && r.right > x0 - 4 && r.top < y0 + h + 4 && r.bottom > y0 - 4) strong += 4;
    }
    var pts = [[x0 + 3, y0 + 3], [x0 + w - 3, y0 + 3], [x0 + 3, y0 + h - 3], [x0 + w - 3, y0 + h - 3], [x0 + w / 2, y0 + h / 2], [x0 + w / 4, y0 + h / 2], [x0 + 3 * w / 4, y0 + h / 2]];
    for (var i = 0; i < pts.length; i++) {
      var el = hitAt(document, pts[i][0], pts[i][1], 0);
      if (!el || el.nodeType !== 1 || el === a || a.contains(el)) continue;
      var od = el.ownerDocument;
      if (el === od.documentElement || el === od.body) continue;
      var stay = app || overlay(el);
      if (el.closest && el.closest(CONTROL)) { if (stay) strong += 3; else weak += 3; }
      else if (MEDIA[el.tagName] && area(el) < 0.25 * screenArea()) { if (stay) strong += 3; else weak += 1; }
      else if (stay && !app) strong += 2;
      else if ((el.textContent || '').trim() && el.children.length < 8) { if (app) strong += 1; else weak += 1; }
    }
    return [strong, weak];
  }
  function better(x, y) { return x[0] !== y[0] ? x[0] < y[0] : x[1] < y[1]; }
  function showReading(on) {
    var r = a.querySelector('.kkp-grid-reading');
    if (r) r.style.display = on ? '' : 'none';
  }
  function place() {
    if (expanded) return;
    var app = isApp(), narrow = window.innerWidth < 560;
    a.style.visibility = 'hidden';
    showReading(true);
    var w = a.offsetWidth || 120, h = a.offsetHeight || 26, best = null, lay = layers();
    // Corners first; the side midpoints only when every corner has something fixed in it.
    for (var i = 0; i < spots.length; i++) {
      if (spots[i].mid && best && best.s[0] === 0) break;
      var sc = busy(spots[i].css, w, h, app, lay);
      if (best === null || better(sc, best.s)) best = { s: sc, c: spots[i] };
      if (sc[0] === 0 && sc[1] === 0) break;
    }
    var c = best.c.css; for (var k in c) a.style[k] = c[k];
    a.dataset.corner = best.c.name;
    a.dataset.score = best.s.join(',');
    showReading(!(narrow || best.s[0] > 0));
    a.style.opacity = best.s[0] > 0 ? '0.84' : '1';
    a.style.visibility = '';
  }
  function current() { for (var i = 0; i < spots.length; i++) if (spots[i].name === a.dataset.corner) return spots[i]; return null; }
  function recheck() {
    if (document.hidden || expanded) return;
    var cur = current(); if (!cur) return;
    a.style.visibility = 'hidden';
    var sc = busy(cur.css, a.offsetWidth, a.offsetHeight, isApp(), layers());
    a.style.visibility = '';
    if (sc[0] > 0) place();
  }
  function expand(on) {
    expanded = on;
    a.style.borderColor = on ? 'rgba(110,223,212,.85)' : 'rgba(110,223,212,.38)';
    a.style.color = on ? '#c1e8ce' : '#6edfd4';
    if (on) { showReading(true); a.style.opacity = '1'; } else place();
  }
  a.addEventListener('mouseenter', function () { expand(true); });
  a.addEventListener('mouseleave', function () { expand(false); });
  a.addEventListener('focus', function () { expand(true); });
  a.addEventListener('blur', function () { expand(false); });
  var dot = document.createElement('span');
  dot.setAttribute('aria-hidden', 'true');
  dot.style.cssText = 'width:6px;height:6px;border-radius:50%;background:#c1e8ce;box-shadow:0 0 8px rgba(193,232,206,.8);display:inline-block';
  a.insertBefore(dot, a.firstChild);
  function reading(d) {
    if (!d) return;
    var txt = null;
    if (d.us48 && d.us48.mw) txt = (d.us48.mw / 1000).toFixed(0) + ' GW';
    else if (d.isos_live) txt = d.isos_live + ' ISOs live';
    if (!txt) return;
    var s = a.querySelector('.kkp-grid-reading') || document.createElement('span');
    s.className = 'kkp-grid-reading';
    s.style.cssText = 'color:#98a6a8;letter-spacing:.08em;font-weight:500';
    s.textContent = '· ' + txt;
    if (!s.parentNode) a.appendChild(s);
    a.title = 'Grid · live U.S. power-grid monitor · relay snapshot ' + (d.generated_utc || '');
    place();
  }
  try {
    var cached = JSON.parse(sessionStorage.getItem('kkp-grid-door') || 'null');
    if (cached && Date.now() - cached.at < 300000) reading(cached.d);
    else fetch(RELAY, { mode: 'cors', cache: 'no-store' }).then(function (r) { return r.ok ? r.json() : null; }).then(function (d) {
      if (d) { sessionStorage.setItem('kkp-grid-door', JSON.stringify({ at: Date.now(), d: d })); reading(d); }
    }).catch(function () {});
  } catch (e) { /* storage unavailable */ }
  place();
  setTimeout(place, 1500);
  setInterval(recheck, 5000);
  var mo; try {
    new MutationObserver(function () { clearTimeout(mo); mo = setTimeout(recheck, 350); }).observe(document.body, { childList: true });
  } catch (e) { /* no observer */ }
  var t; window.addEventListener('resize', function () { clearTimeout(t); t = setTimeout(place, 250); });
})();
