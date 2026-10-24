import numpy as np
sigma=.15; q=np.exp(-2*sigma*sigma); c=(1+q)/2; s=(1-q)/2
M=np.array([[c/4,s/4],[s,c]])
w,V=np.linalg.eig(M); rho=max(w); lam=min(w)
init=np.array([.25,.75]); n=50
p=np.array([np.linalg.matrix_power(M,k)@init for k in range(n+1)])
u=.5+(.25-.5)*q**np.arange(n+1)
print('q',q,'M',M,'eigenvalues',w,'rho',rho,'lambda',lam,'exponent',-np.log(rho),'unprotected_limit',.5)
print('step protected unprotected total')
for k in [0,1,5,10,20,40,50]:print(k,p[k,0],u[k],sum(p[k]))
rng=np.random.default_rng(20261024); N=200000
x=np.full(N,.5);y=np.full(N,np.sqrt(.75));xu=x.copy();yu=y.copy()
for k in range(1,n+1):
 th=rng.normal(0,sigma,N);ct=np.cos(th);st=np.sin(th)
 xx=ct*x-st*y; yy=st*x+ct*y;x=.5*xx;y=yy
 xx=ct*xu-st*yu; yy=st*xu+ct*yu;xu=xx;yu=yy
 if k in [1,5,10,20,40,50]:
  obs=np.mean(x*x);se=np.std(x*x)/np.sqrt(N);ou=np.mean(xu*xu)
  print('MC',k,'pred',p[k,0],'observed',obs,'se',se,'z',(obs-p[k,0])/se,'unprot_pred',u[k],'unprot_MC',ou)
assert np.allclose(M,np.array([[c/4,s/4],[s,c]]))
assert 0<lam<rho<1
assert np.all(p[:,0]>=0)
assert np.allclose(u,.5-.25*q**np.arange(n+1))
print('PASS exact recurrence, spectral bound, unprotected formula')
