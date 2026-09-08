# Part B — ADAE gaps vs `pharmaverseadam`

**Date:** 23AUG2026  
**Gold:** `pharmaverseadam::adae` / `ref_pva.refadae`  
**SAS:** `%m_adae_pva` → Part B `adam.adae`  
**Builder:** `SAS/macro/m_adae_pva.sas` (Part B only — Track A `%m_adae2` unchanged)

## PROC COMPARE: ADSL PASS / ADAE residual ~1148 (revised)

### Layer A — `*DTM` scale (fixed in QC; tracked as ADAM issue)

`refadae.xpt` stores `ASTDTM`/`AENDTM`/`LDOSEDTM` as **Date** (date-scale ~6210-20030), while `%m_adae_pva` builds **datetime**. Part B `%m_qc_norm_dtm_scale` promotes date-scale and midnight-collapses `time_imputation=last` (23:59:59) on QC copies. That alone dropped ADSL 254→0 and ADAE 1191→1148 (**43** rows cleared — AST-only / no LDOSE mismatch).

**Catalog:** `adam.qc_sdtm_issues` / `SOURCE=ADAM` / `PVA_ADAE_DTM_DATE_COLLAPSE` — do **not** count this gold quirk against SAS ADAE (see `qc_sdtm_issues_pva.md`).

### Layer B — last dose / DOSEON (builder — drives ~1148)

After DTM norm, residual row fails are **clinical**, mainly `LDOSEDTM`/`LDOSEDT`/`DOSEON`/`DOSEU`:

| Fact | Count |
|------|------:|
| Gold `LDOSEDTM` nonmiss | 1126 |
| Match vs period `raw.ex` last dose | ~42 |
| Match vs `admiral::ex_single` last dose | **1126** |
| Gold `DOSEON` nonmiss | 796 (= same calendar day as `ASTDT`) |

**Root cause:** PVA gold uses **single-dose EX** (`admiral::ex_single`: keep `EXDOSE in (0,54)`, expand one row per day). Period SDTM EX cannot reproduce LDOSE. Also `DOSEON`/`DOSEU` are **same-day** dose amount/unit, not the prior-day last-dose amount.

**Fix:** `%m_ex_single_pva` (called from `%m_adae_pva`) expands EX like `ex_single`, then last-dose join (`EXSTDTM<=ASTDTM`, asc + `mode=last`), then blank `DOSEON`/`DOSEU` when `LDOSEDT ne ASTDT`. No EOSDT AEN post-cap (DTHDT via DTM `max_dates=` only).

## What changed vs Track A `%m_adae2`

| Area | Track A (`%m_adae2`) | Part B (`%m_adae_pva`) |
|------|----------------------|-------------------------|
| AST/AEN impute | DTM `hi=D` + TE-relative day | DTM `hi=M` first/last + date-safe min_dates |
| EX / LDOSE | Period EX, date join | `%m_ex_single_pva` daily + DTM join (PVA) |
| Last dose join | `DESC` + `mode=last` | `order=EXSTDTM EXSEQ` + `mode=last` |
| TRTEMFL | admiral port + YM post-pass | `%m_derive_var_trtemfl` only |
| AESI / SMQ / CQ | default on | default **off** |

**POLICY:** Track A keeps conservative `hi=D` + TE-clear + period EX. Part B mirrors PVA / admiral template.

## Daily EX expansion (`%m_ex_single_pva`)

- Filter `EXDOSE in (0, 54)` (placebo/active — matches `create_ex_single.R`)
- Expand each interval calendar day from `EXSTDTC` through `EXENDTC`
- Set `EXSTDTC=EXENDTC` that day, `EXDOSFRQ=ONCE`; **keep EXDOSE/EXDOSU** (QD level unchanged)
- Renumber `EXSEQ` by subject/date; keep `EXROUTE` for `LDOS_RTE`

## ODA rebuild

1. Upload Part B `macro/m_ex_single_pva.sas`, `macro/m_adae_pva.sas`, `programs/create_ADaM_pva_oda.sas`
2. Re-run `create_ADaM_pva_oda.sas` (rebuild `adam.adae`)
3. Upload Part B QC if not already (`m_qc_compare_pva.sas` / `m_qc_procompare_pva.sas` / driver) — DTM norm already required for ADSL PASS
4. Re-run `run_qc_compare_pva_oda.sas` — expect ADAE `status=PASS` `value_diffs=0`

Do **not** overwrite Track A QC macros or `%m_adae2` for Part B work.
