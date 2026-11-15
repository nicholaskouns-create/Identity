#!/usr/bin/env python3
"""One-button E47 certificate runner: explicit commands, per-file logs, summary and exit status."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "proof-results"
OUT.mkdir(exist_ok=True)
lean = ["Core47", "RGFixed", "Retention", "Clock", "EncodedOracle",
        "Spin2Generators", "Tensor125", "SpectralMask128", "MonographCore",
        "E47WeightCounts"]
coq = ["Core47", "RGFixed", "Retention", "Clock", "EncodedOracle",
       "Spin2Generators", "Tensor125", "SpectralMask128", "MonographCore"]
checks = []
def run(label, command):
    proc = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, errors="replace")
    output = "$ " + " ".join(command) + "\n" + proc.stdout + proc.stderr
    path = OUT / (label.replace("/", "_") + ".log")
    path.write_text(output)
    checks.append({"check": label, "result": "PASS" if proc.returncode == 0 else "FAIL",
                   "exit_code": proc.returncode, "command": command,
                   "log": str(path.relative_to(ROOT))})
    print(f"{checks[-1]['result']}: {label}", flush=True)

for name in lean:
    path = ROOT / f"formal/e47/unified/{name}.lean"
    if path.exists():
        run("Lean-" + name, ["lean", str(path.relative_to(ROOT))])
    else:
        checks.append({"check": "Lean-" + name, "result": "MISSING", "exit_code": 127,
                       "command": [], "log": ""})
for name in coq:
    path = ROOT / f"formal/e47/unified/{name}.v"
    if path.exists():
        run("Coq-" + name, ["coqc", str(path.relative_to(ROOT))])
    else:
        checks.append({"check": "Coq-" + name, "result": "MISSING", "exit_code": 127,
                       "command": [], "log": ""})
run("Integer-matrix", ["python", "validation/e47_tensor_bracket_trace_exact.py"])
run("Independent-crosscheck", ["python", "-I", "validation/e47_independent_crosscheck.py"])

files = sorted(p for p in OUT.glob("*.log"))
hashes = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in files}
(OUT / "SHA256SUMS.json").write_text(json.dumps(hashes, indent=2) + "\n")
(OUT / "results.json").write_text(json.dumps({
    "generated_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "git_sha": os.getenv("GITHUB_SHA", "unknown"),
    "checks": checks,
}, indent=2) + "\n")
passed = sum(c["result"] == "PASS" for c in checks)
summary = [f"# E47 Proof Runner — {passed}/{len(checks)} checks passed", "",
           f"Commit: \`{os.getenv('GITHUB_SHA', 'unknown')}\`", "",
           "| Certificate | Status |", "|---|---|"]
summary += [f"| {c['check']} | {c['result']} |" for c in checks]
summary += ["", "Download the **e47-proof-receipts** artifact for per-file compiler output, machine-readable results, and SHA-256 hashes."]
report = "\n".join(summary) + "\n"
(OUT / "SUMMARY.md").write_text(report)
print(report)
if os.getenv("GITHUB_STEP_SUMMARY"):
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as f:
        f.write(report)
sys.exit(0 if passed == len(checks) else 1)
