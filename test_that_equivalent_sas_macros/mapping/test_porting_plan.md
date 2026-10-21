# Test porting plan

The `porting_tier` column in `test_inventory.csv` is a heuristic starting point.

## Tier 1: scalar / simple checks
`dt_level`, `compute_*`, `convert_xxtpt_to_hours`, `transform_range`. Scalar inputs and outputs;
port with `%m_golden_assert_num` / `%m_golden_assert_char`. Start with `dt_level`, then `compute_*`.

## Tier 2: dataset comparison checks
`derive_var_*`, `derive_vars_*`, `derive_param_*`, date/time derivations, record derivations,
filters and dataset creation using `expect_dfs_equal` / `expect_equal` on small tibbles.
Port with `%m_golden_assert_from_ds` (PROC COMPARE). Prefer derive_var_* tests that compare a
single column or a small dataset first.

## Tier 3: complex / R-specific / maybe not portable
All core-infrastructure tests (`call_derivation`, `restrict_derivation`, `slice_derivation`,
`event`, `admiral_options`, `admiral_df`, ...) and any test using `expect_snapshot`,
`expect_error`, `expect_warning` or `expect_message`. Error/warning tests can be approximated by
asserting an error flag and message text (not an exact snapshot port); R-specific ones (S3 classes,
`exprs()`, function-valued arguments) may be marked `n/a`.

## Status values
`todo`, `done`, `n/a`, `needs_review`.
