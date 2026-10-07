# test_that_equivalent_sas_macros

Scaffold for porting the `test_that()` coverage in
[pharmaverse/admiral `tests/testthat`](https://github.com/pharmaverse/admiral/tree/main/tests/testthat)
to SAS equivalents. This folder currently holds the **inventory and plan only**; no SAS ports are
implemented yet.

## Layout

```
test_that_equivalent_sas_macros/
├── README.md
├── mapping/
│   ├── test_inventory.csv      # one row per test_that() block (generated)
│   └── test_porting_plan.md    # tiering / prioritisation
└── tools/
    └── build_test_inventory.py # regenerates the inventory
```

## Workflow: inventory -> porting

1. Regenerate the inventory (below) when admiral changes.
2. Pick `todo` rows by tier (see `mapping/test_porting_plan.md`).
3. Port using the existing helpers in `macros/m_golden_assert.sas`
   (`%m_golden_assert_char`, `%m_golden_assert_num`, `%m_golden_assert_from_ds`,
   `%m_golden_summary`); do not modify them. Keep case IDs as `<function> Test N`.
4. Set `sas_port_status` (`todo`, `done`, `n/a`, `needs_review`) and `sas_notes` in the CSV.
   Existing `macros/m_*_admiral_mirror.sas` macros may already cover some functions.

## Regenerating the inventory

```
git clone --depth 1 https://github.com/pharmaverse/admiral /tmp/admiral
python3 test_that_equivalent_sas_macros/tools/build_test_inventory.py /tmp/admiral
```

Requires Python 3 only. Note that regeneration overwrites the CSV, including manually edited
`sas_port_status`/`sas_notes` values; commit or merge those edits before re-running.

## CSV columns

`r_file`, `r_test_name`, `r_line_start`, `r_line_end`, `r_category`
(core_infrastructure, compute, date_time, derive_var, derive_vars, derive_param,
record_filter_dataset_creation), `r_expectation_type` (first of snapshot/error/warning/message/
dfs_equal/equal/identical found in the block, else other expectation or `other`),
`r_function_under_test` (nearest preceding `# fn ----` comment, else name prefix, else file name),
`porting_tier`, `sas_port_status`, `sas_notes`.

Classification is heuristic; review `other` rows manually.
