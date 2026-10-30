import unittest
from tools.e47_instrument_bridge import EPS, K2, MULT, RATE, run

class TestBridge(unittest.TestCase):
    def test_dimensions(self):
        self.assertEqual(sum(MULT), 125)
        self.assertEqual(MULT[2] + MULT[5], 47)

    def test_rate(self):
        self.assertEqual(max(abs(1-EPS*k) for k in K2 if k), RATE)

    def test_receipt(self):
        sources = [{'path':'a','blob_sha':'a'*40},{'path':'b','blob_sha':'b'*40}]
        result = run(sources)
        self.assertTrue(result['within_bound_with_roundoff'])
        self.assertEqual(result['sha256'], run(sources)['sha256'])

if __name__ == '__main__':
    unittest.main()
