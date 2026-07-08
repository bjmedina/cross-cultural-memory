#!/usr/bin/env python3
"""Reconcile the two levels of analysis.

Per-sound measures (averaged across participants): hit rate, FA rate, and
corrected recognition CR = hit_rate - FA_rate, per sound. For each we report:
  - across-SOUND mean and SD (how much the measure varies from sound to sound)
  - within-group split-half reliability (how well that per-sound vector is measured)
  - between-group Spearman correlation (do the same sounds rank alike across groups)
This shows the between-group correlation is driven by across-sound SPREAD and
RELIABILITY, not by the overall rate MAGNITUDE. Screened sample (d'>=2).
"""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
OUT = HERE / "dprime_vs_isi_outputs"
GROUPS = [("US", ("PRO","BOS","CAM")), ("SanBorja", ("SBO","SNB","SBJ")),
          ("Tsimane", ("NVM","MAJ","MAN","NUM","NUV","CVR"))]
GLAB = {"US":"US","SanBorja":"SB","Tsimane":"Ts"}
CONDS = [("Industrial-Nature","Env"), ("Globalized-Music","Music"), ("NHS","NHS")]
MINRESP = 2
rng = np.random.default_rng(0)


def persound(hits, fas):
    with np.errstate(invalid="ignore"):
        h = np.nanmean(hits, 0); f = np.nanmean(fas, 0)
    return h, f, h - f


def splithalf(compute, n, nsplit=300):
    rs = []
    for _ in range(nsplit):
        idx = rng.permutation(n); a, b = idx[:n//2], idx[n//2:]
        va, vb = compute(a), compute(b)
        m = np.isfinite(va) & np.isfinite(vb)
        if m.sum() >= 5:
            rs.append(spearmanr(va[m], vb[m]).correlation)
    r = np.nanmedian(rs)
    return (2*r)/(1+r) if np.isfinite(r) else np.nan


def main():
    G = {}
    for cond, clab in CONDS:
        for g, codes in GROUPS:
            hits, fas, items = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
            h, f, cr = persound(hits, fas)
            n = hits.shape[0]
            rel_h = splithalf(lambda ix: np.nanmean(hits[ix], 0), n)
            rel_f = splithalf(lambda ix: np.nanmean(fas[ix], 0), n)
            rel_cr = splithalf(lambda ix: np.nanmean(hits[ix], 0) - np.nanmean(fas[ix], 0), n)
            G[(clab, g)] = dict(items=list(items), h=h, f=f, cr=cr,
                                rel=dict(hit=rel_h, fa=rel_f, cr=rel_cr))

    # Table 1: spread + reliability
    print("ACROSS-SOUND mean±SD  and  split-half reliability, per group")
    print(f"{'cond':<6}{'grp':<4}"
          f"{'hit mean±SD':>16}{'rel':>6}{'FA mean±SD':>16}{'rel':>6}{'CR mean±SD':>16}{'rel':>6}")
    for cond, clab in CONDS:
        for g, _ in GROUPS:
            D = G[(clab, g)]
            def ms(a): return f"{np.nanmean(a):.2f}±{np.nanstd(a):.2f}"
            print(f"{clab:<6}{GLAB[g]:<4}"
                  f"{ms(D['h']):>16}{D['rel']['hit']:>6.2f}"
                  f"{ms(D['f']):>16}{D['rel']['fa']:>6.2f}"
                  f"{ms(D['cr']):>16}{D['rel']['cr']:>6.2f}")
        print()

    # Table 2: between-group Spearman per measure
    PAIRS = [("US","SanBorja","US-SB"),("US","Tsimane","US-Ts"),("SanBorja","Tsimane","SB-Ts")]
    KM = {"hit":"h","fa":"f","cr":"cr"}
    def corr(cond, a, b, key):
        Da, Db = G[(cond,a)], G[(cond,b)]; kk = KM[key]
        ia = {it:i for i,it in enumerate(Da["items"])}; ib={it:i for i,it in enumerate(Db["items"])}
        sh=[it for it in Da["items"] if it in ib]
        va=np.array([Da[kk][ia[it]] for it in sh]); vb=np.array([Db[kk][ib[it]] for it in sh])
        m=np.isfinite(va)&np.isfinite(vb)
        return spearmanr(va[m], vb[m]).correlation
    print("BETWEEN-GROUP Spearman correlation")
    print(f"{'cond':<6}{'measure':<5}{'US-SB':>8}{'US-Ts':>8}{'SB-Ts':>8}")
    results={}
    for cond, clab in CONDS:
        for key in ("hit","fa","cr"):
            row=[corr(clab,a,b,key) for a,b,_ in PAIRS]
            results[(clab,key)]=row
            print(f"{clab:<6}{key:<5}{row[0]:>8.2f}{row[1]:>8.2f}{row[2]:>8.2f}")
        print()

    # figure: between-group corr by measure, per condition
    import matplotlib; matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    MC={"hit":"#2E7D32","fa":"#C62828","cr":"#7E57C2"}
    fig,axes=plt.subplots(1,3,figsize=(13,4.2),sharey=True)
    x=np.arange(3); w=0.26
    for c,(cond,clab) in enumerate(CONDS):
        ax=axes[c]
        for k,key in enumerate(("hit","fa","cr")):
            ax.bar(x+(k-1)*w, results[(clab,key)], w, color=MC[key],
                   label={"hit":"hit rate","fa":"FA rate","cr":"corrected recog."}[key])
        ax.set_xticks(x); ax.set_xticklabels(["US-SB","US-Ts","SB-Ts"],fontsize=9)
        ax.set_ylim(0,1); ax.set_title(clab,fontsize=11); ax.grid(axis="y",ls="--",alpha=.3)
        if c==0: ax.set_ylabel("between-group correlation (Spearman)")
    axes[0].legend(fontsize=8,loc="upper right")
    fig.suptitle("Between-group item correlation by measure: hit rate, FA rate, corrected recognition",
                 fontsize=12.5,fontweight="bold")
    fig.tight_layout(rect=[0,0,1,0.96])
    fig.savefig(OUT/"reconcile_measures.png",dpi=160,bbox_inches="tight")
    fig.savefig(OUT/"reconcile_measures.pdf",bbox_inches="tight")
    print("saved reconcile_measures")


if __name__ == "__main__":
    main()
