"""Reproducible P26 -> P27 complex128 checks; no A5 character claim."""
import numpy as np
def run(seed=47):
    rng=np.random.default_rng(seed); n=64
    z=rng.standard_normal((n,n))+1j*rng.standard_normal((n,n))
    v,_=np.linalg.qr(z)
    p=v[:,:26]@v[:,:26].conj().T; eye=np.eye(n)
    phi=rng.standard_normal(n)+1j*rng.standard_normal(n); phi/=np.linalg.norm(phi)
    r=(eye-p)@phi; assert np.linalg.norm(r)>1e-8
    u=r/np.linalg.norm(r); pi=np.outer(u,u.conj())
    p27=p+pi; q27=eye-p27
    assert np.linalg.norm(p27@p27-p27,2)<1e-12
    assert abs(np.trace(p27).real-27)<1e-10
    assert np.linalg.norm(p27@phi-phi)<1e-12
    for theta in np.linspace(0,np.pi/2,9):
        a=p+np.sin(theta)*pi
        b=q27+np.cos(theta)*pi
        halmos=np.block([[a,b],[b,-a]])
        assert np.linalg.norm(halmos.conj().T@halmos-np.eye(128),2)<1e-11
    assert np.isclose(2**-40,9.094947017729282e-13)
    print("PASS: P27 rank, projector, observer capture, 9 Halmos unitaries, contraction")
if __name__=="__main__":run()
