# Part B — ADVS gaps vs `pharmaverseadam`

**Date:** 24AUG2026 (gap analysis refreshed)  
**Gold:** `pharmaverseadam::advs` / `ref_pva.refadvs` (n=65032)  
**SAS:** `%m_advs_pva` → Part B `adam.advs`  
**Builder:** `SAS/macro/m_advs_pva.sas` (Part B only — Track A unchanged)  
**Admiral template:** `admiral/templates/ad_advs.R`

## Verdict

**Yes, SAS can and should mirror admiral ADVS for COUNT-critical provenance** — but core BDS steps (PARAMN 1–9, MAP/BMI/BSA, AVERAGE, BASETYPE/ABLFL, CHG/PCHG) are **already mirrored**. Remaining COUNT gap is **`DTYPE=LOV` End-of-Treatment rows**, which require **`ANL01FL` first**. Do **not** invent new DTYPE values beyond PVA (`AVERAGE`, `LOV`, blank/NA).

Optional first slice (AVERAGE DTYPE on observed path): **already done** — no further small fix needed.

---

## 1. Side-by-side: admiral `ad_advs.R` vs `%m_advs_pva`

| # | Admiral step | SAS Part B status | Notes |
|---|--------------|-------------------|-------|
| 1 | `derive_vars_merged` ADSL (TRTSDT/…) | **done** `%m_derive_vars_merged` | BDS subset; full ADSL later optional |
| 2 | `derive_vars_dt` / `derive_vars_dy` | **done** | No ADTM on PVA ADVS |
| 3 | PARAM lookup PARAMN 1–9 | **done** | Exact PVA map (see §3) |
| 4 | `AVAL = VSSTRESN` (+ unit policy) | **done** (+ SAS unit convert) | SAS-only AVALU consistency |
| 5 | `derive_param_map/bsa/bmi` | **done** Track A ports | Drop SDTM MAP/BMI/BSA first |
| 6 | ATPT/ATPTN, AVISIT/AVISITN | **done** | Screen/unsched → blank AVISIT |
| 7 | `derive_summary_records` → `DTYPE=AVERAGE` | **done** (inline SQL) | Could swap to `%m_derive_summary_records` later |
| 8 | `derive_var_ontrtfl` + Baseline clear | **done** | |
| 9 | range lookup + `derive_var_anrind` | **missing** | ANRIND on REF; not COUNT driver |
| 10 | `derive_basetype_records` | **done** (ATPTN 815/816/817) | |
| 11 | ABLFL last `ADT<=TRTSDT` & `is.na(DTYPE)` | **done** | |
| 12 | BASE / CHG / PCHG (`AVISITN>0`) | **done** | PCHG 1dp = POLICY |
| 13 | `ANL01FL` extreme last post-BL | **missing** | Prerequisite for LOV |
| 14 | `derive_extreme_records` EoT `DTYPE=LOV` | **missing** | **Primary COUNT gap** |
| 15 | ASEQ, AVALCAT1, full ADSL | **missing** | Template extras; lower priority |

---

## 2. DTYPE on PVA REF vs SAS

**REF evidence** (`pharmaverseadam::advs`, 24AUG2026):

| DTYPE | n | Meaning |
|-------|---|---------|
| blank/NA | 41948 | Observed / derived MAP·BMI·BSA (provenance blank) |
| `AVERAGE` | 20060 | Visit-date mean across ATPT (additive) |
| `LOV` | 3024 | End of Treatment copies (`AVISIT="End of Treatment"`, `AVISITN=99`) |

**SAS today:**

| DTYPE | Sets? |
|-------|-------|
| blank | **yes** — observed + computed params (`DTYPE=''`) |
| `AVERAGE` | **yes** — appended summary rows |
| `LOV` | **no** — not implemented |

Admiral LOV rule (template): last of `4 < AVISITN <= 13 & ANL01FL=="Y" & is.na(DTYPE)` by `STUDYID USUBJID PARAMCD ATPTN`, set `AVISIT="End of Treatment"`, `AVISITN=99`, `DTYPE="LOV"`.

---

## 3. PARAMN map alignment

| PARAMN | PARAMCD | Admiral / PVA | SAS `%m_advs_pva` |
|--------|---------|---------------|-------------------|
| 1 | SYSBP | yes | yes |
| 2 | DIABP | yes | yes |
| 3 | PULSE | yes | yes |
| 4 | WEIGHT | yes | yes |
| 5 | HEIGHT | yes | yes |
| 6 | TEMP | yes | yes |
| 7 | MAP | yes | yes |
| 8 | BMI | yes | yes |
| 9 | BSA | yes | yes |

**Aligned.** Minor PARAM text spacing vs template (`BMI (kg/m^2)` vs `BMI(kg/m^2)`) — cosmetic unless QC compares PARAM string.

---

## 4. Feasibility — can SAS mirror?

**Yes**, via existing Part A/B patterns:

