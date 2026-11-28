// Grid × Radar multimodal overlays. Each source remains independent of MRMS.
// Browser-local preferences only; no keys, source data or private records are uploaded.
import { fetchQuakes, fetchFires, fetchNws, fetchAurora } from './sources.js';

const KEY = 'kkp-multimodal-radar-v1';
const EMPTY = () => ({ type: 'FeatureCollection', features: [] });
const FEEDS = [
 { id: 'quakes', label: 'USGS earthquakes (M2.5+, 24 h)', provider: 'USGS', kind: 'point' },
 { id: 'fires', label: 'NIFC wildfire incidents', provider: 'NIFC / WFIGS', kind: 'point' },
 { id: 'alerts', label: 'NWS severe-weather polygons', provider: 'NWS', kind: 'polygon' },
 { id: 'aurora', label: 'NOAA SWPC aurora forecast', provider: 'NOAA SWPC', kind: 'point' },
 { id: 'plants', label: 'U.S. generating plants (published)', provider: 'WRI / EIA-860', kind: 'point' }
];
export const MULTIMODAL_FEEDS = FEEDS.map(x => ({...x}));
const id = name => 'mmr-' + name;
const escaped = s => String(s || '').replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const clip = (x,lo,hi) => Math.max(lo, Math.min(hi,x));
const loadPrefs = () => { try { return JSON.parse(localStorage.getItem(KEY) || '{}') || {}; } catch { return {}; } };
const savePrefs = prefs => { try { localStorage.setItem(KEY, JSON.stringify(prefs)); } catch {} };
export const distanceKm = (a,b) => {
 const r = Math.PI/180, dlat=(b[1]-a[1])*r, dlon=(b[0]-a[0])*r;
 const h=Math.sin(dlat/2)**2 + Math.cos(a[1]*r)*Math.cos(b[1]*r)*Math.sin(dlon/2)**2;
 return 12742*Math.asin(Math.min(1,Math.sqrt(h)));
};

export function pointInRing(point, ring) {
 let inside=false,x=point[0],y=point[1];
 for(let i=0,j=ring.length-1;i<ring.length;j=i++){
  const a=ring[i],b=ring[j];
  if((a[1]>y)!==(b[1]>y)&&x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])inside=!inside;
 }
 return inside;
}
export function pointInGeometry(point,g) {
 if(!g)return false;
 const polys=g.type==='Polygon'?[g.coordinates]:g.type==='MultiPolygon'?g.coordinates:[];
 return polys.some(rings=>rings.length&&pointInRing(point,rings[0])&&!rings.slice(1).some(hole=>pointInRing(point,hole)));
}

