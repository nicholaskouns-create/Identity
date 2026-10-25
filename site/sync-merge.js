// Conflict plan for optional sync. The SHA-256 receipt ignores updated_at.
export const KINDS = new Set(['proven', 'numerically_tested', 'hypothesis', 'refuted', 'unverified', 'historical']);

export function stamp(value) {
  if (!value) return null;
  const time = Date.parse(value);
  return Number.isFinite(time) ? time : null;
}

export function acceptable(row) {
  return !!row
    && typeof row.id === 'string'
    && row.id.length >= 1 && row.id.length <= 80
    && !/[\s\u0000-\u001f]/.test(row.id)
    && typeof row.title === 'string'
    && row.title.length >= 1 && row.title.length <= 300
    && KINDS.has(row.kind)
    && typeof row.content === 'string'
    && row.content.length <= 20000
    && typeof row.created_at === 'string'
    && row.created_at.length >= 10 && row.created_at.length <= 80
    && typeof row.sha256 === 'string'
    && /^[a-f0-9]{64}$/.test(row.sha256);
}

export function planSync(local, remote) {
  const remoteById = new Map(remote.map(row => [row.id, row]));
  const localById = new Map(local.map(row => [row.id, row]));
  const pull = [];
  for (const row of remote) {
    if (!acceptable(row)) continue;
    const prev = localById.get(row.id);
    if (!prev) {
      pull.push(row);
      continue;
    }
    if (prev.sha256 === row.sha256) continue;
    const localStamp = stamp(prev.updated_at);
    const remoteStamp = stamp(row.updated_at);
    if (localStamp !== null && remoteStamp !== null && remoteStamp > localStamp) pull.push(row);
  }
  const pulled = new Set(pull.map(row => row.id));
  const push = [];
  for (const row of local) {
    if (!acceptable(row) || pulled.has(row.id)) continue;
    const prev = remoteById.get(row.id);
    if (!prev || !acceptable(prev)) {
      push.push(row);
      continue;
    }
    if (prev.sha256 === row.sha256) continue;
    const localStamp = stamp(row.updated_at);
    const remoteStamp = stamp(prev.updated_at);
    if (localStamp === null || remoteStamp === null || localStamp >= remoteStamp) push.push(row);
  }
  return { pull, push };
}

export function toLocalRow(row) {
  const local = {
    id: row.id,
    title: row.title,
    kind: row.kind,
    content: row.content,
    created_at: row.created_at,
    sha256: row.sha256
  };
  if (row.updated_at) local.updated_at = row.updated_at;
  return local;
}

export function toRemoteRow(row, ownerId, updatedAt) {
  if (!acceptable(row)) throw new Error('Record cannot be synced');
  if (typeof ownerId !== 'string' || !ownerId) throw new Error('Missing account');
  return {
    id: row.id,
    owner_id: ownerId,
    title: row.title,
    kind: row.kind,
    content: row.content,
    created_at: row.created_at,
    sha256: row.sha256,
    updated_at: updatedAt
  };
}


// Human-readable completion status. Invalid receipts are excluded, never silently counted as synced.
export function formatSyncStatus({ pulled, pushed, count, skipped = 0, skippedLocal = 0 }) {
  const exclusions = skipped + skippedLocal;
  let message = (exclusions ? 'Sync completed with exclusions.' : 'Synced.')
    + ' Pulled ' + pulled + ', pushed ' + pushed + '. ' + count + ' local record(s).';
  if (skipped) message += ' ' + skipped + ' remote row(s) failed the receipt check and were left untouched.';
  if (skippedLocal) message += ' ' + skippedLocal + ' local row(s) failed the receipt check and were not synced; they remain in this browser.';
  return message;
}
