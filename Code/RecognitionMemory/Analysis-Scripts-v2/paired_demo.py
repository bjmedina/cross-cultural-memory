#!/usr/bin/env python3
"""Demonstrate the dependence argument on the real data.

Two between-group correlations that SHARE a group (e.g. r(US,SB) and r(US,Ts)
both use US) are estimated from overlapping data, so their bootstrap estimates
are positively correlated and the variance of their DIFFERENCE is smaller than
sqrt(var1+var2). Hence marginal CIs can overlap while the paired difference is
still significant. We measure all of this with a shared-resample paired bootstrap.
"""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from scipy.stats import norm

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402
from python.intergroup_corr import itemwise_corr  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
MINRESP, NBOOT = 2, 4000


def spearman_valid(MA, MB, MC):
    """Pairwise Spearman on items valid (>=MINRESP) in all THREE groups."""
    from scipy.stats import spearmanr
    nA = np.sum(~np.isnan(MA), 0); nB = np.sum(~np.isnan(MB), 0); nC = np.sum(~np.isnan(MC), 0)
    v = (nA >= MINRESP) & (nB >= MINRESP) & (nC >= MINRESP)
    a = np.nanmean(MA[:, v], 0); b = np.nanmean(MB[:, v], 0); c = np.nanmean(MC[:, v], 0)
    return (spearmanr(a, b).correlation, spearmanr(a, c).correlation,
            spearmanr(b, c).correlation)


def align3(mats):
    its = [set(m[1]) for m in mats]
    shared = [it for it in mats[0][1] if it in its[1] and it in its[2]]
    out = []
    for M, names in mats:
        pos = {it: k for k, it in enumerate(names)}
        out.append(M[:, [pos[it] for it in shared]])
    return out


def fisher_ci(r, sd_z, alpha=0.05):
    z = np.arctanh(np.clip(r, -1 + 1e-6, 1 - 1e-6))
    k = norm.ppf(1 - alpha / 2)
    return np.tanh(z - k * sd_z), np.tanh(z + k * sd_z)


def run(cond, kind):
    def mat(g):
        h, f, it = build_hit_fa_matrices(list_matfiles(BASE, GROUPS[g], cond, 2.0, False))
        return (h if kind == "hit" else f), it
    MA, MB, MC = align3([mat("US"), mat("SanBorja"), mat("Tsimane")])
    rAB, rAC, rBC = spearman_valid(MA, MB, MC)
    nA, nB, nC = MA.shape[0], MB.shape[0], MC.shape[0]
    rng = np.random.default_rng(0)
    bAB, bAC, bBC = (np.empty(NBOOT) for _ in range(3))
    for k in range(NBOOT):
        iA = rng.integers(0, nA, nA); iB = rng.integers(0, nB, nB); iC = rng.integers(0, nC, nC)
        bAB[k], bAC[k], bBC[k] = spearman_valid(MA[iA], MB[iB], MC[iC])  # iA shared by AB & AC

    print(f"\n===== {cond} / {kind} =====  (US n={nA}, SB n={nB}, Ts n={nC})")
    print(f" observed: r(US,SB)={rAB:.3f}  r(US,Ts)={rAC:.3f}  r(SB,Ts)={rBC:.3f}")
    # marginal SDs on Fisher-z scale
    sdz_AB = np.std(np.arctanh(np.clip(bAB, -1+1e-6, 1-1e-6)), ddof=1)
    sdz_AC = np.std(np.arctanh(np.clip(bAC, -1+1e-6, 1-1e-6)), ddof=1)
    loAB, hiAB = fisher_ci(rAB, sdz_AB); loAC, hiAC = fisher_ci(rAC, sdz_AC)
    overlap = not (hiAC < loAB or hiAB < loAC)
    print(f" marginal Fisher-z 95% CI  r(US,SB)=[{loAB:.2f},{hiAB:.2f}]  "
          f"r(US,Ts)=[{loAC:.2f},{hiAC:.2f}]  -> marginals overlap? {overlap}")

    # dependence + variance reduction for the AB-vs-AC contrast (shared = US)
    dep = np.corrcoef(bAB, bAC)[0, 1]
    sd_AB, sd_AC = np.std(bAB, ddof=1), np.std(bAC, ddof=1)
    diff = bAB - bAC
    sd_paired = np.std(diff, ddof=1)
    sd_indep = np.sqrt(sd_AB**2 + sd_AC**2)
    print(f" bootstrap corr(r_AB, r_AC) = {dep:+.2f}  (positive => dependent)")
    print(f" SD(diff) paired = {sd_paired:.3f}   vs independent sqrt(v1+v2) = {sd_indep:.3f}"
          f"   ({100*(1-sd_paired/sd_indep):.0f}% smaller)")
    d_obs = rAB - rAC
    lo, hi = np.percentile(diff, [2.5, 97.5])
    dc = diff - diff.mean()
    p_rec = np.mean(np.abs(dc) >= abs(d_obs))
    print(f" DIFFERENCE r(US,SB)-r(US,Ts) = {d_obs:+.3f}  95% CI [{lo:+.3f},{hi:+.3f}]"
          f"  recentered p = {max(p_rec,1/(NBOOT+1)):.3f}")


if __name__ == "__main__":
    run("Industrial-Nature", "fa")   # near-tie marginals
    run("Globalized-Music", "fa")    # the dip
