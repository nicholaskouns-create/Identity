"""CLI safety tests for the synthetic ablation output (no benchmark execution)."""
import ast
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "experiments" / "e47_ablation.py"


class AblationOutputCLITests(unittest.TestCase):
    def invoke(self, *args, cwd=None):
        return subprocess.run(
            [sys.executable, str(SCRIPT), *args],
            cwd=cwd, capture_output=True, text=True, timeout=15, check=False,
        )

    def test_script_syntax(self):
        ast.parse(SCRIPT.read_text(encoding="utf-8"), filename=str(SCRIPT))

    def test_help_does_not_require_scientific_dependencies(self):
        result = self.invoke("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("--output", result.stdout)
        self.assertIn("e47_ablation_reproduced.json", result.stdout)

    def test_existing_explicit_output_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "archived.json"
            output.write_text("original results", encoding="utf-8")
            result = self.invoke("--output", str(output), cwd=directory)
            self.assertEqual(result.returncode, 2)
            self.assertIn("Refusing to overwrite", result.stderr)
            self.assertEqual(output.read_text(encoding="utf-8"), "original results")

    def test_existing_default_output_is_never_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "e47_ablation_reproduced.json"
            output.write_text("keep this", encoding="utf-8")
            result = self.invoke(cwd=directory)
            self.assertEqual(result.returncode, 2)
            self.assertIn("Refusing to overwrite", result.stderr)
            self.assertEqual(output.read_text(encoding="utf-8"), "keep this")

    def test_missing_output_directory_fails_before_simulation(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "missing" / "results.json"
            result = self.invoke("--output", str(output), cwd=directory)
            self.assertEqual(result.returncode, 2)
            self.assertIn("Output directory does not exist", result.stderr)
            self.assertFalse(output.exists())


if __name__ == "__main__":
    unittest.main()
