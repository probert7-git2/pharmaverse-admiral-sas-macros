# Understood QC mismatches (Track A — SAS vs R gold)

**Purpose:** HA / explainability narrative for residual SAS↔gold diffs after equal-`n` compares.  
**Policy:** Do **not** force perfect parity. Prefer honest **POLICY / gold / Pharmaverse** labels over false PASS.  
**Evidence baseline:** ODA digest 19AUG2026 (post SHIFT rebuild) — ADSL / ADTTE / ADVS / ADEG / **ADCM PASS**; ADAE **POLICY** (`base_n=compare_n=1191`); **ADLB FAIL** closer (`value_diffs` **359**, was ~58700 blank SHIFT). Golden subjects **21/21 PASS**.

Related: [`qc_rules_and_scope.md`](qc_rules_and_scope.md), [`dual_track_qc.md`](dual_track_qc.md), [`admiral_sas_analogues.md`](admiral_sas_analogues.md).

## Status legend (digest)

| Digest `status` | Meaning |
|-----------------|--------|
| PASS | Equal `n`, keys match, no value diffs on compared vars |
| POLICY | ADAE DATE_IMPUTE, or ADEG CT/label (`ms` vs deprecated `msec`, and/or RR PARAM Interval vs Duration) — not a SAS bug to weaken |
| FAIL | Equal `n` but key orphans and/or value diffs (not DATE_IMPUTE / ADEG CT POLICY) |
| COUNT / SCOPE | Row counts disagree — value diffs unreliable until `n` matches |

`base` = R gold (`ref.ref_*`), `compare` = SAS `adam.*`.

---

## Understood mismatch matrix

| Domain | Symptom (19AUG2026 digest) | Likely cause | SAS vs Gold / Pharmaverse note | Action |
|--------|----------------------------|--------------|--------------------------------|--------|
| ADSL | PASS | — | Aligned on compared vars | accept |
| ADAE | POLICY — equal `n=1191`; paired orphans (REF `ASTDT=.` vs SAS imputed); 9 TRTEMFL blank vs REF `Y` when `ASTDT` missing; non-unique `USUBJID ASTDT AEDECOD` sample is expected | Gold `derive_vars_dt(hi=n)` leaves day-missing partials missing; SAS `%m_adae2` keeps DTM `hi=D` + subject-relative TE onset. Same events, key mismatch from DATE_IMPUTE — not missing AEs. Dup business keys = two AEs same day same PT (AESEQ tiebreak → `_KEYSEQ`) — **not** extra rows. OCCDS spex key (not SEQ-only) | Intentional **safety / TE** policy. Closing gap = **gold** adopts day-only conservative impute — **not** SAS → `hi=n`. **Canonical FP:** `01-701-1148` / `AESEQ=8` (below) | **accept** as POLICY |
| ADTTE | PASS | First `TRTEMFL='Y'` with non-missing `ASTDT` | BDS-TTE key `USUBJID PARAMCD` (not OCCDS) | accept |
| ADVS | PASS | — | Dup same-day keys via `_KEYSEQ` OK. Match key is `USUBJID PARAMCD AVISIT ADT` (admiral/ADaMIG analysis visit — not the stripped Track A template) | accept |
| ADEG | **POLICY** — `ms` vs `msec` (+ RR PARAM Interval vs Duration) | SAS CDISC CT **`ms`** (24JUN2022); gold / Admiral-shaped refs may still use deprecated **`msec`** and SDTM EGTEST **"RR Duration"** | Intentional. Do **not** rematch SAS to `msec`. Digest POLICY when those are the only diffs. Optional: reconvert Track A gold for PASS | **accept** as POLICY |
| ADCM | **PASS** | Prior DOSE ~1e-17 cleared by `round(DOSE,1e-8)` + PROC COMPARE `criterion=1e-8` | OCCDS key `USUBJID ASTDT CMDECOD` | accept |
| ADLB | FAIL — **359** value diffs (was ~58700 blank SHIFT). SHIFT now populated | Blank-SHIFT flood fixed. Residual likely SHIFT/BNRIND/BASEC content on a thin slice (e.g. BASO/EOS). v2e restores missing-side spacing (`"  to NORMAL"`) — Layer-1 `strip()` may already neutralize that. Sample `XXXXXXX` on SHIFT is likely listing truncation, not literal X. Match key is `USUBJID PARAMCD AVISIT ADT` | Gold `paste(coalesce(BNRIND," "),"to",...)`. | **next pass** — freq `_issue` on `_qc_mis`; optional v2e re-QC |
| Cross-cutting | Char length / pad noise | Different `$` lengths after XPT / KEEP | Layer-1 char compare `strip()` both sides | fix SAS (done earlier) |
| Pharmaverse / Track B | Broader admiral surface | Track A gold is a thin admiral+dplyr export | Dual-track gaps expected | accept / investigate on Track B |

