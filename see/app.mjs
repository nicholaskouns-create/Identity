import {SCHEMA,newRecord,rank,reflect,tensions,evidenceVector,exportArchive,importArchive,sourceContext} from "./engine.mjs";
const $=id=>document.getElementById(id);
const STORAGE="SEE_RECORDS_V1";
const MODEL="Llama-3.2-1B-Instruct-q4f16_1-MLC";
let records=[],engine=null,busy=false;
const escapeURL=u=>/^https:\/\/[^ \n<>]+$/i.test(u||"")?u:null;
const sampleSources=[
 {statement:"On the 11-observation DENSITY seed, leave-one-out raw ART RMSE was 0.4318927246; P47 RMSE was 0.4993708025.",source:"DENSITY · reconstruction study",kind:"repository",url:"https://github.com/nicholaskouns-create/E47-Kartekeya/blob/main/docs/density-sensitivity-tomography.md"},
 {statement:"In the DENSITY rank-47 control, P47 beat 0 of 47 deterministic random rank-47 projector controls; the canonical P47-specific generalization gate remains OPEN.",source:"DENSITY · stronger control",kind:"repository",url:"https://github.com/nicholaskouns-create/E47-Kartekeya/blob/main/certificates/MC-DENSITY-RANK47-CONTROL-20260930-001.json"},
 {statement:"The BUILD transport surface uses xᵢ(k) = μ + (1−α)^k(xᵢ(0)−μ), preserving the centroid and contracting dispersion Dk = (1−α)^(2k)D0.",source:"BUILD · supplied public instrument",kind:"external",url:"https://brave-ivory-pearl-ever.grok.me/"},
 {statement:"The SCALAR surface visualizes a 125-state Casimir spectral carrier, the 47-dimensional kernel selected at eigenvalues 6 and 30, and transverse spectral contraction.",source:"SCALAR · supplied public instrument",kind:"external",url:"https://heart-eagle-blade-hazel.grok.me/"}
];
function notify(msg){const n=$("askStatus");n.textContent=msg;setTimeout(()=>{if(n.textContent===msg)n.textContent="LOCAL-FIRST · NO AUTOMATIC UPLOAD"},7000)}
function load(){
 try {const x=JSON.parse(localStorage.getItem(STORAGE)||"[]"); if(!Array.isArray(x))throw Error("Invalid local store.");records=importArchive(JSON.stringify(x));}
 catch(e){records=[];console.warn("SEE local-store read failed:",e.message);notify("LOCAL STORE UNAVAILABLE — EXPORT REGULARLY")}
 renderRecords();
}
function persist(){
 try{localStorage.setItem(STORAGE,JSON.stringify(records));return true}
 catch(e){notify("LOCAL STORAGE FAILED — EXPORT YOUR RECORDS");return false}
}
function setView(view){
 const allowed=["mirror","evidence","sources","method"];if(!allowed.includes(view))return;
 document.querySelectorAll(".view").forEach(n=>n.classList.toggle("hidden",n.id!=="view-"+view));
 document.querySelectorAll(".navitem").forEach(n=>{const active=n.dataset.view===view;n.classList.toggle("active",active);if(active)n.setAttribute("aria-current","page");else n.removeAttribute("aria-current")});
 $("viewLabel").textContent=view.toUpperCase();
 try{history.replaceState(null,"","#"+view)}catch{}
 scrollTo({top:0,behavior:"instant"});
}
document.querySelectorAll("[data-view]").forEach(n=>n.addEventListener("click",()=>setView(n.dataset.view)));
document.querySelectorAll("[data-go]").forEach(n=>n.addEventListener("click",()=>setView(n.dataset.go)));
function make(tag,cls="",text=""){
 const n=document.createElement(tag);if(cls)n.className=cls;if(text)n.textContent=text;return n;
}
function renderRecords(){
 $("recordCount").textContent=records.length;
 $("auditCount").textContent=String(records.length).padStart(2,"0");
 $("tensionCount").textContent=tensions(records).length;
 const box=$("recordList");box.replaceChildren();
 if(!records.length){box.append(make("div","empty","The record register is empty. Add a note to begin. Your words remain editable."));return;}
 records.slice().reverse().forEach(r=>{
 const item=make("article","record");
 item.append(make("div","record-title",r.statement));
 const meta=make("div","record-meta",r.kind.toUpperCase()+" / "+r.source+" / "+r.created_at.slice(0,10));
 item.append(meta);
 const actions=make("div","record-actions");
 if(escapeURL(r.url)){const a=make("a","","VIEW SOURCE ↗");a.href=r.url;a.target="_blank";a.rel="noopener noreferrer";actions.append(a);}
 const edit=make("button","","EDIT");edit.type="button";edit.addEventListener("click",()=>{
  const next=prompt("Edit evidence statement:",r.statement);if(next===null)return;
  if(!next.trim())return;records=records.map(x=>x.id===r.id?{...x,statement:next.trim().slice(0,2500)}:x);persist();renderRecords();
 });
 const del=make("button","","DELETE");del.type="button";del.addEventListener("click",()=>{records=records.filter(x=>x.id!==r.id);persist();renderRecords()});
 actions.append(edit,del);item.append(actions);box.append(item);
 });
}
$("recordForm").addEventListener("submit",e=>{
 e.preventDefault();
 try{
 const r=newRecord($("statement").value,$("sourceName").value,$("kind").value,$("sourceURL").value);
 records.push(r);const ok=persist();renderRecords();
 $("recordForm").reset();$("sourceName").value="Personal note";
 $("recordStatus").textContent=ok?"Record added to this browser. Not independently verified.":"In memory only; local storage failed. Export now.";
 }catch(e){$("recordStatus").textContent=e.message;}
});
$("loadExamples").addEventListener("click",()=>{
 let n=0;
 for(const x of sampleSources){if(records.some(r=>r.statement===x.statement))continue;records.push(newRecord(x.statement,x.source,x.kind,x.url));n++;}
 persist();renderRecords();$("recordStatus").textContent=n+" published-source examples added, labeled as source claims—not facts about you.";
});
$("clearRecords").addEventListener("click",()=>{
 if(!confirm("Delete all See records stored in this browser? Export first if you wish to keep them."))return;
 records=[];persist();renderRecords();$("recordStatus").textContent="Local evidence register cleared.";
});
function download(name,text,mime="application/json"){
 const url=URL.createObjectURL(new Blob([text],{type:mime}));const a=document.createElement("a");a.href=url;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1500);
}
async function exportData(){
 const archive=exportArchive(records);
 download("SEE-evidence-"+new Date().toISOString().slice(0,10)+".json",archive);
 try{
 const data=await crypto.subtle.digest("SHA-256",new TextEncoder().encode(archive));
 const hex=[...new Uint8Array(data)].map(b=>b.toString(16).padStart(2,"0")).join("");
 notify("EXPORTED / SHA-256 "+hex.slice(0,16)+"…");
 $("recordStatus").textContent="Archive exported. SHA-256: "+hex+" — integrity of bytes, not proof of truth.";
 }catch{notify("ARCHIVE EXPORTED")}
}
$("exportTop").addEventListener("click",exportData);
$("exportRecords").addEventListener("click",exportData);
$("importRecords").addEventListener("click",()=>$("fileInput").click());
$("fileInput").addEventListener("change",async e=>{
 const file=e.target.files[0];if(!file)return;
 try{if(file.size>3e6)throw Error("Maximum import size is 3 MB.");
 const incoming=importArchive(await file.text());
 const existing=new Set(records.map(r=>r.id));let n=0;
 for(const r of incoming){if(existing.has(r.id))continue;records.push(r);existing.add(r.id);n++;}
 persist();renderRecords();$("recordStatus").textContent="Imported "+n+" records; existing IDs preserved.";
 }catch(err){$("recordStatus").textContent="Import rejected: "+err.message;}
 e.target.value="";
});
function addMessage(who,text,status="",hits=[]){
 const msg=make("article","msg "+(who==="YOU"?"user":"assistant"));
 msg.append(make("div","speaker",who+" / "+new Date().toLocaleTimeString([], {hour:"2-digit",minute:"2-digit"})));
 if(status){const t=make("span","tag"+(status.includes("UNKNOWN")||status.includes("INSUFFICIENT")?" unknown":""),status);msg.append(t);}
 msg.append(make("div","message-text",text));
 if(who==="SEE"){
  const v=evidenceVector(hits||[]);
  msg.append(make("div","truth-vector","EVIDENCE VECTOR · RECORDS "+v.cited_records+" · SOURCE URLS "+v.source_urls+" · TENSION CANDIDATES "+v.possible_tensions+" · UNKNOWN "+(v.unknown?"YES":"NOT RESOLVED")));
 }
 if(hits?.length){
 const c=make("div","receipts");
 hits.forEach((h,i)=>{
  const line=make("div","receipt");
  line.append(document.createTextNode("["+(i+1)+"] "+h.record.kind.toUpperCase()+" · "+h.record.source));
  if(escapeURL(h.record.url)){line.append(document.createTextNode(" · "));const a=make("a","","SOURCE ↗");a.href=h.record.url;a.target="_blank";a.rel="noopener noreferrer";line.append(a)}
  c.append(line);
 });msg.append(c);
 }
 $("messages").append(msg);$("messages").scrollTop=$("messages").scrollHeight;
}
const broad=/^(what.*(know|see|remember|mirror)|who am i|summari[sz]e me|reflect me|tell me about myself)/i;
function retrieve(question){
 const q=rank(question,records,5);
 if(q.length||!broad.test(question))return q;
 return records.slice(-5).reverse().map(record=>({record,matching:0,coverage:0}));
}
async function reply(question){
 const hits=retrieve(question);
 if(!hits.length)return {status:"INSUFFICIENT EVIDENCE",text:reflect(question,records).text,hits:[]};
 const conflicts=tensions(hits.map(h=>h.record));
 const evidence=hits.map((h,i)=>"["+(i+1)+"] "+h.record.statement).join("\n\n");
 if(!engine)return {status:conflicts.length?"SOURCE-BOUND · POSSIBLE TENSION":"SOURCE-BOUND",text:"Here is what your existing records say:\n\n"+evidence+"\n\nThese records are not independently established as true. "+(conflicts.length?"Some statements may be in tension; inspect their sources before drawing conclusions.":"The mirror does not infer beyond their content."),hits};
 const promptText="USER QUESTION: "+question+"\n\nEVIDENCE:\n"+sourceContext(hits)+"\n\nUse only the evidence above for personal factual claims. If the evidence does not establish something, say unknown. Separate cited statements from interpretation. Be concise, useful, curious, and never invent sources. Label all inferences. Refer to source identifiers [1], [2], etc. Preserve contradictions.";
 try{
 const out=await engine.chat.completions.create({messages:[{role:"system",content:"You are SEE, a local, source-grounded reflective assistant. Personal facts require cited evidence. Unknown stays unknown. Do not assign numerical truth probabilities. Distinguish user-provided claims from independent verification. You may suggest possibilities clearly marked as possibilities."},{role:"user",content:promptText}],temperature:0.2,max_tokens:550});
 const answer=String(out?.choices?.[0]?.message?.content||"").trim();
 if(!answer)throw Error("Model returned no text.");
 return {status:conflicts.length?"LOCAL MODEL DRAFT · TENSION":"LOCAL MODEL DRAFT · NOT VERIFIED",text:answer,hits};
 }catch(e){notify("LOCAL MODEL ERROR — USING EVIDENCE ENGINE");return {status:"SOURCE-BOUND · MODEL UNAVAILABLE",text:"Model generation failed: "+e.message+"\n\n"+evidence,hits};}
}
$("askForm").addEventListener("submit",async e=>{
 e.preventDefault();if(busy)return;
 const question=$("question").value.trim();if(!question)return;
 $("question").value="";addMessage("YOU",question);
 busy=true;$("askButton").disabled=true;notify(engine?"LOCAL MODEL THINKING":"RETRIEVING EVIDENCE");
 try{const answer=await reply(question);addMessage("SEE",answer.text,answer.status,answer.hits)}
 catch(err){addMessage("SEE","An error interrupted this reflection: "+err.message,"ERROR")}
 finally{busy=false;$("askButton").disabled=false;notify("LOCAL-FIRST · NO AUTOMATIC UPLOAD");}
});
$("question").addEventListener("keydown",e=>{
 if(e.key==="Enter"&&!e.shiftKey){e.preventDefault();$("askForm").requestSubmit();}
});
async function loadMobileModel(){
 $("aiProgress").textContent="Initializing small free on-device CPU model (Transformers.js / WASM)…";
 const lib=await import("https://cdn.jsdelivr.net/npm/@huggingface/transformers@4.3.2");
 let pipe;
 try{
  pipe=await lib.pipeline("text-generation","onnx-community/SmolLM2-135M-Instruct-ONNX-GQA",{
   device:"wasm",dtype:"q4",progress_callback:p=>{$("aiProgress").textContent=p?.status==="progress"?"Downloading CPU model: "+Math.round(p.progress||0)+"%":"Preparing CPU model…";}
  });
 }catch(first){
  $("aiProgress").textContent="Trying alternative CPU quantization…";
  pipe=await lib.pipeline("text-generation","onnx-community/SmolLM2-135M-Instruct-ONNX-GQA",{device:"wasm",dtype:"q8"});
 }
 return {chat:{completions:{create:async({messages,max_tokens})=>{
  const out=await pipe(messages,{max_new_tokens:Math.min(220,max_tokens||220),do_sample:false});
  const raw=out?.[0]?.generated_text;
  const content=Array.isArray(raw)?String(raw.at(-1)?.content||""):String(raw||"");
  return {choices:[{message:{content}}]};
 }}}};
}
$("enableAI").addEventListener("click",async()=>{
 if(engine){notify("LOCAL MODEL ALREADY ACTIVE");return}
 $("enableAI").disabled=true;
 let gpuError="";
 if("gpu" in navigator){
  try{
   $("aiProgress").textContent="Downloading WebGPU model on your device (first use can be large)…";
   const lib=await import("https://esm.run/@mlc-ai/web-llm");
   engine=await lib.CreateMLCEngine(MODEL,{initProgressCallback:p=>{$("aiProgress").textContent=p?.text||"Loading WebGPU model…"}});
   $("modelState").textContent="ON-DEVICE AI · GPU";
  }catch(e){gpuError=e.message;engine=null;}
 }
 if(!engine){
  try{
   engine=await loadMobileModel();
   $("modelState").textContent="ON-DEVICE AI · CPU";
  }catch(e){
   engine=null;$("enableAI").disabled=false;
   $("aiProgress").textContent="On-device model unavailable"+(gpuError?" (GPU: "+gpuError+")":"")+": "+e.message+". The free evidence mirror remains usable.";
   return;
  }
 }
 $("aiProgress").textContent="Local model initialized. Sources remain visible; all generated text is marked MODEL DRAFT.";
 $("enableAI").textContent="Local AI ready ✓";
});
const VIEWER_SOURCES=new Set([...$("viewerSource").options].map(o=>o.value));
$("viewerSource").addEventListener("change",()=>{$("viewerOpen").href=$("viewerSource").value;});
$("viewerLoad").addEventListener("click",()=>{
 const src=$("viewerSource").value;
 if(!VIEWER_SOURCES.has(src))return;
 $("viewerPlaceholder").hidden=true;
 const frame=$("viewerFrame");frame.hidden=false;frame.src=src;
 $("viewerOpen").href=src;
 notify("VIEWING EXTERNAL INSTRUMENT · NO MIRROR DATA SHARED");
});
function buildCityPacket(){
 const now=new Date().toISOString();
 return {schema:"CITY-QUERY/1.0",query_code:"SEE-"+Date.now().toString(36).toUpperCase(),title:"SEE evidence reflection / user-authorized",prompt:"Analyze user-provided statements preserving provenance, uncertainty, contradictions and unresolved observations. A spectral rank does not determine truth.",task_type:"evidence_reflection",observations:[],requested_sources:[...new Set(records.map(r=>r.url).filter(Boolean))],blind_sources:[],metadata:{from:"SEE/1.0",no_evidence_promotion:true,note:"NOT a density-reconstruct input: no 0–4 carrier coordinates supplied.",evidence:records.map(r=>({statement:r.statement,source:r.source,kind:r.kind,url:r.url}))},created_at:now};
}
$("cityPacket").addEventListener("click",()=>{
 const query=buildCityPacket();
 download(query.query_code+".json",JSON.stringify(query,null,2));
 $("cityStatus").textContent="CITY-QUERY/1.0 packet downloaded locally. Not published.";
 notify("CITY QUERY PACKET EXPORTED LOCALLY — NOT PUBLISHED");
});
$("cityPublish").addEventListener("click",async()=>{
 if(!records.length){$("cityStatus").textContent="No evidence records to publish.";return;}
 if(window.top!==window.self){$("cityStatus").textContent="Publishing is disabled inside an embedded frame. Open SEE directly.";return;}
 const allow=confirm("Publish all current SEE evidence records to the existing City Query bus? This will broadcast to other open Mathematical City tabs on this origin and persist the last packet in this browser's localStorage. This is not a private sync service. Continue?");
 if(!allow)return;
 try{
  if(location.origin!=="https://nicholaskouns-create.github.io")throw Error("City Query bus requires the published Mathematical City origin.");
  const original=await import("/E47-Kartekeya/interfaces/shared/city-query.js");
  const raw=buildCityPacket();
  const packet=original.makeCityQuery(raw);
  const bus=original.installCityQuery({surface:"SEE-EVIDENCE-MIRROR"});
  bus.publish(packet);
  $("cityStatus").textContent="Published locally through the existing CITY-PULSE/1.0 transport: "+packet.query_code+". No agent completion is implied.";
 }catch(e){$("cityStatus").textContent="Publish unavailable: "+e.message+". The local packet export remains available.";}
});
if("serviceWorker"in navigator&&location.protocol==="https:")navigator.serviceWorker.register("./sw.js").catch(()=>{});
const v=location.hash.replace("#","");setView(["mirror","evidence","sources","method"].includes(v)?v:"mirror");
load();
