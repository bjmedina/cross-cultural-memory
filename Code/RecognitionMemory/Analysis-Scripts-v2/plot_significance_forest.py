#!/usr/bin/env python3
"""Significance forest plot: all 18 paired contrasts (3 sound sets x {hits,FA} x 3
group pairs). Each row is a difference between two between-group correlations,
with a 95% interval (centered on the observed difference, width from the paired
bootstrap) and the recentered-null p-value. Color marks significance; a star
marks contrasts that survive Holm correction across the 18 tests. Spearman."""
from __future__ import annotations
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
CONDS = [("Industrial-Nature", "Env"), ("Globalized-Music", "Music"), ("NHS", "NHS")]
CONTRASTS = [("US-SB − US-Ts", "ab", "ac"), ("US-SB − SB-Ts", "ab", "bc"),
             ("US-Ts − SB-Ts", "ac", "bc")]
MINRESP, NBOOT = 2, 2000


def align3(cond, kind):
    M = {}
    for g in GROUPS:
        h, f, it = build_hit_fa_matrices(list_matfiles(BASE, GROUPS[g], cond, 2.0, False))
        M[g] = ((h if kind == "hit" else f), list(it))
    sh = [i for i in M["US"][1] if i in set(M["SanBorja"][1]) and i in set(M["Tsimane"][1])]
    def cols(g):
        Mat, names = M[g]; p = {x: k for k, x in enumerate(names)}
        return Mat[:, [p[i] for i in sh]]
    return cols("US"), cols("SanBorja"), cols("Tsimane")


def three(U, S, T):
    nU = np.sum(~np.isnan(U), 0); nS = np.sum(~np.isnan(S), 0); nT = np.sum(~np.isnan(T), 0)
    v = (nU >= MINRESP) & (nS >= MINRESP) & (nT >= MINRESP)
    u, s, t = np.nanmean(U[:, v], 0), np.nanmean(S[:, v], 0), np.nanmean(T[:, v], 0)
    return dict(ab=spearmanr(u, s).correlation, ac=spearmanr(u, t).correlation, bc=spearmanr(s, t).correlation)


def main():
    rng = np.random.default_rng(0)
    rows = []
    for cond, clab in CONDS:
        for kind in ("hit", "fa"):
            U, S, T = align3(cond, kind)
            obs = three(U, S, T)
            nU, nS, nT = U.shape[0], S.shape[0], T.shape[0]
            boot = {k: np.empty(NBOOT) for k in ("ab", "ac", "bc")}
            for bi in range(NBOOT):
                d = three(U[rng.integers(0, nU, nU)], S[rng.integers(0, nS, nS)], T[rng.integers(0, nT, nT)])
                for k in boot:
                    boot[k][bi] = d[k]
            for lab, k1, k2 in CONTRASTS:
                d_obs = obs[k1] - obs[k2]
                db = boot[k1] - boot[k2]; sd = np.std(db, ddof=1)
                p = max(np.mean(np.abs(db - db.mean()) >= abs(d_obs)), 1 / (NBOOT + 1))
                rows.append(dict(cell=f"{clab} {kind}", lab=lab, d=d_obs,
                                 lo=d_obs - 1.96 * sd, hi=d_obs + 1.96 * sd, p=p))
    # Holm across the 18
    ps = np.array([r["p"] for r in rows]); order = np.argsort(ps); m = len(rows)
    holm = np.zeros(m, bool); thresh = 0.05
    for rank, idx in enumerate(order):
        if ps[idx] <= 0.05 / (m - rank):
            holm[idx] = True
        else:
            break
    for i, r in enumerate(rows):
        r["holm"] = holm[i]

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(8.5, 8.2))
    y = np.arange(len(rows))[::-1]
    for yi, r in zip(y, rows):
        if r["holm"]:
            col = "#1B5E20"
        elif r["p"] < 0.05:
            col = "#66BB6A"
        else:
            col = "#9E9E9E"
        ax.plot([r["lo"], r["hi"]], [yi, yi], color=col, lw=2.5, solid_capstyle="round")
        ax.plot(r["d"], yi, "o", color=col, ms=7, zorder=5)
        star = " ★" if r["holm"] else ("*" if r["p"] < 0.05 else "")
        ax.text(0.62, yi, f"p={r['p']:.3f}{star}", fontsize=8, va="center",
                color=col, fontweight="bold" if r["p"] < 0.05 else "normal")
    ax.axvline(0, color="k", lw=1)
    ax.set_yticks(y); ax.set_yticklabels([f"{r['cell']}:  {r['lab']}" for r in rows], fontsize=8.5)
    ax.set_xlabel("difference between two between-group correlations (95% CI)")
    ax.set_xlim(-0.45, 0.85)
    ax.set_title("All 18 paired contrasts. ★ = survives Holm correction", fontsize=12, fontweight="bold")
    # legend
    from matplotlib.lines import Line2D
    ax.legend(handles=[Line2D([0],[0],color="#1B5E20",lw=3,label="survives Holm"),
                       Line2D([0],[0],color="#66BB6A",lw=3,label="p<.05 (uncorrected)"),
                       Line2D([0],[0],color="#9E9E9E",lw=3,label="n.s.")],
              fontsize=8.5, loc="lower right")
    ax.grid(axis="x", ls="--", alpha=0.3)
    fig.tight_layout()
    out = HERE / "dprime_vs_isi_outputs" / "significance_forest.png"
    fig.savefig(out, dpi=170, bbox_inches="tight"); fig.savefig(out.with_suffix(".pdf"), bbox_inches="tight")
    print("saved", out)
    for r in rows:
        if r["p"] < 0.05:
            print(f"  sig: {r['cell']:<10} {r['lab']:<14} d={r['d']:+.3f} p={r['p']:.3f} holm={r['holm']}")


if __name__ == "__main__":
    main()
