# E47 image representation experiment

Two independent instruments:

1. [Live browser lab](../../site/e47-image-lab/index.html) builds a spin-2 tensor Casimir on ℝ¹²⁵, selects eigenvalues {6, 30}, and projects a hand-engineered 125D image feature vector into the exact rank-47 invariant sector. It reports energy retention, projector idempotence residual and direct RGB reconstruction error. No training occurs in the browser.
2. [Trainable benchmark](train_e47_image.py) trains a matched 125-dimensional autoencoder in three conditions: full 125D latent, fixed E47 projected latent, and seeded random rank-47 projected latent. Same architecture, initialization seed, data split, and training epochs. It writes validation RMSE and measured latent retention to JSON.

## Execution

Install Python dependencies: `pip install numpy pillow torch`

Smoke test with procedurally generated images:

```sh
python research/e47_image/train_e47_image.py --synthetic --max-images 160 --epochs 1 --output /tmp/e47-smoke.json
```

Train on **locally obtained, appropriately licensed** face photographs or other image data:

```sh
python research/e47_image/train_e47_image.py --images /path/to/images --max-images 2000 --epochs 10 --output e47-faces.json
```

CelebA-HQ is not included, and this repository does not download it. The deprecated TensorFlow Datasets lazy import `CelebAHq = lazy_builder_import.LazyBuilderImport('celeb_a_hq')` only locates a dataset builder.

## Evidence boundary

- **Exact finite-dimensional algebra**: spectrum {0,2,6,12,20,30,42}, multiplicities {1,9,25,28,27,22,13}, E47 rank 25+22=47, P²=P up to floating-point roundoff.
- **Direct browser image experiment**: fixed 25 spatial points × five hand-selected channels; reconstructs by reading projected RGB coordinates (not by learned decoding).
- **Training hypothesis to be evaluated**: a learned encoder and decoder may retain useful image detail when passing through the E47 space. Neither the dimension ratio 47/125 nor the measured energy retention alone establishes reconstruction quality or generalization.
- **Controls**: random-rank-47 vs E47; full 125D vs E47. Real-data benchmark results are not claimed until training is executed.

No alteration of other Mathematical City engines is required.
