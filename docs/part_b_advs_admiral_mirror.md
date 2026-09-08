# Part B: ADVS Admiral 1:1 mirror

**Approach:** Pure reverse-engineering of the Admiral ADVS R template. SAS macros are called in the **same order** as R functions. Semantics follow each R function’s contract — **not** PVA REF-tuned BASE rules.

## R template used

| Source | Path |
|--------|------|
| Local copy | `SAS/R/admiral_templates/ad_advs.R` |
| Upstream | https://github.com/pharmaverse/admiral/blob/main/inst/templates/ad_advs.R |

## Ordered R → SAS map

| # | R (`ad_advs.R`) | SAS macro | Status |
|---|-----------------|-----------|--------|
| 0 | `convert_blanks_to_na(vs)` | `%m_adm_convert_blanks_to_na` | real |
| 1 | `derive_vars_merged` (ADSL TRT*) | `%m_adm_derive_vars_merged` | real |
| 2 | `derive_vars_dt` (VSDTC → ADT) | `%m_adm_derive_vars_dt` | real |
| 3 | `derive_vars_dy` (ADT vs TRTSDT) | `%m_adm_derive_vars_dy` | real |
| 4 | `derive_vars_merged_lookup` (PARAMCD) | `%m_adm_derive_vars_merged_lookup` | real |
| 5 | `mutate(AVAL)` | `%m_adm_advs_mutate_aval` | real |
| 6 | `derive_param_map` | `%m_adm_derive_param_map` | real (mirror-safe computed; PARAMCD only) |
| 7 | `derive_param_bsa` | `%m_adm_derive_param_bsa` | real |
| 8 | `derive_param_bmi` | `%m_adm_derive_param_bmi` | real |
| 9 | `mutate` timing | `%m_adm_advs_mutate_timing` | real |
| 10 | `derive_summary_records` AVERAGE | `%m_adm_derive_summary_records` | real (`where not missing(AVAL)`, `n≥1`) |
| 11 | `derive_var_ontrtfl` | `%m_adm_derive_var_ontrtfl` | real (`ref_end_window=0`) |
| 12 | `derive_vars_merged` ranges | `%m_adm_derive_vars_merged` | real (ANRLO/HI + A1LO/HI) |
| 13 | `derive_var_anrind` | `%m_adm_derive_var_anrind` | real (ANRLO/HI path only) |
| 14 | `derive_basetype_records` | `%m_adm_derive_basetype_map` | real (ATPTN 815/816/817 / LAST) |
| 15 | `restrict_derivation` ABLFL | `%m_adm_restrict_extreme_flag` | real (blank DTYPE, `ADT<=TRTSDT`) |
| 16 | `derive_var_base` BASE | `%m_adm_derive_var_base` | real |
| 17 | `derive_var_base` BNRIND | `%m_adm_derive_var_base` | real |
| 18–19 | `restrict_derivation` CHG/PCHG | `%m_adm_restrict_derive_var_chg` / `_pchg` | real |
| 20 | `restrict_derivation` ANL01FL | `%m_adm_restrict_extreme_flag` | real |
| 21 | `derive_extreme_records` LOV | `%m_adm_derive_extreme_records` | real (**COUNT**) |
| 22 | `mutate(TRTP, TRTA)` | `%m_adm_mutate_trt` | real |
| 23 | `derive_var_obs_number` ASEQ | `%m_adm_derive_var_obs_number` | real |
| 24 | `derive_vars_cat` HEIGHT | `%m_adm_advs_derive_vars_cat` | real |
| 25 | `derive_vars_merged` PARAM/PARAMN | `%m_adm_derive_vars_merged` | real |
| 26 | `derive_vars_merged` rest ADSL | `%m_adm_derive_vars_merged` | **partial** (SUBJID/SITEID) |

## Long R name → short SAS name

| R function | SAS macro (≤32) |
|------------|-----------------|
| `restrict_derivation(derive_var_extreme_flag)` | `%m_adm_restrict_extreme_flag` |
| `derive_extreme_records` | `%m_adm_derive_extreme_records` |
| `derive_basetype_records` (multi) | `%m_adm_derive_basetype_map` |
| `derive_param_computed` (mirror-safe) | `%m_adm_derive_param_computed` |

## SET_ASSIGN / Part A note

Part A `%m_derive_param_computed` + `%m_derive_param_map/bmi/bsa` can fail when `PARAM=` values contain spaces (pipe/`SET_ASSIGN` parsing). The mirror uses **`%m_adm_derive_param_*`** which sets **PARAMCD only** (matching `ad_advs.R`), then merges PARAM/PARAMN from the lookup — Part A is untouched.

## Gaps / approximations

| Topic | Note |
|-------|------|
| Full ADSL re-merge | SUBJID/SITEID only |
| `derive_var_anrind` A1LO/A1HI | Vars merged; indicator uses ANRLO/HI only |
| `check_type="error"` on ASEQ | Not hard ERROR |
| Unit asserts on map/bsa/bmi | Skipped |

## Files

| File | Role |
|------|------|
| `SAS/macro/admiral/m_adm_common_ports.sas` | Shared `%m_adm_*` (dt, param_*, extreme, basetype map, …) |
| `SAS/macro/admiral/m_adm_advs_ports.sas` | ADVS glue mutates / cat |
| `SAS/macro/m_advs_admiral_mirror.sas` | Driver in R call order |
| `SAS/R/admiral_templates/ad_advs.R` | Vendored template |
| `SAS/docs/part_b_advs_admiral_mirror.md` | This doc |

## Create / QC on ODA

1. Upload Part B tree (see `_oda_upload_advs_adlb_mirror/UPLOAD_CHECKLIST.txt`).
2. Run `SAS/programs/create_ADaM_pva_oda.sas` — ADVS uses mirror when `&ADVS_BUILDER=mirror` (default).
3. QC: `SAS/programs/proc_compare_advs_vs_ref_oda.sas`.

Legacy:

```sas
%let ADVS_BUILDER=pva;
```