function layerIds(name) { return name==='alerts' ? [id(name+'-fill'),id(name+'-line')] : [id(name+'-dots')]; }
function paints(name) {
 if(name==='quakes') return {'circle-radius':['interpolate',['linear'],['zoom'],3,3,10,8], 'circle-color':'#fa9c51','circle-opacity':.83,'circle-stroke-color':'#19191f','circle-stroke-width':1};
 if(name==='fires') return {'circle-radius':6,'circle-color':'#ff634c','circle-opacity':.85,'circle-stroke-color':'#ffddaa','circle-stroke-width':1};
 if(name==='aurora') return {'circle-radius':3,'circle-color':['interpolate',['linear'],['get','p'],10,'#146a7a',40,'#1ad0c1',80,'#b0ffae'],'circle-opacity':.43,'circle-blur':.25};
 return {'circle-radius':['interpolate',['linear'],['zoom'],3,1.5,10,5], 'circle-color':'#b7a8fb','circle-opacity':.6};
}
async function retrieve(name) {
 if(name==='quakes') return fetchQuakes();
 if(name==='fires') return fetchFires();
 if(name==='alerts') { const a=await fetchNws(); return a.geo || EMPTY(); }
 if(name==='aurora') {
  const a=await fetchAurora(); const features=(a.pts||[]).filter((p,i)=>p.properties.p>=15 && i%3===0);
  return {type:'FeatureCollection',features,observationTime:a.observed,forecastTime:a.forecast,thinned:true};
 }
 if(name==='plants') {
  const response=await fetch(new URL('../data/plants-us.json',import.meta.url),{cache:'force-cache'});
  if(!response.ok) throw Error('Plant archive HTTP '+response.status);
  const d=await response.json();
  return {type:'FeatureCollection',features:d.rows.map((r,i)=>({type:'Feature',id:i,geometry:{type:'Point',coordinates:[r[0],r[1]]},properties:{capacity_mw:r[2],fuel:r[3],name:r[4],gppd_id:r[5]}})),published:true};
 }
 return EMPTY();
}
export function mountMultimodalRadar(map, root) {
 if(!root) throw Error('Multimodal controls root missing');
 const store=loadPrefs(), selected=Object.assign({quakes:false,fires:false,alerts:false,aurora:false,plants:false},store.selected||{});
 let radius=clip(Number(store.radius)||40,5,250), visible=false, timer=null, loading=new Map(), data=new Map(), statuses=new Map();
 root.innerHTML = '<section class="mmr-panel" style="padding:12px 6px;border-top:1px solid #45606c;margin-top:10px"><div class="eyebrow">Multimodal radar · independent measurements</div><p style="font-size:12px;opacity:.8">Optional geospatial overlays. NOAA MRMS is precipitation reflectivity; these other sources are not Doppler velocity or radar I/Q.</p><div data-mm-list></div><p data-mm-status style="font-size:12px" aria-live="polite">Select a feed to fetch it.</p><label style="font-size:12px">Proximity radius <input data-mm-radius type="range" min="5" max="250" step="5"><b data-mm-radius-label></b> km</label><p data-mm-analysis style="font-size:12px">Proximity analysis loads when plants and events are selected.</p><div><button class="btn" data-mm-refresh>Refresh selected</button></div><div style="margin-top:8px"><input data-mm-preset-name placeholder="Preset name" aria-label="Preset name" style="max-width:125px"><button class="btn" data-mm-save>Save view</button></div><div><select data-mm-presets aria-label="Saved views"></select><button class="btn" data-mm-restore>Restore</button><button class="btn" data-mm-delete>Delete</button></div><div style="margin-top:8px"><button class="btn" data-mm-export>Export findings JSON</button></div><p style="font-size:11px;opacity:.7">Saved views stay in this browser only. Proximity is geographical screening, not causal attribution. Data are labeled by publisher and browser retrieval time.</p><p style="font-size:12px"><a href="https://nicholaskouns-create.github.io/Radar/optical-radar-atlas/" target="_blank" rel="noopener">Synthetic phase / coherence / E₄₇ lab</a> · <a href="https://github.com/nicholaskouns-create/Radar/blob/main/src/e47_radar/calibrated_fmcw.py" target="_blank" rel="noopener">Measured I/Q FMCW baseline code</a></p></section>';
 const qs=s=>root.querySelector(s), list=qs('[data-mm-list]'), status=qs('[data-mm-status]'), analysis=qs('[data-mm-analysis]'), range=qs('[data-mm-radius]'), rlabel=qs('[data-mm-radius-label]');
 list.innerHTML=FEEDS.map(f=>'<label style="display:block;margin:6px 0;font-size:12px"><input type="checkbox" data-mm-feed="'+f.id+'"> '+escaped(f.label)+' <small style="opacity:.6">('+f.provider+')</small></label>').join('');
 range.value=radius; rlabel.textContent=radius;
 const persist=()=>savePrefs({selected,radius,presets:store.presets||{}});
 const chosen=()=>FEEDS.filter(f=>selected[f.id]).map(f=>f.id);
 function layers(name,fc) {
  if(!map.getSource(id(name))) map.addSource(id(name),{type:'geojson',data:fc});
  else map.getSource(id(name)).setData(fc);
  const before=map.getLayer('states-line')?'states-line':undefined;
  if(name==='alerts'){
   if(!map.getLayer(id('alerts-fill')))map.addLayer({id:id('alerts-fill'),type:'fill',source:id(name),paint:{'fill-color':'#f6cf6c','fill-opacity':.10}},before);
   if(!map.getLayer(id('alerts-line')))map.addLayer({id:id('alerts-line'),type:'line',source:id(name),paint:{'line-color':'#ffd170','line-width':1.6,'line-opacity':.75}},before);
  }else if(!map.getLayer(id(name+'-dots')))map.addLayer({id:id(name+'-dots'),type:'circle',source:id(name),paint:paints(name)},before);
  layerIds(name).forEach(l=>{if(map.getLayer(l))map.setLayoutProperty(l,'visibility',visible&&selected[name]?'visible':'none')});
 }
 function updateAnalysis(){
  const plants=data.get('plants')?.features||[];
  if(!plants.length){analysis.textContent='Select generating plants together with incident, earthquake or NWS alerts to calculate geographical intersections.';return}
  const events=['quakes','fires'].flatMap(name=>(data.get(name)?.features||[]).map(f=>({...f,origin:name})));
  const alerts=(data.get('alerts')?.features||[]).filter(f=>['Polygon','MultiPolygon'].includes(f.geometry?.type));
  const notes=[];
  if(events.length){
   const found=new Set(),counts={quakes:0,fires:0};let pairs=0;
   for(let i=0;i<plants.length;i++){
    const p=plants[i].geometry?.coordinates; if(!p)continue;
    for(const e of events){const q=e.geometry?.coordinates;if(!q)continue;if(distanceKm(p,q)<=radius){found.add(i);counts[e.origin]++;pairs++;}}
   }
   const cap=[...found].reduce((sum,i)=>sum+Number(plants[i].properties.capacity_mw||0),0);
   notes.push(found.size+' plants within '+radius+' km of ≥1 plotted event; '+pairs+' plant–event pairs ('+counts.quakes+' seismic, '+counts.fires+' fire), '+Math.round(cap).toLocaleString()+' MW historical nameplate.');
  }
  if(alerts.length){
   const matched=new Set();let pairs=0;
   for(let i=0;i<plants.length;i++){
    const p=plants[i].geometry?.coordinates;if(!p)continue;
    for(const warning of alerts)if(pointInGeometry(p,warning.geometry)){matched.add(i);pairs++}
   }
   const cap=[...matched].reduce((sum,i)=>sum+Number(plants[i].properties.capacity_mw||0),0);
   notes.push(matched.size+' plants within '+alerts.length+' mapped NWS severe alert polygons ('+pairs+' polygon intersections, '+Math.round(cap).toLocaleString()+' MW historical nameplate).');
  }
  analysis.textContent=(notes.length?notes.join(' '):'Select earthquakes, wildfire incidents or NWS severe alerts to compute intersections.')+' Geographic screening only; outages, causality and reliability impacts are not inferred.';
 }
 async function load(name){
  if(!visible||!selected[name])return;
  if(loading.has(name))return loading.get(name);
  statuses.set(name,'loading');showStatus();
  const p=(async()=>{
   try{
    const fc=await retrieve(name);
    if(!selected[name])return;
    data.set(name,fc);layers(name,fc);
    statuses.set(name,fc.features.length+' plotted · '+(fc.published?'published archive':'publisher feed')+' · retrieved '+new Date().toISOString().slice(0,16)+'Z'+(fc.forecastTime?' · forecast '+fc.forecastTime:''));
    updateAnalysis();
   }catch(e){statuses.set(name,'unavailable: '+String(e.message||e));}
   finally{loading.delete(name);showStatus();}
  })(); loading.set(name,p);return p;
 }
 function showStatus(){status.textContent=chosen().map(name=>name+': '+(statuses.get(name)||'not fetched')).join(' · ')||'No additional feeds enabled';}
 function redraw(){FEEDS.forEach(f=>{const inp=qs('[data-mm-feed="'+f.id+'"]');inp.checked=!!selected[f.id];layerIds(f.id).forEach(l=>{if(map.getLayer(l))map.setLayoutProperty(l,'visibility',visible&&selected[f.id]?'visible':'none')});if(visible&&selected[f.id]&&!data.has(f.id))load(f.id)});showStatus();updateAnalysis();}
 async function refresh(){await Promise.all(chosen().map(load));}
 function presets(){const sel=qs('[data-mm-presets]');sel.innerHTML='<option value="">Saved views</option>'+Object.keys(store.presets||{}).map(name=>'<option value="'+escaped(name)+'">'+escaped(name)+'</option>').join('');}
 list.addEventListener('change',e=>{const name=e.target.dataset.mmFeed;if(!Object.hasOwn(selected,name))return;selected[name]=e.target.checked;persist();redraw();});
 range.oninput=()=>{radius=Number(range.value);rlabel.textContent=radius;persist();updateAnalysis()};
 qs('[data-mm-refresh]').onclick=refresh;
 qs('[data-mm-save]').onclick=()=>{const name=qs('[data-mm-preset-name]').value.trim().slice(0,60);if(!name){status.textContent='Enter a preset name first.';return}store.presets ||= {};store.presets[name]={selected:{...selected},radius,center:map.getCenter().toArray(),zoom:map.getZoom()};persist();presets();qs('[data-mm-presets]').value=name;status.textContent='Saved '+name+' on this device.';};
 qs('[data-mm-restore]').onclick=()=>{const name=qs('[data-mm-presets]').value,p=store.presets?.[name];if(!p)return;Object.assign(selected,p.selected);radius=clip(p.radius||40,5,250);range.value=radius;rlabel.textContent=radius;persist();if(Array.isArray(p.center))map.easeTo({center:p.center,zoom:p.zoom});redraw();};
 qs('[data-mm-delete]').onclick=()=>{const name=qs('[data-mm-presets]').value;if(!store.presets?.[name])return;delete store.presets[name];persist();presets();status.textContent='Deleted saved view '+name};
 qs('[data-mm-export]').onclick=()=>{
  const snapshot={format:'Grid Multimodal Radar v1',exported_at:new Date().toISOString(),coordinate_reference:'WGS84',selected:{...selected},radius_km:radius,sources:Object.fromEntries([...statuses]),counts:Object.fromEntries([...data].map(([k,v])=>[k,v.features.length])),note:'Proximity is not causal evidence. No raw radar velocity or I/Q inferred.'};
  const a=document.createElement('a');a.href=URL.createObjectURL(new Blob([JSON.stringify(snapshot,null,2)],{type:'application/json'}));a.download='grid-multimodal-snapshot.json';a.click();setTimeout(()=>URL.revokeObjectURL(a.href),1000);
 };
 presets();redraw();
 return {setVisible(on){
  visible=!!on;root.hidden=!visible;if(visible){redraw();if(!timer)timer=setInterval(refresh,600000)}else{clearInterval(timer);timer=null;FEEDS.forEach(f=>layerIds(f.id).forEach(l=>{if(map.getLayer(l))map.setLayoutProperty(l,'visibility','none')}))};
 },refresh,features:name=>data.get(name)||EMPTY(),selected:()=>({...selected})};
}
