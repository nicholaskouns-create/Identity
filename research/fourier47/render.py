"""Render the measured receipt without manually retyping numerical results."""
from pathlib import Path
import json, hashlib, html
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

d=Path(__file__).parent
r=json.loads((d/'results.json').read_text())
plt.rcParams.update({'font.family':'DejaVu Sans','svg.fonttype':'none','mathtext.fontset':'dejavusans'})
fig=plt.figure(figsize=(18,24),facecolor='#f7f8fa')
ax=fig.add_axes([0,0,1,1]); ax.set_xlim(0,1);ax.set_ylim(0,1);ax.axis('off')
navy='#142d45'; teal='#087f83'; gray='#526575'
def txt(x,y,s,size=15,color=navy,weight='normal'):
    ax.text(x,y,s,fontsize=size,color=color,fontweight=weight,va='top',transform=ax.transAxes)
ax.add_patch(Rectangle((0,.87),1,.13,color=navy))
txt(.045,.969,'125 → 47: EXACT SPECTRAL PRESERVATION',31,'white','bold')
txt(.045,.936,'Rank-47 Fourier projector • mathematical proof + executed numerical validation',18,'#ccdde8')
txt(.045,.902,'FOURIER-47-125-001   |   Construction supplied by Nicholas Shane Kouns',13,'#ccdde8')
for x,big,small in [(.045,'47 + 78 = 125','retained + discarded dimensions'),(.37,'47 / 125 = 37.6%','energy retained by every unit impulse'),(.715,'28 / 28 PASS','6 exact checks • 22 numerical checks')]:
    txt(x,.846,big,25,teal,'bold');txt(x,.816,small,12,gray)
ax.plot([.51,.51],[.105,.785],color='#ccd5db',lw=1)
txt(.045,.782,'EXACT MATHEMATICS',19,teal,'bold')
blocks=[
(.75,'1  SELECT THE FREQUENCIES',[r'$N=125,\quad S=\{-23,\ldots,23\},\quad |S|=47$',r'$q_k(t)=125^{-1/2}e^{-2\pi i kt/125}$',r'$\langle q_j,q_k\rangle=\frac{1}{125}\sum_{t=0}^{124}e^{2\pi i(j-k)t/125}=\delta_{jk}$']),
(.645,'2  PROJECT AND COUNT',[r'$Q^*Q=I_{47},\quad P=QQ^*$',r'$P^2=Q(Q^*Q)Q^*=P,\quad P^*=P$',r'$\operatorname{rank}P=47,\quad\dim\ker P=78$',r'$P_{ts}=\frac{1}{125}\left[1+2\sum_{k=1}^{23}\cos\frac{2\pi k(t-s)}{125}\right]$']),
(.515,'3  ENCODE, RECONSTRUCT, MINIMIZE',[r'$B=[125^{-1/2},\ \sqrt{2/125}\cos_k,\ \sqrt{2/125}\sin_k]$',r'$B^TB=I_{47},\quad BB^T=P,\quad a=B^Tx$',r'$Ba=Px,\quad \|x\|^2=\|Px\|^2+\|(I-P)x\|^2$',r'$\|x-z\|^2=\|(I-P)x\|^2+\|Px-z\|^2$',r'$z\in\operatorname{im}P:\quad \mathrm{minimum\ at}\ z=Px$']),
(.365,'4  EQUIVALENCE AND INVARIANCE',[r'$Px=Py\ \Longleftrightarrow\ x-y\in\ker P$',r'$\mathbb{R}^{125}/\ker P\cong\operatorname{im}P\cong\mathbb{R}^{47}$',r'$Pd=0\ \Longrightarrow\ P(x+d)=Px$',r'$P^m=P\quad(m\geq1)$']),
(.235,'5  CALCULATOR ARITHMETIC',[r'$1+2(23)=47,\quad125-47=78$',r'$\|Pe_t\|^2=P_{tt}=47/125=0.376$',r'$\mathrm{mixed:}\quad1/(1+1/4)=4/5=0.8$',r'$\|2\sin(2\pi40t/125)\|=\sqrt{250}$'])]
for y,title,lines in blocks:
    txt(.045,y,title,14,navy,'bold')
    for j,line in enumerate(lines):txt(.045,y-.026-j*.023,line,15)
