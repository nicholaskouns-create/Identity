import re, subprocess
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle

BG="#080b0e"; PANEL="#0e1419"; RULE="#1f2d36"
GOLD="#c9a227"; MINT="#6fcf97"; INK="#e6edf1"; DIM="#7d8f9a"; FAINT="#55646e"; COPPER="#cf8a4e"
MONO="DejaVu Sans Mono"; SERIF="DejaVu Serif"; SANS="DejaVu Sans"

ROOT=Path("/home/claude/survey/Identity/formal/e47")
def count(pat, glob):
    n=0
    for f in ROOT.rglob(glob):
        n+=len(re.findall(pat, f.read_text(errors="ignore"), re.M))
    return n
coq_thms  = count(r"^(Theorem|Lemma|Corollary|Example)\s", "*.v")
lean_thms = count(r"^(theorem|lemma|example)\s", "*.lean")

COQ=[("E47Spectral.v",72),("E47WeightAlgebra.v",277),("TowerIdentity.v",57),
     ("unified/Clock.v",8),("unified/Core47.v",8),("unified/EncodedOracle.v",33),
     ("unified/RGFixed.v",10),("unified/Retention.v",9),
     ("unified/Spin2Generators.v",71),("unified/Tensor125.v",134)]
LEAN=[("E47Spectral.lean",62,"ok"),("E47WeightAlgebra.lean",249,"ax"),
      ("unified/Clock.lean",8,"ok"),("unified/Core47.lean",8,"ok"),
      ("unified/EncodedOracle.lean",31,"ok"),("unified/RGFixed.lean",9,"ok"),
      ("unified/Retention.lean",8,"ok"),("unified/Spin2Generators.lean",56,"ax"),
      ("unified/Tensor125.lean",127,"ax"),("E47ConcreteMatrix.lean",1571,"skip")]

fig=plt.figure(figsize=(14,20),dpi=170); fig.patch.set_facecolor(BG)
ax=fig.add_axes([0,0,1,1]); ax.set_xlim(0,100); ax.set_ylim(0,148); ax.axis("off")
ax.set_facecolor(BG)
def t(x,y,s,size=10,c=INK,f=SANS,w="normal",ha="left",va="center",st="normal",sp=0):
    ax.text(x,y,s,fontsize=size,color=c,family=f,weight=w,ha=ha,va=va,style=st,
            linespacing=1.65,**({"fontstretch":"normal"})) if sp==0 else \
    ax.text(x,y,s,fontsize=size,color=c,family=f,weight=w,ha=ha,va=va,style=st,linespacing=1.65)
def rule(y,x0=6,x1=94,c=RULE,lw=0.8): ax.plot([x0,x1],[y,y],color=c,lw=lw,zorder=1)
def panel(x,y,w,h,fc=PANEL,ec=RULE,lw=0.8):
    ax.add_patch(Rectangle((x,y),w,h,facecolor=fc,edgecolor=ec,lw=lw,zorder=0))

# ---------- header
t(6,144.0,"E 4 7   F O R M A L   V A L I D A T I O N   P L A T E",15.5,GOLD,SERIF,"bold")
t(6,141.0,"Machine-checked kernel certificate  ·  Coq 8.18.0 and Lean 4.35.0",11,INK,SERIF,st="italic")
t(6,138.8,"RUB5-C17 descent  ·  Identity/formal/e47  ·  26 October 2026",8.3,DIM,MONO)
rule(137.3)

# ---------- verdict strip
panel(6,127.0,88,9.6)
cells=[("19 / 20","source files compiled",MINT),
       ("0","proofs admitted or sorry",MINT),
       ("30","theorems axiom-audited",GOLD),
       ("1","file deferred (Mathlib)",COPPER)]
for i,(v,k,c) in enumerate(cells):
    x=10+i*22
    t(x,133.2,v,19,c,MONO,"bold")
    t(x,129.1,k,7.6,DIM,SANS)
    if i: ax.plot([x-4,x-4],[128.0,135.6],color=RULE,lw=0.8)

