"""Fail-closed regression tests for the real Lean axiom-ledger parser.

These tests mock compiler text only to exercise the parser; they do not
constitute a Lean proof. GitHub Actions separately invokes the real compiler.
"""
import io
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path
from unittest.mock import patch

from scripts import axiom_ledger as ledger


class AxiomLedgerParserTests(unittest.TestCase):
    def test_prefixed_compiler_output_is_parsed(self):
        line = "info: E47.lean:8:1: 'E47.foo' depends on axioms: [propext, Quot.sound]"
        match = ledger.AXLINE.search(line)
        self.assertIsNotNone(match)
        self.assertEqual(match.group(1), "E47.foo")
        self.assertEqual(ledger.classify(match.group(2).split(", ")), "STANDARD")

    def test_native_with_unrecognized_axiom_is_broken(self):
        self.assertEqual(ledger.classify(["Lean.ofReduceBool", "User.hiddenAxiom"]), "BROKEN")
        self.assertEqual(ledger.classify(["Lean.ofReduceBool", "propext"]), "NATIVE")

    def test_source_print_count(self):
        src = "#print axioms E47.first\n-- #print axioms E47.comment\n#print axioms second\n"
        self.assertEqual(ledger.SOURCE_PRINT.findall(src), ["E47.first", "second"])

    def run_mock(self, output, minimum=1):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / "Proof.lean"
            file.write_text("#print axioms foo\n", encoding="utf-8")
            with patch.object(ledger, "run_lean", return_value=(0, output)):
                with patch.object(sys, "argv",
                                  ["axiom_ledger.py", "--min-audits", str(minimum), str(file)]):
                    with redirect_stdout(io.StringIO()):
                        return ledger.main()

    def test_missing_compiler_axiom_report_fails(self):
        self.assertEqual(self.run_mock("compilation completed without report\n"), 1)

    def test_prefixed_matching_report_passes(self):
        self.assertEqual(
            self.run_mock("info: file:1:1: 'Proof.foo' depends on axioms: [propext]\n"),
            0,
        )

    def test_wrong_theorem_report_fails(self):
        self.assertEqual(
            self.run_mock("'Proof.other' does not depend on any axioms\n"), 1
        )


if __name__ == "__main__":
    unittest.main()
