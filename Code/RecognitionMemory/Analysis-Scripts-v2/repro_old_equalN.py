#!/usr/bin/env python3
"""Reproduce the OLD slide EXACTLY, in the new code, including the equal-N fill-in
resampling from intergroupCorrelationBootstrap.m.

Recipe: d'>=1.5, no finished filter. Per bootstrap: draw minParticipants (=smaller
group N) participants with replacement from each group; per item take the sampled
non-NaN responses and, if fewer than minParticipants, FILL by resampling existing
responses up to minParticipants; per-item mean; Spearman across items. The bar =
mean of the bootstrap r, then disattenuated by split-half reliability. This fill-in
step injects noise into the sparse HIT channel and drives its correlation down.
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
COND, SCREEN, NBOOT = "Industrial-Nature", 1.5, 300
rng = np.random.default_rng(0)
OLD = {("hit","Ts","SB"):0.95,("hit","Ts","US"):0.36,("hit","SB","US"):0.51,
       ("fa","Ts","SB"):0.87,("fa","Ts","US"):0.77,("fa","SB","US"):0.83}


def load(g):
    h,f,it = build_hit_fa_matrices(list_matfiles(BASE, CODES[g], COND, SCREEN, False, 0))
    return h, f, list(it)


def splithalf(mat, nsplit=200):
    n=mat.shape[0]; rs=[]
    for _ in range(nsplit):
        idx=rng.permutation(n); a,b=idx[:n//2],idx[n//2:]
        with np.errstate(invalid="ignore"):
            va,vb=np.nanmean(mat[a],0),np.nanmean(mat[b],0)
        m=np.isfinite(va)&np.isfinite(vb)
        if m.sum()>=5: rs.append(spearmanr(va[m],vb[m]).correlation)
    r=np.nanmedian(rs); return (2*r)/(1+r) if np.isfinite(r) else np.nan


def align(matA, itA, matB, itB):
    ib={it:i for i,it in enumerate(itB)}
    sh=[it for it in itA if it in ib]
    ia={it:i for i,it in enumerate(itA)}
    return matA[:,[ia[i] for i in sh]], matB[:,[ib[i] for i in sh]]


def equalN_boot_mean(matA, matB):
    A,B = matA, matB
    nA,nB = A.shape[0], B.shape[0]; nItems=A.shape[1]
    minP = min(nA,nB)
    rs=[]
    for _ in range(NBOOT):
        sA=A[rng.integers(0,nA,minP)]; sB=B[rng.integers(0,nB,minP)]
        mA=np.full(nItems,np.nan); mB=np.full(nItems,np.nan)
        for j in range(nItems):
            va=sA[:,j]; va=va[~np.isnan(va)]
            vb=sB[:,j]; vb=vb[~np.isnan(vb)]
            if 0<len(va)<minP: va=np.concatenate([va, rng.choice(va, minP-len(va))])
            if 0<len(vb)<minP: vb=np.concatenate([vb, rng.choice(vb, minP-len(vb))])
            if len(va) and len(vb): mA[j]=va.mean(); mB[j]=vb.mean()
        m=~np.isnan(mA)&~np.isnan(mB)
        if m.sum()>=3: rs.append(spearmanr(mA[m],mB[m]).correlation)
    return np.nanmean(rs)


G={g:load(g) for g in CODES}
print("N per group:", {g:G[g][0].shape[0] for g in CODES}, "\n")
print(f"{'meas':<5}{'pair':<8}{'r_boot_mean':>12}{'relA':>6}{'relB':>6}{'r*_disatt':>11}{'old':>7}")
for mk,idx in [("hit",0),("fa",1)]:
    for a,b in [("Ts","SB"),("Ts","US"),("SB","US")]:
        MA,MB = align(G[a][idx],G[a][2], G[b][idx],G[b][2])
        rb = equalN_boot_mean(MA,MB)
        relA,relB = splithalf(G[a][idx]), splithalf(G[b][idx])
        rstar = rb/np.sqrt(relA*relB) if relA>0 and relB>0 else np.nan
        print(f"{mk:<5}{a+'-'+b:<8}{rb:>12.2f}{relA:>6.2f}{relB:>6.2f}{rstar:>11.2f}{OLD[(mk,a,b)]:>7.2f}")
    print()
