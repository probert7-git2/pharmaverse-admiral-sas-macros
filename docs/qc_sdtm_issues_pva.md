# Part B — `adam.qc_sdtm_issues`

**Purpose:** Permanent informational QC of **data issues** that affect ADaM processing — incoming SDTM AE problems **and** known PVA/ADaM gold quirks. Written during `%include create_ADaM_pva_oda.sas` after ADSL/ADAE so the Part B `adam` lib exists. Findings are **NOTES only** — they do not ERROR-abort the create.

**Macro:** `SAS/macro/m_qc_sdtm_issues_pva.sas` → `%m_qc_sdtm_issues_pva`  
**Output:** `adam.qc_sdtm_issues` (name is historical; content is SDTM + ADAM via `SOURCE`)  
**Input (v1):** `raw.ae` (Track A `sdtm/` via create driver `libname raw`); `ref_pva.refadae` / `ref_pva.refadcm` (PVA gold, when present)

## Columns

| Column | Role |
|--------|------|
| ISSUE_ID | `ISSUE_TYPE` + zero-padded row counter |
| DOMAIN | SDTM domain (`AE`) or ADaM domain (`ADAE`) |
| USUBJID | Subject (blank for dataset-level ADAM catalog rows) |
| KEY_VARS | Grouping / key variable names |
| KEY_TXT | Pipe-separated key values (or short catalog key text) |
| ISSUE_TYPE | Machine code (see below) |
| ISSUE_DESC | Human-readable impact note |
| N_ROWS | Contributing rows |
| EXAMPLE_SEQS | Example `AESEQ` values (blank for catalog rows) |
| SOURCE | `SDTM` or `ADAM` |

## ISSUE_TYPE codes — SDTM (`SOURCE=SDTM`)

| Code | Rule |
|------|------|
| `AE_SEV_SAME_DATES` | Same `USUBJID` + `AEDECOD` + `AESTDTC` + `AEENDTC` with >1 distinct `AESEV` — unexpected overlapping severities; impacts OCCDS uniqueness / TE windows |
| `AE_DUP_SEQ` | Duplicate `USUBJID` + `AEDECOD` + `AESEQ` |
| `AE_MISSING_AESTDTC` | `AEDECOD` present with missing `AESTDTC` |

## ISSUE_TYPE codes — ADAM / PVA gold (`SOURCE=ADAM`)

| Code | Rule |
|------|------|
| `PVA_ADAE_DTM_DATE_COLLAPSE` | **Dataset-level catalog** when `refadae` has any non-missing `ASTDTM`/`AENDTM`/`LDOSEDTM` in SAS date-scale `(0, 100000)`. PVA/pharmaverseadam stores these as date-scale (equal to `*DT`) with DATE format — export/Date-collapse artifact vs CDISC/admiral datetime + TMF. **Do not treat SAS full datetime as a builder defect against this gold.** Part B QC `%m_qc_norm_dtm_scale` promotes on compare copies only. |
| `PVA_ADCM_AENDT_NO_EOS_CAP` | **Subject catalog** when `refadcm` has `USUBJID=01-718-1170` with `AENDT=31DEC2013`. PVA imputes partial `CMENDTC` to **year-end** without `EOSDT` cap. admiral `ad_adcm.R` / SAS `%m_adcm_pva`: `hi=M`, `date_imputation=last`, `max_dates=DTHDT,EOSDT` → SAS `AENDT=03NOV2013` for `CMENDTC=2013-11` / `EOSDT=03NOV2013`. Part B QC marks AENDT/AENDY-only diffs as **POLICY**. **Do not change SAS to match PVA.** |

## Extensibility

Stub reserved in the macro for later BDS (LB, EG, VS) rules — keep `SOURCE=SDTM` and new `ISSUE_TYPE` codes. Future ADAM gold quirks: append with `SOURCE=ADAM`.

## Related external tooling (not a substitute)

`{pharmaversesdtm}` is **test SDTM data only** — no QC/check exports ([docs](https://pharmaverse.github.io/pharmaversesdtm/)).

Usual companion for analysis-facing SDTM integrity is **`{sdtmchecks}`** (`check_*`, `run_all_checks`) — [site](https://pharmaverse.github.io/sdtmchecks/), [intro vignette](https://pharmaverse.github.io/sdtmchecks/articles/sdtmchecks.html). Complementary to Pinnacle 21 (full CDISC conformance), not a replacement.

Keep this create-time net: it is SAS-side, ADaM-impact focused (e.g. `AE_SEV_SAME_DATES`, `PVA_ADAE_DTM_DATE_COLLAPSE`, `PVA_ADCM_AENDT_NO_EOS_CAP`), and does not require R. Optionally run `{sdtmchecks}` on the same pilot AE for broader coverage — note `check_ae_dup` keys **include** severity/tox grade, so same dates with **different** `AESEV` are a different finding than our `AE_SEV_SAME_DATES`.