---

## ADAE reading guide (equal n=1191)

1. **Non-unique business key ≠ extra AE rows.** Digest `base_n=compare_n=1191`. QC business key is `USUBJID ASTDT AEDECOD`; when two AEs share the same subject + onset day + preferred term, AESEQ orders them and `_KEYSEQ` pairs 1:1. Example: `01-701-1023` ERYTHEMA `07AUG2012` AESEQ=2 and 4 → `_KEYSEQ` 2 and 3. That is normal same-day same-PT multiplicity, not a row-count problem.
2. **REF_ONLY / SAS_ONLY orphans are paired DATE_IMPUTE**, not one side missing the AE. Examples: `01-701-1239` FATIGUE/HORDEOLUM and `01-716-1418` HEADACHE/VISION BLURRED — REF `ASTDT=.` vs SAS imputed date (gold `hi=n` vs SAS `hi=D` / TE day). Same events; the date key disagrees.
3. **TRTEMFL 9 rows** SAS blank vs REF `Y` when `ASTDT` missing — known admiral missing-start→Y vs SAS YM-window POLICY (see canonical case below).

---

## What is **not** a SAS bug (do not weaken)

1. **ADAE DATE_IMPUTE / POLICY** — conservative day-only (`hi=D`) + TE-relative onset + YM-in-window TRTEMFL post-pass. Digest `POLICY` is correct. Do **not** change SAS to gold `hi=n` or force missing-`ASTDT` -> `Y` when YM is outside the TE window. Example: `01-701-1148` / `AESEQ=8` — gold `Y` is a **false-positive TE**; SAS blank matches FDA onset TE and official `pharmaverseadam::adae`.
2. **ADEG `AVALU` = `ms`** — current CDISC CT / FDA. Do **not** rematch SAS to Admiral/`metacore`/`xportr` legacy `msec`. Track A gold uses `ms`; Track B Pharmaverse `msec` is an understood dual-track gap (see `dual_track_qc.md`).
3. **ATOXGR CTCAE richness** — optional submission path (`tox_method=CTCAE`); Track A gold is SIMPLE+MAXABS.
4. **`*SEQ` differences** after exclusion — assignment order only.
5. **Non-unique ADAE business keys** when `n` matches — expected same-day same-PT repeats; tiebreak AESEQ / `_KEYSEQ` handles pairing.

---

## Already in tree (verify on ODA after upload)

| Fix | Files |
|-----|--------|
| `*SEQ` exclude from value compare; tiebreak + `_KEYSEQ` | `m_qc_compare.sas`, `m_qc_compare_adam2.sas`, `m_qc_procompare.sas` |
| Soften non-unique business-key NOTE/title (not "duplicate sort keys" alarm) | `m_qc_compare.sas` |
| ADLB `tox_method=SIMPLE` default + `combine_method=MAXABS` | `m_adlb.sas`, `m_derive_var_atoxgr.sas` |
| ADCM / gold admiral TRTEMFL | `m_adcm2.sas`, `R/export_r_adam_ref.R` |
| ADAE TE-relative `hi=D` + YM TRTEMFL rules | `m_adae2.sas` (+ golden subjects) |
| ADCM DOSE `round(..., 1e-8)` + PROC COMPARE `criterion=1e-8` | `m_adcm2.sas`, `m_qc_procompare.sas` |
| Char strip in Layer-1 value compare | `m_qc_compare.sas` |
| **SHIFT rebuild v2e** (no re-strip of `byte(32)`; LENGTH before SET; log proof) | `m_adlb.sas`, `m_derive_var_base.sas` |

---

## Canonical case: gold / admiral false-positive TE (`01-701-1148` / `AESEQ=8`)

**Clinical stance (authoritative):** onset ~18 months before treatment (`AESTDTC` like `2012-02--` / `2012-02`); SDTM AE has no worsening intensity unless SUPPAE. FDA TEAE = onset **or** worsening **after** treatment start -> **TRTEMFL blank** is correct. Do **not** change SAS to match gold `Y`.

### Official admiral `derive_var_trtemfl` rules (confirmed)

