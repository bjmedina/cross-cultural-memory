#!/usr/bin/env python3
"""Try to reproduce the OLD slide's item-wise correlations (Natural sounds).

Old pipeline recipe: d'>=1.5 screen, NO finished-session filter, per-sound Spearman
correlation, then attenuation-corrected r* = r / sqrt(rel_A rel_B) plotted as the
bar. We compute observed r and r* under that screen and compare to the slide.

Old slide (Natural sounds = Environmental):
    HIT:  Ts-SB 0.95   Ts-US 0.36   SB-US 0.51
    FA :  Ts-SB 0.87   Ts-US 0.77   SB-US 0.83
"""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
CODES = {"US": ("PRO","BOS","CAM"), "SB": ("SBO","SNB","SBJ"),
         "Ts": ("NVM","MAJ","MAN","NUM","NUV","CVR")}
COND = "Industrial-Nature"   # Natural sounds
SCREEN = 1.5                  # old passing d'
MINTRIALS = 0                # old: no finished-session filter
rng = np.random.default_rng(0)
OLD = {("hit","Ts","SB"):0.95, ("hit","Ts","US"):0.36, ("hit","SB","US"):0.51,
       ("fa","Ts","SB"):0.87, ("fa","Ts","US"):0.77, ("fa","SB","US"):0.83}


def load(g):
    h,f,it = build_hit_fa_matrices(list_matfiles(BASE, CODES[g], COND, SCREEN, False, MINTRIALS))
    return h, f, list(it)


def splithalf(mat, nsplit=300):
    n = mat.shape[0]; rs=[]
    for _ in range(nsplit):
        idx=rng.permutation(n); a,b=idx[:n//2],idx[n//2:]
        with np.errstate(invalid="ignore"):
            va,vb=np.nanmean(mat[a],0),np.nanmean(mat[b],0)
        m=np.isfinite(va)&np.isfinite(vb)
        if m.sum()>=5: rs.append(spearmanr(va[m],vb[m]).correlation)
    r=np.nanmedian(rs); return (2*r)/(1+r) if np.isfinite(r) else np.nan


G = {g: load(g) for g in CODES}
print("N per group (screen=%.1f, no finished filter):" % SCREEN,
      {g: G[g][0].shape[0] for g in CODES})
print(f"\n{'meas':<5}{'pair':<8}{'N_items':>8}{'r_obs':>8}{'relA':>6}{'relB':>6}"
      f"{'r*':>7}{'old':>7}")
PAIRS = [("Ts","SB"),("Ts","US"),("SB","US")]
for mk,idx in [("hit",0),("fa",1)]:
    for a,b in PAIRS:
        hA = G[a][idx]; hB = G[b][idx]; itA=G[a][2]; itB=G[b][2]
        with np.errstate(invalid="ignore"):
            dA=dict(zip(itA,np.nanmean(hA,0))); dB=dict(zip(itB,np.nanmean(hB,0)))
        sh=[k for k in dA if k in dB and np.isfinite(dA[k]) and np.isfinite(dB[k])]
        x=np.array([dA[k] for k in sh]); y=np.array([dB[k] for k in sh])
        r=spearmanr(x,y).correlation
        relA,relB=splithalf(hA),splithalf(hB)
        rstar=r/np.sqrt(relA*relB) if relA>0 and relB>0 else np.nan
        print(f"{mk:<5}{a+'-'+b:<8}{len(sh):>8}{r:>8.2f}{relA:>6.2f}{relB:>6.2f}"
              f"{rstar:>7.2f}{OLD[(mk,a,b)]:>7.2f}")
    print()
