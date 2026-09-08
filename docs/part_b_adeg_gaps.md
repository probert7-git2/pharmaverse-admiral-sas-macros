# Part B — ADEG gaps vs `pharmaverseadam`

**Date:** 24AUG2026  
**Gold:** `pharmaverseadam::adeg` / `ref_pva.refadeg` (n=78756)  
**SAS:** `%m_adeg_pva` → Part B `adam.adeg`  
**Builder:** `SAS/macro/m_adeg_pva.sas` (Part B only — Track A unchanged)  
**Admiral template:** `admiral/templates/ad_adeg.R`

## Verdict — baseline (verified on REF)

**Claim checked:** “BASE = average of the six pre-dose (screening) values.”  
**REF result: false.** BASE is the **Baseline visit triplicate mean** (`DTYPE=AVERAGE`, `ABLFL=Y`), not the mean of the six screening rows.

### Evidence — `01-701-1015` / `HR`

| Source | Values | Mean |
|--------|--------|------|
| Screening blank-DTYPE (6) | 79, 52, 76, 75, 58, 71 | **68.5** |
| Baseline blank-DTYPE (3) | 73, 83, 65 | **73.666…** |
| REF `ABLFL=Y` row | `DTYPE=AVERAGE`, `AVISIT=Baseline`, `ADY=1` | **AVAL=BASE=73.666…** |

Across 60 subject×param samples: `match_scr=0/60`, `match_bl_avg=60/60`.  
All 1778 `ABLFL=Y` rows: `DTYPE=AVERAGE`, `AVISIT=Baseline`, `AVISITN=0`, `ADY=1`.

### ADEG baseline rules (REF / admiral)

1. **Keep** individual triplicate rows (screenings and visits).
2. **Add** `DTYPE=AVERAGE` rows (mean AVAL by visit-date; `n>=2`; `PARAMCD≠EGINTP`).
3. **ABLFL** = last `DTYPE=AVERAGE` with `ADT<=TRTSDT` (and non-missing AVAL), by `USUBJID` / `PARAMCD` / `BASETYPE`, order `ADT, VISITNUM, EGSEQ`.
4. **BASE** = AVAL from that ABLFL row (Baseline AVERAGE when Baseline exists).
5. **BASETYPE** = `BASELINE DAY 1` (single basetype — not ATPT-specific).
6. **CHG/PCHG** only when `AVISITN > 0`.

## How this differs from ADVS baseline

| | **ADVS** | **ADEG** |
|--|----------|----------|
| ABLFL target | last **blank** DTYPE, `ADT<=TRTSDT` | last **`DTYPE=AVERAGE`**, `ADT<=TRTSDT` |
| Typical ABLFL visit | **BASELINE** observed ATPT row(s) | **Baseline AVERAGE** row |
| BASETYPE | ATPTN → lying / stand 1 / stand 3 (or `LAST`) | always `BASELINE DAY 1` |
| AVERAGE role | additive; **not** ABLFL | additive; **is** ABLFL |
| Six screenings | kept; not the BASE source | kept; not the BASE source |

## Fixed (24AUG2026)

- `DTYPE=AVERAGE` (additive; `having count(*)>=2`; exclude EGINTP)
- `BASETYPE='BASELINE DAY 1'`
- ABLFL last AVERAGE `ADT<=TRTSDT` (not all `ADT<TRTSDT`)
- BASE from ABLFL; CHG/PCHG blank unless `AVISITN>0`
- ATPT/ATPTN from EGTPT/EGTPTNUM on output
- ONTRTFL `ref_end_window=30` + clear Baseline

## Remaining / open (not required for this baseline fix)

| Item | Notes |
|------|--------|
| Derived params RRR/QTCBR/QTCFR/QTLCR | Admiral `derive_param_*` — COUNT / PARAM set gap if raw EG lacks them |
| EGINTP / AVALC | Current builder keeps numeric `EGSTRESN` only |
| ANRIND / ANL01FL / ASEQ / categories | Template extras; ANL01FL on AVERAGE for LOV-like analysis |
| PARAM text / AVALU `ms` vs `msec` | POLICY (AVALU) |
| QC keys | Still `USUBJID PARAMN AVISITN ADT EGSEQ` — ATPTN not in ADEG QC key (EGSEQ separates positions on observed rows) |

## What SAS did wrong (before fix)

1. `ABLFL='Y'` on **every** `ADT < TRTSDT` observed row (not last AVERAGE).
2. No `DTYPE=AVERAGE` rows → wrong COUNT and wrong baseline provenance.
3. `BASE` via SQL `max(AVAL)` among many ABLFL=Y rows (wrong value).
4. CHG/PCHG populated on pre-baseline / Baseline.
5. No ATPT/ATPTN/BASETYPE on output.
