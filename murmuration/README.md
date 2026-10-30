# Murmuration public synchronization feed

This is an **additive, read-only public metadata feed** in Identity. It does not
modify the Grok-hosted Murmuration app, the Mathematical City instruments, or
the source repositories.

Once this branch is merged and the GitHub Actions workflow is enabled, an
hourly scheduled job (minute 17) fetches the latest public GitHub commit
metadata for `nicholaskouns-create/Identity` and `E47-Kartekeya` and writes
`murmuration/feed.json`. It commits only if changed.

Consumer URL after merge and first successful run:
https://raw.githubusercontent.com/nicholaskouns-create/Identity/main/murmuration/feed.json

GitHub Pages URL if the existing Pages deployment serves the repository root:
https://nicholaskouns-create.github.io/Identity/murmuration/feed.json

The Grok-hosted Murmuration app **must explicitly fetch** one of these URLs
to display live data. We have not edited that external app or established
its support for remote feeds. A public JSON URL alone does not connect it.

Feed schema: `mc.murmuration.feed/1`. `sha256` is a deterministic digest of
the object without the digest field, using sorted-key compact UTF-8 JSON.
It is an integrity checksum, **not an authenticity signature**.

Unreachable sources are marked `unavailable`; they are never silently
replaced with cached facts. The job fails if all sources are unreachable.
The feed intentionally contains no private Notion, Drive, Supabase, telemetry,
secrets, or user-specific account data.

To expand sources, add independent public adapters and tests. Preserve
provenance, evidence classes, and source autonomy. No data is promoted to a
proof certificate or live instrument-health assertion by this feed.
