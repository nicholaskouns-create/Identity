"""Reproducible E47 spectral bridge over source descriptors; abstract diagonal basis."""
import hashlib,json,math
from fractions import Fraction
SPECTRUM=(0,2,6,12,20,30,42)
MULT=(1,9,25,28,27,22,13)
K2=tuple(((j*(j+1)-6)*(j*(j+1)-30))**2 for j in range(7))
EPS=Fraction(1,99144)
RATE=Fraction(15,17)
def canonical(x):
    return json.dumps(x,sort_keys=True,separators=(',',':'),ensure_ascii=False).encode()
def vector(sources):
    b=hashlib.shake_256(canonical(sources)).digest(250)
    return [(int.from_bytes(b[i:i+2],'big')-32768)/32768 for i in range(0,250,2)]
def run(sources,steps=220):
    if len(sources)<2 or not all(len(s['blob_sha'])==40 and s['path'] for s in sources):
        raise ValueError('two valid source descriptors required')
    v=vector(sources)
    sectors=[j for j,m in zip(SPECTRUM,MULT) for _ in range(m)]
    p=[x if j in (6,30) else 0 for x,j in zip(v,sectors)]
    multipliers=[float(1-EPS*k) for k in K2]
    g=[x*multipliers[SPECTRUM.index(j)]**steps for x,j in zip(v,sectors)]
    residual=math.dist(g,p)
    bound=float(RATE)**steps*math.dist(v,p)
    out={'schema':'mc.e47.cross_instrument/1','scope':'source-provenance-to-abstract-diagonal-e47',
         'sources':sources,'carrier_dimension':125,'kernel_dimension':47,
         'casimir_spectrum':list(SPECTRUM),'sector_dimensions':list(MULT),
         'encoding':'SHAKE256(canonical source descriptors) into 125 signed uint16 coordinates',
         'steps':steps,'epsilon':'1/99144','sharp_rate':'15/17',
         'numerical_residual_l2':residual,'theoretical_bound_l2':bound,
         'within_bound_with_roundoff':residual<=bound+1e-12,
         'limitations':['No flight or quantum simulator executed',
                        'Abstract diagonal basis, not concrete 125x125 Casimir',
                        'Not a vehicle authorization or physical safety certificate']}
    out['sha256']=hashlib.sha256(canonical(out)).hexdigest()
    return out
if __name__=='__main__':
    sources=[
      {'instrument':'EIDOLON','repo':'nicholaskouns-create/E47-Kartekeya','path':'website/interfaces/flight/eidolon/index.html','blob_sha':'674cda1a27f7a7658003539538ead1abfc73acdf'},
      {'instrument':'THE MATRIX','repo':'nicholaskouns-create/E47-Kartekeya','path':'website/interfaces/matrix/index.html','blob_sha':'d311e7444d003345de2e755aeecff6df2191a0ba'},
      {'instrument':'E47 Richardson','repo':'nicholaskouns-create/Identity','path':'formal/e47/E47Richardson.lean','blob_sha':'2cb7efc571dc5d1437cf90b9c1df54f48e196a05'}]
    print(json.dumps(run(sources),indent=2))
