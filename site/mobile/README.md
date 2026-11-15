# E47 Proof Observatory — mobile-first app

An additive, phone-first progressive web app using the existing Mathematical City design language and **unchanged** Identity proof runner.

## What runs where
- **On phone:** exact finite-spectrum arithmetic checks; an interactive isotropic-state contraction instrument under Γ = I − K²/99144; offline application shell once loaded over HTTPS.
- **On GitHub:** the existing [One Button workflow](https://github.com/nicholaskouns-create/Identity/actions/workflows/e47-one-button.yml), which runs Lean, Coq and Python, produces per-check results and downloadable SHA-256 receipt artifacts. GitHub sign-in and selection of Run workflow are required. The mobile app reads public workflow status without credentials.
- **Notion / Google Drive / Linear / Supabase:** source-native navigation links, no automatic synchronization or mutations.

## Use on iPhone
After this PR is merged and the repository's Pages deployment updates, open `https://nicholaskouns-create.github.io/Identity/site/mobile/` in Safari; use Share → Add to Home Screen. Before the Pages deployment, this URL should **not** be assumed live.

## Tests
Run `node --test tests/mobile-math.test.mjs` from the repository root. The app has no build dependencies. To serve locally, run `python -m http.server 8000` from the repository root and open `http://localhost:8000/site/mobile/`.

## Proof and numerical semantics
Carrier dimension 125; multiplicities `[1,9,25,28,27,22,13]` for Casimir spectrum `[0,2,6,12,20,30,42]`; kernel rank 47, complement 78. The filter uses `K=(C−6I)(C−30I)`; `Γ=I−K²/99144`; complement spectral contraction factor exactly 15/17. Chart initialization is explicitly isotropic and **not** a recorded experiment. Local arithmetic checks are not representations of Lean/Coq compilation.

## Privacy and autonomy
The app stores no GitHub tokens, makes no private database requests, and does not change the existing proofs, workflows, City records, or sources. No service-role keys or Supabase credentials should be placed in client JavaScript.

## Verification state
Eight unit tests passed in a local Node 22 runtime. JavaScript syntax and ZIP integrity were checked. Native iOS/Safari runtime and GitHub Pages deployment have **not yet** been tested. The repository branch itself is not a deployment.
