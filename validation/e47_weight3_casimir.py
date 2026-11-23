"""Independent stdlib-only integer audit of canonical 125-state weight-3 block."""
from fractions import Fraction
N=125
STATES=[3,7,11,15,27,31,35,51,55,75]
S=[[-2,-4,-4,-2,2,2,4,-1,1,1],[3,4,2,0,-1,5,1,-1,0,3],[-3,-2,0,0,-1,-3,3,1,-3,3],[2,0,0,0,2,-6,6,1,-2,1],[0,2,4,3,2,-4,1,-2,3,3],[0,-3,-3,0,-3,3,-12,0,0,6],[0,2,0,0,2,0,0,2,-3,3],[0,0,-2,-3,0,-6,3,-1,3,3],[0,0,2,0,0,6,0,1,0,3],[0,0,0,2,0,0,6,0,1,1]]
B=[[-22,66,-154,308,-44,88,-154,-44,66,-22],[-66,88,-22,-231,-22,-66,253,88,-187,99],[-66,-22,88,99,88,-66,-187,-22,253,-231],[-22,-44,-44,-22,66,88,66,-154,-154,308],[162,-72,-138,63,126,-30,159,-72,27,-135],[54,42,-24,-45,-24,-10,9,-46,53,21],[18,36,36,18,-30,-40,-30,14,14,84],[-264,-352,-176,0,-176,0,176,176,352,264],[-88,-176,-176,-88,0,0,0,176,176,176],[24,48,48,24,48,64,48,48,48,24]]
VALUES=[12,12,12,12,20,20,20,30,30,42]
def abc(n): return n//25,(n//5)%5,n%5
def z(n): return 6-sum(abc(n))
def up(i,j):
 a,b,c=abc(i);x,y,t=abc(j)
 return (x*(5-x) if a+1==x and b==y and c==t else 0)+(y*(5-y) if a==x and b+1==y and c==t else 0)+(t*(5-t) if a==x and b==y and c+1==t else 0)
def down(i,j):
 a,b,c=abc(i);x,y,t=abc(j)
 return int(a==x+1 and b==y and c==t)+int(a==x and b==y+1 and c==t)+int(a==x and b==y and c==t+1)
def casimir(i,j):
 return sum(down(i,k)*up(k,j) for k in range(N))+(z(i)*(z(i)+1) if i==j else 0)
def mul(A,B):
 return [[sum(A[i][k]*B[k][j] for k in range(len(B))) for j in range(len(B[0]))] for i in range(len(A))]
def charpoly(A):
 n=len(A);Q=[[Fraction(int(i==j)) for j in range(n)] for i in range(n)];coeff=[1]
 for k in range(1,n+1):
  Q=mul(A,Q);tr=sum(Q[i][i] for i in range(n))
  assert tr%k==0
  ck=-tr//k;coeff.append(ck)
  for i in range(n):Q[i][i]+=ck
 return coeff
def main():
 assert [i for i in range(N) if z(i)==3]==STATES
 A=[[casimir(i,j) for j in STATES] for i in STATES]
 assert all(casimir(i,j)==0 and casimir(j,i)==0 for i in STATES for j in range(N) if j not in STATES)
 print('E47_WEIGHT3_INVARIANCE_PASS')
 assert A==[[18,4,0,0,4,0,0,0,0,0],[6,22,6,0,4,4,0,0,0,0],[0,6,22,6,0,4,4,0,0,0],[0,0,4,18,0,0,4,0,0,0],[6,4,0,0,22,4,0,6,0,0],[0,6,6,0,6,24,6,6,6,0],[0,0,4,6,0,4,22,0,6,0],[0,0,0,0,6,4,0,22,4,6],[0,0,0,0,0,4,6,4,22,6],[0,0,0,0,0,0,0,4,4,18]]
 print('E47_WEIGHT3_CONCRETE_ENTRIES_PASS')
 assert mul(A,S)==[[S[i][j]*VALUES[j] for j in range(10)] for i in range(10)]
 assert mul(B,S)==mul(S,B)==[[1320*int(i==j) for j in range(10)] for i in range(10)]
 print('E47_WEIGHT3_DIAGONALIZATION_PASS')
 p=charpoly(A);print('E47_WEIGHT3_CHARPOLY_COEFFICIENTS',p)
 q=[1]
 for root in VALUES:
  t=[0]*(len(q)+1)
  for k,v in enumerate(q):t[k]+=v;t[k+1]-=root*v
  q=t
 assert p==q
 print('E47_WEIGHT3_CHARPOLY_EXACT_PASS', {x:VALUES.count(x) for x in sorted(set(VALUES))})
 A2=mul(A,A);A3=mul(A2,A);A4=mul(A3,A)
 assert all(A4[i][j]-104*A3[i][j]+3804*A2[i][j]-57600*A[i][j]+302400*int(i==j)==0 for i in range(10) for j in range(10))
 print('E47_WEIGHT3_QUARTIC_PASS')
 mutant=[row[:] for row in A];mutant[1][1]+=1
 assert charpoly(mutant)!=p
 print('E47_WEIGHT3_MUTANT_REJECTED')
if __name__=='__main__':main()
