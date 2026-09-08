# Part B — ADCM gaps vs `pharmaverseadam`

**Date:** 24AUG2026  
**Gold:** `pharmaverseadam::adcm` / `ref_pva.refadcm` (n=7510)  
**SAS:** `%m_adcm_pva` → Part B `adam.adcm`  
**Builder:** `SAS/macro/m_adcm_pva.sas` (Part B only — Track A `%m_adcm2` unchanged)

## Digest status (re-run after AST/AEN hi=M rebuild)

| Layer | Result |
|-------|--------|
| Row counts | Equal (7510) |
| Key orphans | 0 / 0 (`USUBJID ASTDT CMDECOD CMSEQ`, `keysrc=CALLER`) |
| Layer-1 value mismatches | **AENDT** (+ **AENDY** when in floatvars) — index subject only |
| PROC COMPARE | `value_diffs=1` → **POLICY** after gate (was FAIL before POLICY) |

**Tonight 24AUG2026 ODA FAIL root cause:** POLICY macros were **not on ODA** (create/QC ~20:31–20:39; local POLICY touch ~20:58). Layer-1 already had sole `MISMATCH:AENDT` for `01-718-1170` / CMSEQ=20 — gate logic was fine, upload was missing. After upload look for log stamps `ADCM_AENDT_POLICY_V2` and `STACKED_DIF_FINGERPRINT=20260824G`.

## Known case — PVA year-end AENDT without EOSDT cap

| Field | Value |
|-------|--------|
| Subject | `01-718-1170` |
| CMSEQ / term | 20 / DONEPEZIL HYDROCHLORIDE |
| SDTM `CMENDTC` | `2013-11` (day missing) |
| ADSL `EOSDT` | `03NOV2013` |
| SAS `AENDT` | `03NOV2013` (**correct**) |
| PVA `AENDT` | `31DEC2013` (**wrong** — year-end) |
| Related | `AENDY` follows `AENDT` (also differs on PROC COMPARE) |

**Admiral rule** (`ad_adcm.R`): `highest_imputation=M`, `date_imputation=last`, `max_dates=c("DTHDT","EOSDT")` then `dtm_to_dt`.  
Partial `CMENDTC=2013-11` → last day of month (`30NOV2013`) → **cap by EOSDT** when EOS is earlier → `03NOV2013`.

**PVA gold behavior:** looks like year-end imputation (`31DEC2013`) **without** EOSDT (or DTHDT) cap.

**SAS:** `%m_adcm_pva` post-pass caps imputed `AENDT` (`AENDTF` in `D`/`M`) by `EOSDT` — matches admiral. **Do not change SAS to match PVA Dec 31.**

## POLICY / catalog

| Mechanism | Code / gate |
|-----------|-------------|
| Layer-1 / digest | When n/keys match and Layer-1 mismatches are **only** `AENDT` and/or `AENDY` → `status=POLICY` |
| Data issues | `adam.qc_sdtm_issues` / `SOURCE=ADAM` / `PVA_ADCM_AENDT_NO_EOS_CAP` |

See `qc_sdtm_issues_pva.md` and `qc_scope_pva.md`.

## ODA re-run (QC only for ADCM POLICY — builder already correct)

1. Upload Part B (overwrite on ODA, then **new Studio session**):
   - `macro/m_qc_compare_pva.sas`
   - `macro/m_qc_procompare_pva.sas`
   - `macro/m_qc_print_dif_pva_sas.sas` (fixes `_PDF_AVARS` ERROR 22-322 noise)
   - `macro/m_advs_pva.sas` (create-log `%put` ERROR 180 — only if re-running create)
2. Re-run `run_qc_compare_pva_oda.sas` — expect ADCM `status=POLICY` with `value_diffs=1`
3. Confirm log: `ADCM_AENDT_POLICY_V2 FIRE` and `STACKED_DIF_FINGERPRINT=20260824G`
4. Optional: re-run `create_ADaM_pva_oda.sas` for create ERROR=0 (ADVS `%put` only — does not change ADSL/ADAE/ADCM)

Do **not** overwrite Track A QC macros or `%m_adcm2` for Part B work.