Source: [derive_var_trtemfl reference](https://pharmaverse.github.io/admiral/main/reference/derive_var_trtemfl.html), [R source](https://github.com/pharmaverse/admiral/blob/main/R/derive_var_trtemfl.R), OCCDS vignette [Creating an OCCDS ADaM](https://pharmaverse.github.io/admiral/main/articles/occds.html). Cases are evaluated **in this order**; first match wins:

1. **Not treated** — `trt_start_date` missing → `NA`
2. **Event before treatment** — `end_date` before `trt_start_date` (and end not missing) → `NA`
3. **No event date** — `start_date` missing → **`"Y"`** — quote: *"as in such cases it is usually considered more conservative to assume the event was treatment-emergent"* / examples: *"If missing AE start date then we flag as treatment-emergent as worst case … unless we know that the AE end date was before treatment"*
4. **Started during treatment** — `start_date >= trt_start_date` (and, if `end_window` set, `start_date <= trt_end_date + end_window`) → `"Y"`
5. **Started before treatment and (possibly) worsened** — only if `initial_intensity` / `intensity` (or `group_var`) are supplied: pre-Tx start, ongoing/end on/after Tx, and intensity worsened → `"Y"`
6. **Otherwise** → `NA`

**Default call (no intensity args):** known pre-Tx onset without worsening → blank; missing start → Y. Worsening TE is **opt-in**, not default. Aligned with [PHUSE WP-087](https://phuse.s3.eu-central-1.amazonaws.com/Deliverables/Safety+Analytics/WP-087+Recommended+Definition+of++Treatment-Emergent+Adverse+Events+in+Clinical+Trials+.pdf) when intensity args are used.

**pharmaverse examples ADAE** ([adae.html](https://pharmaverse.github.io/examples/adam/adae.html)): same `derive_var_trtemfl()`; notes intensity args only *if* you also want pre-Tx starts that worsen. Their example imputes partial starts (`highest_imputation = "M"`, `min_dates = TRTSDT`) so many day-missing rows never hit the missing-start→Y branch. Official `pharmaverseadam::adae` for this subject uses first-of-month `ASTDT` → blank (pre-Tx), matching SAS.

### Three-way comparison (this case)

| Stance | Missing / out-of-window day-missing start | Known pre-Tx start, no worsening | Pre-Tx + worsening (intensity supplied) |
|--------|-------------------------------------------|----------------------------------|-----------------------------------------|
| **Admiral default** | `TRTEMFL=Y` (conservative / "worst case") | blank | blank unless intensity args used |
| **FDA-style baseline** | blank / not TEAE (baseline condition) | blank (baseline) | Y if worsened after Tx |
| **SAS-ADAE (`%m_adae2`)** | blank when YM outside `[TRTSDT, TRTEDT+30]` (overrides port missing→Y); YM-in-window can force Y | blank | not used in default path |

| Source | ASTDT | TRTEMFL | Why |
|--------|-------|---------|-----|
| SAS `%m_adae2` | missing (out-of-window YM clear) | **blank** | After `%m_derive_var_trtemfl`, day-missing YM **outside** `[TRTSDT, TRTEDT+30]` + missing `ASTDT` -> force blank (overrides admiral missing-start=`Y`) |
| Track A R gold (`export_r_adam_ref.R`) | missing (`derive_vars_dt(hi="n")`) | **Y** | `admiral::derive_var_trtemfl` treats missing start as TE (`Y`) - **false-positive** vs FDA onset TE; matches admiral docs above |
| Official `pharmaverseadam::adae` (v1.3.0 checked) | `2012-02-01` (`ASTDTF=D`, first-of-month) | **blank/NA** | `ASTDT` << `TRTSDT` (2013-08-23) -> not TE; agrees with SAS, **not** Track A gold |

**Mechanism (Track A gold):** `export_r_adam_ref.R` uses `derive_vars_dt(..., highest_imputation = "n")` so partial `AESTDTC` -> missing `ASTDT`, then `derive_var_trtemfl` sets missing start -> `Y` (by design in admiral, not a local gold bug).

**Mechanism (SAS):** `%m_adae2` steps 8 + 8b - port may set `Y` on missing `ASTDT`, then YM post-pass blanks when month is outside the TE window (this case: 2012-02 vs TRTSDT 2013-08). **No SAS code change** — intentional FDA-aligned override of admiral's ultra-conservative missing-start rule.

### Verify vs official Pharmaverse ADAE

`pharmaverseadam` **does** ship CDISC-pilot `adae` (same study as `pharmaversesdtm`).

**Local check** (package installed):

```r
Rscript SAS/R/check_pva_adae_trtemfl_case.R
# or:
data(adae, package = "pharmaverseadam")
subset(adae, USUBJID == "01-701-1148" & AESEQ == 8,
       c(USUBJID, AESEQ, AESTDTC, ASTDT, ASTDTF, TRTSDT, TRTEMFL))
```

**Track B path** (sibling `SAS_mirrored_Admiral_safety_ADaM`):

1. `setwd(".../SAS_mirrored_Admiral_safety_ADaM/SAS"); source("R/export_pharmaverseadam_ref.R")` -> `validation/refadae.xpt`
2. ODA: simple `proc copy` of `ref*.xpt` -> `ref_pva.refadae` (member REFADAE / refadae)
3. Spot-check or `programs/run_qc_compare_pva_oda.sas` (keys `USUBJID`/`AESEQ`, `chkvars` includes `TRTEMFL`)

Expect PVA gold **blank** and SAS **blank**; Track A `ref.ref_adae` may still show **Y** until gold policy changes - that is POLICY, not a SAS defect.

## AETRTEM vs TRTEMFL (not a conflict)

| Variable | Where it lives | Meaning |
|----------|----------------|---------|
| **AETRTEM** | SDTM **SUPPAE** `QNAM=AETRTEM` (also kept on ADAE) | Source supplemental TE flag from SDTM — **copied**, not re-derived |
| **TRTEMFL** | ADaM ADAE / ADCM | Analysis TE flag from `%m_derive_var_trtemfl` (admiral window + SAS YM policy) |

Local evidence: `metadata/pharmaversesdtm_supp_qval.csv` and `supp_qnam_observed.csv` show SUPPAE **AETRTEM** Y/N counts. Metacore value_spec where-clause citing `QNAM='TRTEMFL'` is a **pilot quirk** — actual QNAM list and pharmaversesdtm use **AETRTEM**. Keeping both on ADAE is intentional for QC/traceability.

## Re-upload / re-run (ODA)

**Upload at least:**

- `macros/m_advs2.sas`, `macros/m_adeg2.sas`, `macros/m_adlb.sas` (BDS sort `USUBJID PARAMCD AVISIT ADT *SEQ` + AVISIT derive)
- `macros/m_adae2.sas`, `macros/m_adcm2.sas` (OCCDS sort comments - keys unchanged)
- `macros/m_qc_compare.sas`, `macros/m_qc_compare_adam2.sas` (BDS `AVISIT` keys + OCCDS spex notes + `AVISIT` on mismatch shell)
- `R/export_r_adam_ref.R` (BDS VISIT/AVISIT + OCCDS arrange comments)
- Then regenerate gold and confirm `ref.ref_*` under `validation/` (see order below)
- `macros/m_derive_var_base.sas` (shift port harden **v2e**) — if not already on ODA
- `programs/build_adam2_metadata_oda.sas` (CODE_ONLY fill)
- `metadata/adam2_derivation_registry.csv` (SHIFT/BNRIND/AETRTEM rows)

**Order:**

1. Local: re-run `SAS/R/export_r_adam_ref.R` so gold carries `VISIT`/`AVISIT`/`AVISITN` and arrange on BDS `USUBJID PARAMCD AVISIT ADT *SEQ` (OCCDS arrange unchanged).
2. Upload new `refadvs` / `refadeg` / `refadlb` XPTs (+ macros above). OCCDS XPTs optional if arrange-only comment change.
3. Fresh SAS Studio session (macro cache).
4. Confirm gold `ref.ref_*` sas7bdat under `validation/` (from `R/export_r_adam_ref.R`).
5. `programs/run_adam2_workflow_oda.sas` (rebuild BDS + OCCDS so adam SORTEDBY is set).
6. `programs/run_qc_compare_adam2_oda.sas`.
7. Optional: `programs/build_adam2_metadata_oda.sas`; `programs/run_golden_subjects_oda.sas`.

**Expect after refresh:** ADSL / ADTTE / **ADCM** / ADVS / ADEG stay PASS with AVISIT in the BDS match key; **ADLB** residual value diffs unchanged by the visit-key restore; **ADAE remains POLICY**. SORTEDBY still prefers adam when present.

**Note on prior revert:** Dropping VISIT from BDS keys because the Track A template lacked visit columns was the wrong north star. Pharmaverse/admiral BDS includes analysis visit (`AVISIT`); Track A gold now follows that spex. OCCDS keys already matched admiral OCCDS (start + dictionary term) — documented, not SEQ-only.

**Key alignment rule:** BDS and OCCDS do not share one pattern. Align `adam.<ds>` ↔ `ref.ref_<ds>` per dataset (see Per-domain keys in `qc_rules_and_scope.md` / `admiral_sas_analogues.md`).
