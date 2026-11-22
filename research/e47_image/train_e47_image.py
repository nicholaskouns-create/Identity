#!/usr/bin/env python3
"""Train matched 125D image autoencoders: full, E47, random-rank-47.

Requires: numpy, pillow, torch. Images must be locally supplied; no dataset
is bundled or downloaded. Example:
  python train_e47_image.py --images /path/to/licensed/images --epochs 10
  python train_e47_image.py --synthetic --epochs 1 --max-images 160

Records validation RMSE, measured retained energy, and projector defects.
No inference of trained reconstruction quality from rank or energy alone.
"""
import argparse
import json
import math
from pathlib import Path
import random

import numpy as np
from PIL import Image
import torch
from torch import nn
from torch.utils.data import Dataset, DataLoader


SPIN2 = np.arange(-2, 3, dtype=np.float64)
COEFF = np.array([1, math.sqrt(6)/2, math.sqrt(6)/2, 1])
EIGENVALUES = (0, 2, 6, 12, 20, 30, 42)
EXPECTED_MULTIPLICITIES = (1, 9, 25, 28, 27, 22, 13)
SIDE = 32


def casimir_and_projector():
    """Construct spin-2 tensor Casimir, then select eigenvalues 6 and 30."""
    plus = np.zeros((5, 5))
    for i, x in enumerate(COEFF):
        plus[i+1, i] = x
    jx = plus + plus.T
    a = plus - plus.T  # Jy = -i*A
    jz = np.diag(SPIN2)
    ident = np.eye(5)

    def total(g):
        return sum(np.kron(np.kron(g if k == 0 else ident,
                                  g if k == 1 else ident),
                                  g if k == 2 else ident)
                   for k in range(3))

    tx, ta, tz = total(jx), total(a), total(jz)
    c = tx @ tx - ta @ ta + tz @ tz
    eigen, vec = np.linalg.eigh(c)
    counts = tuple(int(np.count_nonzero(np.isclose(eigen, s, atol=1e-7)))
                   for s in EIGENVALUES)
    assert counts == EXPECTED_MULTIPLICITIES, counts
    mask = np.isclose(eigen, 6, atol=1e-7) | np.isclose(eigen, 30, atol=1e-7)
    basis = vec[:, mask]
    p = basis @ basis.T
    assert basis.shape == (125, 47)
    assert np.linalg.norm(p @ p - p, ord=2) < 1e-10
    return c, p, counts


