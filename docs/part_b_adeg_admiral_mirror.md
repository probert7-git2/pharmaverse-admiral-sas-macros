# Part B: ADEG Admiral 1:1 mirror

**Approach:** Pure reverse-engineering of the Admiral ADEG R template. SAS macros are called in the **same order** as R functions. Semantics follow each R function’s contract / source — **not** PVA REF-tuned BASE rules, and **not** a six-screening-mean special case (the template does not implement that).

## R template used

| Source | Path |
|--------|------|
| Local copy | `SAS/R/admiral_templates/ad_adeg.R` |
| Upstream | https://github.com/pharmaverse/admiral/blob/main/inst/templates/ad_adeg.R |
| Also found on disk | `C:\Users\probe\Downloads\ad_adeg.R` |

pharmaverseadam ADEG is produced by running this admiral template (see pharmaverseadam `data-raw/create_adams_data.R`).

## Finding: PVA ADEG and SAS ADEG are not built from the same EG

PVA gold (`pharmaverseadam::adeg` / `ref_pva.refadeg`) was built from **`pharmaversesdtm::eg`**. SAS ADEG is built from **Track A `raw.eg`** (`safety_monitoring_system/SAS/sdtm`). Both ADaM programs copy SDTM `EG*` columns verbatim. They can still disagree when the two EG files disagree.

QC (25AUG2026): analysis keys and `A*` timing (`ATPT`/`ATPTN`) pair. Remaining PROC COMPARE noise on **`EGTPT`** and **`EGSTRESU`** is that source difference:

| Variable | PVA (from `pharmaversesdtm::eg`) | SAS (from Track A `raw.eg`) |
|----------|----------------------------------|-----------------------------|
| `EGTPTNUM` | 815 / 816 / 817 | same |
| `EGTPT` | planned time-point **name** (`AFTER LYING DOWN FOR 5 MINUTES`, …) | planned time-point **code** (`1`, `2`, `3`) |
| `EGSTRESU` | mixed-case (`beats/min`) | upcase (`BEATS/MIN`) |

`ad_adeg.R` sets `ATPT = EGTPT` and does **not** decode `EGTPTNUM`. SAS ADEG does not recode `EGTPT` either. Do not “fix” `EG*` in ADEG to match PVA — that would invent SDTM on the ADaM. Treat leftover `EG*` diffs as **SDTM-source POLICY**, not an ADEG mirror miss. `ATPT` is ADaM and may use the 815/816/817 labels.

## Ordered R → SAS map

| # | R (`ad_adeg.R`) | SAS macro | Status |
|---|-----------------|-----------|--------|
| 0 | `convert_blanks_to_na(eg)` | `%m_adm_convert_blanks_to_na` | real |
| 1 | `derive_vars_merged` (ADSL TRT*) | `%m_adm_derive_vars_merged` | real (wrap Part A) |
| 2 | `derive_vars_dtm` (EGDTC → A*) | `%m_adm_derive_vars_dtm` | real (wrap Part A) |
| 3 | `derive_vars_dy` (ADTM vs TRTSDT) | `%m_adm_derive_vars_dy` | real (wrap Part A) |
| 4 | `derive_vars_merged_lookup` (PARAMCD) | `%m_adm_derive_vars_merged_lookup` | real (wrap Part A) |
| 5 | `mutate(AVAL, AVALC)` | `%m_adm_adeg_mutate_aval` | real (template glue) |
| 6 | `derive_param_rr` | `%m_adm_derive_param_rr` | real (via Part A computed) |
| 7–9 | `derive_param_qtc` ×3 | `%m_adm_derive_param_qtc` | real (Bazett/Fridericia/Sagie) |
| 10 | `mutate` timing | `%m_adm_adeg_mutate_timing` | real (template glue) |
| 11 | `derive_summary_records` | `%m_adm_derive_summary_records` | real (mean + DTYPE=AVERAGE, n≥2) |
| 12 | `derive_var_ontrtfl` | `%m_adm_derive_var_ontrtfl` | real (+ `filter_pre_timepoint`) |
| 13 | `derive_vars_merged` (ANRLO/HI) | `%m_adm_derive_vars_merged` | real |
| 14 | `derive_var_anrind` | `%m_adm_derive_var_anrind` | real (ANRLO/HI path) |
| 15 | `derive_basetype_records` | `%m_adm_derive_basetype_records` | real (constant TRUE basetype) |
| 16 | `restrict_derivation(derive_var_extreme_flag)` ABLFL | `%m_adm_restrict_extreme_flag` | real (keeps all rows) |
| 17–19 | `derive_var_base` BASE/BASEC/BNRIND | `%m_adm_derive_var_base` | real (wrap Part A) |
| 20–21 | `restrict_derivation(derive_var_chg/pchg)` | `%m_adm_restrict_derive_var_chg` / `_pchg` | real |
| 22 | `restrict_derivation` ANL01FL | `%m_adm_restrict_extreme_flag` | real |
| 23 | `mutate(TRTP, TRTA)` | `%m_adm_adeg_mutate_trt` | real |
| 24 | `derive_var_obs_number` ASEQ | `%m_adm_derive_var_obs_number` | real |
| 25–26 | `derive_vars_cat` | `%m_adm_derive_vars_cat` | real (ADEG QT lookups) |
| 27 | `derive_vars_merged` PARAM/PARAMN | `%m_adm_derive_vars_merged` | real |
| 28 | `derive_vars_merged` rest of ADSL | `%m_adm_derive_vars_merged` | **partial** (SUBJID/SITEID only — full ADSL column set not mirrored) |

