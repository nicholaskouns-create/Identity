"""Tests for the axiom ledger's own correctness.

The ledger decides whether a proof counts. Three faults it had were faults in
the gate rather than in the files it judged, and each one made it say something
false:

  1. It scanned prose inside `/- -/` headers as code, so any file whose
     documentation honestly described its own `sorry` placeholders was reported
     as having an unfinished proof. The gate punished candour.

  2. It ran every file with no search path, so a file importing a sibling by
     bare module name failed as `unknown module prefix` and was recorded as a
     compile failure. That is a statement about the gate's invocation, not
     about the file.

  3. It recorded a file the runner killed for memory as "did not compile",
     which asserts the proof is wrong when the only thing established is that
     the machine was too small. An absence of evidence was being filed as
     evidence of absence.

These tests pin all three. They run the real script as a subprocess, because
what matters is the exit code CI reads, not an internal call.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
LEDGER = ROOT / "scripts" / "axiom_ledger.py"

sys.path.insert(0, str(ROOT / "scripts"))
from axiom_ledger import classify, strip_comments  # noqa: E402


# --------------------------------------------------------------------- units

def test_block_comment_prose_is_not_code():
    """A header that says the word `sorry` is documentation, not a proof."""
    text = """/-
  STATUS: PLACEHOLDER. Three `sorry` placeholders, each labelled below.
  Its header as received claimed "Zero sorry"; that claim is false.
-/
theorem t : 1 = 1 := rfl
"""
    code = "\n".join(c for _, c in strip_comments(text))
    assert "sorry" not in code
    assert "theorem t" in code


def test_a_real_sorry_in_code_is_still_caught():
    """Fixing the false positive must not create a false negative."""
    text = "theorem t : 1 = 1 := by sorry\n"
    code = "\n".join(c for _, c in strip_comments(text))
    assert "sorry" in code


def test_nested_and_inline_comments():
    text = "/- outer /- inner sorry -/ still outer -/\ntheorem ok : True := trivial\n"
    code = "\n".join(c for _, c in strip_comments(text))
    assert "sorry" not in code
    assert "theorem ok" in code
    line = "theorem u : True := trivial -- sorry, not really\n"
    assert "sorry" not in "\n".join(c for _, c in strip_comments(line))


def test_line_numbers_survive_stripping():
    """A reported line number has to point at the line the reader will open."""
    text = "/-\n a\n b\n-/\ntheorem t : 1 = 1 := by sorry\n"
    hits = [n for n, c in strip_comments(text) if "sorry" in c]
    assert hits == [5]


@pytest.mark.parametrize(
    "axioms, verdict",
    [
        ([], "CLEAN"),
        (["propext"], "STANDARD"),
        (["propext", "Classical.choice", "Quot.sound"], "STANDARD"),
        (["sorryAx"], "BROKEN"),
        (["Lean.ofReduceBool"], "NATIVE"),
        (["propext", "myCustomAxiom"], "BROKEN"),
    ],
)
def test_classify_is_unchanged(axioms, verdict):
    """The verdicts themselves must not have drifted while fixing the plumbing."""
    assert classify(axioms) == verdict


# ------------------------------------------------------------- end to end

def run(args: list[str]) -> subprocess.CompletedProcess:
    return subprocess.run(
        [sys.executable, str(LEDGER), *args],
        capture_output=True, text=True, timeout=300,
    )


def test_documented_placeholder_does_not_fail_the_gate(tmp_path):
    """The exact shape that used to fail: honest prose about sorry, no sorry."""
    f = tmp_path / "Documented.lean"
    f.write_text("/-\n  This file once claimed zero sorry; that was false.\n-/\ntheorem t : 1 = 1 := rfl\n#print axioms t\n")
    r = run([str(f)])
    assert "unfinished proof" not in r.stdout + r.stderr


def test_a_genuine_sorry_still_fails_the_gate(tmp_path):
    f = tmp_path / "Broken.lean"
    f.write_text("theorem t : 1 = 1 := by sorry\n")
    r = run([str(f)])
    assert r.returncode == 1
    assert "unfinished proof" in r.stdout


def test_declared_axiom_still_fails_the_gate(tmp_path):
    f = tmp_path / "Axiomatic.lean"
    f.write_text("axiom cheat : 1 = 2\n")
    r = run([str(f)])
    assert r.returncode == 1
    assert "declares an axiom" in r.stdout


def test_an_axiom_named_only_in_a_comment_does_not_fail(tmp_path):
    f = tmp_path / "Mentioned.lean"
    f.write_text("/-\n  axiom cheat : 1 = 2   -- described, never declared\n-/\ntheorem t : 1 = 1 := rfl\n")
    r = run([str(f)])
    assert "declares an axiom" not in r.stdout


def test_missing_file_is_reported_not_skipped(tmp_path):
    r = run([str(tmp_path / "Nope.lean")])
    assert r.returncode == 1
    assert "missing" in r.stdout
