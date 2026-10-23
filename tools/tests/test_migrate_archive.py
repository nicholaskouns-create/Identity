import sys,unittest,json,hashlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from migrate_archive import convert,canonical
class MigrationTests(unittest.TestCase):
    def test_count_and_receipt(self):
        source={"tables":{"public.source_artifacts":[{"id":1,"content":"a"},{"id":2,"content":"b"}],"mnemosyne_private.proof_records":[{"id":"x","status":"proven"}]}}
        out=convert(source)
        self.assertEqual(out["manifest"]["record_count"],3)
        self.assertEqual(len({r["id"] for r in out["records"]}),3)
        for r in out["records"]:
            self.assertEqual(hashlib.sha256(canonical(r).encode()).hexdigest(),r["sha256"])
        self.assertEqual(out,convert(source))
    def test_reject_bad_input(self):
        with self.assertRaises(ValueError):convert({"tables":{"x":[None]}})
    def test_preserve_row(self):
        out=convert({"tables":{"public.test":[{"id":3,"payload":{"x":[1,2]}}]}})
        self.assertEqual(json.loads(out["records"][0]["content"])["source_row"]["payload"]["x"],[1,2])
if __name__=="__main__":unittest.main()
