// Deterministic source, geodesic and interface contracts. No live data is synthesized.
import assert from 'node:assert/strict';
import fs from 'node:fs';
import test from 'node:test';
const source = path => fs.readFileSync(path,'utf8');
const asModule = s => import('data:text/javascript;base64,'+Buffer.from(s).toString('base64'));
const multiSrc = source('grid/live/multimodal.js').replace(/^import \{ fetchQuakes, fetchFires, fetchNws, fetchAurora \} from '.\/sources.js';/m,'');
const multi = await asModule(multiSrc);
const radar = await asModule(source('grid/live/radar.js'));
const registry = await asModule(source('grid/live/sources.js'));
test('Geodesic metric is symmetric, exact at coincidence and within Earth-scale tolerances',()=>{
 assert.equal(multi.distanceKm([-100,30],[-100,30]),0);
 const d=multi.distanceKm([0,0],[0,1]);
 assert.ok(d>111.1&&d<111.3,d);
 assert.ok(Math.abs(multi.distanceKm([-115,36],[-116,37])-multi.distanceKm([-116,37],[-115,36]))<1e-10);
});
test('Five independent modalities remain distinct from radar reflectivity',()=>{
 const x=multi.MULTIMODAL_FEEDS;
 assert.deepEqual(x.map(e=>e.id),['quakes','fires','alerts','aurora','plants']);
 assert.ok(x.every(e=>e.provider&&e.kind));
 assert.ok(!x.some(e=>/velocity|doppler I.Q/i.test(e.label)));
});
test('NWS polygon containment respects boundaries and interior holes',()=>{
 const outer=[[0,0],[4,0],[4,4],[0,4],[0,0]],hole=[[1,1],[2,1],[2,2],[1,2],[1,1]];
 const geometry={type:'Polygon',coordinates:[outer,hole]};
 assert.equal(multi.pointInGeometry([3,3],geometry),true);
 assert.equal(multi.pointInGeometry([1.5,1.5],geometry),false);
 assert.equal(multi.pointInGeometry([10,10],geometry),false);
 const multiPoly={type:'MultiPolygon',coordinates:[[[[20,20],[21,20],[21,21],[20,20]]],[outer]]};
 assert.equal(multi.pointInGeometry([3,3],multiPoly),true);
});
test('MRMS tile requests preserve EPSG:3857 placeholder and optional historical time',()=>{
 assert.ok(radar.tileURL().includes('bbox={bbox-epsg-3857}'));
 assert.ok(!radar.tileURL().includes('&time='));
 assert.ok(radar.tileURL(1234567890000,3).includes('&time=1234567890000'));
});
test('Source parsers retain publisher geometry and event labels',()=>{
 const q=registry.parseQuakes({features:[{geometry:{type:'Point',coordinates:[-115,36,12]},properties:{mag:3.2,place:'Test',time:1700000000,url:'https://earthquake.usgs.gov/',tsunami:0}}]});
 assert.equal(q.features.length,1);assert.deepEqual(q.features[0].geometry.coordinates,[-115,36]);
 const n=registry.parseNws({features:[{id:'a',geometry:{type:'Polygon',coordinates:[[[0,0],[1,0],[1,1],[0,0]]]},properties:{event:'Severe Thunderstorm Warning',severity:'Severe'}}]});
 assert.equal(n.geo.features.length,1); assert.equal(n.geo.features[0].geometry.type,'Polygon');
 const a=registry.parseAurora({coordinates:[[270,60,20],[90,60,20]],'Observation Time':'2026-11-27T20:00:00Z'});
 assert.equal(a.pts.length,1);assert.equal(a.pts[0].geometry.coordinates[0],-90);
});
test('Grid and dedicated radar share registered engine and browser-local saved views',()=>{
 const main=source('grid/app.js'),standalone=source('grid/radar/index.html');
 assert.ok(main.includes("import('./live/multimodal.js')"));
 assert.ok(standalone.includes("live/multimodal.js"));
 assert.ok(multiSrc.includes('localStorage.setItem'));
 assert.ok(multiSrc.includes('Save view') && multiSrc.includes('Export findings JSON'));
});
