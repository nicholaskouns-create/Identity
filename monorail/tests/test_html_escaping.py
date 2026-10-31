"""Regression: Monorail station and repair HTML output encodes data as text.

The public corpus is fixed source data. This verifies the shared rendering
boundary without modifying citizens, station URLs, or restricted Drive access.
"""
import json
import re
import subprocess
import unittest
from pathlib import Path

HTML = (Path(__file__).resolve().parents[1] / "index.html").read_text(encoding="utf-8")
MATCH = re.search(r'<script id="data" type="application/json">([\s\S]*?)</script>', HTML)
if MATCH is None:
    raise RuntimeError("Monorail embedded data missing")
DATA = json.loads(MATCH.group(1))
ESC = next(line for line in HTML.splitlines() if line.startswith("function esc(s)"))
STATION = "function station(slug){" + HTML.split("function station(slug){", 1)[1].split(
    "\nfunction repair(id){", 1
)[0]
REPAIR = "function repair(id){" + HTML.split("function repair(id){", 1)[1].split(
    "\nfunction richardson(){", 1
)[0]


def run_js(source):
    return subprocess.run(
        ["node", "-e", "const DATA = " + json.dumps(DATA) + ";\n" + ESC + "\n" +
         STATION + "\n" + REPAIR + "\n" + source],
        check=True, capture_output=True, text=True,
    ).stdout.strip()


class HtmlEscapingTests(unittest.TestCase):
    def test_all_five_metacharacters_encoded(self):
        result = run_js('console.log(esc(String.fromCharCode(38,60,62,34,39)));')
        self.assertEqual(result, "&amp;&lt;&gt;&quot;&#39;")

    def test_station_label_is_text_not_markup(self):
        result = run_js(
            'DATA.stations.find(s=>s.slug==="tower").links[0].label='
            ' "<img src=x onerror=alert(1)>";'
            'console.log(station("tower"));'
        )
        self.assertIn("&lt;img src=x onerror=alert(1)&gt;", result)
        self.assertNotIn("<img src=x onerror=alert(1)>", result)

    def test_href_attribute_quotes_are_encoded(self):
        result = run_js(
            'DATA.stations.find(s=>s.slug==="tower").links[2].href='
            ' \'https://example.invalid/?q="onclick="test"&x=1\';'
            'console.log(station("tower"));'
        )
        self.assertIn("&quot;onclick=&quot;", result)
        self.assertIn("&amp;x=1", result)
        self.assertNotIn('href="https://example.invalid/?q="onclick="test"', result)

    def test_home_navigation_does_not_promise_restricted_redirects(self):
        # Owner-only 401 originals remain linked but are not redirected.
        # A historical 404 also remains in the record. Home must describe
        # separate alternatives, not promise that broken exits redirect.
        home = HTML.split("function home(){", 1)[1].split("\nfunction station(slug){", 1)[0]
        self.assertNotIn("broken exits already redirected", home)
        self.assertIn("owner-only Drive sources remain restricted", home)
        self.assertIn("working alternatives are separately labeled", home)
        for repair_id in ("mirror", "modsync"):
            self.assertEqual(next(r["status"] for r in DATA["repairs"] if r["id"] == repair_id), "401")

    def test_restricted_originals_and_census_preserved(self):
        self.assertEqual(len(DATA["stations"]), 17)
        self.assertEqual(sum(len(s["links"]) for s in DATA["stations"]), 54)
        self.assertEqual([(r["id"], r["status"]) for r in DATA["repairs"]],
                         [("highlight", "404"), ("paper", "404"),
                          ("mirror", "401"), ("modsync", "401")])
        result = run_js('console.log(repair("mirror"));')
        self.assertIn("1wCmn5J4Tjo0qVV5AOoHUxD1tXComhPf7lU1ntzKtaMs", result)


if __name__ == "__main__":
    unittest.main()
