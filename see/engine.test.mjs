import test from "node:test";
import assert from "node:assert/strict";
import {tokens,newRecord,rank,reflect,tensions,evidenceVector,importArchive,exportArchive} from "./engine.mjs";
const a={id:"a",statement:"I built a map of the national power grid.",source:"My note",kind:"user-supplied",url:""};
const b={id:"b",statement:"The P47 reconstruction gate failed the stronger random-control test.",source:"DENSITY",kind:"repository",url:""};
test("retrieval retrieves only supported notes",()=>{assert.equal(rank("What did I build about the power grid?",[a,b])[0].record.id,"a");assert.equal(rank("what is my birthday",[a,b]).length,0)});
test("no invented autobiography",()=>assert.equal(reflect("Who are my parents?",[a]).status,"INSUFFICIENT EVIDENCE"));
test("no automatic truth scores",()=>assert.equal("probability" in rank("P47",[b])[0],false));
test("import and export preserve statements",()=>assert.equal(importArchive(exportArchive([a]))[0].statement,a.statement));
test("rejects invalid URLs",()=>assert.throws(()=>newRecord("x","s","external","javascript:alert(1)")));
test("tensions are flagged, not resolved",()=>assert.equal(tensions([{...a,statement:"The gate has passed controls."},{...b,statement:"The gate has not passed controls."}]).length,1));
test("Unicode tokens",()=>assert.ok(tokens("Spectral E₄₇ symmetry").length>0));

test("built/made retrieval aliases",()=>assert.equal(rank("What have I made?",[a,b])[0].record.id,"a"));

test("evidence weight is a vector not a truth score",()=>assert.deepEqual(evidenceVector([{record:a}]),{cited_records:1,source_urls:0,inference_records:0,possible_tensions:0,unknown:false}));
