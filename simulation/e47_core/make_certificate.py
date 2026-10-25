"""Write e47_core_certificate.json (deterministic: no timestamps).

Usage: python make_certificate.py [--check]   (--check: fail if the file on disk differs)
"""
import json
import os
import sys

import e47_core

HERE = os.path.dirname(os.path.abspath(__file__))
PATH = os.path.join(HERE, "e47_core_certificate.json")

HASH_METHOD = (
    "constants_sha256 = SHA-256 of the UTF-8 bytes of json.dumps(constants, sort_keys=True, "
    "separators=(',', ':'), ensure_ascii=True), where constants is the 'constants' object "
    "of this file (Fractions are strings 'p/q'). Recompute with e47_core.constants_sha256() "
    "or with any JSON library using that exact serialization."
)


def build():
    checks = e47_core.verify()
    block = e47_core.constants()
    return {
        "schema": "e47-core-certificate/1",
        "constants": block,
        "constants_sha256": e47_core.constants_sha256(block),
        "hash_method": HASH_METHOD,
        "checks": checks,
        "all_checks_pass": all(checks.values()),
    }


def main():
    cert = build()
    text = json.dumps(cert, indent=2, sort_keys=True, ensure_ascii=True) + "\n"
    if "--check" in sys.argv:
        ok = os.path.exists(PATH) and open(PATH, encoding="utf-8").read() == text
        print("certificate up to date" if ok else "certificate DIFFERS from regenerated value")
        return 0 if ok else 1
    with open(PATH, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    print("wrote", PATH)
    print("all_checks_pass:", cert["all_checks_pass"])
    print("constants_sha256:", cert["constants_sha256"])
    return 0 if cert["all_checks_pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
