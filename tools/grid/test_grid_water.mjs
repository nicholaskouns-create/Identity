// Grid water: the browser-side pieces without a browser (run: node tools/grid/test_grid_water.mjs).
// Service-area matching on EPA's Esri JSON, ring orientation and holes, the privacy of the EPA query,
// river gauges near a point, how a water system's EPA standing is worded, and SDWIS names.
import assert from 'node:assert/strict';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const W = await import(pathToFileURL(join(here, '..', '..', 'grid', 'live', 'water.js')).href);
let n = 0; const ok = (m) => { n++; console.log('  ok', m); };

// Rings as EPA's service sends them (Esri JSON): outer rings clockwise, holes counter-clockwise, closed.
const sq = (x0, y0, x1, y1, cw = true) => (cw ? [[x0, y0], [x0, y1], [x1, y1], [x1, y0], [x0, y0]] : [[x0, y0], [x1, y0], [x1, y1], [x0, y1], [x0, y0]]);

// 1. Orientation: a clockwise outer ring with a counter-clockwise hole becomes one polygon with a hole;
//    two clockwise rings become a multipolygon.
const holed = W.esriPolygon({ rings: [sq(0, 0, 10, 10), sq(4, 4, 6, 6, false)] });
assert.equal(holed.type, 'Polygon'); assert.equal(holed.coordinates.length, 2);
assert.ok(W.pointInGeom([2, 2], holed) && !W.pointInGeom([5, 5], holed), 'the hole is a hole');
const two = W.esriPolygon({ rings: [sq(0, 0, 1, 1), sq(5, 5, 6, 6)] });
assert.equal(two.type, 'MultiPolygon'); assert.ok(W.pointInGeom([5.5, 5.5], two));
assert.equal(W.esriPolygon({ rings: [[[0, 0], [1, 1]]] }), null);
assert.equal(W.esriPolygon(null), null);
ok('Esri rings become GeoJSON with holes in the right polygon');

// 2. Matching: a wholesaler's large area, the town inside it, and a neighbour that does not hold the point.
//    Attribute names in two spellings; a malformed system ID is ignored.
const pt = [-84.18, 37.99];
const sab = { features: [
  { attributes: { PWSID: 'KY0250999', PWS_Name: 'REGIONAL WHOLESALE WATER', Population_Served_Count: 90000, Symbology_Field: 'Modeled' }, geometry: { rings: [sq(-84.5, 37.7, -83.9, 38.3)] } },
  { attributes: { pwsid: 'ky0250482', PWSNAME: 'WINCHESTER MUNICIPAL UTILITIES', POPULATION_SERVED_COUNT: '24800', SYMBOLOGY_FIELD: 'System Sourced', Original_Data_Provider: 'Kentucky Division of Water', Verification_Status: 'Verified' }, geometry: { rings: [sq(-84.25, 37.95, -84.12, 38.05)] } },
  { attributes: { PWSID: 'KY0250111', PWS_Name: 'NEIGHBOUR', Population_Served_Count: 500 }, geometry: { rings: [sq(-84.1, 37.9, -84.0, 38.0)] } },
  { attributes: { PWSID: 'BAD', PWS_Name: 'MALFORMED' }, geometry: { rings: [sq(-85, 37, -83, 39)] } },
] };
const m = W.pickServiceArea(sab, pt);
assert.equal(m.hit.pwsid, 'KY0250482'); assert.equal(m.hit.pop, 24800); assert.equal(m.hit.mine, true);
assert.deepEqual(m.also.map((p) => p.pwsid), ['KY0250999']);
assert.equal(m.features.length, 2);
assert.equal(W.basisText(m.hit), 'boundary from Kentucky Division of Water');
assert.equal(W.basisText(m.also[0]), 'EPA-modeled boundary');
assert.equal(W.pickServiceArea({ features: [] }, pt).hit, null);
assert.throws(() => W.pickServiceArea({ error: { code: 400, message: 'Invalid geometry' } }, pt), /Invalid geometry/);
assert.throws(() => W.pickServiceArea('<html>', pt), /unexpected/);
ok('the smallest service area holding the point is yours; overlapping ones are listed beside it');

