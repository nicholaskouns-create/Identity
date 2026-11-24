# SEE — An AI to Mirror You
A source-grounded, free-to-use, static-first browser app in the Mathematical City.

Live entry: https://nicholaskouns-create.github.io/Identity/see/
Code: /see/ on the \`Identity\` repository.

## Capabilities
- Evidence mirror: ask questions about notes you choose to store; no invented personal history.
- Edit/delete individual records, JSON import/export, local storage and SHA-256 byte receipt on export.
- Explicit source categories: user-supplied, repository, computed, external, inferred. These are not proof levels.
- Retrieval based on transparent term overlap, with no bogus "truth probability".
- Possible contradiction candidates shown without silently resolving them.
- Optional local LLM via free WebLLM (WebGPU) after user-initiated model download. Generations are labeled **MODEL DRAFT · NOT VERIFIED**. The fallback evidence engine needs no model.
- Reuse and outbound links to DENSITY, BUILD, SCALAR, Grid, Mnemosyne and two other supplied Grok URLs.
- Download a \`CITY-QUERY/1.0\` task packet. Export only; **never publish user data automatically**.

## Evidence lineage
DENSITY source: https://github.com/nicholaskouns-create/E47-Kartekeya/blob/main/docs/density-sensitivity-tomography.md

The 2026-09-30 DENSITY rank-47 control reports **P47 beat 0/47 random same-rank projector controls**, seed-specific. SEE does not treat P47 contraction as a truth classifier or claim the failed seed gate passed.

The BUILD and SCALAR links are externally hosted pages, not copied source code. The ORBIT and APEX URLs were not inspectable during initial construction, so they are retained only as links.

## Privacy and cost
No subscription, API key, database, or authentication are needed. Notes are in browser localStorage, not in your GitHub repository. Exported JSON may contain private personal details; keep it private.
Only after you click **Enable local AI** does the app download third-party WebLLM JavaScript/model assets. Inference runs locally when available, but model startup may fail on some browsers or memory-limited devices. The evidence mirror works without it.
The app's static service worker caches the UI shell. It does not cache personal records in a server.

SHA-256 checks byte integrity, **not independent veracity, authorship or timestamps**. A model can still generate incorrect language; See marks all generative output as draft.

## Tests
\`\`\`sh
node --test see/engine.test.mjs
node --check see/engine.mjs
node --check see/app.mjs
node --check see/sw.js
\`\`\`

For end-to-end browser review, serve the repository root using \`python3 -m http.server 8000\` and open \`http://localhost:8000/see/\`. Browser-model operation requires network access and supported hardware; the fallback source engine works offline once cached.

## Coexistence
No existing app is replaced, no common adjudicating authority is created and the City surfaces remain independently addressable. The packet is compatible with CITY-QUERY/1.0 but does not silently push data across origins.
