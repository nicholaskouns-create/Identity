#!/usr/bin/env python3
"""
Independent validator for THE TEN-REGISTER THEOREM.

Mirrors Sigillum.lean / Sigillum.v theorem-for-theorem.  Written so that it
re-derives each claim from the definition of the step map, rather than
re-checking a precomputed table.  Exit 0 iff every claim holds.
"""
import sys

NN = 40
def F(s, j): return (3 * j + s) % NN
def orbit(s, j): return [j, F(s, j), F(s, F(s, j)), F(s, F(s, F(s, j)))]
def rep(s, j): return min(orbit(s, j))
def reps(s): return [j for j in range(NN) if rep(s, j) == j]
ODDS = [s for s in range(NN) if s % 2 == 1]

fails = []
def claim(name, ok, detail=""):
    print(f"  [{'ok ' if ok else 'FAIL'}] {name}" + (f"   {detail}" if detail else ""))
    if not ok: fails.append(name)

print("PART I  -- reversible, period four, every offset")
claim("step_injective",
      all(len({F(s, j) for j in range(NN)}) == NN for s in range(NN)),
      "each of the 40 offsets permutes the rim")
claim("period_four",
      all(F(s, F(s, F(s, F(s, j)))) == j for s in range(NN) for j in range(NN)),
      "F^4 = id, all 1600 (s,j) pairs")

print("\nPART II -- primitive at every odd offset")
claim("no_fixed_station",
      all(F(s, j) != j for s in ODDS for j in range(NN)))
claim("no_two_cycle",
      all(F(s, F(s, j)) != j for s in ODDS for j in range(NN)))

print("\nPART III -- THE TEN-REGISTER THEOREM")
counts = {s: len(reps(s)) for s in ODDS}
claim("ten_registers", set(counts.values()) == {10},
      f"all {len(ODDS)} odd offsets give exactly 10 registers")
claim("all_orbits_length_four",
      all(len(set(orbit(s, j))) == 4 for s in ODDS for j in range(NN)))
claim("omega_wheel", 10 * 4 == NN, "Omega_wheel = 10/40 = 1/4")
claim("even_offset_degenerates", len(reps(0)) == 13,
      f"s=0 gives {len(reps(0))} orbits of lengths {sorted({len(set(orbit(0,j))) for j in range(NN)})}")

print("\nPART IV -- constructive witness at s = 1")
REGS = [[0,1,4,13],[2,7,22,27],[3,10,31,14],[5,16,9,28],[6,19,18,15],
        [8,25,36,29],[11,34,23,30],[12,37,32,17],[20,21,24,33],[26,39,38,35]]
flat = [x for r in REGS for x in r]
claim("witness_count",  len(REGS) == 10)
claim("witness_widths", all(len(r) == 4 for r in REGS))
claim("witness_total",  len(flat) == NN)
claim("witness_covers", set(flat) == set(range(NN)))
claim("witness_disjoint", len(flat) == len(set(flat)), "cover + no repeats = partition")
claim("witness_closed", all(F(1, j) in r for r in REGS for j in r),
      "no register leaks into another")
# the witness is not merely consistent -- it IS the orbit set
claim("witness_is_the_orbit_set",
      sorted(sorted(r) for r in REGS) == sorted(sorted(set(orbit(1, j))) for j in reps(1)),
      "listed registers coincide with the computed orbits")

print("\nPART V  -- the CRT refinement 10 = 2 + 8")
claim("mod5_fixed_point", (3 * 2 + 1) % 5 == 2, "station 2 is fixed in the Z_5 factor")
two   = [j for j in reps(1) if j % 5 == 2]
eight = [j for j in reps(1) if j % 5 != 2]
claim("crt_two",   len(two) == 2,   f"registers over the Z_5 fixed point: {two}")
claim("crt_eight", len(eight) == 8, f"registers over the Z_5 four-cycle: {eight}")
claim("crt_sums",  len(two) + len(eight) == 10)
# the deeper statement: the split is forced by the factor orbit structure
def orbs(m, s):
    seen, out = set(), []
    for j in range(m):
        if j in seen: continue
        c = [j]; k = (3*j+s) % m
        while k != j: c.append(k); seen.add(k); k = (3*k+s) % m
        seen.add(j); out.append(c)
    return out
l8 = sorted(len(c) for c in orbs(8, 1)); l5 = sorted(len(c) for c in orbs(5, 1))
claim("crt_factor_structure", l8 == [4,4] and l5 == [1,4],
      f"Z_8 orbit lengths {l8}, Z_5 orbit lengths {l5}")
import math
pred = sum(math.gcd(a, b) for a in l8 for b in l5)
claim("crt_pairing_formula", pred == 10,
      f"sum of gcd(|O_8|,|O_5|) over factor-orbit pairs = {pred} = 2 + 8")

print("\n" + ("ALL CLAIMS HOLD" if not fails else f"FAILURES: {fails}"))
sys.exit(1 if fails else 0)
