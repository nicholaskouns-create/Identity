"""Small checked single-conclusion sequent calculus: identity and implication-left.
Atoms denote separately proved algebraic lemmas; this is not a formalization of
Hilbert-space semantics in Lean/Coq. Proofs retain every mathematical premise.
"""
import json
from pathlib import Path

def imp(a,b):return ('implies',a,b)
def verify(p):
    ctx=set(p['left']);goal=p['right']
    if p['rule']=='identity':return goal in ctx
    if p['rule']=='implies_left':
        a,b=p['formula'][1:];x,y=p['premises']
        return (p['formula'][0]=='implies' and verify(x) and verify(y)
            and x['right']==a and b in y['left'] and y['right']==goal
            and ctx==set(x['left'])|(set(y['left'])-{b})|{imp(a,b)})
    return False

def identity(a):return dict(rule='identity',left=[a],right=a)
def derive_chain(atoms):
    if len(atoms)==1:return identity(atoms[0])
    a,b=atoms[:2];left=identity(a);right=derive_chain(atoms[1:])
    return dict(rule='implies_left',formula=imp(a,b),left=list(set(left['left'])|(set(right['left'])-{b})|{imp(a,b)}),right=right['right'],premises=[left,right])
chains=[['SU2 spin2 tensor carrier','Casimir decomposition','E47 rank47 invariant','spectral contraction'],
['orthogonal code and syndrome isometries','swap error KL conditions','CPTP exact recovery','logical channel identity'],
['encoded classical adapter and identity-or-swap faults','correct syndrome branch','decoded latent preserved','adapter output and gradient preserved']]
proofs=[]
for chain in chains:
    p=derive_chain(chain);assert verify(p);proofs.append(p)
# Negative test of checker: unsupported goal must be rejected.
bad=identity('A');bad['right']='B';assert not verify(bad)
Path(__file__).with_name('sequent_results.json').write_text(json.dumps(dict(valid_derivations=3,rejected_invalid_derivations=1,proofs=proofs,scope='Logical consequence checker relative to explicit mathematical implication premises; algebra discharged in symbolic_check.py and report.'),indent=2))
print('PASS 3 sequent derivations; PASS invalid identity rejection')
