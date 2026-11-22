# Common-mode transfer: the certified residual auditor against existing monitors

A controlled benchmark. Five diverse replicas compute the spectral component `y = P x` of an input
`x` on an open substrate; six pipelines decide what to deliver; nine fault classes are injected, 600
trials each, on two certified carriers (E47 and the Professor's Cube). The numerics are real (LAPACK
in float64 and float32, Padé exponentials, Newton iterations); the faults are synthetic, modelled on
known common-mode failure types.

## Result

Across the five common-mode classes (7,200 trials), voting delivered 3,346 harmful outputs. The certified
auditor passed **0** of them (95% Wilson upper bound 0.11%) and raised **0** false alarms in 1,200
legitimate trials.

| Pipeline | Harmful outputs passed (of 3,346) | 95% interval | False alarms (of 1,200) |
| --- | --- | --- | --- |
| vote | 3,346 (100%) | 99.9–100% | 0 |
| + validated residual (runtime data) | 2,401 (71.8%) | 70.2–73.3% | 0 |
| + independent reference | 2,397 (71.6%) | 70.1–73.1% | 7 |
| + anomaly detector | 1,292 (38.6%) | 37.0–40.3% | 3 |
| + certified auditor | 0 | 0–0.11% | 0 |
| auditor selects | 0 | 0–0.11% | 0 |

Every cell is on [`plates/plate_common_mode_benchmark.png`](plates/plate_common_mode_benchmark.png); the full
tables, calibration values, per-trial scores and provenance (package versions, SHA-256 of every source) are in
`results_E47.json` and `results_Cube.json`.

## Design

- **Replicas.** R1 dense symmetric eigensolver float64 · R2 the same float32 · R5 the same in a rotated basis
  (these three share a window-selection helper) · R3 Newton matrix-sign spectral slicing · R4 the flow
  `exp(−t s(H)²)` at Theorem G's optimal time. One shared configuration, one shared substrate perturbation
  (≤ 0.8 ε₀) plus per-replica jitter (≤ 0.1 ε₀).
- **Fault classes.** legitimate · F1 independent bit flip · CM1a wrong Λ in the shared configuration, rank changes ·
  CM1b wrong Λ, same rank (E47 `{2, 6, 42}`: rank 47 and Ω = 47/125 again) · CM2 one entry of the shared operator
  file altered · CM3 off-by-one in the shared helper · CM4 substrate drift beyond ε₀ · CM5 fp8/bfloat16 precision
  collapse · CM6 input corrupted before anything sees it (control).
- **Pipelines.** majority vote (calibrated tolerance) · + validated residual: the auditor's exact tolerance with P
  rebuilt from the runtime configuration and operator file · + anomaly detector: learned rank assertion and an
  isolation forest, 0.5% false-alarm calibration · + independent reference: separately coded float64 projector on its
  own operator construction, Λ from the shared configuration · + certified auditor ([`auditor.py`](auditor.py)) ·
  auditor selects: the first replica output the auditor accepts, no vote.
- **Ground truth.** A delivered output is harmful when its exact deviation from the spectral component of the TRUE
  input exceeds the specification tolerance `s(ε₀) + ρ` (Theorem G(ii) at the envelope `ε₀ = g/40`, `ρ = 1/200`).
  Calibration (1,000 legitimate trials per carrier) uses seeds disjoint from the test trials.

## How to read it

The auditor computes the ground-truth quantity itself, exactly, on the input it receives. Its zero false accepts are
therefore arithmetic; its zero false alarms are Theorem G's prediction, which every legitimate trial confirmed with a
factor of 6.5 or more to spare (largest legitimate deviation 0.0035 for E47, 0.0050 for the Cube, against 0.0326 and
0.0324). What the benchmark measures is what each other method lets through, and why: each fails where its reference
shares the fault's source — the replicas for voting, the runtime configuration and operator file for the validated
residual and the independent reference. A reference configured outside the deployment would also catch CM1; the
certificate makes that independence checkable (built from the formal statement, SHA-256 pinned, exact arithmetic).

**Not shown.** The auditor certifies the component of the input it receives, not the input: under CM6 every pipeline,
the auditor included, passed nearly all 1,151 harmful outputs. A forged certificate needs a forged pin: all 100
tampered copies were refused. The faults are injected, not observed in the field, and the carriers are two.

## Run

```sh
pip install -r ../../formal/e47/native-residual/requirements.txt
make run      # full benchmark, ~7 min per carrier on one core (N=600, CAL=1000)
make smoke    # N=30: asserts no auditor transfer outside CM6 and no auditor false alarm
make plate    # redraws both plates
```