| Missing mirror | How to implement | Effort |
|----------------|------------------|--------|
| `ANL01FL` | Inline extreme-flag (same pattern as ABLFL) — prefer **not** `%m_derive_var_extreme_flag(..., filter=)` (filter path returns filtered-only). By: `USUBJID PARAMCD AVISIT ATPT DTYPE`; order `ADT AVAL`; mode last; filter `not missing(AVISITN) and ONTRTFL='Y'` | Medium |
| `DTYPE=LOV` EoT | New rows: copy last qualifying obs; no Track A `derive_extreme_records` yet — inline DATA/SQL like AVERAGE | Medium (needs ANL01FL) |
| ANRIND + ranges | Lookup + simple ANRIND data step (or port if exists) | Small–medium |
| AVALCAT1 HEIGHT | Simple if/else categories | Small |
| ASEQ | obs number by subject | Small |
| Full ADSL vars | `%m_derive_vars_merged` remainder | Small; COUNT usually OK without |

**Should** mirror for COUNT: ANL01FL → LOV. **Should not** invent orthostatic PARAMCDs (PVA uses ATPT only).

---

## 5. Recommended next order to close COUNT

1. **`ANL01FL`** on post-baseline ONTRT rows (admiral by/order/mode).
2. **`DTYPE=LOV`** End-of-Treatment extreme records (~3024 REF rows).
3. Re-run Part B ADVS QC (`USUBJID PARAMN AVISITN ADT ATPTN VSSEQ`).
4. Optional: ANRIND / AVALCAT1 / ASEQ if value-level or metadata QC cares.
5. Leave PCHG 1dp and full-ADSL as POLICY / non-blockers.

---

## PVA baseline strategy (REF evidence)

Subject `01-701-1015` SYSBP (`pharmaverseadam::advs`):

| Visit | Rows kept? | DTYPE | ABLFL | BASE |
|-------|------------|-------|-------|------|
| Screening 1 (3 ATPT) | **yes** (6 screen rows total w/ Scr2) | blank | blank | 130/121/131 by position |
| Screening mean | **added** | AVERAGE | blank | missing (BASETYPE=`LAST`) |
| **BASELINE** (3 ATPT) | yes | blank | **Y** ×3 | AVAL of that ATPT |
| Baseline mean | added | AVERAGE | blank | missing |
| Week 2+ | yes | blank / AVERAGE | blank | position BASE |

**Conclusion:**

1. **ABLFL** = last non-missing `AVAL` with `ADT <= TRTSDT` and blank `DTYPE`, by `USUBJID` / `PARAMCD` / `BASETYPE`, order `ADT, VISITNUM, VSSEQ`.
2. **Not** last Screening 2 when Baseline exists on `TRTSDT` (`ADY=1`) — Baseline wins.
3. **AVERAGE** rows are **added** (triplicate means). Individual screening/position rows are **not** dropped.
4. AVERAGE is **not** the ABLFL target (`is.na(DTYPE)` filter in admiral template).

**BASETYPE:** ATPTN 815/816/817 → lying / stand 1 min / stand 3 min; else `LAST`.

**BASE scope (confirmed):** Not a single subject-level baseline. For SYSBP/DIABP/PULSE/MAP, REF BASE differs by ATPT (e.g. 01-701-1015 SYSBP Screening BASE 130 / 121 / 131 for lying / stand1 / stand3). `%m_advs_pva` derives ABLFL / BASE / CHG by `USUBJID × PARAMCD × BASETYPE` (BASETYPE 1:1 with ATPTN 815–817), so positions do not collapse.

**CHG/PCHG:** only when `AVISITN > 0` (pre-dose + Baseline missing).

## Orthostatic / derived PARAMCDs

| Question | PVA answer |
|----------|------------|
| Orthostatic hypotension PARAMCD? | **None** — no ORTH/OH/postural PARAMCD |
| How is orthostatic represented? | **ATPT / ATPTN** on SYSBP/DIABP/PULSE/MAP |
| Extra PARAMCDs vs raw VS | **MAP, BMI, BSA** (derived) |

PVA PARAMCD set (only): `SYSBP DIABP PULSE WEIGHT HEIGHT TEMP MAP BMI BSA`.

## Fixed (24AUG2026)

- BASETYPE + ABLFL last `ADT<=TRTSDT` non-DTYPE per BASETYPE
- `DTYPE=AVERAGE` (additive; screenings kept)
- CHG/PCHG blank unless `AVISITN > 0`; **PCHG round 0.1** (SAS preference)
- ATPT/ATPTN on output; QC/sort keys include **ATPTN**
- Derive **MAP / BMI / BSA** via Track A `%m_derive_param_*` ports
- Baseline visit cleared from ONTRTFL
- PARAMN 1–9 aligned with admiral/PVA

## Remaining COUNT drivers

| Driver | PARAMCD / note | Status |
|--------|----------------|--------|
| MAP BMI BSA | derived | **implemented** |
| AVERAGE rows | all PARAMCD | **implemented** |
| `DTYPE=LOV` End of Treatment | ~3024 REF rows | **open** (needs ANL01FL) |
| `ANL01FL`, ANRIND, AVALCAT1 | template extras | **open** (ANL01FL blocks LOV) |
| PCHG 1dp vs PVA float | POLICY | intentional |
| Full ADSL vars on ADVS | PVA carries ADSL | SAS BDS subset OK |

## QC match key (Part B)

`USUBJID PARAMN AVISITN ADT ATPTN VSSEQ` (+ `_KEYSEQ`)

## Code changed this pass

None — AVERAGE/PARAMN already in place; LOV/ANL01FL is a medium slice (plan only).