// 3. Privacy: EPA is asked with a box about 2 km across, rounded to 0.001°; the position itself is not sent.
const q = W.sabQuery(-115.139871, 36.169941);
const u = new URL(q);
assert.equal(u.searchParams.get('geometry'), '-115.150,36.160,-115.130,36.180');
assert.ok(!q.includes('139871') && !q.includes('169941'));
assert.equal(u.searchParams.get('geometryType'), 'esriGeometryEnvelope'); assert.equal(u.searchParams.get('inSR'), '4326'); assert.equal(u.searchParams.get('f'), 'json');
assert.ok(q.startsWith('https://services.arcgis.com/cJ9YHowT8TU7DUyn/arcgis/rest/services/Water_System_Boundaries/FeatureServer/0/query?'));
ok('the EPA query carries a rounded 2 km box, never the exact position');

// 4. Rivers: rows from the relay's compact form, gauges near a point, stage wording.
const rv = { rows: [
  ['FKFK2', 'minor', 'Kentucky River at Frankfort', 'Kentucky River', 'KY', '2026-11-23 14:00:00', 32.1, 'ft', 29, 31, 40, 48, -84.8819, 38.2014, 'https://water.noaa.gov/gauges/FKFK2'],
  ['STLM7', 'major', 'Mississippi River at St. Louis', 'Mississippi River', 'MO', '2026-11-23 14:00:00', 41.2, 'ft', 28, 30, 35, 40, -90.1797, 38.6286, 'https://water.noaa.gov/gauges/STLM7'],
  ['BAD01', 'no_flooding', 'x', 'x', 'KY', '', 1, 'ft', null, null, null, null, -84, 38, ''],
] };
assert.equal(W.riverRows(rv).length, 2);
const near = W.nearRivers(rv, -84.18, 37.99, 80);
assert.deepEqual(near.map((r) => r.lid), ['FKFK2']); assert.ok(near[0].km > 60 && near[0].km < 70);
assert.deepEqual(W.stageText(W.riverRows(rv)[0]), { now: '32.1 ft', ref: 'flood stage 31 ft' });
assert.deepEqual(W.stageText(W.riverRows(rv)[1]), { now: '41.2 ft', ref: 'major stage 40 ft' });
const geo = W.riversGeo(rv);
assert.equal(geo.features.length, 2); assert.equal(geo.features[1].properties.rank, 3);
ok('river gauges: compact rows, distance from you, stage beside its threshold');

// 5. A water system's standing in EPA's terms, source water, names.
const sys = W.systems({ systems: [
  ['KY0250482', 'WINCHESTER MUNICIPAL UTILITIES', 24800, 'SW', 'No Violation', false, false, 0, 0, '', '', 'WINCHESTER', 'Local Government'],
  ['KY0250999', 'SMALL TOWN WATER', 1250, 'GWP', 'In Violation', false, true, 1, 3, 'Revised Total Coliform Rule', '', '', 'Private'],
  ['KY0250777', 'LONG TROUBLE WSD', 900, 'GU', 'Significant Noncompliance', true, true, 2, 9, 'Arsenic', 'Arsenic', '', 'Private'],
] });
assert.deepEqual(W.standing(sys[0]), { cls: 'ok', text: 'No violations in EPA’s latest quarter' });
assert.deepEqual(W.standing(sys[1]), { cls: 'warn', text: 'In violation in EPA’s latest quarter: Revised Total Coliform Rule' });
assert.equal(W.standing(sys[2]).cls, 'bad');
assert.equal(W.standing(null).cls, '');
assert.equal(W.sourceText('SW'), 'surface water'); assert.equal(W.sourceText('gwp'), 'groundwater, bought from another system'); assert.equal(W.sourceText('ZZ'), null);
assert.equal(W.waterName('LAS VEGAS VALLEY WATER DISTRICT'), 'Las Vegas Valley Water District');
assert.equal(W.waterName('CITY OF HENDERSON'), 'City of Henderson');
assert.equal(W.waterName('HARRIS CO MUD 290'), 'Harris Co MUD 290');
assert.equal(W.waterName('NV Energy Water'), 'NV Energy Water');
assert.equal(W.dfrUrl('KY0250482'), 'https://echo.epa.gov/detailed-facility-report?fid=KY0250482&sys=SDWIS');
ok('EPA standing, source water and SDWIS names read the way ECHO defines them');

console.log(`water: ${n} checks passed`);
