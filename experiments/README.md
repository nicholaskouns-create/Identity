# E47 synthetic QGNN ablation: reproduction

The archived `e47_ablation_results.json` contains eight seed-level ROC-AUC
measurements from the synthetic link-prediction experiment implemented in
`e47_ablation.py`. It is **synthetic, E47-aligned evidence**, not a
TGBL-wiki/Cora reproduction, physical-hardware result, or Lean/Coq theorem.

## Run without overwriting archived evidence

From the repository root, in a Python environment with NumPy, SciPy, and
scikit-learn installed:

```sh
python experiments/e47_ablation.py --output e47_ablation_reproduced.json
```

The default is `./e47_ablation_reproduced.json`; use `--output` to choose
another path. The destination directory must exist, and the script refuses to
overwrite an existing file, including the tracked archived JSON. Each run
creates a separate evidence artifact. Use `--help` for CLI usage.

## Experimental pairing and evidence boundary

- Eight independent synthetic graph draws are indexed `seed=0..7`.
- NumPy graph RNG uses `default_rng(seed + 100)`; the train/test split uses
  `random_state=seed`. Each arm shares the graph, labels, and split at that
  index, so paired differences compare corresponding seed indices.
- The 64D baseline, random rank-24, and E47-derived rank-24 arms receive 64D
  inputs; the full E47 arm receives 125D inputs. Comparisons against the
  full E47 arm are therefore **not matched-input comparisons**.
- Results are floating-point numerical measurements. The archived JSON
  contains no proof-assistant certificate or hardware measurement.
- Numerical reproduction can depend on library versions and environment.
  Compare the new seed-level JSON against the archived JSON rather than
  assuming bit-for-bit equality without matching dependencies.

The lightweight output-safety tests run independently of scientific packages:

```sh
python -m unittest discover -s tools/tests -p 'test_ablation_output_cli.py' -v
```

These tests cover CLI parsing and no-clobber behavior; they do **not**
execute the eight-seed experiment or validate ROC-AUC values.
