# Part B: ADLB Admiral 1:1 mirror

**Approach:** Pure reverse-engineering of the Admiral ADLB R template. SAS macros are called in the **same order** as R functions. Semantics follow each R function’s contract — **not** PVA REF-tuned BASE rules.

## R template used

| Source | Path |
|--------|------|
| Local copy | `SAS/R/admiral_templates/ad_adlb.R` |
| Upstream | https://github.com/pharmaverse/admiral/blob/main/inst/templates/ad_adlb.R |

## Ordered R → SAS map

| # | R (`ad_adlb.R`) | SAS macro | Status |
|---|-----------------|-----------|--------|
| 0 | `convert_blanks_to_na(lb)` | `%m_adm_convert_blanks_to_na` | real |
| 1 | `derive_vars_merged` (ADSL TRT*) | `%m_adm_derive_vars_merged` | real |
| 2 | `derive_vars_dt` (LBDTC → ADT) | `%m_adm_derive_vars_dt` | real |
| 3 | `derive_vars_dy` | `%m_adm_derive_vars_dy` | real |
| 4 | `derive_vars_merged_lookup` PARAM* | `%m_adm_derive_vars_merged_lookup` | real |
| 5 | `mutate` PARCAT1/AVAL/AVALC/ANR* | `%m_adm_adlb_mutate_aval` | real |
| 6 | `derive_param_wbc_abs` BASO | `%m_adm_derive_param_wbc_abs` + patch | real (skip-if-exists) |
| 7 | `derive_param_wbc_abs` LYMPH | `%m_adm_derive_param_wbc_abs` + patch | real |
| 8 | `mutate` timing (SCREEN→Baseline) | `%m_adm_adlb_mutate_timing` | real |
| 9 | `derive_var_ontrtfl` | `%m_adm_derive_var_ontrtfl` | real |
| 10 | `derive_var_anrind` | `%m_adm_derive_var_anrind` | real |
| 11 | `mutate(BASETYPE="LAST")` | `%m_adm_derive_basetype_map` mode=LAST | real |
| 12 | `restrict_derivation` ABLFL | `%m_adm_restrict_extreme_flag` | real |
| 13–15 | `derive_var_base` BASE/BASEC/BNRIND | `%m_adm_derive_var_base` | real |
| 16–17 | `restrict_derivation` CHG/PCHG | `%m_adm_restrict_derive_var_chg` / `_pchg` | real |
| 18 | `derive_vars_merged` grade_lookup | `%m_adm_adlb_merge_grade_lookup` | real (labels only) |
| 19–21 | `derive_var_atoxgr_dir` / `atoxgr` / BTOX* | `%m_adm_adlb_stub_atoxgr` | **STUB** (WARNING) |
| 22–24 | `derive_var_analysis_ratio` ×3 | `%m_adm_derive_var_analysis_ratio` | real |
| 25 | `derive_var_shift` SHIFT1 | `%m_adm_derive_var_shift` | real |
| 26 | `restrict_derivation` SHIFT2 | skipped | **STUB** (needs ATOXGR) |
| 27 | `restrict_derivation` ANL01FL | `%m_adm_restrict_extreme_flag` | real |
| 28 | `restrict_derivation` LVOTFL | `%m_adm_restrict_extreme_flag` | real |
| 29 | `mutate(TRTP, TRTA)` | `%m_adm_mutate_trt` | real |
| 30 | `derive_extreme_records` MINIMUM | `%m_adm_derive_extreme_records` | real (**COUNT**) |
| 31 | `derive_extreme_records` MAXIMUM | `%m_adm_derive_extreme_records` | real (**COUNT**) |
| 32 | `derive_extreme_records` LOV | `%m_adm_derive_extreme_records` | real (**COUNT**) |
| 33 | `derive_var_obs_number` ASEQ | `%m_adm_derive_var_obs_number` | real |
| 34 | `derive_vars_merged` rest ADSL | `%m_adm_derive_vars_merged` | **partial** |

## Long R name → short SAS name

| R function | SAS macro (≤32) |
|------------|-----------------|
| `derive_param_wbc_abs` | `%m_adm_derive_param_wbc_abs` |
| `derive_var_analysis_ratio` | `%m_adm_derive_var_analysis_ratio` |
| `derive_extreme_records` | `%m_adm_derive_extreme_records` |

## COUNT-critical vs stubs

**Real (affects row count):** WBC abs (when abs missing), MINIMUM / MAXIMUM / LOV extreme records, ANL01FL/LVOTFL (flags only).

**Stub (value gaps, not primary COUNT):** CTCv4 `derive_var_atoxgr_dir` / `derive_var_atoxgr` / BTOX* baselines, SHIFT2.

## Files

| File | Role |
|------|------|
| `SAS/macro/admiral/m_adm_common_ports.sas` | Shared ports |
| `SAS/macro/admiral/m_adm_adlb_ports.sas` | ADLB glue / grade lookup / ATOX stub |
| `SAS/macro/m_adlb_admiral_mirror.sas` | Driver in R call order |
| `SAS/R/admiral_templates/ad_adlb.R` | Vendored template |
| `SAS/docs/part_b_adlb_admiral_mirror.md` | This doc |

## Create / QC on ODA

1. Upload Part B tree (see `_oda_upload_advs_adlb_mirror/UPLOAD_CHECKLIST.txt`).
2. Run `create_ADaM_pva_oda.sas` — ADLB uses mirror when `&ADLB_BUILDER=mirror` (default).
3. QC: `SAS/programs/proc_compare_adlb_vs_ref_oda.sas`.

Legacy:

```sas
%let ADLB_BUILDER=pva;
```
