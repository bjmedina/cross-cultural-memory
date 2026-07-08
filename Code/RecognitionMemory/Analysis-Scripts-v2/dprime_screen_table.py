#!/usr/bin/env python3
"""Table of observed r and disattenuated r* for every condition x pair x measure,
as a function of the passing d' (ISI=0 catch) criterion. Clean split-half
reliability, no fill-in. Finished sessions only. Cells shown as 'r (r*)'."""
import sys
from pathlib import Path
import numpy as np
from scipy.stats import spearmanr

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from python.io import list_matfiles, build_hit_fa_matrices  # noqa: E402

BASE = HERE.parents[2] / "Data" / "RecognitionMemory" / "Results"
CODES = {"US": ("PRO","BOS","CAM"), "SanBorja": ("SBO","SNB","SBJ"),
         "Tsimane": ("NVM","MAJ","MAN","NUM","NUV","CVR")}
CONDS = [("Industrial-Nature","Env"),("Globalized-Music","Music"),("NHS","World")]
PAIRS = [("US","SanBorja","US-SB"),("US","Tsimane","US-Ts"),("SanBorja","Tsimane","SB-Ts")]
SCREENS = [0.0, 1.0, 1.5, 2.0, 2.5]
rng = np.random.default_rng(0)
_c = {}


def mats(g, cond, s):
    k=(g,cond,s)
    if k not in _c: _c[k]=build_hit_fa_matrices(list_matfiles(BASE, CODES[g], cond, s, False))
    return _c[k]


def splithalf(mat, nsplit=150):
    n=mat.shape[0]; rs=[]
    for _ in range(nsplit):
        idx=rng.permutation(n); a,b=idx[:n//2],idx[n//2:]
        with np.errstate(invalid="ignore"):
            va,vb=np.nanmean(mat[a],0),np.nanmean(mat[b],0)
        m=np.isfinite(va)&np.isfinite(vb)
        if m.sum()>=5: rs.append(spearmanr(va[m],vb[m]).correlation)
    r=np.nanmedian(rs); return (2*r)/(1+r) if np.isfinite(r) else np.nan


def rr(cond,a,b,s,idx):
    A=mats(a,cond,s); B=mats(b,cond,s)
    with np.errstate(invalid="ignore"):
        dA=dict(zip(A[2],np.nanmean(A[idx],0))); dB=dict(zip(B[2],np.nanmean(B[idx],0)))
    sh=[k for k in dA if k in dB and np.isfinite(dA[k]) and np.isfinite(dB[k])]
    x=np.array([dA[k] for k in sh]); y=np.array([dB[k] for k in sh])
    r=spearmanr(x,y).correlation
    relA,relB=splithalf(A[idx]),splithalf(B[idx])
    rs=r/np.sqrt(relA*relB) if relA>0 and relB>0 else np.nan
    return r, rs


for idx,mlab in [(0,"HIT RATE"),(1,"FA RATE")]:
    print(f"\n===== {mlab}:  observed r  (disattenuated r*) =====")
    print(f"{'cond':<7}{'pair':<7}" + "".join(f"{'d>='+str(s):>16}" for s in SCREENS))
    for cond,clab in CONDS:
        for a,b,plab in PAIRS:
            cells=[]
            for s in SCREENS:
                r,rs=rr(cond,a,b,s,idx); cells.append(f"{r:.2f} ({rs:.2f})")
            print(f"{clab:<7}{plab:<7}" + "".join(f"{c:>16}" for c in cells))
        print()