No intentional stubs with `%put WARNING: stub` in the critical path. Known **gaps / approximations**:

| Topic | Note |
|-------|------|
| Full ADSL re-merge | Template merges all ADSL vars except those already joined; SAS port only adds SUBJID/SITEID. |
| `get_unit_expr` / unit asserts | R `derive_param_rr`/`qtc` assert units; SAS ports skip asserts. |
| `check_type="error"` on ASEQ | Not enforced as hard ERROR on duplicate keys. |
| `derive_var_anrind` | ANRLO/ANRHI only (no A1LO/A1HI branch). |
| Part A `derive_param_computed` | New rows keep only `by_vars` + PARAMCD/PARAM/AVAL — aligns with admiral note on param derives. |
| `%m_order_vars_like_ref` | Presentation only; not an Admiral step. |

## How BASE maps to R calls (template only)

From `ad_adeg.R` literally:

1. **`derive_summary_records`** — append rows with `AVAL = mean(AVAL)`, `DTYPE = "AVERAGE"` when `n() >= 2` and `PARAMCD != "EGINTP"`, by subject/param/visit-date keys in the template.
2. **`derive_basetype_records`** — `BASETYPE = "BASELINE DAY 1"` when condition is `TRUE` for all rows.
3. **`restrict_derivation(derive_var_extreme_flag)`** — `ABLFL` on last row (by `ADT, VISITNUM, EGSEQ`) among rows matching the template filter: non-missing AVAL/AVALC, `ADT <= TRTSDT`, non-missing BASETYPE, `DTYPE == "AVERAGE"`, `PARAMCD != "EGINTP"`.
4. **`derive_var_base`** — broadcast `AVAL` (and AVALC/ANRIND) from `ABLFL = 'Y'` by `STUDYID, USUBJID, PARAMCD, BASETYPE`.

There is **no** template call that means “BASE = mean of six screenings.” Any such rule would be outside the R mirror.

## Files created

| File | Role |
|------|------|
| `SAS/macro/admiral/m_adm_adeg_ports.sas` | `%m_adm_*` ports |
| `SAS/macro/m_adeg_admiral_mirror.sas` | Driver in R call order |
| `SAS/R/admiral_templates/ad_adeg.R` | Vendored template |
| `SAS/docs/part_b_adeg_admiral_mirror.md` | This doc |
| `SAS/programs/create_ADaM_pva_oda.sas` | ADEG hook → mirror by default |

## Create / QC on ODA

1. Upload Part B tree (especially `macro/admiral/`, `m_adeg_admiral_mirror.sas`, updated create).
2. Ensure Track A macros still available (create `%include`s them read-only).
3. Run `SAS/programs/create_ADaM_pva_oda.sas` — ADEG uses `%m_adeg_admiral_mirror` when `&ADEG_BUILDER=mirror` (default).
4. QC: `SAS/programs/proc_compare_adeg_vs_ref_oda.sas` and/or `run_qc_compare_pva_oda.sas`.

To use the approximate legacy builder instead:

```sas
%let ADEG_BUILDER=pva;
```

before the create driver runs (or edit the default in create).

## Selection vs `%m_adeg_pva`

| Builder | File | Invoked by create? |
|---------|------|--------------------|
| **Mirror (default)** | `m_adeg_admiral_mirror.sas` + `admiral/m_adm_adeg_ports.sas` | Yes when `ADEG_BUILDER=mirror` |
| Legacy approximate | `m_adeg_pva.sas` | Only when `ADEG_BUILDER=pva` |

Both files remain. Only one writes `adam.adeg` per create run.
