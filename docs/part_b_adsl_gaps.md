# Part B — ADSL gaps vs `pharmaverseadam`

**Date:** 24AUG2026  
**Gold:** `pharmaverseadam::adsl` / `ref_pva.refadsl` (n=306, 55 vars)  
**SAS:** `%m_adsl_pva` → `adam.adsl` (n=306)

## Root cause of PROC COMPARE FAIL (diffs=52) — EOSSTT screen failures

After DTM-scale QC was green (`value_diffs=0`), keeping `EOSSTT` produced **`value_diffs=52`**.

| Evidence | Meaning |
|----------|---------|
| Count 52 | Exactly PVA untreated / `TRTSDTM` missing / `ARM='Screen Failure'` |
| PVA `EOSSTT` | 110 COMPLETED, 144 DISCONTINUED, **52 NA** (screen failure) |
| SAS before fix | `format_eosstt` set SF → blank, then `if missing(EOSSTT) then ONGOING` **overwrote** SF blanks |
| Keys / SUBJID | `USUBJID` match; `SUBJID`/`SITEID` = parse(USUBJID) on all 306 — **not** misalignment or `$4` pad noise |

**Cause:** admiral `missing_values = exprs(EOSSTT = "ONGOING")` applies only when **no** DISPOSITION EVENT merges. SAS treated character blank (SF) as missing and filled ONGOING. PROC COMPARE `value_diffs` counts **rows with any unequal common var** — so the same 52 rows look like “all new vars fail”; eyeballing `SUBJID` on those rows still matches.

**Fix:** `%m_adsl_pva` uses `exist_flag=` on the EOSSTT merge; set ONGOING only when the flag is missing.

## Prior: PROC COMPARE FAIL (diffs=254) — DTM scale

Layer-1 (`%m_qc_one`) can be empty while PROC COMPARE FAILs with `diffs=254`.

| Evidence | Meaning |
|----------|---------|
| `refadsl.xpt` `TRTSDTM` | **Date** class / date-scale numeric (~19183-19968 = `TRTSDT`) |
| `adam.adsl` `TRTSDTM` | **Datetime** (~1.65e9 = days*86400, midnight for start) |
| Count 254 | All treated subjects (same as non-missing `TRTSDTM`) |

**Cause:** XPT writer historically Date-collapsed `*DTM`. **Fix:** `%m_qc_norm_dtm_scale` on QC working copies (+ optional re-export).

## Gap inventory

### SAS-only (not on PVA)

`ITTFL`, `EFFFL`, `COMPL8FL`, `COMPL16FL`, `COMPL24FL` — SUPPDM pop flags. Keep on ADSL; Part B Layer-1 **masks** them.

### PVA-only (still deferred / partial)

`RFSTDTC` `RFENDTC` `RFXSTDTC` `RFXENDTC` `RFPENDTC` `RFICDTC` `BRTHDTC` `DMDTC` `DMDY` `ETHNIC` `ACTARMCD`,  
`LSTALVDT`, `AGEGR1` `RACEGR1` `REGION1` `LDDTHGR1` `DTH30FL` `DTHA30FL` `DTHB30FL`.

### Common vars — status

| Area | Status |
|------|--------|
| Demog / ARM / TRT01* / `TRTSDT`/`TRTEDT` | Aligned (Layer-1) |
| `TRTSDTM`/`TRTEDTM`/`TRTSTMF`/`TRTETMF` | Builders OK; QC scale norm for XPT Date vs datetime |
| `SAFFL` | EX exist-flag condition; SUPPDM preferred when present |
| `EOSDT`/`RANDDT`/`SCRFDT`/`FRVDT` | When `ds=` supplied |
| `EOSSTT` | Fixed — SF blank retained; ONGOING only if no disposition event |
| `DTHCAUS`/`DTHDOM`/`DTHCGR1` | Deferred |

## ODA rebuild / re-run

1. Upload Part B `macro/m_adsl_pva.sas` (EOSSTT exist_flag fix)
2. Rebuild `adam.adsl` (`create_ADaM_pva_oda.sas`)
3. Re-run `run_qc_compare_pva_oda.sas` — expect ADSL `status=PASS` `value_diffs=0`
4. Verify: `unequal_var=EOSSTT` gone; optional SUBJID-only PROC COMPARE still 0 diffs
