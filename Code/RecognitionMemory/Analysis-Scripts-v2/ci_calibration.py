#!/usr/bin/env python3
"""Which CI for the between-group itemwise correlation is most stable for THESE data?

Simulation calibration: generate synthetic two-group participant x item data with
a KNOWN true itemwise correlation, at sample sizes / reliabilities matched to the
cross-cultural data, then build percentile / Fisher-z / BCa CIs from a participant
bootstrap and measure, per method:
    coverage   - fraction of 95% CIs containing the true correlation (target 0.95)
    width      - mean CI width (narrower is better, given adequate coverage)
    miss_point - fraction of CIs that EXCLUDE the sample point estimate (a failure)
    nan        - fraction of undefined CIs

Run across true-r values and two reliability regimes (a "good" one ~ the music/FA
and environmental cells, and a "low" one ~ the globalized-music Tsimane' hit cell,
reliability ~0.2). Recommends the method with coverage closest to nominal that does
not break.
"""
from __future__ import annotations
import sys, argparse
from pathlib import Path
import numpy as np
from scipy.stats import norm

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.intergroup_corr import itemwise_corr, jackknife_intergroup_corr  # noqa: E402
from python.ci_methods import all_cis  # noqa: E402
from python.split_half import calculate_split_half_reliability  # noqa: E402

MINRESP, MINITEMS = 2, 5


def gen_group(p_item, n, q_seen, rng):
    """n participants x m items; each sees an item as target w.p. q_seen,
    then responds Bernoulli(p_item). Unseen -> NaN."""
    m = len(p_item)
    seen = rng.random((n, m)) < q_seen
    resp = (rng.random((n, m)) < p_item[None, :]).astype(float)
    resp[~seen] = np.nan
    return resp


def one_replicate(r_latent, nA, nB, m, q_seen, scale, B, rng):
    # latent bivariate normal per item -> probabilities (true corr set by r_latent)
    z = rng.multivariate_normal([0, 0], [[1, r_latent], [r_latent, 1]], size=m)
    pA = norm.cdf(z[:, 0] * scale)
    pB = norm.cdf(z[:, 1] * scale)
    from scipy.stats import spearmanr
    true_r = spearmanr(pA, pB).correlation

    A = gen_group(pA, nA, q_seen, rng)
    B_ = gen_group(pB, nB, q_seen, rng)
    r_hat, _ = itemwise_corr(A, B_, min_resp=MINRESP, min_items=MINITEMS)
    if not np.isfinite(r_hat):
        return None

    # participant bootstrap (resample within each group independently)
    boot = np.full(B, np.nan)
    for b in range(B):
        ia = rng.integers(0, nA, nA)
        ib = rng.integers(0, nB, nB)
        rb, _ = itemwise_corr(A[ia], B_[ib], min_resp=MINRESP, min_items=MINITEMS)
        boot[b] = rb
    jk_raw, _ = jackknife_intergroup_corr(A, B_, min_resp=MINRESP, min_items=MINITEMS)
    cis = all_cis(r_hat, boot, jk_raw)
    return true_r, r_hat, cis


def evaluate(r_latent, nA, nB, m, q_seen, scale, R, B, seed=0):
    rng = np.random.default_rng(seed)
    methods = ["percentile", "fisher_z", "bca"]
    cover = {k: [] for k in methods}; width = {k: [] for k in methods}
    miss = {k: [] for k in methods}; nan = {k: 0 for k in methods}
    rels, truers = [], []
    done = 0
    while done < R:
        out = one_replicate(r_latent, nA, nB, m, q_seen, scale, B, rng)
        if out is None:
            continue
        true_r, r_hat, cis, relA = out
        rels.append(relA); truers.append(true_r); done += 1
        for k in methods:
            lo, hi = cis[k]
            if not (np.isfinite(lo) and np.isfinite(hi)):
                nan[k] += 1; continue
            cover[k].append(lo <= true_r <= hi)
            width[k].append(hi - lo)
            miss[k].append(not (lo <= r_hat <= hi))
    return dict(true_r=np.mean(truers), rel=np.mean(rels),
                methods={k: dict(coverage=np.mean(cover[k]) if cover[k] else np.nan,
                                 width=np.mean(width[k]) if width[k] else np.nan,
                                 miss_point=np.mean(miss[k]) if miss[k] else np.nan,
                                 nan=nan[k] / R) for k in methods})


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--R", type=int, default=250)
    ap.add_argument("--B", type=int, default=600)
    args = ap.parse_args()
    m = 80
    # regimes: (label, nA, nB, q_seen, scale)  scale controls between-item spread -> reliability
    regimes = [
        ("good reliability (~0.7)", 100, 70, 0.5, 1.3),
        ("low reliability  (~0.2)", 70, 70, 0.5, 0.35),
    ]
    print(f"R={args.R} replicates, B={args.B} bootstrap, m={m} items, 95% CIs\n")
    for label, nA, nB, q, scale in regimes:
        print(f"########## {label} ##########")
        for r_lat in (0.4, 0.7, 0.9):
            res = evaluate(r_lat, nA, nB, m, q, scale, args.R, args.B)
            print(f"  true r≈{res['true_r']:.2f}  (achieved reliability≈{res['rel']:.2f})")
            print(f"    {'method':<11}{'coverage':>10}{'width':>9}{'miss_pt':>9}{'nan':>7}")
            for k, v in res["methods"].items():
                print(f"    {k:<11}{v['coverage']:>10.3f}{v['width']:>9.3f}"
                      f"{v['miss_point']:>9.3f}{v['nan']:>7.2f}")
        print()


if __name__ == "__main__":
    main()
