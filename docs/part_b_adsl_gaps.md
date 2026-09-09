# Part B — ADSL gaps vs `pharmaverseadam`

**Date:** 23AUG2026  
**Gold:** `pharmaverseadam::adsl` / `ref_pva.refadsl` (n=306)  
**SAS:** Part B `%m_adsl_pva` (companion repo) → `adam.adsl`

## Root cause of PROC COMPARE FAIL (diffs=254) — revised

Not blank TMF after rebuild. Gold XPT stores `TRTSDTM`/`TRTEDTM` as **date-scale** (same numeric as `TRTSDT`); SAS builds **datetime**. See companion `SAS_mirrored_Admiral_safety_ADaM/SAS/docs/part_b_adsl_gaps.md`.

**Fix in this repo (Track A QC macros used by Part B):** `%m_qc_norm_dtm_scale` in `m_qc_compare.sas` (via `%m_qc_prep_pair`) **and** explicit re-call inside `%m_qc_procompare_one` before PROC COMPARE. Log must show `Promoted date-scale *DTM` with `n_values=` (gold side typically hundreds).

## ODA upload (critical)

1. `safety_monitoring_system/SAS/macros/m_qc_compare.sas` — **required** (defines + prep_pair norm)
2. `safety_monitoring_system/SAS/macros/m_qc_procompare.sas` — **required** (Layer-2 re-apply + unequal-var summary)
3. Part B `run_qc_compare_pva_oda.sas` (`keysrc=CALLER`) — already confirmed on ODA if digest says `(CALLER)`

After re-run, search the log for: `Promoted date-scale *DTM`
