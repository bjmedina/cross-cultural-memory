#!/usr/bin/env python3
"""Power for the music-FA paired contrasts vs (a) number of SOUNDS and
(b) number of PARTICIPANTS. Accumulates replicates across runs so totals can be
built up within a time budget, and shows +/-1 SEM (binomial) bands.

  --mode items / participants : run reps and APPEND their per-rep p-values to a
        cumulative .npz (use --seed to vary). Re-run to add more reps.
  --mode reset-<items|participants> : clear the accumulator for that sweep.
  --mode plot : combine both sweeps into one 2-panel figure with SEM bands.
"""
from __future__ import annotations
import sys, argparse
from pathlib import Path
import numpy as np

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
OUT = HERE / "dprime_vs_isi_outputs"
ALPHA = 0.05

OBS = (0.63, 0.25, 0.42); REL = (0.86, 0.74, 0.70)
_pr = [REL[0]*REL[1], REL[0]*REL[2], REL[1]*REL[2]]
RHO = tuple(min(OBS[k] / np.sqrt(_pr[k]), 0.97) for k in range(3))
N_OBS = dict(US=96, SB=63, Ts=68)
LABELS = ["US–SB vs US–Ts", "US–SB vs SB–Ts", "US–Ts vs SB–Ts"]
COLS = ["#7E57C2", "#8D6E63", "#5D8AA8"]
ITEM_GRID = list(range(5, 81, 5))
PART_GRID = [20, 35, 50, 75, 110, 160]


def _run_point(P, m, na, nb, nc, reps, boot, seed):
    r = P(n_reps=reps, n_a=na, n_b=nb, n_c=nc, n_items=m, rho=RHO, rel=REL,
          n_boot=boot, seed=seed, progress_every=0)
    return r.p_null  # (reps, 3)


def run(mode, reps, boot, seed):
    from python.power_simulation import power_simulation_paired_bootstrap as P
    grid = ITEM_GRID if mode == "items" else PART_GRID
    npz = OUT / f"power_sweep_{mode}.npz"
    # new p-values: shape (G, reps, 3)
    new = np.stack([
        _run_point(P, m if mode == "items" else 80,
                   N_OBS["US"], N_OBS["SB"] if mode == "items" else m,
                   N_OBS["Ts"] if mode == "items" else m, reps, boot, seed)
        for m in grid])
    if npz.exists():
        old = np.load(npz)["pvals"]
        if old.shape[0] == new.shape[0]:
            new = np.concatenate([old, new], axis=1)
    np.savez(npz, grid=grid, pvals=new)
    tot = new.shape[1]
    print(f"[{mode}] now {tot} total reps. power@max-grid: " +
          "  ".join(f"{LABELS[k]}={np.nanmean(new[-1,:,k]<=ALPHA):.2f}" for k in range(3)))


def _power_se(pvals):
    rej = pvals <= ALPHA
    valid = ~np.isnan(pvals)
    n = valid.sum(axis=1)                       # (G,3)
    p = np.where(n > 0, np.nansum(rej & valid, axis=1) / np.maximum(n, 1), np.nan)
    se = np.sqrt(p * (1 - p) / np.maximum(n, 1))
    return p, se, int(np.median(n))


def plot():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    it = np.load(OUT / "power_sweep_items.npz"); pa = np.load(OUT / "power_sweep_participants.npz")
    pit, seit, nit = _power_se(it["pvals"]); ppa, sepa, npa = _power_se(pa["pvals"])
    fig, (a1, a2) = plt.subplots(1, 2, figsize=(13, 5), sharey=True)
    for k in range(3):
        a1.plot(it["grid"], pit[:, k], "-o", color=COLS[k], lw=2, ms=4, label=LABELS[k])
        a1.fill_between(it["grid"], pit[:, k]-seit[:, k], pit[:, k]+seit[:, k], color=COLS[k], alpha=0.18)
        a2.plot(pa["grid"], ppa[:, k], "-o", color=COLS[k], lw=2, ms=4, label=LABELS[k])
        a2.fill_between(pa["grid"], ppa[:, k]-sepa[:, k], ppa[:, k]+sepa[:, k], color=COLS[k], alpha=0.18)
    for ax, xl, ti in [(a1, "number of sounds (items)", f"Sweep stimuli (participants fixed; {nit} reps)"),
                       (a2, "participants per field group", f"Sweep participants (80 sounds; {npa} reps)")]:
        ax.axhline(0.8, ls="--", color="#C62828", lw=1.3); ax.axhline(0.05, ls=":", color="#888", lw=1)
        ax.set_xlabel(xl); ax.set_ylim(0, 1.02); ax.grid(True, ls="--", alpha=0.3); ax.set_title(ti, fontsize=11)
    a1.set_ylabel("power (paired-bootstrap rejection, α=.05)  ± SEM")
    a1.legend(fontsize=8.5, loc="upper left")
    fig.tight_layout()
    fig.savefig(OUT / "power_sweeps.png", dpi=160, bbox_inches="tight")
    fig.savefig(OUT / "power_sweeps.pdf", bbox_inches="tight")
    print("saved", OUT / "power_sweeps.png", f"(items {nit} reps, participants {npa} reps)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", required=True)
    ap.add_argument("--reps", type=int, default=40)
    ap.add_argument("--boot", type=int, default=150)
    ap.add_argument("--seed", type=int, default=0)
    args = ap.parse_args()
    if args.mode == "plot":
        plot()
    elif args.mode.startswith("reset-"):
        f = OUT / f"power_sweep_{args.mode.split('-')[1]}.npz"
        f.unlink(missing_ok=True); print("reset", f)
    else:
        run(args.mode, args.reps, args.boot, args.seed)


if __name__ == "__main__":
    main()
