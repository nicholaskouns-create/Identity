// Optional NOAA MRMS reflectivity overlay. No requests or timers until enabled.
const ID='mrms-radar';
export const URL='https://mapservices.weather.noaa.gov/eventdriven/rest/services/radar/radar_base_reflectivity_time/ImageServer';
export function tileURL(time=null,revision=0){
 return URL+'/exportImage?bbox={bbox-epsg-3857}&bboxSR=3857&imageSR=3857&size=256,256&format=png32&transparent=true&f=image&interpolation=RSP_NearestNeighbor'+(time===null?'':'&time='+time)+'&_='+revision;
}
export function mountRadar(map, root, status, local, national){
 const settingsKey='kkp-mrms-view-v1';
 let prior={};try{prior=JSON.parse(localStorage.getItem(settingsKey)||'{}')||{}}catch{}
 let enabled=false, timer=null, animation=null, time=null, revision=0;
 let opacity=Number.isFinite(prior.opacity)?Math.max(0,Math.min(1,prior.opacity)):.65;
 let historyMinutes=Number.isFinite(prior.historyMinutes)?Math.max(0,Math.min(225,Math.round(prior.historyMinutes/5)*5)):0;
 const remember=()=>{try{localStorage.setItem(settingsKey,JSON.stringify({opacity,historyMinutes}))}catch{}};
 const box=document.createElement('div'); box.hidden=true;
 box.innerHTML='<div class="eyebrow">NOAA MRMS · reflectivity (dBZ)</div><label>Opacity <input aria-label="Radar opacity" type="range" min="0" max="100" value="65"></label><div><button class="btn" data-r="local">Local</button> <button class="btn" data-r="national">Lower 48</button></div><label>History (minutes ago) <input aria-label="Radar history" type="range" min="0" max="225" step="5" value="0"></label><div aria-live="polite" data-r="stamp">Latest available</div><button class="btn" data-r="play">Replay last hour</button> <button class="btn" data-r="live">Latest</button><p>Colors show echo reflectivity, not radial wind velocity. Blank areas may be missing coverage. <a href="https://radar.weather.gov/" target="_blank" rel="noopener">NOAA legend / radar</a> · <a href="https://nicholaskouns-create.github.io/Radar/optical-radar-atlas/" target="_blank" rel="noopener">Radar laboratory</a></p>';
 root.append(box);
 const sliders=box.querySelectorAll('input'), stamp=box.querySelector('[data-r="stamp"]');
 sliders[0].value=Math.round(opacity*100);sliders[1].value=historyMinutes;
 function refresh(){
  if(!enabled)return;
  const tiles=[tileURL(time,++revision)];
  if(!map.getSource(ID)){
   map.addSource(ID,{type:'raster',tiles,tileSize:256,maxzoom:8,attribution:'NOAA / NWS MRMS'});
   map.addLayer({id:ID,type:'raster',source:ID,paint:{'raster-opacity':opacity,'raster-fade-duration':0}},map.getLayer('states-line')?'states-line':undefined);
  }else map.getSource(ID).setTiles(tiles);
  stamp.textContent=time===null?'Latest available · requested '+new Date().toISOString().slice(11,16)+'Z':'Requested '+new Date(time).toISOString().slice(11,16)+'Z';
  status('mrms','loading','Radar imagery requested; observation time not independently verified');
 }
 function stop(){clearInterval(animation);animation=null;}
 function age(n){historyMinutes=Math.max(0,Math.min(225,Math.round(n/5)*5));time=historyMinutes?Math.floor(Date.now()/300000)*300000-historyMinutes*60000:null;sliders[1].value=historyMinutes;remember();refresh();}
 const sourced=e=>{if(enabled&&e.sourceId===ID&&e.isSourceLoaded&&e.sourceDataType==='content')status('mrms','ok','Radar source loaded; requested time is not verified observation time');};
 const error=e=>{if(enabled&&(e.sourceId===ID||e.source?.id===ID))status('mrms','error','Radar imagery unavailable');};
 map.on('sourcedata',sourced);map.on('error',error);
 sliders[0].oninput=()=>{opacity=Number(sliders[0].value)/100;remember();if(map.getLayer(ID))map.setPaintProperty(ID,'raster-opacity',opacity);};
 sliders[1].onchange=()=>{stop();age(Number(sliders[1].value));};
 box.onclick=e=>{switch(e.target.dataset.r){case 'local':local();break;case 'national':national();break;case 'live':stop();age(0);break;case 'play':stop();let n=60;age(n);animation=setInterval(()=>{n-=5;if(n<0){stop();return;}age(n);},1800);break;}};
 return {getState(){return {opacity,historyMinutes}},applyState(p){if(!p)return;stop();if(Number.isFinite(p.opacity)){opacity=Math.max(0,Math.min(1,p.opacity));sliders[0].value=Math.round(opacity*100);if(map.getLayer(ID))map.setPaintProperty(ID,'raster-opacity',opacity)}age(Number(p.historyMinutes)||0);remember()},set(on){if(enabled===on)return;enabled=on;box.hidden=!on;if(on){age(historyMinutes);timer=setInterval(()=>{if(time===null&&!animation)refresh();},300000);}else{stop();clearInterval(timer);if(map.getLayer(ID))map.removeLayer(ID);if(map.getSource(ID))map.removeSource(ID);status('mrms','idle','Optional overlay off');}}};
}
