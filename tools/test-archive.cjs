// Exercise the actual archive handlers against an IndexedDB implementation.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const {webcrypto} = require('node:crypto');
const {indexedDB, IDBObjectStore} = require('fake-indexeddb');
const elements = new Map();
const element = () => ({value:'',textContent:'',children:[],handlers:{},
  addEventListener(name,fn){this.handlers[name]=fn},
  replaceChildren(){this.children=[]}, append(...items){this.children.push(...items)}});
const document = {getElementById(id){if(!elements.has(id))elements.set(id,element());return elements.get(id)},createElement:element};
const context = vm.createContext({document,indexedDB,crypto:webcrypto,TextEncoder,console,Blob,URL,setTimeout});
vm.runInContext(fs.readFileSync(path.join(__dirname,'../site/mnemosyne.js'),'utf8'),context);
const evaluate = code => vm.runInContext(code,context);
async function makeRecord(id,content){
  const r={id,title:id,kind:'historical',content,created_at:'2026-10-23T00:00:00Z'};
  r.sha256=Buffer.from(await webcrypto.subtle.digest('SHA-256',new TextEncoder().encode(JSON.stringify([r.id,r.title,r.kind,r.content,r.created_at])))).toString('hex');
  return r;
}
async function importRecords(records){
  const input=document.getElementById('import');
  const text=JSON.stringify({format:'mnemosyne-archive-v1',records});
  await input.handlers.change({target:{files:[{size:Buffer.byteLength(text),text:async()=>text}],value:'archive.json'}});
  return document.getElementById('status').textContent;
}
(async()=>{
  await evaluate('all()');
  const original=await makeRecord('existing','original');
  assert.match(await importRecords([original]),/^Imported 1/);
  const duplicateFirst=await makeRecord('duplicate','first');
  const duplicateLast=await makeRecord('duplicate','last');
  assert.match(await importRecords([duplicateFirst,duplicateLast]),/^Import rejected: Duplicate record ID in import/);
  const unchanged=await evaluate('all()');
  assert.equal(unchanged.length,1);
  assert.equal(unchanged[0].content,'original');
  console.log('PASS duplicate import IDs rejected before any IndexedDB writes');
  const replacement=await makeRecord('existing','replacement');
  const added=await makeRecord('added','new');
  assert.match(await importRecords([replacement,{...added,sha256:'invalid'}]),/^Import rejected:/);
  let rows=await evaluate('all()');
  assert.equal(rows.length,1);assert.equal(rows[0].content,'original');
  console.log('PASS invalid later record leaves existing archive unchanged');
  const originalPut=IDBObjectStore.prototype.put;
  let writes=0;
  IDBObjectStore.prototype.put=function(...args){const req=originalPut.apply(this,args);if(++writes===2)this.transaction.abort();return req};
  try{assert.match(await importRecords([replacement,added]),/^Import rejected:/)}finally{IDBObjectStore.prototype.put=originalPut}
  rows=await evaluate('all()');assert.equal(rows.length,1);assert.equal(rows[0].content,'original');
  console.log('PASS aborted transaction rolls back every write');
  assert.match(await importRecords([replacement,added]),/^Imported 2/);
  rows=await evaluate('all()');assert.equal(rows.length,2);assert.equal(rows.find(r=>r.id==='existing').content,'replacement');
  assert.equal(await evaluate('all().then(rows=>Promise.all(rows.map(verify))).then(xs=>xs.every(Boolean))'),true);
  for(const r of rows)assert.equal(r.sha256,(r.id==='existing'?replacement:added).sha256);
  console.log('PASS successful import merges records and retains receipts');
  await evaluate("putMany([])");
  assert.equal((await evaluate('all()')).length,2);
  console.log('PASS empty transaction completes without altering archive');
})().catch(error=>{console.error(error);process.exitCode=1});
