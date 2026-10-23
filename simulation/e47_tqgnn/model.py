"""Temporal graph net whose 47-dimensional state is rotated by the E47 clock."""
import numpy as np


def sigmoid(x):
    return 1 / (1 + np.exp(-np.clip(x, -30, 30)))


def init_params(width, rng):
    params = {}
    for name in ('Wz', 'Wr', 'Wh', 'Uz', 'Ur', 'Uh'):
        params[name] = rng.normal(0, 0.05, (width, width))
    for name in ('bz', 'br', 'bh'):
        params[name] = np.zeros(width)
    return params


def gru(x, h, params):
    z = sigmoid(x @ params['Wz'] + h @ params['Uz'] + params['bz'])
    r = sigmoid(x @ params['Wr'] + h @ params['Ur'] + params['br'])
    reset = r * h
    candidate = np.tanh(x @ params['Wh'] + reset @ params['Uh'] + params['bh'])
    nxt = (1 - z) * h + z * candidate
    return nxt, (x, h, z, r, reset, candidate)


def gru_backward(upstream, cache, params):
    x, h, z, r, reset, candidate = cache
    d_candidate = upstream * z
    d_h = upstream * (1 - z)
    d_z = upstream * (candidate - h)
    d_candidate_pre = d_candidate * (1 - candidate ** 2)
    grads = {
        'Wh': x.T @ d_candidate_pre,
        'Uh': reset.T @ d_candidate_pre,
        'bh': d_candidate_pre.sum(axis=0),
    }
    d_reset = d_candidate_pre @ params['Uh'].T
    d_x = d_candidate_pre @ params['Wh'].T
    d_r = d_reset * h
    d_h += d_reset * r
    d_z_pre = d_z * z * (1 - z)
    d_r_pre = d_r * r * (1 - r)
    grads.update({
        'Wz': x.T @ d_z_pre,
        'Uz': h.T @ d_z_pre,
        'bz': d_z_pre.sum(axis=0),
        'Wr': x.T @ d_r_pre,
        'Ur': h.T @ d_r_pre,
        'br': d_r_pre.sum(axis=0),
    })
    d_x += d_z_pre @ params['Wz'].T + d_r_pre @ params['Wr'].T
    d_h += d_z_pre @ params['Uz'].T + d_r_pre @ params['Ur'].T
    return d_x, d_h, grads


def check_gru_gradient():
    rng = np.random.default_rng(0)
    width = 2
    params = init_params(width, rng)
    x = rng.normal(size=(1, width))
    h = rng.normal(size=(1, width))
    nxt, cache = gru(x, h, params)
    upstream = 2 * nxt
    _, _, grads = gru_backward(upstream, cache, params)
    step = 1e-6
    for name, value in params.items():
        numeric = np.zeros_like(value)
        for index in np.ndindex(value.shape):
            original = value[index]
            value[index] = original + step
            plus, _ = gru(x, h, params)
            value[index] = original - step
            minus, _ = gru(x, h, params)
            value[index] = original
            numeric[index] = (np.sum(plus ** 2) - np.sum(minus ** 2)) / (2 * step)
        if np.max(np.abs(numeric - grads[name])) > 1e-5:
            raise AssertionError(name)
    return True


def make_graph(nodes, steps, rng):
    edges = []
    for _ in range(steps):
        step = []
        for source in range(nodes):
            targets = [n for n in range(nodes) if n != source]
            chosen = rng.choice(targets, size=3, replace=False)
            step.extend((source, int(target)) for target in chosen)
        edges.append(step)
    return edges


def aggregate(state, edges, shift):
    clocked = np.roll(state, shift, axis=1) if shift else state
    message = np.zeros_like(state)
    for source, target in edges:
        message[target] += clocked[source]
    return message


def scores_for(state, pairs):
    return np.array([np.dot(state[i], state[j]) for i, j in pairs])


def roc_auc(scores, labels):
    labels = np.asarray(labels)
    order = np.argsort(scores, kind='mergesort')
    ranks = np.empty(len(scores))
    ranks[order] = np.arange(1, len(scores) + 1)
    positive = labels == 1
    n_pos = int(positive.sum())
    n_neg = len(labels) - n_pos
    if n_pos == 0 or n_neg == 0:
        raise AssertionError('auc needs both classes')
    return float((ranks[positive].sum() - n_pos * (n_pos + 1) / 2) / (n_pos * n_neg))


def _pairs(edges, nodes, rng):
    positive = [(target, source) for source, target in edges]
    negative = []
    occupied = set(positive)
    while len(negative) < len(positive):
        i, j = int(rng.integers(nodes)), int(rng.integers(nodes))
        if i != j and (i, j) not in occupied:
            negative.append((i, j))
            occupied.add((i, j))
    pairs = positive + negative
    labels = np.array([1] * len(positive) + [0] * len(negative))
    return pairs, labels


def train_and_score(edges, use_clock, seed):
    nodes, width, steps = 16, 47, len(edges)
    rng = np.random.default_rng(seed)
    params = init_params(width, rng)
    moment = {k: np.zeros_like(v) for k, v in params.items()}
    second = {k: np.zeros_like(v) for k, v in params.items()}
    holdout = edges[-1]
    observed = edges[:-1]
    learning_rate = 0.02
    for epoch in range(1, 9):
        state = rng.normal(0, 0.05, (nodes, width))
        caches, shifts, used = [], [], []
        for time, step_edges in enumerate(observed[:-1]):
            shift = (time + 1) % 47 if use_clock else 0
            message = aggregate(state, step_edges, shift)
            nxt, cache = gru(message, state, params)
            caches.append(cache)
            shifts.append(shift)
            used.append(step_edges)
            state = nxt
        pairs, labels = _pairs(observed[-1], nodes, rng)
        logits = scores_for(state, pairs)
        probability = sigmoid(logits)
        d_logit = probability - labels
        d_state = np.zeros_like(state)
        for (i, j), derivative in zip(pairs, d_logit):
            d_state[i] += derivative * state[j]
            d_state[j] += derivative * state[i]
        grads = {k: np.zeros_like(v) for k, v in params.items()}
        for cache, shift, step_edges in zip(reversed(caches), reversed(shifts), reversed(used)):
            d_message, d_state, local = gru_backward(d_state, cache, params)
            for name in grads:
                grads[name] += local[name]
            d_clocked = np.zeros_like(d_state)
            for source, target in step_edges:
                d_clocked[source] += d_message[target]
            d_state += np.roll(d_clocked, -shift, axis=1) if shift else d_clocked
        beta1, beta2, eps = 0.9, 0.999, 1e-8
        for name in params:
            moment[name] = beta1 * moment[name] + (1 - beta1) * grads[name]
            second[name] = beta2 * second[name] + (1 - beta2) * grads[name] ** 2
            correction1 = moment[name] / (1 - beta1 ** epoch)
            correction2 = second[name] / (1 - beta2 ** epoch)
            params[name] -= learning_rate * correction1 / (np.sqrt(correction2) + eps)
    eval_rng = np.random.default_rng(1000 + seed)
    state = eval_rng.normal(0, 0.05, (nodes, width))
    for time, step_edges in enumerate(observed):
        shift = (time + 1) % 47 if use_clock else 0
        state, _ = gru(aggregate(state, step_edges, shift), state, params)
    pairs, labels = _pairs(holdout, nodes, np.random.default_rng(7))
    return roc_auc(scores_for(state, pairs), labels)
