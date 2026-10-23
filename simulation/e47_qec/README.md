# E47 functional quantum recovery and LLM adapter

This package implements a rank-47 E47 code, an orthogonal 47-dimensional syndrome, a trace-preserving recovery channel for the error space span{I,U}, and a matching classical residual adapter inside a small causal language model.

## Start here

- [Full proofs and formalism](REPORT.md): Lie algebra, projector, contraction, Knill–Laflamme identities, recovery channel, sequent derivations, and LLM effective weights.
- [Implementation](e47_qec.py): carrier, encoding, recovery, and adapter.
- [Numerical validation](validate.py) and [results](results.json): 37 passed checks.
- [Exact SymPy validation](symbolic_check.py) and [results](symbolic_results.json): 14 passed checks.
- [Sequent checker](sequent_check.py) and [derivations](sequent_results.json): three valid derivations relative to explicit mathematical premises, plus invalid-identity rejection.
- [Causal language-model demonstration](llm_demo.py) and [results](llm_results.json).
- [Computed encoding/syndrome basis](e47_basis.npz) and [SHA-256 manifest](SHA256SUMS.json).

## Run

From the repository root:

```bash
python -m pip install -r simulation/e47_qec/requirements.txt
python simulation/e47_qec/validate.py
python simulation/e47_qec/symbolic_check.py
python simulation/e47_qec/sequent_check.py
python simulation/e47_qec/llm_demo.py
```

Scripts regenerate their result files. Numerical basis vectors may differ between eigensolver implementations while spanning the same invariant spaces. The manifest records the original validated files; compare it before rerunning generators.

## Recorded execution

| Test | Result |
|---|---|
| 48 quantum state/channel recoveries | Maximum Frobenius error 6.99e-15 |
| Float32 classical adapter | Relative error 3.88e-8 |
| Causal model, 21 of 48 blocks swapped | Uncorrected max logit error 0.1920588622 |
| Same model with recovery | Max logit error 5.55e-16; argmax agreement 100% |

Quantum results are complex density-matrix/Kraus simulations. The classical adapter was executed inside an untrained, random-weight causal model with hidden width 64 and vocabulary 32. The specified code/syndrome faults are corrected; pretrained-model quality and physical hardware performance have not been measured. The report states every error-model and proof-checking assumption.
