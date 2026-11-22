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
console.log('grid-live parsers: all assertions pass');
