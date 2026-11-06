"""Regression tests for the synthetic benchmark's ranking metric."""
import importlib.util
from pathlib import Path

import numpy as np
import pytest

spec = importlib.util.spec_from_file_location(
    'tqgnn_benchmark_model',
    Path(__file__).resolve().parents[1] / 'simulation/e47_tqgnn/model.py',
)
model = importlib.util.module_from_spec(spec)
spec.loader.exec_module(model)


def pairwise_auc(scores, labels):
    positive = scores[labels == 1]
    negative = scores[labels == 0]
    differences = positive[:, None] - negative
    return np.mean((differences > 0) + 0.5 * (differences == 0))


def test_ties_receive_half_credit_and_ignore_input_order():
    assert model.roc_auc([0, 0, 0, 0], [1, 1, 0, 0]) == 0.5
    scores = np.array([0, 1, 1, 2, 2, 2, 3, 3])
    labels = np.array([0, 0, 1, 1, 0, 1, 0, 1])
    expected = pairwise_auc(scores, labels)
    for seed in range(10):
        p = np.random.default_rng(seed).permutation(len(scores))
        assert model.roc_auc(scores[p], labels[p]) == expected


def test_auc_perfect_reversed_and_invalid_inputs():
    assert model.roc_auc([1, 2, 3, 4], [0, 0, 1, 1]) == 1
    assert model.roc_auc([1, 2, 3, 4], [1, 1, 0, 0]) == 0
    for scores, labels in [([1], [1]), ([1, float('nan')], [0, 1]),
                           ([1, 2], [0, 2]), ([1, 2], [0])]:
        with pytest.raises(ValueError):
            model.roc_auc(scores, labels)
