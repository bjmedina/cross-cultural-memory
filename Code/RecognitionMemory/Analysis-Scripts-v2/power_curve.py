#!/usr/bin/env python3
"""Power vs sample size for detecting the cross-cultural item-level contrasts.

Drives the chapter's own power_simulation_paired_bootstrap across a grid of
per-group participant counts, at the OBSERVED music-FA effect (the one real
effect: r(US,SB)=0.63, r(US,Ts)=0.25, r(SB,Ts)=0.42), and reports the empirical
power (rejection rate of the recentered-null paired test) for each pairwise
contrast. US is held near its realized size; the two field groups (San Borja,
Tsimane') are swept together, since they are the binding constraint.

Reliability is held at the observed FA levels, so power rises with n only through
reduced sampling variance -> a CONSERVATIVE estimate (real reliability also grows
with n). Output: power_curve.png + printed table with the n for 80% power.
"""
from __future__ import annotations
import sys, argparse
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.power_simulation import power_simulation_paired_bootstrap  # noqa: E402

# A=US, B=San Borja, C=Tsimane'; order = (AB, AC, BC)
OBS = (0.63, 0.25, 0.42)          # OBSERVED globalized-music FA correlations
REL = (0.86, 0.74, 0.70)          # observed FA within-group reliabilities
# de-attenuate so the simulated *observable* correlations reproduce OBS:
#   observable = latent * sqrt(rel_a * rel_b)  ->  latent = observable / sqrt(rel_a*rel_b)
import numpy as _np
_pair_rel = [REL[0]*REL[1], REL[0]*REL[2], REL[1]*REL[2]]
RHO = tuple(min(OBS[k] / _np.sqrt(_pair_rel[k]), 0.97) for k in range(3))
N_US = 96
N_GRID = [20, 35, 50, 75, 110, 160]
LABELS = ["US–SB vs US–Ts", "US–SB vs SB–Ts", "US–Ts vs SB–Ts"]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--reps", type=int, default=60)
    ap.add_argument("--boot", type=int, default=300)
    args = ap.parse_args()

    power = np.zeros((len(N_GRID), 3))
    for i, n in enumerate(N_GRID):
        res = power_simulation_paired_bootstrap(
            n_reps=args.reps, n_a=N_US, n_b=n, n_c=n, n_items=80,
            rho=RHO, rel=REL, n_boot=args.boot, seed=0, progress_every=0)
        power[i] = res.reject_null
        print(f"n(field)={n:4d}: power " +
              "  ".join(f"{LABELS[k]}={power[i,k]:.2f}" for k in range(3)))

    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(7.5, 5))
    cols = ["#7E57C2", "#8D6E63", "#5D8AA8"]
    for k in range(3):
        ax.plot(N_GRID, power[:, k], "-o", color=cols[k], lw=2, label=LABELS[k])
    ax.axhline(0.8, ls="--", color="#C62828", lw=1.4)
    ax.text(N_GRID[-1], 0.81, "80% power", ha="right", color="#C62828", fontsize=9)
    ax.axhline(0.05, ls=":", color="#888", lw=1)
    ax.set_xlabel("participants per field group (San Borja = Tsimane’)")
    ax.set_ylabel("power  (paired-bootstrap rejection rate, α=.05)")
    ax.set_ylim(0, 1.02); ax.grid(True, ls="--", alpha=0.3); ax.legend(fontsize=9)
    ax.set_title("Power to detect the globalized-music FA contrasts (US n=96)", fontsize=11)
    fig.tight_layout()
    out = HERE / "dprime_vs_isi_outputs" / "power_curve.png"
    fig.savefig(out, dpi=160, bbox_inches="tight")
    fig.savefig(out.with_suffix(".pdf"), bbox_inches="tight")
    print("saved", out)


if __name__ == "__main__":
    main()
