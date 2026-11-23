// Live reads through Grid's edge function (Supabase Edge Function `grid-live`, source in
// tools/grid/supabase/grid-live): ERCOT real-time frequency, ODIN county outages, HHS emPOWER, NOAA river
// gauges, EPA drinking-water systems and the U.S. Drought Monitor. The function reads them server-side,
// caches them and adds CORS.
export const LIVE_URL = 'https://gpkjvihkyectnenvnbng.supabase.co/functions/v1/grid-live';
// The City project's public anon key: it names the project and grants only public access.
export const ANON = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imdwa2p2aWhreWVjdG5lbnZuYm5nIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUxNzYwOTYsImV4cCI6MjEwMDc1MjA5Nn0.WLsj1N9akCxpNVAIPj43fO9InCTHRuNz1WTPDNyuOVM';

export async function fetchLive(src, { timeoutMs = 20000, params = null } = {}) {
  const ctl = new AbortController();
  const h = setTimeout(() => ctl.abort(), timeoutMs);
  const q = new URLSearchParams({ src, ...(params || {}) });
  try {
    const r = await fetch(`${LIVE_URL}?${q}`, { headers: { Authorization: `Bearer ${ANON}`, apikey: ANON }, signal: ctl.signal, cache: 'no-store' });
    const j = await r.json().catch(() => null);
    if (!r.ok || !j || j.error) throw new Error((j && j.error) || `HTTP ${r.status}`);
    return j;
  } catch (e) {
    throw new Error(e.name === 'AbortError' ? 'timed out' : String(e.message || e));
  } finally {
    clearTimeout(h);
  }
}

// Which synchronous grid a place shares a frequency with. By state, with the known longitude
// splits (El Paso, the Texas and Oklahoma panhandles, eastern Montana, Wyoming and New Mexico,
// the Black Hills). Approximate at the seams; exact enough to say whose frequency you are hearing.
export const INTERCONNECTIONS = {
  eastern: { id: 'eastern', name: 'Eastern Interconnection', short: 'Eastern' },
  western: { id: 'western', name: 'Western Interconnection', short: 'Western' },
  ercot: { id: 'ercot', name: 'Texas Interconnection (ERCOT)', short: 'ERCOT' },
  alaska: { id: 'alaska', name: 'Alaska grids', short: 'Alaska' },
  hawaii: { id: 'hawaii', name: 'Hawaii island grids', short: 'Hawaii' },
  pr: { id: 'pr', name: 'Puerto Rico grid', short: 'Puerto Rico' },
};
const WEST = new Set(['Washington', 'Oregon', 'California', 'Nevada', 'Idaho', 'Utah', 'Arizona', 'Colorado', 'Wyoming', 'Montana', 'New Mexico']);
export function interconnectionFor(state, lon, lat) {
  const I = INTERCONNECTIONS;
  if (!state) return null;
  if (state === 'Alaska') return I.alaska;
  if (state === 'Hawaii') return I.hawaii;
  if (state === 'Puerto Rico') return I.pr;
  if (state === 'Texas') { if (lon < -104.0) return I.western; if (lat > 34.3) return I.eastern; return I.ercot; }
  if (state === 'South Dakota' && lon < -103.0) return I.western;
  if (WEST.has(state)) {
    if ((state === 'Montana' || state === 'Wyoming') && lon > -104.6) return I.eastern;
    if (state === 'New Mexico' && lon > -103.8) return I.eastern;
    return I.western;
  }
  return I.eastern;
}
