# QC rules and scope (what is checked, and why)

This document explains the **automated checks** in the ADaM2 QC pipeline so you can tune severity or extend coverage without guessing.

## ODA folder layout

Project files and run archives live under the same repo tree:

```
SAS/                                    <- HOME on ODA
  safety_monitoring_system/
    SAS/                                <- ROOT (&ROOT)
      output/                           <- run archives (libname goldout, &OUTDIR)
      adam/                             <- primary ADaM build
      logs/                             <- primary PRINTTO logs
      sdtm/                             <- SDTM (libname raw)
      programs/                         <- driver .sas files
```

## Output locations (backward compatible)

| Location | Purpose |
|----------|---------|
| `.../safety_monitoring_system/SAS/adam/` | Primary ADaM build |
| `.../safety_monitoring_system/SAS/logs/` | Primary SAS logs |
| **`.../safety_monitoring_system/SAS/output/`** | Archive copies from every ODA driver |

## Archived artifacts by program (`SAS/output/` under ROOT)

| Program | Log copy | Dataset copies (goldout.*) |
|---------|----------|----------------------------|
| `xpt2bdat_oda.sas` | `xpt2bdat.log` | — |
| `run_adam2_workflow_oda.sas` | `adam2_workflow.log` | `adam2_workflow_adsl`, `_adae`, `_adtte`, … |
| `run_adam_workflow_oda.sas` (legacy_original) | — | do not publish to CURRENT adam |
| `run_adam_with_chklog_oda.sas` (legacy_original) | `adam_workflow.log` | legacy only |
| `run_adsl2_adae2_oda.sas` | — | `adsl2_adae2_adsl2`, `_adae2` |
| `build_adam2_metadata_oda.sas` | `adam2_metadata.log` | `adam2_metadata_adam2_var_trace`, … + CSV |
| `run_qc_compare_adam2_oda.sas` | `qc_compare.log` | `qc_compare_qc_adam2_mismatches`, … |
| `run_qc_adam2_suite_oda.sas` | `qc_adam2_suite.log` | QC tables + `golden_subjects_*` |
| `run_golden_subjects_oda.sas` | `golden_subjects.log` | `golden_subjects_summary`, … |
| `run_edge_tests_oda.sas` | `edge_tests.log` | `edge_tests_log_issues` |

Also: `*_annotated.log` (for `%m_chklog` line numbers), `_oda_publish_<runtag>.txt` markers, and `adam2_workflow_log_issues.sas7bdat` when `%m_chklog` runs.

## Layers of checking

| Layer | Source | What it enforces | Typical severity |
|-------|--------|------------------|------------------|
| Golden subjects | `validation/gs_mock_spec_adam2.md` | Known edge cases vs frozen oracle | ERROR on mismatch |
| Edge tests | `m_edge_tests_adam2.sas` | Keys, duplicates, flags on built ADaM | WARNING if dataset missing |
| Ref compare | `m_qc_compare_adam2.sas` | Row/variable diff vs R gold (`ref.ref_*`) | ERROR on controlled mismatch |
| Missingness | `metadata/adam2_ds_vars.csv` | Required / Expected variable completeness | FAIL / WARN by core |
| Metacore align | `metadata/adam2_var_trace` + spec CSV | Variable presence, label, length vs trace | INFO / WARN |
| xportr (R) | `metadata/adam2_var_inventory.csv` | Transport type, length, label, order | CSV summary |
| Log scan | `m_chklog.sas` | ERROR/WARNING patterns in saved log | Reporting only |

## Match keys (why `*SEQ` is not the key)

`AESEQ` / `VSSEQ` / `EGSEQ` / `CMSEQ` / `LBSEQ` carry no clinical meaning. They just number records within a subject, and each side numbers them independently from its own view of the source. If one side has one extra or one missing source record, every later `*SEQ` on that side shifts by one — so a single upstream difference reports as thousands of "key orphans" and buries the real finding.

Each domain therefore declares two things:

| Parameter | Meaning |
|-----------|---------|
| `sortkeys=` | The ADaM sort key — business columns both builders reproduce from SDTM |
| `tiebreak=` | The `*SEQ`, used **only** to order rows inside a duplicate `sortkeys` group |

