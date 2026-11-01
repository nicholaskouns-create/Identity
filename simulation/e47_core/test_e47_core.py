import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from fractions import Fraction

import e47_core as e
import make_certificate

HERE = os.path.dirname(os.path.abspath(__file__))


def _read(path):
    with open(path, encoding="utf-8") as fh:
        return fh.read()


def _cert():
    return json.loads(_read(os.path.join(HERE, "e47_core_certificate.json")))

CHECK = os.path.join(HERE, "e47_core_check.py")


class Core(unittest.TestCase):
    def test_verify_all_true(self):
        res = e.verify()
        self.assertGreaterEqual(len(res), 30)
        self.assertEqual([k for k, v in res.items() if not v], [])

    def test_headline_values(self):
        self.assertEqual(len(e.triples), 125)
        self.assertEqual(e.kernel_rank, 47)
        self.assertEqual(e.Omega_c, Fraction(47, 125))
        self.assertEqual(e.epsilon, Fraction(1, 99144))
        self.assertEqual(e.rho, Fraction(15, 17))
        self.assertEqual(e.pr_normalizer, 1814400)
        self.assertEqual(e.k_squared, [11664, 12544, 19600, 32400, 186624])
        self.assertEqual(e.eigenspace_dims, [1, 9, 25, 28, 27, 22, 13])
        self.assertEqual(e.tower["D"], 47)

    def test_lean_coq_names_exist(self):
        for n in ("triples", "w", "mult", "casimir", "lam", "gap", "pr"):
            self.assertTrue(callable(getattr(e, n)) or isinstance(getattr(e, n), list), n)

    def test_certificate_current_and_hash_independent(self):
        cert = _cert()
        self.assertEqual(cert, make_certificate.build())
        raw = json.dumps(cert["constants"], sort_keys=True, separators=(",", ":"), ensure_ascii=True)
        self.assertEqual(hashlib.sha256(raw.encode("utf-8")).hexdigest(), cert["constants_sha256"])
        self.assertTrue(cert["all_checks_pass"])

    def test_check_script_in_sync_with_certificate(self):
        src = _read(CHECK)
        cert = _cert()
        self.assertIn('PINNED_SHA256 = "%s"' % cert["constants_sha256"], src)
        self.assertIn("CONSTANTS_JSON = '%s'" % e.canonical_bytes().decode(), src)


class Check(unittest.TestCase):
    def run_on(self, text, name="doc.md"):
        with tempfile.TemporaryDirectory() as d:
            open(os.path.join(d, name), "w", encoding="utf-8").write(text)
            r = subprocess.run([sys.executable, CHECK, d], capture_output=True, text=True)
            return r.returncode, r.stdout

    def test_consistent_text_ok(self):
        txt = ("The kernel has 47/125 = 0.376 of states (Ω = 0.376, about 0.38).\n"
               "epsilon = 1/99144, contraction 15/17, pr normalizer 1814400.\n"
               "Casimir multiplicities 1, 9, 25, 28, 27, 22, 13 and spins [1, 3, 5, 4, 3, 2, 1].\n"
               "K^2 eigenvalues 11664, 12544, 19600, 32400, 186624. 25 + 22 = 47.\n")
        rc, out = self.run_on(txt)
        self.assertEqual(rc, 0, out)

    def test_absent_ok(self):
        self.assertEqual(self.run_on("nothing relevant here 123/456\n")[0], 0)

    def test_drift_detected(self):
        # built from pieces so this file itself never contains a contradicting statement
        bad = ["kernel fraction is 48" + "/125", "Ω = 0" + ".367", "epsilon = 1/99" + "114",
               "contraction rate 14" + "/17",
               "Casimir multiplicities 1, 9, 25, 28, 27, 22, " + "12", "pr normalizer 18144" + "40",
               "K^2 eigenvalues 11664, 12544, 19600, 32400, 1866" + "42", "kernel rank 4" + "6"]
        for line in bad:
            rc, out = self.run_on(line + "\n")
            self.assertEqual(rc, 1, line + "\n" + out)
            self.assertIn("DRIFT doc.md:1", out)

    def test_read_only(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "a.md")
            open(p, "w").write("kern" + "el 48/125\n")
            before = os.stat(p).st_mtime_ns
            subprocess.run([sys.executable, CHECK, d], capture_output=True)
            self.assertEqual(os.stat(p).st_mtime_ns, before)
            self.assertEqual(os.listdir(d), ["a.md"])


if __name__ == "__main__":
    unittest.main()
