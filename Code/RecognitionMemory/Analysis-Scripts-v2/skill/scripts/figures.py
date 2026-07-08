#!/usr/bin/env python3
"""House-style figure helpers for the cross-cultural recognition-memory analysis.

Group colors, labels, the U-shape pair ordering (most-distant pair CENTERED), and
an automatic UNFILTERED banner when no catch screen was applied. Import and reuse
so every figure in the chapter matches.
"""
from __future__ import annotations
import numpy as np

# --- fixed identities for THIS dataset ---
GROUP_CODES = {"US": ("PRO", "BOS", "CAM"),
               "SanBorja": ("SBO", "SNB", "SBJ"),
               "Tsimane": ("NVM", "MAJ", "MAN", "NUM", "NUV", "CVR")}
GLAB = {"US": "U.S.", "SanBorja": "San Borja", "Tsimane": "Tsimane'"}
GCOL = {"US": "#1f77b4", "SanBorja": "#ff7f0e", "Tsimane": "#2E7D32"}
MEASURE_COL = {"hit": "#2E7D32", "fa": "#C62828", "cr": "#7E57C2"}
CONDS = [("Industrial-Nature", "Environmental"),
         ("Globalized-Music", "Music"),
         ("NHS", "World song")]
# center column/point = most culturally distant pair so a dip reads as a U
PAIRS_U = [("US", "SanBorja"), ("US", "Tsimane"), ("SanBorja", "Tsimane")]

UNFILTERED_NOTE = r"UNFILTERED: all participants, no d$'\geq$2 catch-trial screen applied"
RSTAR_NOTE = (r"r = observed Spearman;  r* = corrected for attenuation "
              r"(r / $\sqrt{\rho_A\,\rho_B}$, split-half reliabilities)")


def suptitle(fig, title, screened=True, **kw):
    """Suptitle that appends the UNFILTERED banner when screened=False."""
    txt = title if screened else title + "\n" + UNFILTERED_NOTE
    fig.suptitle(txt, fontweight="bold", **kw)


def annotate_r(ax, r, rstar=None):
    ax.text(0.05, 0.90, f"r = {r:.2f}", transform=ax.transAxes,
            fontsize=12, fontweight="bold", color="#212121")
    if rstar is not None and np.isfinite(rstar):
        ax.text(0.05, 0.80, f"r* = {rstar:.2f}", transform=ax.transAxes,
                fontsize=10, color="#1565C0")


def diagonal(ax):
    ax.plot([0, 1], [0, 1], ls=":", color="#bbb", lw=1)
    ax.set_xlim(-0.03, 1.03)
    ax.set_ylim(-0.03, 1.03)
    ax.set_aspect("equal")


def rstar_footnote(fig):
    fig.text(0.5, 0.005, RSTAR_NOTE, ha="center", fontsize=8.5, color="#444")
