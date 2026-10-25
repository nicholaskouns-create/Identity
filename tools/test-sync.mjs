import assert from 'node:assert/strict';
import { planSync, toLocalRow, toRemoteRow, formatSyncStatus } from '../site/sync-merge.js';

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

const cleanStatus = formatSyncStatus({ pulled: 1, pushed: 2, count: 3 });
assert.equal(cleanStatus, 'Synced. Pulled 1, pushed 2. 3 local record(s).');
const excludedStatus = formatSyncStatus({ pulled: 0, pushed: 0, count: 2, skipped: 1, skippedLocal: 1 });
assert.match(excludedStatus, /^Sync completed with exclusions\./);
assert.match(excludedStatus, /1 remote row\(s\) failed the receipt check and were left untouched/);
assert.match(excludedStatus, /1 local row\(s\) failed the receipt check and were not synced; they remain in this browser/);
assert.ok(!excludedStatus.startsWith('Synced.'));
const localOnlyStatus = formatSyncStatus({ pulled: 0, pushed: 0, count: 1, skippedLocal: 2 });
assert.match(localOnlyStatus, /2 local row\(s\) failed the receipt check/);
assert.doesNotMatch(localOnlyStatus, /remote row/);

console.log('PASS sync merge plan');
