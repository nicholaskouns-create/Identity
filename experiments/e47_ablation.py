"""Controlled synthetic link-prediction ablation; NOT a TGBL-wiki/Cora run."""
import numpy as np
from scipy.special import expit
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score
from sklearn.model_selection import train_test_split

m=np.array([2,1,0,-1,-2],float)
Jp=np.zeros((5,5),complex)
for i in range(4):
    s=m[i+1];Jp[i,i+1]=np.sqrt(6-s*(s+1))
Jx=(Jp+Jp.conj().T)/2; Jy=(Jp-Jp.conj().T)/(2j);Jz=np.diag(m)
I=np.eye(5); eye=np.eye(125)
def tot(a):return np.kron(np.kron(a,I),I)+np.kron(np.kron(I,a),I)+np.kron(np.kron(I,I),a)
X,Y,Z=[tot(a) for a in (Jx,Jy,Jz)]
C=X@X+Y@Y+Z@Z
K=(C-6*eye)@(C-30*eye)
w,v=np.linalg.eigh(K)
Q=v[:,np.abs(w)<1e-7]
P=Q@Q.conj().T
assert Q.shape==(125,47)
assert np.linalg.norm(P@P-P)<1e-10
assert np.max(np.abs(P.imag))<1e-10
P=P.real
A=np.eye(125)[:,:64]
B=A.T@P@A
b,vec=np.linalg.eigh(B)
Q24=vec[:,-24:]
Pd=Q24@Q24.T
print('E47 rank',np.linalg.matrix_rank(P,tol=1e-8),'P residual',np.linalg.norm(P@P-P))
print('64-d compressed spectrum leading',np.round(b[-5:],5),'rank24 projector residual',np.linalg.norm(Pd@Pd-Pd))

results={k:[] for k in ['baseline64','random24','E47derived24','E47full125']}
for seed in range(8):
    rng=np.random.default_rng(seed+100)
    n=220
    # True graph-generating latent signal occupies a fixed 12-dimensional E47 subspace.
    H= rng.normal(size=(n,12))@Q[:,:12].real.T
    H+=0.35*rng.normal(size=(n,125))
    # Label-generating process uses a low-rank E47 signal, not the noisy 64-dimensional features.
    S=H@Q[:,:12].real
    pair=np.array([(i,j) for i in range(n) for j in range(i+1,n)],dtype=int)
    logits=np.sum(S[pair[:,0]]*S[pair[:,1]],axis=1)/np.sqrt(12)
    labels=rng.binomial(1,expit(logits))
    tr,te=train_test_split(np.arange(len(labels)),test_size=0.35,random_state=seed,stratify=labels)
    R,_=np.linalg.qr(rng.normal(size=(64,24)))
    F64=H@A
    feats={'baseline64':F64,'random24':F64@(R@R.T),'E47derived24':F64@Pd,'E47full125':H@P}
    for key,F in feats.items():
        # Pairwise Hadamard feature; identical estimator and split across arms.
        V=F[pair[:,0]]*F[pair[:,1]]
        model=LogisticRegression(max_iter=400, C=1.0,solver='liblinear')
        model.fit(V[tr],labels[tr]);pred=model.predict_proba(V[te])[:,1]
        results[key].append(roc_auc_score(labels[te],pred))
    print('seed',seed,*(f'{key}:{results[key][-1]:.4f}' for key in results),flush=True)
print('\nMEAN ± SAMPLE SD (8 independent synthetic graph seeds)')
for key,x in results.items():print(f'{key:17s} {np.mean(x):.5f} ± {np.std(x,ddof=1):.5f} delta_baseline={np.mean(x)-np.mean(results["baseline64"]):+.5f}')
import json
with open('/mnt/data/e47_ablation_results.json','w') as f:json.dump({'experiment':'synthetic graph link prediction; E47-aligned ground truth','seeds':8,'auc_by_seed':results,'means':{k:float(np.mean(v)) for k,v in results.items()}},f,indent=2)
