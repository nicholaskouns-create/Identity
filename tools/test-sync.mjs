import assert from 'node:assert/strict';
import { planSync, toLocalRow, toRemoteRow } from '../site/sync-merge.js';

const base = {
  id: 'a',
  title: 'A',
  kind: 'historical',
  content: 'one',
  created_at: '2026-10-23T00:00:00.000Z',
  sha256: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  updated_at: '2026-10-23T00:00:01.000Z'
};
const remoteNewer = [{ ...base, content: 'two', sha256: 'b'.repeat(64), updated_at: '2026-10-23T00:00:02.000Z' }];
let plan = planSync([base], remoteNewer);
assert.equal(plan.pull.length, 1);
assert.equal(plan.push.length, 0);

const dirty = [{ ...base, content: 'local', sha256: 'c'.repeat(64), updated_at: undefined }];
plan = planSync(dirty, remoteNewer);
assert.equal(plan.pull.length, 0);
assert.equal(plan.push.length, 1);

plan = planSync([base], [{ ...base }]);
assert.equal(plan.pull.length, 0);
assert.equal(plan.push.length, 0);

const onlyRemote = planSync([], [base]);
assert.equal(onlyRemote.pull.length, 1);
assert.equal(toLocalRow(onlyRemote.pull[0]).created_at, base.created_at);

const row = toRemoteRow(dirty[0], '11111111-1111-1111-1111-111111111111', '2026-10-23T00:00:03.000Z');
assert.equal(row.owner_id, '11111111-1111-1111-1111-111111111111');
assert.equal(row.created_at, base.created_at);
assert.equal(row.sha256, 'c'.repeat(64));
assert.throws(() => toRemoteRow({ ...dirty[0], kind: 'nope' }, 'user', '2026-10-23T00:00:03.000Z'));
console.log('PASS sync merge plan');
