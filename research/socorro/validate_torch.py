import torch
D=torch.float64
I=torch.eye(2,dtype=D)
R=torch.diag(torch.tensor([-1.,1.],dtype=D))
Pp=(I+R)/2; Pm=(I-R)/2
G=I-(I-R)/4
T=torch.diag(torch.tensor([3.,7.],dtype=D))
checks={
'R^2=I':torch.equal(R@R,I),
'P+ idempotent':torch.equal(Pp@Pp,Pp),
'P- idempotent':torch.equal(Pm@Pm,Pm),
'orthogonality':torch.equal(Pp@Pm,torch.zeros_like(I)),
'completeness':torch.equal(Pp+Pm,I),
'commutation':torch.equal(T@R,R@T),
'axis invariance':torch.equal(T@torch.tensor([0.,2.],dtype=D),torch.tensor([0.,14.],dtype=D)),
'Gamma^40 residual':torch.equal(torch.linalg.matrix_power(G,40)-Pp,torch.diag(torch.tensor([2.**-40,0.],dtype=D))),
'Lie centralizer commutator':torch.equal(T@R-R@T,torch.zeros_like(I))}
for k,v in checks.items():print(('PASS' if v else 'FAIL'),k)
assert all(checks.values())
print('torch',torch.__version__,'all',len(checks),'passed')
