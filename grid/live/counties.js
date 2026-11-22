// U.S. counties for the outage layer and search: Census cartographic boundaries (1:10m) from
// us-atlas 3.0.1, kept as TopoJSON (shared arcs, 0.8 MB) and decoded here on first use.
export const STATE_ABBR = { '01': 'AL', '02': 'AK', '04': 'AZ', '05': 'AR', '06': 'CA', '08': 'CO', '09': 'CT', '10': 'DE', '11': 'DC', '12': 'FL', '13': 'GA', '15': 'HI', '16': 'ID', '17': 'IL', '18': 'IN', '19': 'IA', '20': 'KS', '21': 'KY', '22': 'LA', '23': 'ME', '24': 'MD', '25': 'MA', '26': 'MI', '27': 'MN', '28': 'MS', '29': 'MO', '30': 'MT', '31': 'NE', '32': 'NV', '33': 'NH', '34': 'NJ', '35': 'NM', '36': 'NY', '37': 'NC', '38': 'ND', '39': 'OH', '40': 'OK', '41': 'OR', '42': 'PA', '44': 'RI', '45': 'SC', '46': 'SD', '47': 'TN', '48': 'TX', '49': 'UT', '50': 'VT', '51': 'VA', '53': 'WA', '54': 'WV', '55': 'WI', '56': 'WY', '60': 'AS', '66': 'GU', '69': 'MP', '72': 'PR', '78': 'VI' };

let loading = null;
export function loadCounties(url = 'data/us-counties-10m.json') {
  if (!loading) loading = fetch(url).then((r) => { if (!r.ok) throw new Error(`HTTP ${r.status}`); return r.json(); }).then(decode).catch((e) => { loading = null; throw e; });
  return loading;
}

export function decode(topo) {
  const [sx, sy] = topo.transform.scale, [tx, ty] = topo.transform.translate;
  const arcs = topo.arcs.map((arc) => { let x = 0, y = 0; return arc.map(([dx, dy]) => [(x += dx) * sx + tx, (y += dy) * sy + ty]); });
  const ring = (ids) => {
    const pts = [];
    ids.forEach((i, k) => { const a = i < 0 ? arcs[~i].slice().reverse() : arcs[i]; for (let j = k ? 1 : 0; j < a.length; j++) pts.push(a[j]); });
    return pts;
  };
  const features = [];
  for (const g of topo.objects.counties.geometries) {
    const geometry = g.type === 'Polygon' ? { type: 'Polygon', coordinates: g.arcs.map(ring) }
      : g.type === 'MultiPolygon' ? { type: 'MultiPolygon', coordinates: g.arcs.map((p) => p.map(ring)) } : null;
    if (!geometry) continue;
    const st = STATE_ABBR[String(g.id).slice(0, 2)] || '';
    features.push({ type: 'Feature', id: g.id, properties: { fips: g.id, name: g.properties?.name || g.id, st, label: `${g.properties?.name || g.id}, ${st}` }, geometry, bbox: bbox(geometry) });
  }
  return { features, byFips: new Map(features.map((f) => [f.id, f])) };
}

function bbox(g) {
  let x0 = 180, y0 = 90, x1 = -180, y1 = -90;
  const walk = (c) => { if (typeof c[0] === 'number') { if (c[0] < x0) x0 = c[0]; if (c[0] > x1) x1 = c[0]; if (c[1] < y0) y0 = c[1]; if (c[1] > y1) y1 = c[1]; } else c.forEach(walk); };
  walk(g.coordinates);
  return [x0, y0, x1, y1];
}

const inRing = (pt, ring) => { let c = false; for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) { const [xi, yi] = ring[i], [xj, yj] = ring[j]; if (((yi > pt[1]) !== (yj > pt[1])) && (pt[0] < ((xj - xi) * (pt[1] - yi)) / (yj - yi) + xi)) c = !c; } return c; };
const inPoly = (pt, poly) => inRing(pt, poly[0]) && !poly.slice(1).some((h) => inRing(pt, h));
export function countyAt(C, lon, lat) {
  for (const f of C.features) {
    const b = f.bbox;
    if (lon < b[0] || lon > b[2] || lat < b[1] || lat > b[3]) continue;
    const g = f.geometry;
    if (g.type === 'Polygon' ? inPoly([lon, lat], g.coordinates) : g.coordinates.some((p) => inPoly([lon, lat], p))) return f;
  }
  return null;
}
export function unionBbox(list) {
  let b = null;
  for (const x of list) { if (!x) continue; b = b ? [Math.min(b[0], x[0]), Math.min(b[1], x[1]), Math.max(b[2], x[2]), Math.max(b[3], x[3])] : x.slice(); }
  return b;
}
