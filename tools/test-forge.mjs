import assert from 'node:assert/strict';import {cases,execute,findCounterexample,matrixView,sha256,canonical} from '../site/forge-engine.js';
assert.equal(cases.length,5);
for(const c of cases){const result=await execute(c.id);assert.equal(result.result.pass,true,c.id);const {sha256:receipt,...payload}=result;assert.equal(await sha256(payload),receipt)}
assert.deepEqual(findCounterexample([1,0,-1]).x,-12);
assert.equal(findCounterexample([0,0,0]).found,false);
assert.throws(()=>findCounterexample([1.5,0,0]));
assert.equal(matrixView().dimension,125);
assert.equal(matrixView().traceSquared,750);
assert.equal(canonical({b:1,a:2}), '{"a":2,"b":1}');
console.log('MNEMOSYNE_FORGE_PASS',cases.length,'reference experiments; counterexample and matrix checks');
