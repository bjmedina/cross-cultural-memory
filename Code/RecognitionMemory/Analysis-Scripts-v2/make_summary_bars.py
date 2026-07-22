#!/usr/bin/env python3
"""Chapter-3 summary figure: the exposure-distance effect in one panel.

For each sound set, one bar = the difference between the two Tsimane'-involving
between-group per-sound FA correlations,

    delta = r(San Borja, Tsimane') - r(U.S., Tsimane').

Tsimane' is held constant, so delta isolates the effect of the OTHER group's
exposure to globalized media. If cross-cultural divergence tracks exposure
distance, the U.S. (most distant from Tsimane') should agree LESS with Tsimane'
than San Borja does for globalized music, giving delta > 0; the sets where
experience gives nothing to differentiate (environmental, world song) give
delta ~ 0. The CI and p come from the chapter's paired bootstrap, which shares
the Tsimane' resample across the two correlations (Section cc-paired).
"""
from pathlib import Path
import sys
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402
from python.split_half import calculate_split_half_reliability  # noqa: E402
from python.paired_bootstrap import paired_bootstrap_compare_correlations  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
GROUPS = {"US": ("PRO", "BOS", "CAM"), "SanBorja": ("SBO", "SNB", "SBJ"),
          "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
CONDS = [("Industrial-Nature", "Environmental"),
         ("Globalized-Music", "Globalized\nmusic"), ("NHS", "World song\n(NHS)")]
NBOOT = 5000


def stars(p):
    return "***" if p < .001 else "**" if p < .01 else "*" if p < .05 else "n.s."


def main():
    rng = np.random.default_rng(0)
    rows = []
    for cond, clab in CONDS:
        rel = {}
        for g, codes in GROUPS.items():
            hits, fas, items = build_hit_fa_matrices(list_matfiles(BASE, codes, cond, 2.0, False))
            rel[g] = calculate_split_half_reliability(hits, fas, items, n_splits=500)
        res = paired_bootstrap_compare_correlations(
            rel["US"], rel["SanBorja"], rel["Tsimane"],
            trial_type="fa", n_boot=NBOOT, rng=rng, verbose=False)
        r_us_ts = res.observed["r_AC"]     # r(U.S., Tsimane')
        r_sb_ts = res.observed["r_BC"]     # r(San Borja, Tsimane')
        delta = r_sb_ts - r_us_ts
        lo_acbc, hi_acbc = res.ci["AC_minus_BC"]   # percentiles of r_AC - r_BC
        lo, hi = -hi_acbc, -lo_acbc                 # CI on delta = r_BC - r_AC
        p = res.ac_vs_bc
        rows.append(dict(clab=clab, r_us_ts=r_us_ts, r_sb_ts=r_sb_ts,
                         delta=delta, lo=lo, hi=hi, p=p))
        print(f"{cond:18s} r(US-Ts)={r_us_ts:.2f} r(SB-Ts)={r_sb_ts:.2f} "
              f"delta={delta:+.2f} CI[{lo:+.2f},{hi:+.2f}] p={p:.3f} {stars(p)}")

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(6.6, 4.4))
    x = np.arange(len(rows))
    cols = ["#9E9E9E", "#C0392B", "#9E9E9E"]  # highlight music
    d = [r["delta"] for r in rows]
    ax.bar(x, d, 0.6, color=cols, edgecolor="white", zorder=3)
    for i, r in enumerate(rows):
        ax.plot([i, i], [r["lo"], r["hi"]], color="black", lw=1.6, zorder=6)
        for yy in (r["lo"], r["hi"]):
            ax.plot([i - 0.09, i + 0.09], [yy, yy], color="black", lw=1.6, zorder=6)
        top = max(r["hi"], r["delta"]) + 0.02
        ax.text(i, top, stars(r["p"]), ha="center", va="bottom", fontsize=11)
    ax.axhline(0, color="#444", lw=1)
    ax.set_xticks(x)
    ax.set_xticklabels([r["clab"] for r in rows], fontsize=10)
    ax.set_ylabel("$r$(San Borja, Tsimane’) $-$ $r$(U.S., Tsimane’)", fontsize=10.5)
    ax.set_title("Exposure-distance effect on between-group false-alarm agreement",
                 fontsize=11, fontweight="bold")
    ax.grid(axis="y", ls="--", alpha=0.3)
    ax.set_ylim(min(-0.05, min(r["lo"] for r in rows) - 0.05),
                max(r["hi"] for r in rows) + 0.12)
    fig.tight_layout()
    out = HERE / "dprime_vs_isi_outputs" / "summary_pair_diff_fa"
    fig.savefig(out.with_suffix(".png"), dpi=170, bbox_inches="tight")
    fig.savefig(out.with_suffix(".pdf"), bbox_inches="tight")
    print("saved", out.with_suffix(".pdf"))


if __name__ == "__main__":
    main()