`%m_qc_prep_pair` copies both sides, probes mixed-case character keys, UPCASE(STRIP)s character business keys, coerces char `*SEQ`/`*NUM` and ISO date keys as needed, then `PROC SORT`s by `sortkeys tiebreak` and derives `_KEYSEQ` — the 1-based ordinal of the row inside its `sortkeys` group. The merge / `PROC COMPARE ID` key is `sortkeys _KEYSEQ`. When the sort key is unique, `_KEYSEQ` is `1` on every row, so numbering can only ever go wrong inside one duplicated key group; it cannot cascade.

**Case rule:** character match keys (`USUBJID`, `PARAMCD`, `VISIT`, `AEDECOD`, …) are forced uppercase on the QC working copies only. Adam vs R gold often differ only in case; without the UPCASE those rows sort apart and report as total orphans. Resolved sortkeys are already excluded from value-compare lists, so this does not hide a real content mismatch on a non-key variable.

The `*SEQ` is **tiebreak only** (orders duplicate `sortkeys` groups for `_KEYSEQ`). It is **excluded from value compare** — SEQ is assignment order, not clinical content. Comparing EGSEQ previously reported every ADEG row as a value mismatch (e.g. 43 vs 12) even when AVAL/PARAM matched.

## Row-count-first triage (verify `n` before value diffs)

**Mental model:** equal row counts are a gate, not a footnote. If SAS `adam.*` and R `ref.ref_*` disagree on `n`, key orphans and value diffs describe an incomplete pairing and must not be read as derivation disagreements until counts match.

| Digest `status` | Meaning | What was compared |
|-----------------|---------|-------------------|
| `PASS` | `base_n = compare_n`, keys match, no value diffs | Full compare |
| `COUNT` | `base_n ≠ compare_n` | Key/value compare still runs, but `value_diffs` is marked **secondary/UNRELIABLE** until `n` matches |
| `SCOPE` | ADLB only: one side has under half the rows of the other | **Nothing** compared — fix inputs and re-run |
| `POLICY` | ADAE only: equal `n`, orphans from REF missing `ASTDT` **values** vs SAS imputed dates (match key already includes `ASTDT`) | **DATE_IMPUTE / gold-policy** — not a missing key column and not a SAS bug; user reviewing cases |
| `FAIL` | Counts match, but key orphans and/or value diffs (not DATE_IMPUTE) | Key/value results are meaningful |

In the digest, `base` = R gold and `compare` = SAS build, so **`base_n` = gold row count** and **`compare_n` = SAS row count**. Layer 1 (`%m_qc_one`) prints the same numbers as `SAS n=` / `REF n=` at the start of every domain.

**SAS `first./last.` vs R ordering.** SAS builders often collapse or flag with `PROC SORT` + `first.` / `last.` BY-group logic. R can replicate that (`group_by` + `slice` / `filter(row_number()==1)`), but **tie-break and default sort order can differ**, so one side keeps an extra row (or a different row) when keys are not unique. That shows up first as unequal `n` (or as equal `n` with divergent `*SEQ` / order-dependent derives). When counts differ — or when counts match but SEQ/order-dependent values diverge — check sort order and tie-breaks on both sides **before** chasing individual value mismatches.

### Per-domain keys

**Alignment rule (authoritative):** BDS and OCCDS do **not** share one key pattern with each other. For each dataset, SAS ADaM sort keys must align with the corresponding Track A R gold (`ref.ref_*`) for **that same dataset** — e.g. `adam.advs` ↔ `ref.ref_advs`, `adam.adae` ↔ `ref.ref_adae`. Derive each domain’s sort from pharmaverse/admiral spex for that class, then keep R export + SAS builder + QC defaults on the **same per-domain** key. Do not force ADAE to look like ADVS (or the reverse).

