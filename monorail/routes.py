"""Route definitions. A route is an ordered list of stations.

Certified(R) = AND over k of Pass(S_k).  If station S_j fails, every
station after it is BLOCKED, not merely unrun. Charter, 'Governing
monorail law'.

Station kinds:
  lean   — compile a .lean file with the Lean kernel
  coq    — compile a .v file with coqc
  python — run an exact-arithmetic validator

Evidence class is declared per station and is NEVER raised by transit.
`issue` ties each station to the E47 Proof Forge lane that owns it.
"""

ROUTES = {
    "KX-E47-KERNEL": {
        "title": "K Express · carrier to kernel dimension certificate",
        "service": "K-Express",
        "origin": "Canonical Manifest Depot",
        "destination": "Frozen Release Depot",
        "object_id": "E47-CASIMIR",
        "parents": ["E47-CARRIER-125"],
        "scope": ("Only the exact statements these files compile. The carrier "
                  "bridge connects the WEIGHT data of the concrete 125-state "
                  "operator to the block decomposition; it does NOT establish "
                  "dim ker (C-6I)(C-30I) = 47 for the full Casimir, which "
                  "still needs centrality and eigenspace identification "
                  "(lanes #17, #19) and remains open."),
        "stations": [
            {"name": "spin2_generators", "kind": "lean",
             "file": "formal/e47/unified/Spin2Generators.lean",
             "theorem_id": "E47-SPIN2-GENERATORS", "evidence_class": "E0",
             "issue": 15},
            {"name": "spin2_generators_coq", "kind": "coq",
             "file": "formal/e47/unified/Spin2Generators.v",
             "theorem_id": "E47-SPIN2-GENERATORS", "evidence_class": "E0",
             "issue": 15},
            {"name": "triple_tensor", "kind": "lean",
             "file": "formal/e47/unified/Tensor125.lean",
             "theorem_id": "E47-TENSOR-125", "evidence_class": "E0",
             "issue": 16},
            {"name": "weight_decomposition", "kind": "lean",
             "file": "formal/e47/E47WeightAlgebra.lean",
             "theorem_id": "E47-WEIGHT-ALGEBRA", "evidence_class": "E0",
             "issue": 18},
            {"name": "spectral_census", "kind": "lean",
             "file": "formal/e47/E47Spectral.lean",
             "theorem_id": "E47-SPECTRAL-CENSUS", "evidence_class": "E0",
             "issue": 19},
            {"name": "kernel_dimension", "kind": "lean",
             "file": "formal/e47/unified/RankNullity47.lean",
             "theorem_id": "E47-KERNEL-47", "evidence_class": "E0",
             "issue": 21},
            {"name": "kernel_dimension_coq", "kind": "coq",
             "file": "formal/e47/unified/RankNullity47.v",
             "theorem_id": "E47-KERNEL-47", "evidence_class": "E0",
             "issue": 21},
            {"name": "carrier_bridge", "kind": "lean",
             "file": "formal/e47/unified/E47Bridge.lean",
             "theorem_id": "E47-CARRIER-BRIDGE", "evidence_class": "E0",
             "issue": 19},
            {"name": "carrier_bridge_coq", "kind": "coq",
             "file": "formal/e47/unified/E47Bridge.v",
             "theorem_id": "E47-CARRIER-BRIDGE", "evidence_class": "E0",
             "issue": 19},
            {"name": "exact_matrix_rank", "kind": "python",
             "file": "validation/e47_rank_nullity_exact.py",
             "theorem_id": "E47-RANK-78", "evidence_class": "E1",
             "issue": 19},
            {"name": "exact_bracket_trace", "kind": "python",
             "file": "validation/e47_tensor_bracket_trace_exact.py",
             "theorem_id": "E47-BRACKETS-EXACT", "evidence_class": "E1",
             "issue": 17},
        ],
    },
}
