#!/usr/bin/env python3
"""(#2, feasible form) Bayesian hierarchical measurement-error model for the
cross-cultural item-effect correlations, fit by conjugate Gibbs (fast, no
external sampler).

For each shared item j and group g we take the per-item logit rate y_gj with its
delta-method sampling variance v_gj = 1/(n_gj p(1-p)) (more participants -> smaller
v_gj). The latent true item effects theta_j = (US, SB, Ts) are MVN(mu, Sigma):

    y_gj ~ N(theta_gj, v_gj)        (measurement layer, attenuation modelled)
    theta_j ~ MVN(mu, Sigma)        (Sigma's correlations = TRUE between-group
                                     item-effect correlations, disattenuated)

Gibbs over {theta_j}, mu (flat), Sigma (inverse-Wishart). The posterior of the
correlations and of the contrast r(US,SB)-r(US,Ts) is reported with 94% HDIs and
P(>0). This is the one-stage estimate the chapter wants: it corrects attenuation
inside the model and propagates uncertainty (no separate disattenuation step).
The trial-level logistic twin (bayes_itemcorr.py) needs a BLAS/GPU sampler.
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from scipy.stats import invwishart

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
CONDS = [("Industrial-Nature", "Env"), ("Globalized-Music", "Music"), ("NHS", "NHS")]
MINRESP = 2
EPS = 1e-2


def per_item(cond, kind):
    """Return logit-rate y [m x 3] and variance v [m x 3] over items shared by all
    three groups with >= MINRESP obs each."""
    mats = {}
    for g, codes in GROUPS.items():
        h, f, it = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
        mats[g] = ((h if kind == "hit" else f), list(it))
    shared = [it for it in mats["US"][1] if it in set(mats["SanBorja"][1]) and it in set(mats["Tsimane"][1])]
    Y, V = [], []
    for it in shared:
        row_y, row_v, ok = [], [], True
        for g in ["US", "SanBorja", "Tsimane"]:
            M, names = mats[g]; col = M[:, names.index(it)]
            obs = col[~np.isnan(col)]
            if obs.size < MINRESP:
                ok = False; break
            p = np.clip(obs.mean(), EPS, 1 - EPS); n = obs.size
            row_y.append(np.log(p / (1 - p)))
            row_v.append(1.0 / (n * p * (1 - p)))
        if ok:
            Y.append(row_y); V.append(row_v)
    return np.array(Y), np.array(V)


def gibbs(Y, V, n_iter=3000, burn=800, seed=0):
    rng = np.random.default_rng(seed)
    m = Y.shape[0]
    mu = Y.mean(0)
    Sigma = np.cov(Y.T) + 0.05 * np.eye(3)
    nu0 = 4; Psi0 = np.eye(3) * 0.5
    Dinv = np.zeros((m, 3, 3))           # per-item diag(1/V[j])
    for j in range(m):
        Dinv[j] = np.diag(1.0 / V[j])
    YoverV = Y / V                       # (m,3)
    corrs = []
    for t in range(n_iter):
        Sinv = np.linalg.inv(Sigma)
        Prec = Dinv + Sinv[None, :, :]               # (m,3,3)
        Cov = np.linalg.inv(Prec)                     # (m,3,3)
        rhs = YoverV + (Sinv @ mu)[None, :]           # (m,3)
        mean = np.einsum('mij,mj->mi', Cov, rhs)      # (m,3)
        L = np.linalg.cholesky(Cov)                   # (m,3,3)
        Z = rng.standard_normal((m, 3))
        theta = mean + np.einsum('mij,mj->mi', L, Z)  # (m,3)
        mu = rng.multivariate_normal(theta.mean(0), Sigma / m)
        dev = theta - mu
        Sigma = invwishart.rvs(df=nu0 + m, scale=Psi0 + dev.T @ dev, random_state=rng)
        if t >= burn:
            d = np.sqrt(np.diag(Sigma))
            R = Sigma / np.outer(d, d)
            corrs.append([R[0, 1], R[0, 2], R[1, 2]])
    return np.array(corrs)


def summ(x):
    return dict(mean=float(np.mean(x)), hdi=[float(np.percentile(x, 3)), float(np.percentile(x, 97))])


def main():
    print("Bayesian hierarchical measurement-error model (Gibbs). "
          "Disattenuated between-group item correlations with 94% HDI.\n")
    print(f"{'cell':<11}{'m':>4}  {'US-SB (mean[HDI])':<22}{'US-Ts':<22}{'SB-Ts':<22}"
          f"{'contrast US-SB - US-Ts'}")
    for cond, clab in CONDS:
        for kind in ("hit", "fa"):
            Y, V = per_item(cond, kind)
            C = gibbs(Y, V)
            ab, ac, bc = summ(C[:, 0]), summ(C[:, 1]), summ(C[:, 2])
            d = C[:, 0] - C[:, 1]
            ds = summ(d); pgt = float((d > 0).mean())
            fmt = lambda s: f"{s['mean']:.2f}[{s['hdi'][0]:.2f},{s['hdi'][1]:.2f}]"
            print(f"{clab+' '+kind:<11}{Y.shape[0]:>4}  {fmt(ab):<22}{fmt(ac):<22}{fmt(bc):<22}"
                  f"{fmt(ds)} P(>0)={pgt:.3f}")
        print()


if __name__ == "__main__":
    main()
