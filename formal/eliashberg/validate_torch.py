import torch
torch.set_default_dtype(torch.float64)
lam=torch.tensor(2.7); mu=torch.tensor(0.1)
w=torch.tensor(0.15); kb=torch.tensor(8.617333262e-5)
L1=2.46*(1+3.8*mu)
f1=(1+(lam/L1)**1.5)**(1/3)
tm=w/kb/1.2*torch.exp(-1.04*(1+lam)/(lam-mu*(1+0.62*lam)))
ta=f1*tm
assert abs(ta.item()-356.5785411780889)<1e-8
weight=lam*w/2
assert torch.allclose(2*weight/w,lam)
assert torch.allclose(torch.exp((2/lam)*weight*torch.log(w)/w),w)
assert torch.allclose(torch.sqrt((2/lam)*weight*w),w)
K=torch.tensor([[1.15,.1],[.1,.7]])
D=torch.tensor([[-.03,.01],[.01,.02]])
norm=torch.linalg.matrix_norm(D,ord=2)
shift=abs(torch.linalg.eigvalsh(K+D)[-1]-torch.linalg.eigvalsh(K)[-1])
assert shift<=norm+1e-12
print("PASS Allen-Dynes",ta.item())
print("PASS spectral identities")
print("PASS finite-dimensional Weyl bound",float(shift),float(norm))