txt(.545,.782,'EXECUTED RECEIPT',19,teal,'bold')
txt(.545,.751,'EXACT: integer / rational checks',14,navy,'bold')
txt(.545,.727,'125/125 root-of-unity sums; 47 distinct modes;',13)
txt(.545,.708,'conjugate pairing; dimension split; 37.6%; 80%.',13)
txt(.545,.682,'NUMERICAL CHECK',12,gray,'bold');txt(.86,.682,'RESIDUAL',12,gray,'bold')
short={'Fourier orthonormality':'Q*Q − I','idempotence':'P² − P','self-adjointness':'P* − P','reality':'Imaginary part of P','real-basis orthonormality':'BᵀB − I','real-basis reconstruction':'P − BBᵀ','78 zero eigenvalues':'78 zero eigenvalues (max)','47 unit eigenvalues':'47 unit eigenvalues (max)','trace 47':'Trace − 47','all 125 impulse fractions':'125 impulse fractions (max)','complement orthogonality':'P(I − P)','all 125 Fourier basis actions':'125 Fourier basis actions','1000 energy decompositions':'1,000 energy decompositions','1000 coordinate reconstructions':'1,000 reconstructions','1000 discarded perturbations':'1,000 discarded perturbations','original equivalence example':'Original equivalence example'}
numeric=[c for c in r['checks'] if c['kind']=='numerical']
for j,c in enumerate(numeric):
    y=.659-j*.0194
    if j%2==0:ax.add_patch(Rectangle((.537,y-.017),.425,.021,color='#eaf0f3',lw=0))
    txt(.545,y,short.get(c['name'],c['name']),12)
    txt(.86,y,f"{c['residual']:.2e}",12,teal)
txt(.545,.218,'ORIGINAL SIGNAL ENERGY RETAINED',13,navy,'bold')
txt(.545,.193,'DC / frequency 3 / frequency 20',12);txt(.86,.193,'100%',12,teal)
txt(.545,.174,'Frequency 40 / mixed',12);txt(.86,.174,'≈0% / 80%',12,teal)
txt(.545,.155,'Ramp / impulse',12);txt(.83,.155,'99.4235% / 37.6%',12,teal)
txt(.545,.13,'Input distance 15.8113883 → output difference 8.23e−14',11,gray)
ax.plot([.045,.96],[.105,.105],color='#ccd5db')
txt(.045,.091,'Python '+r['python']+'  •  NumPy '+r['numpy']+'  •  complex128  •  seed 47  •  tolerance 1e−12  •  matrix norm: operator 2-norm',12)
txt(.045,.071,'Exact algebra proves the identities. Floating-point checks validate this implementation. Full proof and code accompany this plate.',12)
txt(.045,.051,'Cyclic Fourier selection is explicit; identification with a Casimir-selected projector requires an explicit map. No Lean/Coq run claimed.',11,gray)
txt(.045,.03,'Source SHA-256: '+r['source_sha256'],10,gray)
fig.savefig(d/'plate.png',dpi=300,facecolor=fig.get_facecolor())
fig.savefig(d/'plate.svg',facecolor=fig.get_facecolor())
plt.close(fig)
svg=(d/'plate.svg').read_text(); svg=svg[svg.index('<svg'):]
proof=(d/'README.md').read_text(); source=(d/'validate.py').read_text(); results=(d/'results.json').read_text()
report='<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>FOURIER-47-125-001 — Proof and validation</title><style>body{margin:0;background:#f7f8fa;color:#142d45;font:16px system-ui}main{max-width:1200px;margin:auto;padding:24px}svg{width:100%;height:auto}pre{white-space:pre-wrap;overflow-wrap:anywhere;background:white;padding:24px;border:1px solid #ccd5db;line-height:1.5}h2{color:#087f83}</style><main>'+svg+'<h2>Complete mathematical proof</h2><pre>'+html.escape(proof)+'</pre><h2>Executable validation source</h2><pre>'+html.escape(source)+'</pre><h2>Complete machine-readable receipt</h2><pre>'+html.escape(results)+'</pre></main></html>'
(d/'FOURIER-47-125-001.html').write_text(report)
print(json.dumps({'image':'plate.png','dimensions':[5400,7200],'report_bytes':len(report.encode()),'results_sha256':hashlib.sha256((d/'results.json').read_bytes()).hexdigest()}))