class Images(Dataset):
    def __init__(self, folder=None, synthetic=False, limit=2000, seed=47):
        self.synthetic = synthetic
        self.seed = seed
        self.paths = []
        if not synthetic:
            self.paths = sorted(p for p in Path(folder).rglob("*")
                                if p.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp"))
            self.paths = self.paths[:limit]
            if len(self.paths) < 2:
                raise ValueError("Need at least two local image files")
        else:
            self.length = max(2, limit)

    def __len__(self):
        return self.length if self.synthetic else len(self.paths)

    def __getitem__(self, idx):
        if self.synthetic:
            rng = np.random.default_rng(self.seed + idx)
            y, x = np.mgrid[0:SIDE, 0:SIDE].astype(np.float32)
            x /= SIDE-1
            y /= SIDE-1
            phase = rng.uniform(0, 2*np.pi, 3)
            rgb = np.stack([.5 + .32*np.sin(2*np.pi*(x*(j+1)/3
                             + y*(3-j)/5) + phase[j]) for j in range(3)])
            return torch.tensor(np.clip(rgb, 0, 1).reshape(-1), dtype=torch.float32)
        with Image.open(self.paths[idx]) as im:
            rgb = im.convert("RGB").resize((SIDE, SIDE), Image.Resampling.BILINEAR)
            arr = np.asarray(rgb, dtype=np.float32).transpose(2, 0, 1)/255
        return torch.from_numpy(arr.copy().reshape(-1))


class Autoencoder(nn.Module):
    def __init__(self, projector):
        super().__init__()
        self.encoder = nn.Sequential(nn.Linear(3*SIDE*SIDE, 256),
                                     nn.GELU(), nn.Linear(256, 125))
        self.decoder = nn.Sequential(nn.Linear(125, 256), nn.GELU(),
                                     nn.Linear(256, 3*SIDE*SIDE), nn.Sigmoid())
        self.register_buffer("p", projector)

    def forward(self, x):
        z = self.encoder(x)
        zp = z @ self.p
        return self.decoder(zp), z, zp


def train(name, projector, train_loader, val_loader, epochs, lr, seed, device):
    torch.manual_seed(seed)
    model = Autoencoder(projector).to(device)
    opt = torch.optim.AdamW(model.parameters(), lr=lr)
    history = []
    for epoch in range(epochs):
        model.train()
        for x in train_loader:
            x = x.to(device)
            prediction, _, _ = model(x)
            loss = (prediction-x).square().mean()
            opt.zero_grad()
            loss.backward()
            opt.step()
        model.eval()
        total, energy, denom, n = 0., 0., 0., 0
        with torch.no_grad():
            for x in val_loader:
                x = x.to(device)
                prediction, z, zp = model(x)
                total += (prediction-x).square().sum().item()
                energy += zp.square().sum().item()
                denom += z.square().sum().item()
                n += x.numel()
        row = {"epoch": epoch+1, "val_rmse": math.sqrt(total/n),
               "retained_energy_fraction": energy/max(denom, 1e-30)}
        history.append(row)
        print(name, row, flush=True)
    return history


def main():
    ap = argparse.ArgumentParser()
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--images", type=Path)
    group.add_argument("--synthetic", action="store_true")
    ap.add_argument("--epochs", type=int, default=5)
    ap.add_argument("--max-images", type=int, default=2000)
    ap.add_argument("--batch-size", type=int, default=32)
    ap.add_argument("--lr", type=float, default=1e-3)
    ap.add_argument("--seed", type=int, default=47)
    ap.add_argument("--output", type=Path, default=Path("e47_image_results.json"))
    args = ap.parse_args()
    if args.epochs < 1:
        ap.error("--epochs must be positive")
    random.seed(args.seed)
    np.random.seed(args.seed)
    torch.manual_seed(args.seed)
    torch.set_num_threads(min(torch.get_num_threads(), 4))
    dataset = Images(args.images, args.synthetic, args.max_images, args.seed)
    nval = max(1, int(len(dataset)*.2))
    ntrain = len(dataset)-nval
    if ntrain < 1:
        ap.error("Need more samples")
    train_set, val_set = torch.utils.data.random_split(
        dataset, [ntrain, nval], generator=torch.Generator().manual_seed(args.seed))
    train_loader = DataLoader(train_set, batch_size=args.batch_size, shuffle=True,
                              generator=torch.Generator().manual_seed(args.seed))
    val_loader = DataLoader(val_set, batch_size=args.batch_size)
    c, e47, counts = casimir_and_projector()
    rng = np.random.default_rng(args.seed)
    q, _ = np.linalg.qr(rng.standard_normal((125, 47)))
    random_p = q @ q.T
    device = "cuda" if torch.cuda.is_available() else "cpu"
    result = {
        "protocol": "same encoder/decoder architecture and initialization seed per condition",
        "data": "procedural synthetic" if args.synthetic else str(args.images),
        "dataset_size": len(dataset), "train_size": ntrain, "validation_size": nval,
        "seed": args.seed, "epochs": args.epochs,
        "casimir_multiplicities": counts,
        "e47_rank": 47,
        "idempotence_defect": float(np.linalg.norm(e47@e47-e47, ord=2)),
        "conditions": {}
    }
    for name, p in [("full_125", np.eye(125)), ("e47_47", e47),
                    ("random_47", random_p)]:
        train_loader = DataLoader(train_set, batch_size=args.batch_size,
            shuffle=True, generator=torch.Generator().manual_seed(args.seed))
        result["conditions"][name] = train(
            name, torch.tensor(p, dtype=torch.float32),
            train_loader, val_loader, args.epochs, args.lr, args.seed, device)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+"\n")
    print("Wrote", args.output)


if __name__ == "__main__":
    main()
