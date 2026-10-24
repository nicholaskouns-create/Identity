import {cases, canonical, sha256} from './forge-engine.js';

const REQUIRED = ['schema', 'id', 'title', 'claim', 'kind', 'result', 'engine', 'runAt', 'scope', 'sha256'];
const fail = reason => ({ok:false, reason});

/** Replay a local Forge reference receipt. This does not authenticate authorship or certify a theorem. */
export async function verifyForgeReceipt(receipt) {
  if (!receipt || typeof receipt !== 'object' || Array.isArray(receipt)) return fail('Expected a Forge receipt object.');
  if (Object.keys(receipt).sort().join('|') !== [...REQUIRED].sort().join('|')) return fail('Unexpected or missing receipt fields.');
  if (typeof receipt.sha256 !== 'string' || !/^[0-9a-f]{64}$/.test(receipt.sha256)) return fail('Invalid SHA-256 format.');
  const {sha256: stored, ...payload} = receipt;
  if (await sha256(payload) !== stored) return fail('Receipt SHA-256 mismatch.');
  const spec = cases.find(c => c.id === receipt.id);
  if (!spec) return fail('Unknown reference case.');
  if (receipt.schema !== 'mnemosyne-forge-v1' ||
      receipt.engine !== 'mnemosyne/forge-engine.js' ||
      receipt.scope !== 'deterministic reference checks; not general proof certification' ||
      receipt.title !== spec.title || receipt.claim !== spec.claim || receipt.kind !== spec.kind) {
    return fail('Receipt metadata does not match the reference case.');
  }
  if (typeof receipt.runAt !== 'string' || !/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z$/.test(receipt.runAt) ||
      !Number.isFinite(Date.parse(receipt.runAt))) return fail('Invalid receipt timestamp.');
  const expected = spec.run();
  if (canonical(receipt.result) !== canonical(expected)) return fail('Recorded result differs from deterministic replay.');
  return {ok:true, id:spec.id, digestMatches:true, replayMatches:true,
    boundary:'Local SHA-256 integrity and deterministic reference replay only; not an authenticated signature, Lean/Coq certificate, or hardware result.'};
}
