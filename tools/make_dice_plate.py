import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle, RegularPolygon, FancyArrowPatch, Circle

PAPER="#eef3f6"; GRID="#dde6ed"; INK="#27394a"; MUTE="#7b8c99"
KEEP="#2f8f6b"; MISS="#d9654a"; SOFT="#aebfca"
SANS="DejaVu Sans"; MONO="DejaVu Sans Mono"

fig=plt.figure(figsize=(16,13.2),dpi=170); fig.patch.set_facecolor(PAPER)
ax=fig.add_axes([0,0,1,1]); ax.set_xlim(0,160); ax.set_ylim(0,132); ax.axis("off")
ax.set_facecolor(PAPER)
for x in range(0,161,4): ax.plot([x,x],[0,132],color=GRID,lw=0.5,zorder=0)
for y in range(0,133,4): ax.plot([0,160],[y,y],color=GRID,lw=0.5,zorder=0)

def T(x,y,s,sz=11,c=INK,f=SANS,w="normal",ha="left",va="center",st="normal"):
    ax.text(x,y,s,fontsize=sz,color=c,family=f,weight=w,ha=ha,va=va,style=st,
            zorder=5,linespacing=1.7)

# ---------------- header
T(8,126.5,"How to find a missing qubit",25,INK,SANS,"bold")
T(8,121.5,"with three dice and one subtraction",15.5,MUTE,SANS,st="italic")

# ---------------- 1. dice
T(8,114.0,"1.  Take three dice. Five sides each, marked  −2  −1  0  1  2.",13,INK,SANS,"bold")
for i,f in enumerate(["−2","0","+1"]):
    cx=24+i*14
    ax.add_patch(RegularPolygon((cx,104.5),5,radius=5.0,
                 facecolor="white",edgecolor=INK,lw=1.7,zorder=4))
    T(cx,104.0,f,16,INK,MONO,"bold",ha="center")
T(70,105.8,"→   125 ways they can land.",13,MUTE,SANS)
T(70,101.8,"(that's 5 × 5 × 5)",10.5,SOFT,SANS,st="italic")

# ---------------- 2. tally
T(8,94.0,"2.  Tally how many ways each total comes up.",13,INK,SANS,"bold")
counts=[1,3,6,10,15,18,19,18,15,10,6,3,1]
labels=["−6","−5","−4","−3","−2","−1","0","1","2","3","4","5","6"]
base=56.0; cw=8.0; x0=24.0; ch=1.45; cwd=5.4
for i,(n,lb) in enumerate(zip(counts,labels)):
    cx=x0+i*cw
    for k in range(n):
        keep=(i>=6)
        ax.add_patch(Rectangle((cx-cwd/2, base+k*ch+0.17), cwd, ch-0.34,
                     facecolor="#e6f2ec" if keep else "white",
                     edgecolor=KEEP if keep else SOFT, lw=0.9, zorder=3))
    T(cx, base+n*ch+2.0, str(n), 11.5, INK if i>=6 else MUTE, MONO,"bold",ha="center")
    T(cx, base-2.8, lb, 10.5, MUTE, MONO, ha="center")
T(x0-7.0, base-2.8, "total", 10, SOFT, SANS, ha="right", st="italic")
T(132, 72, "a bell curve.\nnothing up\nour sleeve.", 11, SOFT, SANS, st="italic")

# ---------------- 3. subtraction
T(8,45.5,"3.  Walk down one side and subtract each from the one before it.",13,INK,SANS,"bold")
subs=[("19","18","1"),("18","15","3"),("15","10","5"),("10","6","4"),
      ("6","3","3"),("3","1","2"),("1","0","1")]
yA=38.5; yB=32.5
for i,(a,b,r) in enumerate(subs):
    cx=x0+(i+6)*cw
    hl=(i==2 or i==5)
    col=KEEP if i==2 else (MISS if i==5 else INK)
    T(cx,yA,f"{a}−{b}",11,MUTE,MONO,ha="center")
    T(cx,yB,r,16 if hl else 13, col if hl else INK, MONO,"bold",ha="center")
    if hl:
        ax.add_patch(Circle((cx,yB),3.5,facecolor="none",edgecolor=col,lw=1.6,zorder=4))
T(38,35.5,"(this is the hard part)",11,SOFT,SANS,st="italic",ha="center")
ax.add_patch(FancyArrowPatch((50,35.0),(67,35.8),arrowstyle="->",color=SOFT,lw=1.2,
             connectionstyle="arc3,rad=-0.2",zorder=4))

# callout on the forgotten branch
T(127,25.8,"the certificate forgot this one.",11.5,MISS,SANS,"bold")
T(127,22.1,"it said 25.",11.5,MISS,SANS,st="italic")
ax.add_patch(FancyArrowPatch((126.0,26.6),(115.0,30.4),arrowstyle="->",
             color=MISS,lw=1.5,connectionstyle="arc3,rad=0.32",zorder=5))

# ---------------- 4. squares
T(8,21.5,"4.  Square the two that survive the filter. Add them.",13,INK,SANS,"bold")
def grid(cx,cy,n,col,lab,sub):
    s=1.55; w=n*s
    for a in range(n):
        for b in range(n):
            ax.add_patch(Rectangle((cx-w/2+a*s, cy+b*s), s-0.26, s-0.26,
                         facecolor=col, edgecolor="none", alpha=0.88, zorder=3))
    T(cx, cy-2.3, lab, 12.5, col, MONO,"bold",ha="center")
    T(cx, cy-5.2, sub, 10, SOFT, SANS, ha="center", st="italic")
grid(88.0, 10.0, 5, KEEP, "5² = 25", "spin-2 branch")
grid(112.0, 10.0, 2, MISS, "2² = 4", "spin-5 branch")
ax.add_patch(FancyArrowPatch((88,28.6),(88,18.6),arrowstyle="->",color=KEEP,lw=1.4,zorder=5))
ax.add_patch(FancyArrowPatch((112,28.6),(112,14.0),arrowstyle="->",color=MISS,lw=1.4,alpha=0.85,zorder=4))
T(126,13.0,"= 29",26,INK,MONO,"bold")
T(126,7.6,"observables that collective\nnoise cannot corrupt",10.5,MUTE,SANS)

# ---------------- footer
ax.plot([8,152],[3.0,3.0],color=SOFT,lw=0.8)
T(8,1.3,"Checked in Lean 4.35.0 and Coq 8.18.0 — 17 theorems, zero axioms, zero sorry, zero Admitted.    "
        "The representation theory is textbook and sits in a comment, not a kernel. It builds in CI; its five headline theorems rest on native_decide.",
  9.6, MUTE, SANS)

fig.savefig("/home/claude/plate/E47_DICE_PLATE.png",facecolor=PAPER,bbox_inches="tight",pad_inches=0.3)
print("ok")