| Class | Domain | SAS ↔ R pair | `sortkeys=` | `tiebreak=` | Uniqueness / spex note |
|-------|--------|--------------|-------------|-------------|------------------------|
| Subject | ADSL | `adam.adsl` ↔ `ref.ref_adsl` | `USUBJID` | — | Subject-level (not OCCDS / not BDS) |
| **OCCDS** | ADAE | `adam.adae` ↔ `ref.ref_adae` | `USUBJID ASTDT AEDECOD` | `AESEQ` | OCCDS spex: analysis start + preferred term. `ASTDT` is ADaM analysis start (not SDTM `AESTDTC`). `*SEQ` orders same-day same-PT via `_KEYSEQ` |
| **OCCDS** | ADCM | `adam.adcm` ↔ `ref.ref_adcm` | `USUBJID ASTDT CMDECOD` | `CMSEQ` | OCCDS spex (same class as ADAE, not BDS). `CMDECOD` = dictionary term |
| BDS-TTE | ADTTE | `adam.adtte` ↔ `ref.ref_adttee` | `USUBJID PARAMCD` | — | **BDS-TTE** (not OCCDS) — one row per subject-parameter |
| **BDS** | ADVS | `adam.advs` ↔ `ref.ref_advs` | `USUBJID PARAMCD AVISIT ADT` | `VSSEQ` | BDS spex: **AVISIT** = ADaM analysis visit (admiral `bds_finding` / ADaMIG). Keep SDTM `VISIT` as content. `*SEQ` for same-key repeats |
| **BDS** | ADEG | `adam.adeg` ↔ `ref.ref_adeg` | `USUBJID PARAMCD AVISIT ADT` | `EGSEQ` | BDS finding shape (same class as ADVS, not OCCDS) |
| **BDS** | ADLB | `adam.adlb` ↔ `ref.ref_adlb` | `USUBJID PARAMCD AVISIT ADT` | `LBSEQ` | BDS finding shape (`VISIT` kept as content) |

Resolution order for every domain:

1. Prefer `SORTEDBY` from **adam** metadata (SAS `adam.*` after builder `PROC SORT` = Admiral / as-programmed sort). Ref XPT usually has none after convert — still use adam’s SORTEDBY when those vars exist on both sides (do not fall back to defaults just because ref lacks metadata).
2. If both adam and ref report `SORTEDBY` and they differ, **adam wins** (logged). Ref metadata is used only when adam has none.
3. Else caller `sortkeys=` / `tiebreak=` from the QC driver.
4. Else `%m_qc_default_keys` map above.
5. Drop any token missing on either side; never keep a bare `*SEQ` as the sole match key.
6. `%m_qc_prep_pair` `PROC SORT`s both sides by the resolved key and appends derived `_KEYSEQ` so duplicate business-key groups stay 1:1.

Three places must stay in step **per domain** when that domain’s key changes:

1. final `PROC SORT` at the end of that domain’s builder (`SAS/macros/m_ad*.sas`)
2. `%m_qc_default_keys` entry for that label in `SAS/macros/m_qc_compare.sas`
3. matching `arrange()` for that ref in `SAS/R/export_r_adam_ref.R`

**BDS visit / sort spex (north star = admiral / pharmaverse, not the thin Track A template).** The Track A Rmd template omitted `VISIT`/`AVISIT` on ADVS/ADEG; that was incomplete versus:

