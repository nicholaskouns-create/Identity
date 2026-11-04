"""P27 PyTorch complex128 independent validation."""
import torch
torch.set_default_dtype(torch.float64)
def run(seed=42,d=64):
 torch.manual_seed(seed); dt=torch.complex128; I=torch.eye(d,dtype=dt)
 V,_=torch.linalg.qr(torch.randn(d,d,dtype=dt))
 P=V[:,:26]@V[:,:26].mH
 phi=torch.randn(d,1,dtype=dt);phi/=torch.linalg.vector_norm(phi)
 r=(I-P)@phi;v=r/torch.linalg.vector_norm(r)
 Pi=v@v.mH; P27=P+Pi; Q27=I-P27
 assert torch.linalg.matrix_norm(P27@P27-P27).item()<1e-11
 assert abs(torch.trace(P27).real.item()-27)<1e-10
 A=torch.randn(d,d,dtype=dt); H=P@((A+A.mH)/2)@P
 H27=H+0.85*phi@phi.mH
 Uh=torch.linalg.matrix_exp(-1j*H27)
 phase=torch.exp(1j*torch.tensor(1.5708,dtype=dt))
 Ug=(I+(phase-1)*(phi@phi.mH))@torch.linalg.matrix_exp(-1j*H)
 for U in [Uh,Ug]:
  assert torch.linalg.matrix_norm(U.mH@U-I).item()<1e-10
  assert torch.linalg.matrix_norm(U@P27-P27@U).item()<1e-10
 for theta in torch.linspace(0,torch.pi/2,5):
  X=P+torch.sin(theta)*Pi;Y=Q27+torch.cos(theta)*Pi
  U=torch.cat([torch.cat([X,Y],1),torch.cat([Y,-X],1)],0)
  assert torch.linalg.matrix_norm(U.mH@U-torch.eye(128,dtype=dt)).item()<1e-10
 print("PASS PyTorch P27 Hamiltonian, phase gate, Halmos")
if __name__=="__main__":run()
