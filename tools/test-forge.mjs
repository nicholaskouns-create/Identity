import assert from 'node:assert/strict';
import {verifyForgeReceipt} from '../site/forge-receipt.js';import {cases,execute,findCounterexample,matrixView,sha256,canonical} from '../site/forge-engine.js';
assert.equal(cases.length,5);
for(const c of cases){const result=await execute(c.id);assert.equal(result.result.pass,true,c.id);const {sha256:receipt,...payload}=result;assert.equal(await sha256(payload),receipt)}
assert.deepEqual(findCounterexample([1,0,-1]).x,-12);
assert.equal(findCounterexample([0,0,0]).found,false);
assert.throws(()=>findCounterexample([1.5,0,0]));
assert.equal(matrixView().dimension,125);
assert.equal(matrixView().traceSquared,750);
assert.equal(canonical({b:1,a:2}), '{"a":2,"b":1}');
const original=await execute('e47-rank');
assert.equal((await verifyForgeReceipt(original)).ok,true);
const tampered={...original,result:{pass:false}};
assert.equal((await verifyForgeReceipt(tampered)).ok,false);
const recomputed={...tampered};
const {sha256:oldHash,...payload}=recomputed;
recomputed.sha256=await sha256(payload);
assert.match((await verifyForgeReceipt(recomputed)).reason,/differs from deterministic replay/);
const mislabeled={...original,title:'Different theorem'};
const {sha256:oldLabelHash,...labelPayload}=mislabeled;
mislabeled.sha256=await sha256(labelPayload);
assert.match((await verifyForgeReceipt(mislabeled)).reason,/metadata/);
assert.equal((await verifyForgeReceipt(null)).ok,false);
console.log('MNEMOSYNE_FORGE_RECEIPT_REPLAY_PASS',cases.length,'replayable reference cases');
console.log('MNEMOSYNE_FORGE_PASS',cases.length,'reference experiments; counterexample and matrix checks');


// Exercise the actual Forge UI with a minimal DOM: no browser/network dependency.
class ForgeElement {
  constructor(tag='div') { this.tagName=tag;this.children=[];this.attributes={};this.style={};this.hidden=false;this.textContent='';this.value=''; }
  append(...nodes) { this.children.push(...nodes); }
  setAttribute(name,value) { this.attributes[name]=value; }
  addEventListener(name,fn) { this['on'+name]=fn; }
  scrollIntoView() {}
}
const forgeRoot=new ForgeElement();
globalThis.document={
  querySelector:selector=>selector==='#mnemosyne-forge .forge-grid'?forgeRoot:null,
  createElement:tag=>new ForgeElement(tag),
  getElementById:()=>new ForgeElement()
};
await import('../site/forge-ui.js');
const descend=node=>[node,...node.children.flatMap(descend)];
const elements=descend(forgeRoot);
const byText=(tag,label)=>elements.find(x=>x.tagName===tag&&x.textContent===label);
const countText=(tag,label)=>elements.filter(x=>x.tagName===tag&&x.textContent===label).length;
const chooser=elements.find(x=>x.tagName==='select');
assert.equal(chooser.attributes['aria-label'],'Forge reference case');
const run=byText('button','Run independent reference check');
const receiptButton=byText('button','Export verification receipt');
assert.equal(receiptButton.hidden,true);
chooser.value='e47-rank';
await run.onclick();
assert.equal(receiptButton.hidden,false);
assert.equal(JSON.parse(elements.find(x=>x.tagName==='pre'&&x.textContent.includes('"schema": "mnemosyne-forge-v1"')).textContent).id,'e47-rank');
chooser.value='clock-period';
await run.onclick();
assert.equal(countText('button','Export verification receipt'),1);
assert.equal(elements.filter(x=>x.tagName==='pre').find(x=>x.textContent.includes('"schema": "mnemosyne-forge-v1"')).textContent.includes('"id": "clock-period"'),true);
const search=byText('button','Search for smallest bounded counterexample');
const counterexampleButton=byText('button','Export counterexample');
assert.equal(counterexampleButton.hidden,true);
await search.onclick();
await search.onclick();
assert.equal(counterexampleButton.hidden,false);
assert.equal(countText('button','Export counterexample'),1);
assert.equal(elements.filter(x=>x.attributes.role==='status').length,3);
const input=elements.find(x=>x.tagName==='input'&&x.type==='number');
input.value='1.5';
await search.onclick();
assert.equal(counterexampleButton.hidden,true);
assert.equal(elements.some(x=>x.attributes.role==='status'&&x.textContent.includes('failed')),true);
console.log('MNEMOSYNE_FORGE_UI_ACCESSIBILITY_PASS accessible statuses, current-only exports, invalid input reset');