# ---------- certified algebra
t(6,123.0,"I  ·  THE ALGEBRA UNDER CERTIFICATE",9.3,GOLD,SANS,"bold")
rule(122.0)
panel(6,99.5,88,21.0)
F=[r"V  =  V$_2$ $\otimes$ V$_2$ $\otimes$ V$_2$              dim V = 125",
   r"C  =  J$_x^2$ + J$_y^2$ + J$_z^2$              spec C = { 0, 2, 6, 12, 20, 30, 42 }",
   r"m  =  ( 1, 3, 5, 4, 3, 2, 1 )              $\Sigma$ m$_j$(2j+1) = 125",
   r"K  =  (C $-$ 6I)(C $-$ 30I)              E$_{47}$ = ker K,   dim = 25 + 22 = 47",
   r"$\Omega_c$ =  47 / 125  =  0.376  exact in $\mathbb{Q}$"]
for i,s in enumerate(F): t(10,117.8-i*2.9,s,9.6,INK,MONO)
t(10,101.9,r"gap 11664 = 108$^2$   ·   $\Vert$K$^2\Vert$ = 186624 = 432$^2$   ·   $\varepsilon^*$ = 1/99144   ·   $\rho$ = 15/17",
  9.0,MINT,MONO)

# ---------- Coq
t(6,96.0,"II  ·  COQ 8.18.0  —  coqc -q, standard library only",9.3,GOLD,SANS,"bold")
rule(95.0)
t(6,92.8,f"{coq_thms} theorems and lemmas across 10 files.  No Axiom, Parameter, Hypothesis or Admitted.",8.2,DIM,SANS)
y=90.3
panel(6,90.3-len(COQ)*2.85-1.0,88,len(COQ)*2.85+1.0)
for i,(f,n) in enumerate(COQ):
    yy=y-1.8-i*2.85
    t(10,yy,f,9.0,INK,MONO)
    t(66,yy,f"{n:>5d} lines",8.4,FAINT,MONO)
    t(84,yy,"COMPILED",8.6,MINT,MONO,"bold")
    if i: ax.plot([8,92],[yy+1.42,yy+1.42],color=RULE,lw=0.5)

# ---------- Lean
yl=56.8
t(6,yl,"III  ·  LEAN 4.35.0  —  commit eb6cafb7, no Mathlib required",9.3,GOLD,SANS,"bold")
rule(yl-1.0)
t(6,yl-3.6,f"{lean_thms} theorems and lemmas.  No file emitted a sorry warning.",8.2,DIM,SANS)
y2=yl-5.7
panel(6,y2-len(LEAN)*2.85-1.0,88,len(LEAN)*2.85+1.0)
MARK={"ok":("COMPILED",MINT),"ax":("COMPILED  +AX",MINT),"skip":("DEFERRED",COPPER)}
for i,(f,n,s) in enumerate(LEAN):
    yy=y2-1.8-i*2.85
    lab,c=MARK[s]
    t(10,yy,f,9.0,INK if s!="skip" else DIM,MONO)
    t(66,yy,f"{n:>5d} lines",8.4,FAINT,MONO)
    t(80,yy,lab,8.6,c,MONO,"bold")
    if i: ax.plot([8,92],[yy+1.42,yy+1.42],color=RULE,lw=0.5)

# ---------- axiom ledger
ya=17.8
t(6,ya,"IV  ·  AXIOM LEDGER  —  self-reported by #print axioms",9.3,GOLD,SANS,"bold")
rule(ya-1.0)
panel(6,4.5,88,11.3)
rows=[("24 theorems","do not depend on any axioms",MINT),
      ("5 theorems","depend on [propext]",INK),
      ("1 theorem","pr_expanded: [propext, Classical.choice, Quot.sound]",INK)]
for i,(a,b,c) in enumerate(rows):
    t(10,13.6-i*2.6,a,8.8,c,MONO,"bold"); t(27,13.6-i*2.6,b,8.6,DIM,MONO)
t(10,6.0,"All three are standard Lean foundations. No custom axiom is introduced anywhere.",8.0,FAINT,SANS,st="italic")

# ---------- boundary
t(6,1.9,"BOUNDARY  ·  E47ConcreteMatrix.lean (1571 lines, import Mathlib) was not built — no Mathlib cache in this environment.\n"
        "Verified here: compilation and axiom provenance of the finite algebraic layer. Not verified: that layer's physical interpretation.",
  7.3,FAINT,SANS)

fig.savefig("/home/claude/plate/E47_FORMAL_VALIDATION_PLATE.png",facecolor=BG,bbox_inches="tight",pad_inches=0.35)
print("coq_thms",coq_thms,"lean_thms",lean_thms)
print("written")
