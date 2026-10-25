# Mnemosyne: GitHub-native, local-first core

This is an operational browser archive designed for GitHub Pages. Records are stored in IndexedDB first. Optional email sign-in copies verified records to the signed-in account. Open `site/index.html` on a secure origin (GitHub Pages or localhost) to use IndexedDB and WebCrypto.

## What works
- Create categorized research records in browser IndexedDB.
- SHA-256 content receipts and verification on rendering/import.
- Search, JSON export, verified JSON import.
- Same-browser live updates across tabs.
- Optional email-code sign-in and owner-scoped cross-device sync.

## Verify an exported archive offline

After using **Export JSON archive** on the [Mnemosyne page](https://nicholaskouns-create.github.io/Identity/site/), you can check every stored SHA-256 receipt without signing in or uploading the archive. From a local checkout of this repository, run:

```sh
python3 tools/verify_archive.py /path/to/mnemosyne-archive.json
```

The [read-only verifier](../tools/verify_archive.py) uses the Python standard library, prints a record count on success or a controlled error on failure, and does not print record contents, write files, or make network requests. It rejects mismatched receipts and duplicate record IDs; its 20 MB and 10,000-record limits match the browser import limits. Keep exported JSON private: it contains your research records.

**Evidence boundary:** a matching SHA-256 receipt establishes consistency with the included digest, not authorship, an independent timestamp, mathematical proof, numerical correctness, or experimental validity. A party able to edit a record can also recalculate its receipt.

## Reproduce the public research pages locally

From a checkout of the repository, serve the **repository root** rather than only `site/`. The ablation explorer reads its archived synthetic dataset from `experiments/` when that directory is available:

```sh
git clone https://github.com/nicholaskouns-create/Identity.git
cd Identity
git rev-parse HEAD
python3 -m http.server 8000 --bind 127.0.0.1
```

Open `http://127.0.0.1:8000/site/` for Mnemosyne and `http://127.0.0.1:8000/site/ablation.html` for the QGNN ablation explorer. Stop the server with Ctrl+C. Use `localhost` or another secure origin rather than opening the HTML through `file://`; browser security rules affect IndexedDB and WebCrypto.

From a second terminal in the repository root, run the dependency-free ablation statistics tests with Node.js 22:

```sh
node --test site/ablation.test.mjs
```

To record the **exact source revision and dataset bytes** used in a reproduction, save the output of `git rev-parse HEAD` and this portable SHA-256 calculation:

```sh
python3 -c "import hashlib,pathlib; p=pathlib.Path('experiments/e47_ablation_results.json'); print(hashlib.sha256(p.read_bytes()).hexdigest())"
```

The dataset is synthetic. The SHA-256 digest identifies bytes, not authorship or scientific validity. The local statistics tests do not compile Lean/Coq certificates or measure quantum hardware. For those independent evidence tracks, consult the repository's formal sources, numerical validators, and workflow results separately.

## Explicit limitations
- Without sign-in, browser data is device-local.
- SHA-256 checks integrity against accidental modification; it does **not** establish authorship, external timestamp, or tamper-proof provenance (an attacker can recompute a digest).
- Sync is not end-to-end encryption. Signed-in rows are readable by that user and by this project's database owner.
- The published page does not include a service key, and unsigned visitors cannot read the account table.
- **Do not publish private research records on public Pages**. The archive UI is public; the records are not, unless you export them or sync them to the account.
- No claims of measured performance superiority are made.

## Deployment

The published URL is `https://nicholaskouns-create.github.io/Identity/site/`. The workflow `.github/workflows/mnemosyne-site.yml` verifies the site on relevant pushes to `main`. Its deploy job uploads `site/` **only if** GitHub Pages is configured for an Actions build (`build_type=workflow`). If Pages uses a branch source, the workflow verifies without deploying; the configured branch controls publication. A successful verification job alone is not evidence that the live URL was updated.

## Migration boundary
Private research tables are not copied into the browser archive by this page. Do not delete existing private data until an explicit export, count check, and restore have passed.
