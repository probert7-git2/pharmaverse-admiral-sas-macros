# Part B plan â€” QC vs `pharmaverseadam` (upstream gold)

**Status:** Draft revised after user decisions (20AUG2026).  
**Project:** `c:\Users\probe\SAS_mirrored_Admiral_safety_ADaM`  
**Companion:** `safety_monitoring_system` (Track A SAS `adam.*` + QC macros)

---

## Glossary

| Abbreviation | Meaning |
|--------------|---------|
| **PVA** | **P**harma**v**erse**a**dam â€” the R package `pharmaverseadam` (published admiral-template ADaMs on `pharmaversesdtm`). Track B gold lives in lib `ref_pva` (`validation/`) / members **REFADSL, REFADAE, â€¦** (from user proc copy of `ref*.xpt`). |
| Track A | This safety_monitoring_system project â€” SAS `%m_*` vs local R twin |
| Track B | Separate repo â€” same SAS `adam.*` vs **PVA** gold |

---

## 1. Purpose (talk narrative)

| Track | Gold | Question |
|-------|------|----------|
| **A** (done) | Local R script + admiral on same SDTM | Does SAS match *our* template twin? |
| **B** (this plan) | Published **`pharmaverseadam` (PVA)** | Does SAS match *official* admiral-template ADaMs? |

Part B answers the â€œBronze vs external goldâ€ challenge: home-grown Track A gold can be dismissed as same-team; PVA is Pharmaverse-maintained.

**Expected outcome:** more POLICY / SPEX gaps than Part A â€” â€œmirror vs faint reflection,â€ not false PASS.

---

## 2. Decisions locked (20AUG2026)

### Drop ADTTE / ADTTEE from Part A and Part B

- There is **no** Pharmaverse **safety** time-to-first-TEAE ADaM. PVA ships **`adtte_onco`** only (oncology efficacy TTE).
- Track A `adtte` / `TTAE` was a project convenience view, not a standard safety deliverable.
- **Action:** omit ADTTE from Part A narrative/slides and from Part B QC entirely. (Code can remain in the repo unused; drivers/docs/slides should not treat it as core.)

### ADAE match key for Part B = same as Track A OCCDS

- Business key: **`USUBJID` + `ASTDT` + `AEDECOD`**
- Tiebreak: **`AESEQ`** (ADaM occurrence sequence; sometimes called ASEQ in templates â€” we use the variable actually on the datasets, typically `AESEQ`)

### When the business key repeats: keep the **last** record

User rationale: an earlier row with the same `USUBJID||AEDECOD||ASTDT` may have been superseded by a later `AESEQ`.

**QC implication:** within each business-key group, sort by `AESEQ` and retain / pair on the **maximum AESEQ** (last), not the first. Document this in PVA QC notes so â€œlast winsâ€ is explicit HA policy â€” not silent dropping of clinical multiplicity without reason.

---

## 3. What already exists (scaffold)

| Piece | Location | Notes |
|-------|----------|--------|
| Export PVA â†’ XPT | `SAS/R/export_pharmaverseadam_ref.R` | `adsl, adae, adcm, advs, adeg, adlb` (no ADTTE) |
| XPT â†’ sas7bdat | User simple `proc copy` on ODA | Members **REFADSL, REFADAE, REFADCM, REFADVS, REFADEG, REFADLB** in `validation/` |
| QC driver | `programs/run_qc_compare_pva_oda.sas` | Keys + last-AESEQ + domains vs `ref_pva.refadsl` etc |
| Scope doc | `docs/qc_scope_pva.md` | Common-var / mask philosophy |
| Libnames | `setup/init_libnames_pva.sas` | `ref_pva` â†’ `validation/`, optional `ADAM_PATH` |

---

## 4. Proposed Part B phases

### Phase B0 â€” Prep

1. Confirm ODA has both trees; `adam.*` from Track A is current.
2. Re-export PVA gold; record `packageVersion("pharmaverseadam")`.
3. Proc copy `ref*.xpt` â†’ verify `ref_pva.refadsl` has non-missing `TRTSDT`.
4. Smoke ADSL + ADAE with upgraded keys.

### Phase B1 â€” Modernize PVA QC harness

- `sortkeys=USUBJID ASTDT AEDECOD`, `tiebreak=AESEQ`, then **keep last AESEQ per group** (or equivalent pairing rule).
- Common-var filter + mask SAS-only extensions.
- Digest: PASS / POLICY / FAIL / COUNT; labels `ADSL_PVA`, `ADAE_PVA`, â€¦
- Reuse Track A POLICY for CT `ms` vs `msec` when ADEG is added.

### Phase B2 â€” Domain roll-out

| Wave | Domains | Notes |
|------|---------|--------|
| 1 | ADSL, ADAE | OCCDS key + last AESEQ — builders live (`m_adsl_pva`, `m_adae_pva`; see `part_b_adae_gaps.md`) |
| 2–3 | ADVS, ADEG, ADCM, ADLB | **Local builders added** (`m_advs_pva`, `m_adeg_pva`, `m_adcm_pva`, `m_adlb_pva`); wired in `create_ADaM_pva_oda.sas` when `raw.vs`/`eg`/`cm`/`lb` exist. ADEG `ms`/`msec` = POLICY. ADLB `tox_method=SIMPLE` default. |
| â€” | **ADTTE** | **Out of scope** |

### Phase B3 â€” Docs / slides

- `qc_understood_mismatches_pva.md`
- Part B slides (mirror vs reflection)

---

## 5. Remaining light choices (optional)

1. **Where `adam` lives on ODA** - Part B `SAS/adam/` via `create_ADaM_pva_oda.sas` (locked).
2. **Part A slides** â€” remove or footnote ADTTE PASS row when you edit comments.
3. **Part B slides** â€” after first PVA digest, or scaffold now.

---

## 6. Success criteria

- Clear dual-track story without non-standard TTE clutter.
- ADAE pairing = OCCDS key + **last AESEQ** when duplicates share the key.
- PVA CT / TE gaps labeled POLICY; SAS-only vars masked.
- Reproducible PVA version + proc copy + QC on ODA.

---

## Part B build isolation (22AUG2026)

- **Driver:** `programs/create_ADaM_pva_oda.sas` → writes `SAS/adam/` under this repo only.
- **Builder naming:** `macro/m_*_pva.sas` / `%m_*_pva` (ADSL: `m_adsl_pva`; ADAE: `m_adae_pva`); Track A not edited.
- **SDTM:** read-only from Track A `safety_monitoring_system/SAS/sdtm`. PVA gold was built on **`pharmaversesdtm`**, which is not the same file as Track A `raw.*`. Verbatim SDTM copies in ADaM (`EGTPT`, `EGSTRESU`, …) can differ even when the admiral mirror is 1:1 — see `part_b_adeg_admiral_mirror.md`.
- **Derive ports:** `%include` from Track A `macros/` read-only until copied into Part B.
- **QC:** `run_qc_compare_pva_oda.sas` compares Part B `adam.*` vs `ref_pva`.
- **BDS wave 2–3:** `m_advs_pva`, `m_adeg_pva`, `m_adcm_pva`, `m_adlb_pva` in Part B `macro/`; driver calls when SDTM domains exist.
