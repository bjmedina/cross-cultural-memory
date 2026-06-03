"""Cross-cultural recognition memory statistics — Python twin of MATLAB stats/.

Mirrors the MATLAB pipeline 1:1 (split-half reliability, intergroup itemwise
correlations with bootstrap CIs, paired-bootstrap comparison of three group
pairs with both p-value variants, and the small-N power simulation).

See ../STATS.md for the methods specification.
"""

from . import _utils
from . import ci_methods
from . import split_half
from . import intergroup_corr
from . import paired_bootstrap
from . import power_simulation
from . import io

from .split_half import (
    estimate_split_half_flexible,
    split_half_sb,
    calculate_split_half_reliability,
)
from .ci_methods import ci_percentile, ci_fisher_z, ci_bca, all_cis
from .intergroup_corr import (
    itemwise_corr,
    bootstrap_intergroup_correlation_sem,
    jackknife_intergroup_corr,
)
from .paired_bootstrap import paired_bootstrap_compare_correlations
from .power_simulation import power_simulation_paired_bootstrap
from .io import list_matfiles, build_hit_fa_matrices, load_group

__all__ = [
    "estimate_split_half_flexible",
    "split_half_sb",
    "calculate_split_half_reliability",
    "ci_percentile",
    "ci_fisher_z",
    "ci_bca",
    "all_cis",
    "itemwise_corr",
    "bootstrap_intergroup_correlation_sem",
    "jackknife_intergroup_corr",
    "paired_bootstrap_compare_correlations",
    "power_simulation_paired_bootstrap",
    "list_matfiles",
    "build_hit_fa_matrices",
    "load_group",
]