- ADaMIG BDS structure: one or more records per subject × parameter × **analysis timepoint** (typically `AVISIT` / `AVISITN`, and/or `ATPT`) — see CDISC ADaMIG §BDS definitions
- [admiral Creating a BDS Finding ADaM](https://pharmaverse.github.io/admiral/main/articles/bds_finding.html) — derives `AVISIT`/`AVISITN` from `VISIT`; analysis flags use `by_vars` including `AVISIT`; `ASEQ` order uses `AVISITN`
- [pharmaverse ADVS example](https://pharmaverse.github.io/examples/adam/advs.html) — same timing derive + `sort_by_key(metacore)`
- Local `pharmaverseadam::advs` / `adeg` / `adlb` — all carry **both** `AVISIT` and `VISIT`

**Match key choice:** `AVISIT` (analysis visit label) + `ADT` + `*SEQ` tiebreak. `AVISITN` is derived/kept as content (define.xml Keys often list `AVISITN`; admiral analysis `by_vars` use character `AVISIT`). `VISIT` remains SDTM traceability, not the primary analysis key. SORTEDBY preference remains **adam first**.

**OCCDS sort spex (admiral / pharmaverse for OCCDS — independent of BDS keys).** In-scope OCCDS members are **ADAE** and **ADCM** only. ADSL is subject-level; ADTTE is BDS-TTE. OCCDS keys are not required to resemble BDS `PARAMCD`/`AVISIT` keys.

| Spex source | What it implies for keys |
|-------------|--------------------------|
| [admiral Creating an OCCDS ADaM](https://pharmaverse.github.io/admiral/main/articles/occds.html) | Occurrence flags / ASEQ ordered by analysis start (`ASTDT`/`ASTDTM`) + SDTM `*SEQ` (+ ATC on ADCM when present). Preferred-term flags use `by_vars = exprs(USUBJID, CMDECOD)` / AE term grouping |
| [pharmaverse ADAE example](https://pharmaverse.github.io/examples/adam/adae.html) | `sort_by_key(metacore)` after specs; occurrence extreme flag order includes `ASTDT`, `AESEQ` |
| admiral `use_ad_template("ADAE")` / `("ADCM")` | ADAE: no final ASEQ in template — occurrence order still `ASTDTM`/`ASTDT` + `AESEQ`. ADCM ASEQ demo: `order = exprs(ASTDTM, CMSEQ, ATC1CD, …)` |
| Local `pharmaverseadam::adae` / `adcm` | Carry `ASTDT`, dictionary terms (`AEDECOD`/`CMDECOD`), and SDTM `*SEQ` |

**Match key choice (CURRENT):** `USUBJID` + `ASTDT` + `AEDECOD`/`CMDECOD`, with `AESEQ`/`CMSEQ` as **tiebreak only**. Dictionary term is required so same-day multi-term rows do not collide under `_KEYSEQ`. We use **date** `ASTDT` (not `ASTDTM`) because Track A gold and CURRENT builders expose analysis dates for QC pairing. ATC hierarchy is not on CURRENT ADCM — when added, consider extending the business key or ASEQ order per the OCCDS vignette.

Three places must stay in step for OCCDS too: builder `PROC SORT`, `%m_qc_default_keys`, R `arrange()`.

### Can the keys be read from SAS metadata?

Yes for adam. `dictionary.columns.SORTEDBY` (also `sashelp.vcolumn`) holds each variable's 1-based position in the `BY` list of the `PROC SORT` that produced the member, `0` when it is not part of the sort key. `%m_qc_meta_sortedby` reads it and `%m_qc_resolve_keys` prefers **adam** SORTEDBY when it validates against both sides.

Caveats:

- SORTEDBY exists **only** when the member was really `PROC SORT`ed. A `DATA` step copy, an XPORT convert, or a `haven`-written XPT carries no sort order.
- R gold refs therefore usually report nothing — XPT has no sort metadata to convert. That does **not** force a fallback to defaults: adam SORTEDBY is still used when the key vars exist on ref.
- The `adam.*` members report a key because each builder ends in a `PROC SORT` with **that domain’s** key (BDS finding: `USUBJID PARAMCD AVISIT ADT *SEQ`; OCCDS: `USUBJID ASTDT *DECOD *SEQ`; etc.). Remove that sort and the resolver drops back to the explicit map.

The log line `MATCH KEY source=…` on every domain says which source was used (`METADATA` = adam/ref SORTEDBY with adam preferred, `CALLER`, or `DEFAULT`).

A trailing `*SEQ` in a metadata key list is split off as the tiebreak, so a builder sorted by `USUBJID PARAMCD AVISIT ADT LBSEQ` resolves to `sortkeys=USUBJID PARAMCD AVISIT ADT`, `tiebreak=LBSEQ`.

## ADLB `status=SCOPE` — what it means

`SCOPE` is a large-gap outcome alongside `PASS`, `COUNT`, and `FAIL`: **nothing was compared**, because the two datasets are not holding the same set of lab records. Modest count mismatches (not a 2× gap) use `status=COUNT` instead — see **Row-count-first triage** above.

Both builders apply the same ADLB row filter — keep an LB record when `LBSTRESN` and the derived `ADT` are both non-missing (`%m_adlb`, and the `adlb` block of `export_r_adam_ref.R`). Neither side subsets by population, visit or parameter. So the row counts must be the same order of magnitude. If one side has less than half the rows of the other, comparing values would produce tens of thousands of orphans and nothing usable.

The gate is **symmetric** — the short side determines the fix:

| Short side | Meaning | Fix |
|------------|---------|-----|
| Gold (`ref.ref_adlb`) | The R export dropped rows or gold was not loaded | Re-run `R/export_r_adam_ref.R` and confirm `ref.ref_adlb` under `validation/` |
| SAS (`adam.adlb`) | The SAS build dropped rows | Check the raw LB upload and the `LBDTC` parse — regenerating gold will not help |

Reading the digest: `base` is the R gold ref and `compare` is the SAS build, so `base_n` is the gold row count and `compare_n` is the SAS row count.

When the gate fires it also runs `%m_qc_lb_source_diag`, which counts raw LB rows surviving each filter step. It prints the SAS-vs-R parse gap directly as `rows the SAS strict parse drops but R keeps`.

**Resolved 18AUG2026 — this was the cause of `adam.adlb` n=220 vs gold n=58700.** `%m_safe_iso_date` used to accept `--DTC` only when it was exactly 10 characters of `YYYY-MM-DD`, while admiral `derive_vars_dt` (the gold side) also accepts an ISO 8601 datetime such as `2013-02-08T10:20` and keeps its date part. `LBDTC` in pharmaversesdtm carries a time on 59,355 of 59,580 rows, so `ADT` was missing for all of them and the `not missing(ADT)` filter dropped them — leaving 220 rows. `%m_safe_iso_date` now takes the date part before `T`, which brings `adam.adlb` to 58,700 rows, matching gold exactly. LB was the only domain affected: every other `--DTC` in this study package is date-only, so `ADSL`/`ADAE`/`ADTTE`/`ADVS`/`ADEG`/`ADCM` parse counts are unchanged.

If the gate fires on the SAS side again, re-check the raw LB upload first (`%m_qc_lb_source_diag` reports 0 for `with non-missing LBSTRESN` when the XPT convert is the problem).

## SAFFL / analysis population (SAS vs R gold)

**Policy (current):** builders and QC compare keep **all subjects / all domain rows**. `SAFFL` is an ADSL analysis flag, not a row filter. Do not drop non-safety subjects from SAS ADaMs to “match” gold.

| Layer | SAFFL=Y filter? | Notes |
|-------|-----------------|-------|
| `%m_adsl2` | No — all DM rows | Derives `SAFFL` (SUPPDM SAFETY, else EX exposure, else `N`) |
| `%m_adae2` / `%m_adcm2` / `%m_advs2` / `%m_adeg2` / `%m_adlb` | No | Domain rows + ADSL merge; no population subset |
| `%m_adttee2` | No | One TTE row per ADSL subject; event filter is `TRTEMFL='Y'`, not `SAFFL` |
| R gold (`export_adam_ref*`) | No | ADSL from DM + TRT dates; **often no `SAFFL` column at all** |
| `%m_qc_compare` / `%m_qc_compare_adam2` | No | Full key merge; `SAFFL`/`ITTFL` requested on ADSL but **skipped** when absent on REF |

**Suspicion that QC noise is “non-SAFFL subjects”:** only weakly plausible for *value* diffs on subjects with `SAFFL='N'` (e.g. no `TRTSDT`). It does **not** explain SAS↔REF row-count divergence, because neither side filters on `SAFFL`. Prior blank-`_ref_val` noise for `SAFFL`/`ITTFL` was harness scope (SAS-only vars), not population mismatch.

**Optional future QC scope** (not implemented): restrict `%m_qc_one` inputs to `USUBJID` with SAS `adam.adsl.SAFFL='Y'` (join ADSL — gold lacks `SAFFL`). Use only as an explicit safety-population slice; keep default full-population compare and never filter builders to match.

## ADAE ASTDT keys (methodology / gold-policy)

**Preferred reporting stance (SAS `%m_adae2`):** `highest_imputation=D` only (never month/year). AE **onset** day is **subject-relative** via a TE-aware DATA step after DTM parse — **not** a blanket first-of-month / last-of-month rule. AENDT keeps `date_imputation=last` only (no TE-window bias on end).

| Partial AESTDTC | Imputed ASTDT |
|-----------------|---------------|
| Month+year = TRTSDT month+year (day missing) | `TRTSDT` (that subject's first dose day) |
| Else month interval intersects `[TRTSDT, TRTEDT+end_window]` (day missing) | `TRTEDT+end_window` (window end) |
| Month+year present but outside TE window (day missing) | `ASTDT` missing (no day-1 invent); `TRTEMFL` blank (not admiral missing→Y) |
| Year-only / missing month | `ASTDT` missing (no month/year invent) |
| Complete date | as-is (no TE override) |

**TE window (confirmed):** upper bound is **`TRTEDT + end_window`** (default `end_window=30`) — same as `%m_derive_var_trtemfl` / R gold. This is **not** `LDOSEDT+30` (last dose prior to AE is a separate OCCDS join).

Day-missing ambiguity still counts against the drug safety profile. Do **not** switch SAS to `hi=n` solely to match Track A gold.

**Track A R gold today** (`export_r_adam_ref.R`): `derive_vars_dt(..., highest_imputation = "n")` leaves partial `AESTDTC` as missing `ASTDT`. Year-only / missing-month partials align (both missing). Day-missing month+year cases that SAS imputes via TE rules remain a **methodology / gold-policy gap** (SAS imputed vs gold missing) — not a SAS bug to “fix away.”

| Side | AE start dates | Match-key effect |
|------|----------------|------------------|
| SAS `%m_adae2` | DTM `hi=D` + TE subject-relative day → imputed `ASTDT` when a TE rule applies | Day-missing AEs keyed on imputed dates |
| Track A gold | `hi=n` → missing `ASTDT` | Same AEs keyed on missing |

QC labels these as **DATE_IMPUTE / gold-policy** (not raw KEY FAIL noise) when the orphan pattern matches. Closing the gap later means **gold adopts day-only conservative imputation** — not SAS weakening to `hi=n`.

## ADLB row scope and the `--DTC` date part

**Policy:** ADLB keeps an LB record when `LBSTRESN` **and** the derived `ADT` are both non-missing. That is the entire row filter on both sides — no population, visit, parameter or `LBCAT` subset. So SAS and gold must land on the same row count, not merely the same order of magnitude.

Reference counts for pharmaversesdtm `lb`:

| Population | Rows |
|------------|------|
| Raw SDTM `LB` | 59,580 |
| `LBSTRESN` non-missing (= expected ADLB) | 58,700 |
| `LBDTC` values carrying a collection time (`YYYY-MM-DDThh:mm`) | 59,355 |
| `LBDTC` values that are a bare `YYYY-MM-DD` | 225 |

**The 220-row ADLB bug (fixed 18AUG2026).** `%m_safe_iso_date` accepted `--DTC` only when the value was exactly 10 characters, so `ADT` was missing for every lab record collected with a time and `adam.adlb` built **220** rows against **58,700** in the gold. The fix takes the ISO 8601 date part (`scan(...,1,'T')`), which is what admiral `derive_vars_dt(highest_imputation = "n")` does on the gold side. Partial dates (`2013-12`, `2013-12--`) still yield missing — this layer imputes nothing.

| Layer | Parses `YYYY-MM-DDThh:mm` | Where |
|-------|---------------------------|-------|
| SAS builders (`%m_adlb`, `%m_advs2`, `%m_adeg2`, `%m_derive_vars_joined`) | Yes | `m_util.sas` `%m_safe_iso_date` |
| Gold `export_r_adam_ref.R` | Yes | admiral `derive_vars_dt(highest_imputation = "n")` |
| Gold `export_r_adam_ref3.R` / `export_adam_ref5.R` | Yes | local `safe_iso_date` helper |

The `safe_iso_date` helper in the `ref3` / `ref5` exports was anchored with `$`, i.e. it had the same strict-length defect. Regenerating gold from those scripts before 18AUG2026 would have shrunk `ref_adlb` to 220 rows too. Keep all four implementations on the date-part rule.

**Reading the ADLB SCOPE gate.** `%m_qc_compare_adam2` writes `status=SCOPE` (not PASS, not FAIL — nothing was compared) when one side has under half the rows of the other, and names the short side. Gold short means re-run the R export and confirm `ref.ref_*` sas7bdat under `validation/`. **SAS short does not mean the gold is stale** — check `raw.lb` and the `LBDTC` parse first, and confirm ODA has the current `macros/m_util.sas`. `%m_qc_lb_source_diag` prints the surviving row count per filter step so the short side can be attributed rather than guessed.

## Treatment-emergent window (TRTEMFL) — SAS and R gold agree

Both sides use **admiral** `derive_var_trtemfl` rules (SAS `%m_derive_var_trtemfl`, R `admiral::derive_var_trtemfl`):

| Bound | Rule |
|-------|------|
| Missing treatment start | blank |
| End before treatment start | blank |
| **Missing ASTDT** (and end not before TRTSDT) | **`Y`** |
| Start | `ASTDT >= TRTSDT` |
| End | `ASTDT <= TRTEDT + end_window` (default `end_window=30`) |

| Layer | Where | Default |
|-------|--------|---------|
| SAS ADAE | `%m_adae2(end_window=30)` → `%m_derive_var_trtemfl` | 30 |
| SAS ADCM | `%m_adcm2(end_window=30)` | 30 |
| R gold | `export_r_adam_ref.R`: `derive_var_trtemfl(..., end_window = 30)` | 30 |
| ADTTE event | First AE with `TRTEMFL='Y'` (not `SAFFL`) | — |

**Do not** use a simplified `case_when` that requires non-missing `ASTDT` for `Y` — that disagreed with admiral on partial/missing CM/AE starts and drove ADCM TRTEMFL Y-vs-blank mass diffs.

Protocol can lengthen the post-`TRTEDT` buffer by changing `end_window=` on the SAS builders **and** the matching R `end_window` — keep them in sync.

**ADAE partial starts:** before `%m_derive_var_trtemfl`, `%m_adae2` may set `ASTDT` to `TRTSDT` or `TRTEDT+end_window` when month+year are known and day is missing (`ASTDTF='D'`; see ADAE ASTDT keys above). After admiral TRTEMFL, a day-missing **YM-in-window** pass forces `TRTEMFL='Y'` when the onset year-month intersects `[TRTSDT, TRTEDT+end_window]` even if `ASTDT` stays missing; out-of-window cleared partials (missing `ASTDT`) override admiral missing-start=`Y` to blank. Year-only cannot use the YM rule; complete onset dates use ASTDT-vs-window only.

**Important:** blank `_ref_val` for `TRTSDT`/`TRTEDT` is **not** a window disagreement. It means gold treatment dates are missing or not converted. `%m_qc_compare_adam2` now **ERRORs** when `ref.ref_adsl` has no (or mostly missing) `TRTSDT` while `adam.adsl` has dates — regenerate gold before interpreting TEAE/ADTTE diffs.

## Dual-track QC

- **Track A (this repo):** home-grown refs via `export_r_adam_ref.R` — see `dual_track_qc.md`
- **Track B:** upstream `pharmaverseadam` — separate project `SAS_mirrored_Admiral_safety_ADaM`

## `%m_chklog` and line numbers

Drivers use `PROC PRINTTO` to `&LOGDIR` under the project. `%m_oda_publish` copies the log to `safety_monitoring_system/SAS/output/`. Use `adam2_workflow_annotated.log` there to match `%m_chklog` `linenum` values.

`%m_chklog` only flags keywords found in **column 1** — that is where SAS writes `ERROR:` / `WARNING:` / `NOTE:` (and numbered forms such as `ERROR 22-322:`). Indented text is listing output (PROC PRINT of a `line` column, titles, wrapped continuation lines) and is deliberately ignored.

The `source` column separates the two kinds of finding:

| `source` | Meaning | Where to fix |
|----------|---------|--------------|
| `SAS` | SAS engine wrote the message | A real log defect — fix the code |
| `QC` | A QC macro wrote `%put WARNING: [ADEG] …` | A compare result — triage `adam.qc_adam2_procompare` |

The closing `WARNING: Log issues found` fires when any `source=SAS` row exists **or** any `ERROR` was flagged (assertion macros write `ERROR: [GOLDEN FAIL]`). A log whose only findings are QC `WARNING`s reports at NOTE level instead.

## `%m_derive_vars_joined` join types (v1 port)

Port scope limit, not a regulatory rule. Supports `all`, `left`, `inner`, and `full`/`outer` (alias for `all`). `right` is not ported — swap dataset roles instead.

## ODA macro pitfalls

SAS OnDemand **does not allow DATALINES/CARDS inside a `%macro`**. Mock fixtures use explicit `output` rows. See `.cursor/rules/sas-comment-pitfalls.mdc`.
