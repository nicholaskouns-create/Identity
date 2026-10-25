// Mnemosyne: local-first archive. This file makes no remote calls. Optional sync lives in sync.js.
const DB='mnemosyne-archive', STORE='records';
const el=id=>document.getElementById(id);
const status=msg=>{el('status').textContent=msg};
function openDB(){return new Promise((resolve,reject)=>{const req=indexedDB.open(DB,1);req.onupgradeneeded=()=>{const db=req.result;if(!db.objectStoreNames.contains(STORE))db.createObjectStore(STORE,{keyPath:'id'})};req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error)})}
async function transaction(mode,action){
  const db=await openDB();
  try{return await new Promise((resolve,reject)=>{
    const tx=db.transaction(STORE,mode);
    let result;
    tx.oncomplete=()=>resolve(result);
    tx.onabort=()=>reject(tx.error || new Error('Archive transaction aborted'));
    try{
      const req=action(tx.objectStore(STORE));
      if(req)req.onsuccess=()=>{result=req.result};
    }catch(err){tx.abort();reject(err)}
  })}finally{db.close()}
}
const putMany=records=>transaction('readwrite',store=>{for(const record of records)store.put(record)});
const all=()=>transaction('readonly',s=>s.getAll());
const put=x=>transaction('readwrite',s=>s.put(x));
const digest=async text=>Array.from(new Uint8Array(await crypto.subtle.digest('SHA-256',new TextEncoder().encode(text)))).map(x=>x.toString(16).padStart(2,'0')).join('');
const canonical=r=>JSON.stringify([r.id,r.title,r.kind,r.content,r.created_at]);
async function verify(r){return r.sha256===await digest(canonical(r))}
async function render(){const query=el('search').value.toLowerCase();const list=(await all()).filter(r=>(r.title+' '+r.content).toLowerCase().includes(query)).sort((a,b)=>b.created_at.localeCompare(a.created_at));const root=el('records');root.replaceChildren();for(const r of list){const node=document.createElement('article');const title=document.createElement('strong');title.textContent=r.title+' · '+r.kind;const body=document.createElement('p');body.textContent=r.content.slice(0,500);const receipt=document.createElement('code');receipt.textContent=(await verify(r)?'SHA-256 verified: ':'CHECKSUM MISMATCH: ')+r.sha256;node.append(title,body,receipt);root.append(node)}if(!list.length)root.textContent='No matching records.'}
const started=Date.now();
const bus=typeof BroadcastChannel==='function'?new BroadcastChannel('mnemosyne-archive'):null;
function announce(){if(bus)bus.postMessage({type:'changed',at:Date.now()});if(typeof document.dispatchEvent==='function'&&typeof CustomEvent==='function')document.dispatchEvent(new CustomEvent('mnemosyne-local-change'))}
async function paintLive(){
  const clock=document.getElementById('live-clock');
  if(!clock||clock.style==null)return;
  const rows=await all();
  const count=document.getElementById('live-count');
  if(count)count.textContent=String(rows.length);
  const n=Math.floor((Date.now()-started)/1000);
  const residual=Math.pow(15/17,n);
  clock.textContent=new Date().toISOString().slice(11,19)+'Z';
  const out=document.getElementById('live-residual');
  if(out)out.textContent=residual<1e-6?'< 1e-6':residual.toExponential(2);
  const fill=document.getElementById('live-fill');
  if(fill&&fill.style)fill.style.width=(Math.min(1,residual)*100).toFixed(2)+'%';
  const step=document.getElementById('live-step');
  if(step)step.textContent=String(n);
}
if(bus)bus.onmessage=()=>{render().then(paintLive).catch(err=>status(err.message))};
if(typeof document.addEventListener==='function')document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')render().then(paintLive).catch(()=>{})});
if(typeof document.addEventListener==='function')document.addEventListener('mnemosyne-refresh',()=>{render().then(paintLive).catch(()=>{})});
try{globalThis.MnemosyneArchive={all,putMany,verify,canonical,digest,announce,refresh:()=>render().then(paintLive)}}catch(err){}
if(typeof setInterval==='function')setInterval(()=>{paintLive().catch(()=>{})},1000);
el('record').addEventListener('submit',async e=>{e.preventDefault();try{const f=new FormData(e.target),r={id:crypto.randomUUID(),title:String(f.get('title')).trim(),kind:String(f.get('kind')),content:String(f.get('content')),created_at:new Date().toISOString()};r.sha256=await digest(canonical(r));await put(r);e.target.reset();announce();status('Saved with verifiable receipt.');await render();await paintLive()}catch(err){status('Save failed: '+err.message)}});
el('search').addEventListener('input',()=>render().catch(err=>status(err.message)));
el('export').addEventListener('click',async()=>{try{const records=await all(),blob=new Blob([JSON.stringify({format:'mnemosyne-archive-v1',records},null,2)],{type:'application/json'}),url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download='mnemosyne-archive.json';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);status('Exported '+records.length+' records.')}catch(err){status(err.message)}});
el('import').addEventListener('change',async e=>{try{const file=e.target.files[0];if(!file)return;if(file.size>20_000_000)throw Error('Import exceeds 20 MB');const data=JSON.parse(await file.text());if(!data||data.format!=='mnemosyne-archive-v1'||!Array.isArray(data.records)||data.records.length>10000)throw Error('Unsupported archive');const seenIds=new Set();for(const r of data.records){if(!r||typeof r.id!=='string'||typeof r.title!=='string'||typeof r.kind!=='string'||typeof r.content!=='string'||typeof r.created_at!=='string'||typeof r.sha256!=='string'||!(await verify(r)))throw Error('Invalid or altered record');if(seenIds.has(r.id))throw Error('Duplicate record ID in import');seenIds.add(r.id)}await putMany(data.records);announce();status('Imported '+data.records.length+' verified records.');await render();await paintLive()}catch(err){status('Import rejected: '+err.message)}finally{e.target.value=''}});
render().then(paintLive).catch(err=>status('Archive unavailable: '+err.message));
