"""Executed tiny causal language-model forward pass. Random weights, no training.
An E47 residual adapter protects its encoded intermediate activations against
whole-block code/syndrome swaps. It does not protect other transformer operations.
"""
import numpy as np
from pathlib import Path
import json
from e47_qec import carrier,E47WeightAdapter
rng=np.random.default_rng(4701);D=64;vocab=32;B=3;length=8;blocks=2
b=carrier();embedding=rng.normal(size=(vocab,D))*.1
position=rng.normal(size=(length,D))*.1
tokens=rng.integers(vocab,size=(B,length));h=embedding[tokens]+position
Wq,Wk,Wv,Wo=[rng.normal(size=(D,D))/np.sqrt(D) for _ in range(4)]
q,k,v=h@Wq,h@Wk,h@Wv
scores=q@k.transpose(0,2,1)/np.sqrt(D)
scores=np.where(np.triu(np.ones((length,length),bool),1),-np.inf,scores)
a=np.exp(scores-scores.max(axis=-1,keepdims=True));a/=a.sum(axis=-1,keepdims=True)
h=h+(a@v)@Wo
A=rng.normal(size=(blocks,47,D))/np.sqrt(D);Bout=rng.normal(size=(D,blocks,47))*.03
adapter=E47WeightAdapter(A,Bout,b);head=rng.normal(size=(D,vocab))/np.sqrt(D)
clean=adapter.forward(h)@head;mask=rng.random((B,length,blocks))<.5
corrected=adapter.forward(h,mask)@head
z=np.einsum('...d,brd->...br',h,A);x=np.einsum('...br,ir->...bi',z,b['Q']);x=np.where(mask[...,None],x@b['U'].T,x)
bad=(h+np.einsum('...br,dbr->...d',x@b['Q'],Bout))@head
err=float(np.max(abs(clean-corrected)));assert err<1e-10
# Check output remains causal: future tokens cannot affect earlier logits here.
assert np.all(a[:,np.arange(length)[:,None]<np.arange(length)[None,:]]==0)
result={'architecture':'single-head causal self-attention + E47 adapter + vocabulary head','weights':'random untrained','vocabulary':vocab,'hidden_width':D,'tokens':int(tokens.size),'encoded_blocks':int(mask.size),'swapped_blocks':int(mask.sum()),'corrected_max_logit_error':err,'uncorrected_max_logit_error':float(np.max(abs(clean-bad))),'corrected_argmax_agreement':float(np.mean(clean.argmax(-1)==corrected.argmax(-1))),'seed':4701,'pass':True}
Path(__file__).with_name('llm_results.json').write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
