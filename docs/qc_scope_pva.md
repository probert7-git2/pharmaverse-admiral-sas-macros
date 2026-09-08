# Track B QC scope — Pharmaverseadam (PVA) gold

**PVA** = **pharmaverseadam** (R package). Gold lib: `ref_pva` → `validation/`.  
Gold members from user **proc copy** of `ref*.xpt`: **REFADSL, REFADAE, REFADCM, REFADVS, REFADEG, REFADLB** (Unix ODA often stores as lowercase `refadsl`, …).

## What is compared (current)

| Domain | Keys | Tiebreak / note |
|--------|------|-----------------|
| ADSL | USUBJID (`keysrc=CALLER`) | Builder SORTEDBY: STUDYID USUBJID (PVA Key Variables / `adsl` sorted by USUBJID) |
| ADAE | USUBJID ASTDT AEDECOD ASEV AESEQ (`keysrc=CALLER`) | Full OCCDS natural key (every row). Builder PROC SORT matches. Force CALLER so adam SORTEDBY cannot drop ASEV/AESEQ (prior digest `METADATA` without them). |
| ADVS | USUBJID PARAMN AVISITN ADT VSSEQ (`keysrc=CALLER`) | BDS display/sort includes PARAM/AVISIT. PARAMN↔PARAMCD and AVISITN↔AVISIT are 1:1 on PVA gold. No ADTM on gold. |
| ADEG | USUBJID PARAMN AVISITN ADT EGSEQ (`keysrc=CALLER`) | Same pattern; builder also keeps/sorts **ADTM** (from EGDTC; gold ADTM may be date-scale). EGSEQ final. Expect **POLICY** on `ms` vs `msec`. |
| ADCM | USUBJID ASTDT CMDECOD CMSEQ (`keysrc=CALLER`) | OCCDS — **no PARAMN**. Keep ASTDT/CMDECOD/CMSEQ. |
| ADLB | USUBJID PARAMN AVISITN ADT LBSEQ (`keysrc=CALLER`) | Same BDS pattern as ADVS. No ADTM on PVA gold. |

**BDS presentation order (builders):** `USUBJID → PARAMN → PARAM → AVISITN → AVISIT → ADT` [→ `ADTM` on ADEG] → `*SEQ`. PARAMN assigned from PVA gold unique PARAMCD→PARAMN maps (`validation/refadvs.xpt` / `refadeg.xpt` / `refadlb.xpt`).

**ADTTE:** out of scope (no PVA safety TTE; only `adtte_onco`).

## Explicitly out of scope

- SAS-only: SMQ*, CQ*, AESIFL, LDOS_RTE / EXROUTE, custom TTAE/ADTTE
- Specialty PVA datasets (onco, vaccine, …)
- Full column compare — PVA is wider; use common-var lists

## Pass / fail / policy

| Result | Meaning |
|--------|---------|
| PASS | Common vars align on keys |
| POLICY | Understood SPEX/CT/gold gap (e.g. ADEG `ms` vs `msec`; ADAE DATE_IMPUTE; ADCM AENDT year-end without EOS) |
| FAIL | Unexpected derivation disagreement on claimed vars |

**Labels:** use domain tokens `ADSL`, `ADAE`, `ADEG`, … (not `ADSL_PVA`). POLICY gates and `%m_qc_default_keys` key off the domain name; a `_PVA` suffix previously blocked ADAE DATE_IMPUTE POLICY (`label = ADAE` exact match).

**ADSL (22–24AUG2026):** PROC COMPARE `diffs=254` was **not** primarily blank TMF after rebuild. After DTM QC norm + EOSSTT screen-failure fix → **`status=PASS` `value_diffs=0`**.

| Evidence | Meaning |
|----------|---------|
| `refadsl.xpt` `TRTSDTM` class | **Date** (numeric ~16072 = same as `TRTSDT`) |
| `adam.adsl` `TRTSDTM` | **Datetime** (~1.4e9) via `%m_derive_vars_dtm` |
| Layer-1 empty | chkvars/dates can match while PROC COMPARE still compares all common vars including `*DTM` |
| PVA `TRTSTMF` | 254×`H` (TMF was a prior gap; builders keep H safety) |

**Root cause:** `write_xpt_sas.R` historically did `as.Date(POSIXt)` before `haven::write_xpt`, collapsing every `*DTM` to date-scale. SAS builders keep true midnight datetime → 254 OUTNOEQUAL rows.

**Fix (Part B QC only):** `%m_qc_norm_dtm_scale` in `SAS/macro/m_qc_compare_pva.sas` / `%m_qc_prep_pair` promotes `0 < *DTM < 100000` to `dhms(*,0,0,0)` and midnight-collapses non-zero timepart on working copies. Track A `m_qc_compare.sas` does **not** promote (Part A isolation). Export writer no longer Date-collapses POSIXt (re-export optional).

**ADAE (23–24AUG2026):** Same `*DTM` Date-scale story as ADSL + last-dose/`ex_single` builder fix → **`status=PASS` `value_diffs=0`**. QC key is **USUBJID ASTDT AEDECOD ASEV AESEQ** with **`keysrc=CALLER`**.

**ADCM (24AUG2026):** Equal n=7510, keys clean, **one** residual `AENDT` (and related `AENDY`) on `01-718-1170`: PVA `31DEC2013` (year-end, no EOS cap) vs SAS `03NOV2013` (admiral `hi=M` last + `max_dates=DTHDT,EOSDT`). Digest **`status=POLICY`**. See `part_b_adcm_gaps.md` / catalog `PVA_ADCM_AENDT_NO_EOS_CAP`.

## Data issues catalog (separate from PVA compare)

`create_ADaM_pva_oda.sas` also writes **`adam.qc_sdtm_issues`** via `%m_qc_sdtm_issues_pva` — informational flags with `SOURCE=SDTM` (messy/incomplete AE) and `SOURCE=ADAM` (e.g. `PVA_ADAE_DTM_DATE_COLLAPSE`, `PVA_ADCM_AENDT_NO_EOS_CAP`). See `docs/qc_sdtm_issues_pva.md`. Not part of the PVA PASS/POLICY/FAIL digest.

## Prerequisites

1. Build Part B `adam.*` via `create_ADaM_pva_oda.sas` (or set `ADAM_PATH`)
2. `export_pharmaverseadam_ref.R` → `validation/ref*.xpt`
3. On ODA: simple `proc copy` each `ref*.xpt` → members **REFADSL** / **refadsl**, … in `validation/`
4. `run_qc_compare_pva_oda.sas` (%include Part B `macro/m_qc_*_pva.sas`; Track A util only)
