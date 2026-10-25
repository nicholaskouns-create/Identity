import {cases,execute,findCounterexample,matrixView,sha256} from './forge-engine.js';
import {verifyForgeReceipt} from './forge-receipt.js';
const root=document.querySelector('#mnemosyne-forge .forge-grid');
if(root){
const el=(tag,text,cls)=>{const x=document.createElement(tag);if(text!==undefined)x.textContent=text;if(cls)x.className=cls;return x};
const section=(name,description)=>{const s=el('div',undefined,'forge-panel');s.append(el('h3',name),el('p',description));root.append(s);return s};
const download=(data,name)=>{const url=URL.createObjectURL(new Blob([JSON.stringify(data,null,2)],{type:'application/json'}));const a=el('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),3000)};
const lab=section('01 · The Forge','Run five deterministic mathematical checks. Every result includes a downloadable SHA-256 receipt. These are reference checks, not general theorem provers.');
const chooser=el('select');chooser.setAttribute('aria-label','Forge reference case');for(const c of cases){const o=el('option',c.title);o.value=c.id;chooser.append(o)}lab.append(chooser);
const run=el('button','Run independent reference check');const out=el('pre','Ready.','forge-output');
const runStatus=el('p','Ready to run a reference check.','muted');runStatus.setAttribute('role','status');
const exportReceipt=el('button','Export verification receipt');exportReceipt.hidden=true;
let latestReceipt=null;exportReceipt.onclick=()=>{if(latestReceipt)download(latestReceipt,latestReceipt.id+'-receipt.json')};
lab.append(run,runStatus,out,exportReceipt);
run.onclick=async()=>{exportReceipt.hidden=true;latestReceipt=null;runStatus.textContent='Running reference check…';
  try{const receipt=await execute(chooser.value);latestReceipt=receipt;out.textContent=JSON.stringify(receipt,null,2);
    runStatus.textContent=receipt.result.pass?'Reference check passed; receipt ready to export.':'Reference check did not pass; inspect result.';
    exportReceipt.hidden=false;
  }catch(e){out.textContent='Error: '+e.message;runStatus.textContent='Reference check failed: '+e.message}};
const matrix=section('02 · Quantum Matrix Studio','Explore the exact diagonal Jtot_z spectrum on the spin-2 triple tensor carrier. This view is not the full Casimir matrix.');
const v=matrixView();const summary=el('p','Dimension '+v.dimension+' · Tr(Jtot_z)='+v.trace+' · Tr(Jtot_z²)='+v.traceSquared);matrix.append(summary);
const chart=el('div',undefined,'matrix-bars');const max=Math.max(...Object.values(v.histogram));for(const [k,n] of Object.entries(v.histogram)){const col=el('div',undefined,'matrix-bar-col');const bar=el('div',undefined,'matrix-bar');bar.style.height=(n/max*125)+'px';bar.title='m='+k+' · multiplicity '+n;col.append(el('small',String(n)),bar,el('small',k));chart.append(col)}matrix.append(chart);
const atlas=section('03 · Contradiction Atlas','Try to falsify the universal claim a·x²+b·x+c=0 over integers from −12 to 12. Bounded search never proves universal truth.');
const fields=[];for(const [label,value] of [['a',1],['b',0],['c',-1]]){const l=el('label',label);const inp=el('input');inp.type='number';inp.step='1';inp.value=String(value);l.append(inp);atlas.append(l);fields.push(inp)}
const find=el('button','Search for smallest bounded counterexample');const report=el('pre','Awaiting a claim.','forge-output');
const searchStatus=el('p','Ready for bounded search.','muted');searchStatus.setAttribute('role','status');
const exportCounterexample=el('button','Export counterexample');exportCounterexample.hidden=true;
let latestCounterexample=null;exportCounterexample.onclick=()=>{if(latestCounterexample)download(latestCounterexample,'contradiction-atlas.json')};
atlas.append(find,searchStatus,report,exportCounterexample);
find.onclick=async()=>{exportCounterexample.hidden=true;latestCounterexample=null;searchStatus.textContent='Searching bounded integer range…';
  try{const coeffs=fields.map(x=>Number(x.value));const result=findCounterexample(coeffs);
    const receipt={schema:'mnemosyne-contradiction-atlas-v1',result,runAt:new Date().toISOString()};receipt.sha256=await sha256(receipt);
    latestCounterexample=receipt;report.textContent=JSON.stringify(receipt,null,2);
    searchStatus.textContent=result.found?'Counterexample found within the stated range.':'No counterexample found in the stated range; not a proof.';
    exportCounterexample.hidden=false;
  }catch(e){report.textContent='Error: '+e.message;searchStatus.textContent='Bounded search failed: '+e.message}};
const surprise=section('04 · Memory Constellation','A living dependency map of the five checked propositions. Select a star to run its reproducible test.');
const sky=el('div',undefined,'forge-stars');cases.forEach((c,i)=>{const b=el('button','✧ '+c.title,'forge-star');b.onclick=()=>{chooser.value=c.id;run.click();document.getElementById('mnemosyne-forge').scrollIntoView({behavior:'smooth'})};sky.append(b)});surprise.append(sky);
const replay=section('05 · Verify Forge receipt','Choose an exported Forge JSON receipt to check its SHA-256 and independently recompute the deterministic reference case in this browser. This does not authenticate authorship or certify a theorem.');
const fileLabel=el('label','Forge receipt JSON ');
const receiptFile=el('input');
receiptFile.type='file';
receiptFile.accept='.json,application/json';
fileLabel.append(receiptFile);
const replayOut=el('pre','No receipt selected.','forge-output');
replayOut.setAttribute('role','status');
replayOut.setAttribute('aria-live','polite');
replay.append(fileLabel,replayOut);
receiptFile.addEventListener('change',async()=>{
  try{
    const file=receiptFile.files?.[0];
    if(!file)return;
    if(file.size>1_000_000)throw Error('Receipt exceeds 1 MB.');
    const receipt=JSON.parse(await file.text());
    const verdict=await verifyForgeReceipt(receipt);
    replayOut.textContent=JSON.stringify(verdict,null,2);
  }catch(err){replayOut.textContent='Receipt rejected: '+err.message}
  finally{receiptFile.value=''}
});
}
