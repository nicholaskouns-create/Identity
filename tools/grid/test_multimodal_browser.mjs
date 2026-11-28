// Headless browser E2E for the actual Grid standalone radar UI.
// Publisher responses are synthetic fixtures to test integration; never presented as live measurements.
import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const base=process.env.GRID_TEST_URL||'http://127.0.0.1:8765/grid/radar/';
const browser=await chromium.launch({headless:true,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader','--no-sandbox']});
const context=await browser.newContext({viewport:{width:390,height:844},deviceScaleFactor:1});
const page=await context.newPage();
const png=Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScL/nwAAAABJRU5ErkJggg==','base64');
const json=(r,body)=>r.fulfill({status:200,contentType:'application/json',headers:{'access-control-allow-origin':'*'},body:JSON.stringify(body)});
await page.route('https://server.arcgisonline.com/**',r=>r.fulfill({status:200,contentType:'image/png',body:png}));
await page.route('https://mapservices.weather.noaa.gov/**',r=>r.fulfill({status:200,contentType:'image/png',body:png}));
await page.route('https://earthquake.usgs.gov/**',r=>json(r,{type:'FeatureCollection',features:[{type:'Feature',geometry:{type:'Point',coordinates:[-118.98,47.95,5]},properties:{mag:3.1,place:'Synthetic WA test',time:1780000000000,url:'https://earthquake.usgs.gov/',tsunami:0}}]}));
await page.route('https://api.weather.gov/**',r=>json(r,{type:'FeatureCollection',features:[{type:'Feature',geometry:{type:'Polygon',coordinates:[[[-119.5,47.5],[-118.5,47.5],[-118.5,48.3],[-119.5,48.3],[-119.5,47.5]]]},properties:{id:'test-warning',event:'Severe Thunderstorm Warning',severity:'Severe',urgency:'Immediate'}}]}));
await page.route('https://services3.arcgis.com/**',r=>json(r,{type:'FeatureCollection',features:[{type:'Feature',geometry:{type:'Point',coordinates:[-119,47.95]},properties:{IncidentName:'Synthetic fire',IncidentTypeCategory:'WF',IncidentSize:100}}]}));
await page.route('https://services.swpc.noaa.gov/**',r=>json(r,{'Observation Time':'2026-11-27T22:00:00Z','Forecast Time':'2026-11-27T23:00:00Z',coordinates:[[240,50,70],[250,55,50],[260,60,80],[270,65,40]]}));
const failures=[];
page.on('pageerror',e=>failures.push('page: '+e.message));
try{
 await page.goto(base,{waitUntil:'domcontentloaded',timeout:60000});
 await page.waitForSelector('[data-mm-feed="quakes"]',{timeout:45000});
 assert.equal(await page.locator('[data-mm-feed]').count(),5);
 await page.locator('[data-mm-feed="quakes"]').check();
 await page.locator('[data-mm-feed="plants"]').check();
 await page.locator('[data-mm-feed="alerts"]').check();
 await page.locator('[data-mm-density]').check();
 await page.waitForFunction(()=>document.querySelector('[data-mm-analysis]')?.textContent?.includes('mapped NWS severe alert polygons'),{timeout:40000});
 const analysis=await page.locator('[data-mm-analysis]').textContent();
 assert.ok(analysis.includes('historical nameplate'),analysis);
 await page.locator('[data-mm-preset-name]').fill('browser-test');
 await page.locator('[data-mm-save]').click();
 assert.equal(await page.locator('[data-mm-presets]').inputValue(),'browser-test');
 await page.reload({waitUntil:'domcontentloaded'});
 await page.waitForSelector('[data-mm-feed="quakes"]',{timeout:45000});
 assert.equal(await page.locator('[data-mm-feed="quakes"]').isChecked(),true);
 assert.equal(await page.locator('[data-mm-density]').isChecked(),true);
 assert.ok((await page.locator('[data-mm-presets]').textContent()).includes('browser-test'));
 fs.mkdirSync('artifacts',{recursive:true});
 await page.screenshot({path:'artifacts/multimodal-radar-browser-smoke.png',fullPage:true});
 assert.deepEqual(failures,[]);
 console.log(JSON.stringify({status:'PASS',tests:['map initialized','5 feeds','mocked USGS + NWS + published plant intersection','derived density','saved browser preset survives reload'],analysis,simulation:'all publisher responses synthetic in this test'},null,2));
}finally{await browser.close();}
