// Tests for the grid-live edge function's parsers (run: node tools/grid/test_grid_live.mjs).
// The function file is plain JavaScript inside .ts, so it is copied to .mjs and imported here.
import assert from 'node:assert/strict';
import { copyFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const dir = mkdtempSync(join(tmpdir(), 'grid-live-'));
copyFileSync(join(here, 'supabase/grid-live/index.ts'), join(dir, 'grid-live.mjs'));
const G = await import(pathToFileURL(join(dir, 'grid-live.mjs')).href);

// ERCOT: label and value in adjacent cells, numbers with and without thousands separators, nested spans.
const ercot = `<html><head><script>var t = "Current Frequency"; </script><style>td{}</style></head><body>
<div class="schedTime rightAlign">Last Updated: Nov 22, 2026 08:43:20</div>
<table><tr><td colspan="2">Frequency</td></tr>
<tr><td class="tdLeft">Current Frequency</td><td class="labelClassCenter">60.004</td></tr>
<tr><td class="tdLeft">Instantaneous Time Error</td><td class="labelClassCenter">-3.982</td></tr>
<tr><td class="tdLeft">Consecutive BAAL Clock-Minute Exceedances (min)</td><td>0</td></tr>
<tr><td colspan="2">Real-Time Data</td></tr>
<tr><td><span>Actual System Demand</span></td><td><span>45,749</span></td></tr>
<tr><td>Average Net Load</td><td>31633</td></tr>
<tr><td>Total System Capacity (not including Ancillary Services)</td><td>84082</td></tr>
<tr><td>Total Wind Output</td><td>13674</td></tr><tr><td>Total PVGR Output</td><td>20318</td></tr>
<tr><td>Current System Inertia</td><td>279134</td></tr>
<tr><td colspan="2">DC Tie Flows</td></tr>
<tr><td>DC_E (East)</td><td>0</td></tr><tr><td>DC_L (Laredo VFT)</td><td>19</td></tr><tr><td>DC_N (North)</td><td>223</td></tr>
<tr><td>DC_R (Railroad)</td><td>151</td></tr><tr><td>DC_S (Eagle Pass)</td><td>0</td></tr></table></body></html>`;
const e = G.parseErcot(ercot);
assert.equal(e.frequency, 60.004); assert.equal(e.timeError, -3.982); assert.equal(e.baalMinutes, 0);
assert.equal(e.demand, 45749); assert.equal(e.netLoad, 31633); assert.equal(e.capacity, 84082);
assert.equal(e.wind, 13674); assert.equal(e.solar, 20318); assert.equal(e.inertia, 279134);
assert.deepEqual(e.dcTies, { East: 0, 'Laredo VFT': 19, North: 223, Railroad: 151, 'Eagle Pass': 0 });
assert.equal(e.updated, '2026-11-22T14:43:20.000Z');          // CST = UTC−6
assert.equal(G.centralToIso('Jul 4, 2026 12:00:00'), '2026-07-04T17:00:00.000Z'); // CDT = UTC−5
assert.throws(() => G.parseErcot('<td>Something else</td><td>1</td>'), /frequency not found/);
assert.throws(() => G.parseErcot('<td>Current Frequency</td><td>6.0</td>'), /implausible/);

// ODIN: county records, meters affected, utility name and id, start, restoration, cause.
const rec = (fips, m, util, id, start, ert, cause) => ({ communityDescriptor: fips, metersAffected: m, names: [{ name: util, nameType: 'UtilityName' }, { name: id, nameType: 'UtilityId' }], reportedStartTime: start, estimatedRestorationTime: { ert }, cause, outageArea: { outageAreaKind: 'county' } });
const odin = { outage: [
  rec('04019', 8, 'TRICO ELECTRIC COOPERATIVE INC', '19189', '2026-11-22T10:00:00Z', null, null),
  rec('06037', 13, 'SOUTHERN CALIFORNIA EDISON CO', '17609', '2026-11-22T12:41:00Z', '2026-11-22T18:00:00Z', 'Analyzing Problem'),
  rec('06037', 120, 'SOUTHERN CALIFORNIA EDISON CO', '17609', '2026-11-22T09:12:00Z', '2026-11-22T16:30:00Z', 'Weather'),
  rec('6037', 5, 'LOS ANGELES DEPT OF WATER & POWER', '11208', '2026-11-22T11:00:00Z', null, 'Weather'),
  rec('04025', null, 'ARIZONA PUBLIC SERVICE CO', '803', '2026-11-22T12:41:00Z', null, null),
  { communityDescriptor: 'not-a-county', metersAffected: 999 },
] };
const status = [{ name: 'A', receivedDate: '2026-11-22T14:43:59.754Z', hasError: false }, { name: 'B', receivedDate: '2026-11-21T19:32:32.509Z', hasError: true }];
const o = G.aggregateOdin(odin, status);
assert.equal(o.customers, 146); assert.equal(o.events, 5); assert.equal(o.nCounties, 3); assert.equal(o.nUtilities, 4);
assert.deepEqual(o.counties[0], ['06037', 138, 3, 'SOUTHERN CALIFORNIA EDISON CO', 2, '2026-11-22T09:12:00Z', '2026-11-22T18:00:00Z', 'Weather']);
assert.equal(o.utilities[0][1], 'SOUTHERN CALIFORNIA EDISON CO'); assert.equal(o.utilities[0][2], 133); assert.equal(o.utilities[0][5], '06037');
assert.equal(o.feeds, 2); assert.equal(o.feedErrors, 1); assert.equal(o.newestFeed, '2026-11-22T14:43:59.754Z');
assert.equal(G.aggregateOdin([], null).customers, 0);

// HHS emPOWER: the first four rows the public service returns (copied from a live query), a recoded FIPS,
// and junk that must be dropped.
const A = (o) => ({ attributes: o });
const emp = G.compactEmpower([
  { features: [
    A({ FIPS_Code: '72085', FIPS_Code_recode: '72085', Medicare_Benes: 8426, Power_Dependent_Devices_DME: 406, Facility_ESRD_Dialysis_Any_DME: 11, O2_Services_Any_DME: 22, Home_Health_Services_Any_DME: 48, AtHome_Hospice_Any_DME: 11 }),
    A({ FIPS_Code: '25025', FIPS_Code_recode: '25025', Medicare_Benes: 115088, Power_Dependent_Devices_DME: 3402, Facility_ESRD_Dialysis_Any_DME: 242, O2_Services_Any_DME: 465, Home_Health_Services_Any_DME: 695, AtHome_Hospice_Any_DME: 187 }),
    A({ FIPS_Code: '72115', FIPS_Code_recode: '72115', Medicare_Benes: 6514, Power_Dependent_Devices_DME: 292, Facility_ESRD_Dialysis_Any_DME: 11, O2_Services_Any_DME: 11, Home_Health_Services_Any_DME: 22, AtHome_Hospice_Any_DME: 11 }),
  ], exceededTransferLimit: true },
  { features: [
    A({ FIPS_Code: '78030', FIPS_Code_recode: '78030', Medicare_Benes: 10062, Power_Dependent_Devices_DME: 56, Facility_ESRD_Dialysis_Any_DME: 11, O2_Services_Any_DME: 11, Home_Health_Services_Any_DME: 11, AtHome_Hospice_Any_DME: 11 }),
    A({ FIPS_Code: '9110', FIPS_Code_recode: '9003', Medicare_Benes: 200000, Power_Dependent_Devices_DME: 5000, Facility_ESRD_Dialysis_Any_DME: null, O2_Services_Any_DME: -1, Home_Health_Services_Any_DME: 'n/a', AtHome_Hospice_Any_DME: 9 }),
    A({ FIPS_Code: 'XX', Medicare_Benes: 5 }),
  ] },
], { editingInfo: { lastEditDate: Date.UTC(2026, 10, 9) } });
assert.equal(emp.nCounties, 5);
assert.deepEqual(emp.fields, ['fips', 'medicare', 'electricityDependent', 'dialysis', 'oxygen', 'homeHealth', 'hospice']);
assert.deepEqual(emp.rows[0], ['09110', 200000, 5000, null, null, null, 9]);
assert.deepEqual(emp.rows.find((r) => r[0] === '25025'), ['25025', 115088, 3402, 242, 465, 695, 187]);
assert.equal(emp.aliases['09003'], '09110');
assert.equal(emp.medicare, 8426 + 115088 + 6514 + 10062 + 200000); assert.equal(emp.electricityDependent, 406 + 3402 + 292 + 56 + 5000);
assert.equal(emp.asOf, '2026-11-09T00:00:00.000Z');
// NOAA NWPS river gauges (layer 0 of riv_gauges, f=json): the documented fields, strings for stages, blank
// and sentinel values, a gauge outside the four flood levels, a gauge with no position, a lowercase id, and a
// hydrograph link that is not NOAA's.
const gauge = (o) => ({ attributes: { status: 'action', location: 'Somewhere', waterbody: 'Some River', state: 'KY', obstime: '2026-11-23 14:00:00', units: 'ft', latitude: 38.0, longitude: -84.5, ...o } });
const riv = G.compactRivers({ features: [
  gauge({ gaugelid: 'FKFK2', status: 'minor', location: 'Kentucky River at Frankfort', observed: '32.10', action: '29.0', flood: '31.0', moderate: '40.0', major: '48.0', url: 'https://water.noaa.gov/gauges/FKFK2', latitude: 38.2014, longitude: -84.8819 }),
  gauge({ gaugelid: 'stlm7', status: 'MAJOR', location: 'Mississippi River at St. Louis', state: 'mo', observed: '41.2', action: '28', flood: '30', moderate: '35', major: '40', url: 'javascript:alert(1)', latitude: 38.6286, longitude: -90.1797 }),
  gauge({ gaugelid: 'LXGK2', status: 'action', observed: '-9999', flood: ' ', action: '12' }),
  gauge({ gaugelid: 'CYNK2', status: 'minor', observed: '24.0', flood: '20', latitude: 38.4, longitude: -84.3 }),
  gauge({ gaugelid: 'NOFL1', status: 'no_flooding' }),
  gauge({ gaugelid: 'ZERO1', status: 'moderate', latitude: 0, longitude: 0 }),
  gauge({ gaugelid: 'TOOLONGID', status: 'moderate' }),
] }, { features: [{ attributes: { status: 'no_flooding', n: 6200 } }, { attributes: { status: 'obs_not_current', n: 1400 } }, { attributes: { status: 'minor', n: 2 } }, { attributes: { status: 'major', n: 1 } }, { attributes: { status: 'action', n: 1 } }] });
assert.deepEqual(riv.counts, { major: 1, moderate: 0, minor: 2, action: 1 });
assert.equal(riv.inFlood, 3);
assert.deepEqual(riv.rows.map((r) => r[0]), ['STLM7', 'CYNK2', 'FKFK2', 'LXGK2']);   // worst first; CYNK2 is 4 ft over flood stage, FKFK2 1.1 ft
assert.equal(riv.rows[0][14], 'https://water.noaa.gov/gauges/STLM7');                 // non-NOAA link replaced
assert.equal(riv.rows[0][4], 'MO');
assert.equal(riv.rows[3][6], null); assert.equal(riv.rows[3][9], null);              // sentinel and blank stages read as missing
assert.equal(riv.reporting, 6204);                                                   // gauges not reporting are left out
assert.throws(() => G.compactRivers({ error: { code: 400, message: 'Invalid query' } }), /Invalid query/);
assert.throws(() => G.compactRivers({ features: 'x' }), /unexpected/);

// EPA ECHO drinking-water systems for one county (get_systems, output=JSON): values are strings. A transient
// system, an inactive one, a duplicate and a malformed ID must be dropped; violations read as ECHO defines them.
const ws = (o) => ({ PWSTypeCode: 'CWS', PWSActivityCode: 'A', PrimarySourceCode: 'GW', SNC: 'No Violation', SeriousViolator: 'No', HealthFlag: 'N', RulesVio: '0', QtrsWithVio: '0', SDWAContaminantsInCurViol: '', SDWAContaminantsInViol3yr: '', CitiesServed: '', OwnerDesc: 'Local Government', ...o });
const wat = G.compactWater({ Results: { Message: 'Success', QueryID: '4417', QueryRows: '6', WaterSystems: [
  ws({ PWSId: 'KY0250482', PWSName: 'WINCHESTER MUNICIPAL UTILITIES', PopulationServedCount: '24800', PrimarySourceCode: 'SW', CitiesServed: 'WINCHESTER', DfrUrl: 'http://echo.epa.gov/detailed-facility-report?fid=KY0250482&sys=SDWIS' }),
  ws({ PWSId: 'KY0250999', PWSName: 'SMALL TOWN WATER', PopulationServedCount: '1,250', SNC: 'In Violation', HealthFlag: 'Y', RulesVio: '1', QtrsWithVio: '3', SDWAContaminantsInCurViol: 'Revised Total Coliform Rule', SeriousViolator: 'Yes', DfrUrl: 'javascript:alert(1)' }),
  ws({ PWSId: 'KY0250482', PWSName: 'DUPLICATE ROW', PopulationServedCount: '99' }),
  ws({ PWSId: 'KY0250111', PWSName: 'CAMPGROUND', PWSTypeCode: 'TNCWS', PopulationServedCount: '40' }),
  ws({ PWSId: 'KY0250222', PWSName: 'CLOSED SYSTEM', PWSActivityCode: 'I', PopulationServedCount: '300' }),
  ws({ PWSId: 'BAD', PWSName: 'MALFORMED' }),
] } }, '21049');
assert.equal(wat.nSystems, 2); assert.equal(wat.population, 26050); assert.equal(wat.nViolating, 1); assert.equal(wat.nPriority, 1);
assert.deepEqual(wat.systems[0], ['KY0250482', 'WINCHESTER MUNICIPAL UTILITIES', 24800, 'SW', 'No Violation', false, false, 0, 0, '', '', 'WINCHESTER', 'Local Government', 'https://echo.epa.gov/detailed-facility-report?fid=KY0250482&sys=SDWIS']);
assert.equal(wat.systems[1][13], '');                                                // only EPA's own report links pass
assert.deepEqual(wat.systems[1].slice(0, 10), ['KY0250999', 'SMALL TOWN WATER', 1250, 'GW', 'In Violation', true, true, 1, 3, 'Revised Total Coliform Rule']);
assert.equal(G.compactWater({ Results: { Message: 'Success', QueryRows: '0' } }, '02013').nSystems, 0);   // a county with none
assert.throws(() => G.compactWater({ Results: { Error: { ErrorMessage: 'Invalid FIPS' } } }, '99999'), /Invalid FIPS/);
assert.throws(() => G.compactWater({ Results: { Message: 'Success', QueryRows: '12' } }, '21049'), /ECHO/);   // rows promised, none sent
assert.throws(() => G.compactWater('<html>maintenance</html>', '21049'), /unexpected/);

// U.S. Drought Monitor county statistics (JSON): the latest week wins, keys in any case; the categorical form
// is used as is, the cumulative form is converted, and shares that do not add up are refused.
const dr = G.compactDrought([
  { MapDate: '20261110', FIPS: '32003', County: 'Clark County', State: 'NV', None: '0.00', D0: '0.00', D1: '10.00', D2: '50.00', D3: '40.00', D4: '0.00', ValidStart: '2026-11-11', ValidEnd: '2026-11-17' },
  { MapDate: '20261117', FIPS: '32003', County: 'Clark County', State: 'NV', None: '0.00', D0: '5.10', D1: '20.00', D2: '40.00', D3: '34.90', D4: '0.00', ValidStart: '2026-11-18', ValidEnd: '2026-11-24' },
], '32003');
assert.equal(dr.week, '2026-11-17'); assert.equal(dr.inDrought, 94.9); assert.equal(dr.worst, 'D3'); assert.equal(dr.d0, 5.1);
const cum = G.compactDrought([{ mapDate: '2026-11-17T00:00:00', none: 20, d0: 80, d1: 60, d2: 25, d3: 0, d4: 0 }], '21049');
assert.deepEqual([cum.none, cum.d0, cum.d1, cum.d2, cum.d3], [20, 20, 35, 25, 0]); assert.equal(cum.inDrought, 60); assert.equal(cum.worst, 'D2');
assert.equal(G.compactDrought([{ MapDate: '20261117', None: 100, D0: 0, D1: 0, D2: 0, D3: 0, D4: 0 }], '21049').worst, null);
assert.throws(() => G.compactDrought([{ MapDate: '20261117', None: 50, D0: 10, D1: 10, D2: 0, D3: 0, D4: 0 }], '21049'), /sum to 70/);
assert.throws(() => G.compactDrought({ message: 'error' }, '21049'), /unexpected/);
assert.throws(() => G.compactDrought([], '21049'), /no weekly/);
// The request path, end to end with the network replaced: fixed hosts, the county code checked, results cached.
const seen = [];
globalThis.fetch = async (url, init) => {
  seen.push({ url: String(url), accept: init?.headers?.accept });
  const u = new URL(url);
  const body = u.host === 'mapservices.weather.noaa.gov' ? (u.searchParams.get('outStatistics') ? { features: [{ attributes: { status: 'no_flooding', n: 10 } }] } : { features: [gauge({ gaugelid: 'FKFK2', status: 'minor', observed: '32', flood: '31' })] })
    : u.host === 'echodata.epa.gov' ? { Results: { Message: 'Success', QueryRows: '1', WaterSystems: [ws({ PWSId: 'KY0250482', PWSName: 'WINCHESTER MUNICIPAL UTILITIES', PopulationServedCount: '24800' })] } }
    : u.host === 'usdmdataservices.unl.edu' ? [{ MapDate: '20261117', None: 100, D0: 0, D1: 0, D2: 0, D3: 0, D4: 0 }] : null;
  return new Response(JSON.stringify(body), { status: body ? 200 : 404 });
};
const call = async (q) => { const r = await G.handle(new Request('https://x.supabase.co/functions/v1/grid-live?' + q)); return { status: r.status, body: await r.json(), cache: r.headers.get('cache-control') }; };
const origLog = console.log; console.log = () => {};
let r = await call('src=water&fips=21049');
assert.equal(r.status, 200); assert.equal(r.body.systems[0][0], 'KY0250482'); assert.match(r.cache, /max-age=3600/);
assert.match(seen[0].url, /^https:\/\/echodata\.epa\.gov\/echo\/sdw_rest_services\.get_systems\?output=JSON&p_fips=21049&p_systyp=CWS&p_act=Y&responseset=1000$/);
assert.equal(seen[0].accept, 'application/json');
await call('src=water&fips=21049'); assert.equal(seen.length, 1);                   // second read served from the cache
for (const bad of ['fips=2104', 'fips=21049x', 'fips=../x', 'fips=']) { r = await call('src=water&' + bad); assert.equal(r.status, 400); }
assert.equal(seen.length, 1);                                                         // nothing reached EPA
r = await call('src=rivers');
assert.equal(r.status, 200); assert.equal(r.body.inFlood, 1); assert.equal(r.body.reporting, 10);
assert.ok(seen.slice(1).every((x) => x.url.startsWith('https://mapservices.weather.noaa.gov/eventdriven/rest/services/water/riv_gauges/MapServer/0/query?')));
r = await call('src=drought&fips=21049');
assert.equal(r.status, 200); assert.equal(r.body.worst, null); assert.match(seen.at(-1).url, /^https:\/\/usdmdataservices\.unl\.edu\/api\/CountyStatistics\/GetDroughtSeverityStatisticsByAreaPercent\?aoi=21049&startdate=\d{1,2}\/\d{1,2}\/\d{4}&enddate=\d{1,2}\/\d{1,2}\/\d{4}&statisticsType=2$/);
r = await call('src=nope'); assert.equal(r.status, 400);
// More than 40 uncached county lookups in a minute: the rest are told to wait, and EPA is not asked.
const before = seen.length; let busy = 0;
for (let i = 0; i < 45; i++) { r = await call(`src=water&fips=${String(30000 + i)}`); if (r.status === 429) busy++; }
assert.ok(busy >= 4 && seen.length - before <= 40, `busy ${busy}, upstream ${seen.length - before}`);
console.log = origLog;
console.log('grid-live parsers: all assertions pass');
