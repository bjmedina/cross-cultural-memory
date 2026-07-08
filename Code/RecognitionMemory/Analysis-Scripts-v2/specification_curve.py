#!/usr/bin/env python3
"""(#4) Specification-curve / multiverse for the surviving effect: the music-FA
contrast r(US,SB) - r(US,Ts). Recompute it across every defensible analysis
choice and show the distribution + significance.

Choices crossed:
  correlation : Spearman, Pearson
  minResp     : 2, 3, 5            (min non-NaN obs per item per group)
  d' screen   : 1.5, 2.0, 2.5      (ISI=0 inclusion threshold)
  estimate    : raw, disattenuated (r / sqrt(rho_A rho_B))
-> 2*3*3*2 = 36 specifications. Each gets a paired-bootstrap recentered p.
"""
from __future__ import annotations
import sys, itertools
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr, pearsonr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402
from python.split_half import calculate_split_half_reliability  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
COND, KIND = "Globalized-Music", "fa"
NBOOT = 500
rng = np.random.default_rng(0)


def corr(a, b, how):
    return (spearmanr(a, b).correlation if how == "spearman" else pearsonr(a, b)[0])


def cellmats(thr):
    out = {}
    for g, codes in GROUPS.items():
        h, f, it = build_hit_fa_matrices(list_matfiles(BASE, codes, COND, thr, False))
        out[g] = ((h if KIND == "hit" else f), it)
    return out


def align3(mats):
    iU, iS, iT = mats["US"][1], mats["SanBorja"][1], mats["Tsimane"][1]
    sh = [it for it in iU if it in set(iS) and it in set(iT)]
    def cols(M, names):
        p = {x: k for k, x in enumerate(names)}; return M[:, [p[i] for i in sh]]
    return (cols(*mats["US"]), cols(*mats["SanBorja"]), cols(*mats["Tsimane"]))


def contrast(U, S, T, minresp, how):
    nU = np.sum(~np.isnan(U), 0); nS = np.sum(~np.isnan(S), 0); nT = np.sum(~np.isnan(T), 0)
    v = (nU >= minresp) & (nS >= minresp) & (nT >= minresp)
    if v.sum() < 5:
        return np.nan
    u, s, t = np.nanmean(U[:, v], 0), np.nanmean(S[:, v], 0), np.nanmean(T[:, v], 0)
    return corr(u, s, how) - corr(u, t, how)


def main():
    specs = []
    cache_rel = {}
    for thr in (1.5, 2.0, 2.5):
        mats = cellmats(thr)
        U, S, T = align3(mats)
        nU, nS, nT = U.shape[0], S.shape[0], T.shape[0]
        # reliabilities at this threshold (for disattenuation)
        relU = calculate_split_half_reliability(U, U, np.arange(U.shape[1]), n_splits=200).sb_hit
        relS = calculate_split_half_reliability(S, S, np.arange(S.shape[1]), n_splits=200).sb_hit
        relT = calculate_split_half_reliability(T, T, np.arange(T.shape[1]), n_splits=200).sb_hit
        for minresp, how, dis in itertools.product((2, 3, 5), ("spearman", "pearson"), (False, True)):
            d_obs = contrast(U, S, T, minresp, how)
            denomAB = np.sqrt(max(relU*relS, 1e-6)); denomAC = np.sqrt(max(relU*relT, 1e-6))
            if dis:
                # disattenuate each correlation in the contrast separately
                nU_ = np.sum(~np.isnan(U), 0); nS_ = np.sum(~np.isnan(S), 0); nT_ = np.sum(~np.isnan(T), 0)
                v = (nU_ >= minresp) & (nS_ >= minresp) & (nT_ >= minresp)
                u, s, t = np.nanmean(U[:, v], 0), np.nanmean(S[:, v], 0), np.nanmean(T[:, v], 0)
                d_obs = corr(u, s, how)/denomAB - corr(u, t, how)/denomAC
            # paired bootstrap recentered p
            db = np.empty(NBOOT)
            for bi in range(NBOOT):
                iu = rng.integers(0, nU, nU); is_ = rng.integers(0, nS, nS); it_ = rng.integers(0, nT, nT)
                Ub, Sb, Tb = U[iu], S[is_], T[it_]
                nUb = np.sum(~np.isnan(Ub), 0); nSb = np.sum(~np.isnan(Sb), 0); nTb = np.sum(~np.isnan(Tb), 0)
                vv = (nUb >= minresp) & (nSb >= minresp) & (nTb >= minresp)
                if vv.sum() < 5:
                    db[bi] = np.nan; continue
                ub, sb_, tb = np.nanmean(Ub[:, vv], 0), np.nanmean(Sb[:, vv], 0), np.nanmean(Tb[:, vv], 0)
                d = corr(ub, sb_, how) - corr(ub, tb, how)
                if dis:
                    d = corr(ub, sb_, how)/denomAB - corr(ub, tb, how)/denomAC
                db[bi] = d
            db = db[np.isfinite(db)]
            p = (np.mean(np.abs(db - db.mean()) >= abs(d_obs)) if len(db) else np.nan)
            specs.append(dict(thr=thr, minresp=minresp, how=how, dis=dis, d=d_obs, p=p))
            print(f"thr={thr} minResp={minresp} {how:<8} {'disatt' if dis else 'raw':<6}: "
                  f"contrast={d_obs:+.3f}  p={p:.3f}")

    # specification curve plot
    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    specs = [s for s in specs if np.isfinite(s["d"])]
    specs.sort(key=lambda s: s["d"])
    d = np.array([s["d"] for s in specs]); p = np.array([s["p"] for s in specs])
    sig = p < 0.05
    x = np.arange(len(specs))
    fig, (ax, ax2) = plt.subplots(2, 1, figsize=(11, 7), height_ratios=[2, 1.6], sharex=True)
    ax.scatter(x[sig], d[sig], s=22, c="#2E7D32", label="p<.05")
    ax.scatter(x[~sig], d[~sig], s=22, c="#bbb", label="n.s.")
    ax.axhline(0, color="k", lw=1); ax.set_ylabel("contrast r(US,SB) - r(US,Ts)")
    ax.set_title(f"Specification curve: music-FA U.S.-Tsimane' dip across {len(specs)} analyses")
    ax.legend(fontsize=8, loc="upper left")
    # dashboard of choices
    rows = [("Spearman","how","spearman"),("Pearson","how","pearson"),
            ("minResp 2","minresp",2),("minResp 3","minresp",3),("minResp 5","minresp",5),
            ("d'>=1.5","thr",1.5),("d'>=2.0","thr",2.0),("d'>=2.5","thr",2.5),
            ("raw","dis",False),("disattenuated","dis",True)]
    for yi,(lab,key,val) in enumerate(rows):
        on = [xi for xi,s in enumerate(specs) if s[key]==val]
        ax2.scatter(on, [yi]*len(on), s=14, c="#333")
    ax2.set_yticks(range(len(rows))); ax2.set_yticklabels([r[0] for r in rows], fontsize=8)
    ax2.set_xlabel("specification (sorted by effect size)"); ax2.invert_yaxis()
    fig.tight_layout()
    out = HERE / "dprime_vs_isi_outputs" / "specification_curve.png"
    fig.savefig(out, dpi=160, bbox_inches="tight"); fig.savefig(out.with_suffix(".pdf"), bbox_inches="tight")
    print(f"\n{sig.sum()}/{len(specs)} specifications significant (p<.05); "
          f"median contrast={np.median(d):+.3f}")
    print("saved", out)


if __name__ == "__main__":
    main()
