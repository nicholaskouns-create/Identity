import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

PAPER="#eef3f6"; INK="#27394a"; MUTE="#7b8c99"; SOFT="#aebfca"
KEEP="#2f8f6b"; MISS="#d9654a"
SANS="DejaVu Sans"; MONO="DejaVu Sans Mono"; SERIF="DejaVu Serif"

fig=plt.figure(figsize=(16,10),dpi=170); fig.patch.set_facecolor(PAPER)
ax=fig.add_axes([0,0,1,1]); ax.set_xlim(0,160); ax.set_ylim(0,100); ax.axis("off")
ax.set_facecolor(PAPER)

def T(x,y,s,sz=11,c=INK,f=SANS,w="normal",ha="left",st="normal"):
    ax.text(x,y,s,fontsize=sz,color=c,family=f,weight=w,ha=ha,va="center",
            style=st,zorder=5,linespacing=1.7)

T(11,94,"E 4 7   ·   2 6   O C T O B E R   2 0 2 6",9.5,SOFT,MONO,"bold")

claim=["The verification apparatus located a missing",
       "four-dimensional algebraic block, confirmed it",
       "independently in two proof assistants with no axioms,",
       "restored the protected qubit it carries to the statement,",
       "and published the correction with the",
       "formalization boundary intact."]
for i,l in enumerate(claim):
    T(11, 85.5-i*5.9, l, 19, INK, SERIF)

ax.plot([11,149],[46.5,46.5],color=SOFT,lw=0.8)
T(11,43.0,"every clause has a file behind it",9.5,SOFT,SANS,st="italic")

blocks=[
 (11, 36.0, KEEP, "a missing four-dimensional block",
  "commutant_excess : commutantDim − 25 = 4",
  "Identity/formal/e47/E47Commutant.{lean,v}"),
 (84, 36.0, KEEP, "confirmed in two proof assistants, no axioms",
  "17 of 17 — “does not depend on any axioms”",
  "Lean 4.35.0 · Coq 8.18.0 · compiled 26 Oct 2026"),
 (11, 21.0, MISS, "the protected qubit, restored to the statement",
  "dropped_block_is_a_qubit : mult 5 = 2",
  "E47-Kartekeya/certificates/RUB5-C17-REV-B.md"),
 (84, 21.0, MUTE, "the boundary, left intact",
  "“WHAT IS NOT FORMALIZED” — in both file headers",
  "E47ConcreteMatrix.lean · builds in CI · native_decide"),
]
for x,y,col,head,stmt,src in blocks:
    ax.plot([x-2.2,x-2.2],[y-8.4,y+2.2],color=col,lw=2.2)
    T(x,y+0.6,head,12.5,INK,SANS,"bold")
    T(x,y-3.6,stmt,10.5,col,MONO)
    T(x,y-7.4,src,9.5,SOFT,MONO)

ax.plot([11,149],[10.5,10.5],color=SOFT,lw=0.8)
T(11,7.2,"Unchanged, because they were already exact:   Ωᴄ = 47/125   ·   gap 11664 = 108²   ·   ‖K²‖ = 186624 = 432²   "
         "·   ε* = 1/99144   ·   ρ = 15/17, equioscillating",10,MUTE,SANS)
T(11,3.4,"Four of the six original certificates needed no correction. Two did.",9.5,SOFT,SANS,st="italic")

fig.savefig("/home/claude/plate/E47_CLAIM_PLATE.png",facecolor=PAPER,bbox_inches="tight",pad_inches=0.35)
print("ok")
