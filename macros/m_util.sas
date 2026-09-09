/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_util.sas
  SAS Version                 : 9.4
  Purpose (short description) : Shared utility macros (nobs, ISO date/DTM, relative day)
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Caller-supplied datasets
  Modification Log            : 18AUG2026 - Marked %m_derive_dy deprecated - prefer
                                %m_derive_vars_dy (admiral) in builders.
                                18AUG2026 - Split ISO helpers into DTC vs DTM paths (admiral-
                                style). Added %m_safe_iso_dtm. %m_safe_iso_date keeps the
                                date-part-before-T rule so LBDTC datetimes still yield ADT
                                (~58.7K ADLB rows). Do not use the DTM helper for ADT vars.
                                18AUG2026 - %m_safe_iso_date accepts YYYY-MM-DD date part of
                                an ISO 8601 datetime (scan before 'T'). Old exact 10-char test
                                held adam.adlb at 220 rows vs 58,700 in the R gold.
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Utility macros for ADaM workflow (mirror R / admiral helpers)

  DTC vs DTM (do not conflate):
    *DTC  = date/datetime character (ISO). Date-only is typically $10.
    *DT   = numeric SAS date (date9.) - ADT, ASTDT, TRTSDT, ...
    *DTM  = numeric SAS datetime (datetime20.) - ASTDTM, TRTSDTM, ...
    DTM -> char uses $20 (never length 21).

  Lightweight DATA-step snippets (no imputation):
    %m_safe_iso_date  — *DTC -> *DT   (admiral derive_vars_dt / hi=n analog)
    %m_safe_iso_dtm   — *DTC -> *DTM  (admiral derive_vars_dtm / hi=n, no time impute)

  Full admiral ports (imputation / flags):
    %m_derive_vars_dt   — in m_derive_vars_dt.sas
    %m_derive_vars_dtm  — in m_derive_vars_dtm.sas

  Use the date path for ADT-like vars even when the source *DTC carries a time
  (e.g. LBDTC -> ADT). Use the DTM path only when the ADaM var is *DTM.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_nobs(ds=);
       %if %sysfunc(exist(&ds)) %then %do;
       %local dsid n;
       %let dsid = %sysfunc(open(&ds, i));
       %let n = %sysfunc(attrn(&dsid, nlobs));
       %let dsid = %sysfunc(close(&dsid));
       %put NOTE: &ds has &n observations.;
  %end;
  %else %put WARNING: Dataset &ds does not exist.;
%mend m_nobs;


/*------------------------------------------------------------------------------
  %m_safe_iso_date — DATA-step snippet (DTC path -> *DT)

  Analog of admiral::derive_vars_dt(..., highest_imputation = "n") for a single
  pair of vars inside a DATA step. Output is a SAS date, never a datetime.

  - Takes the ISO date part before 'T' (datetime-like *DTC still yields a date).
  - Partial / non-ISO -> missing. No imputation.
  - Use for ADT, ASTDT, TRTSDT, AESTDT, etc. Do NOT use for *DTM vars.

  Usage:
    %m_safe_iso_date(invar=LBDTC, outvar=ADT);
------------------------------------------------------------------------------*/
%macro m_safe_iso_date(invar=, outvar=);
  length &outvar 8;
  format &outvar date9.;
  &outvar = .;
  if not missing(&invar) then do;
    _iso = scan(strip(&invar), 1, 'T');
    if length(_iso) = 10
       and substr(_iso, 5, 1) = '-'
       and substr(_iso, 8, 1) = '-'
       and notdigit(compress(substr(_iso, 1, 4) || substr(_iso, 6, 2) || substr(_iso, 9, 2))) = 0
    then &outvar = input(_iso, ?? yymmdd10.);
    drop _iso;
  end;
%mend m_safe_iso_date;


/*------------------------------------------------------------------------------
  %m_safe_iso_dtm — DATA-step snippet (DTM path -> *DTM)

  Analog of admiral::derive_vars_dtm for a single pair of vars when no
  imputation is wanted. Output is numeric SAS datetime (datetime20.).

  - Requires a full YYYY-MM-DD date part AND a time part after 'T' (hh:mm or
    hh:mm:ss). Date-only *DTC stays missing here - use %m_safe_iso_date for *DT
    or %m_derive_vars_dtm when time imputation is intended (ADSL/ADAE ports).
  - Missing seconds default to 0 when hh:mm is present (ISO often omits :ss).
  - Temp char lengths use $20 for the time piece (never $21).
  - Use for ASTDTM, AENDTM, EXSTDTM, etc. Do NOT use when the ADaM var is ADT.

  Usage:
    %m_safe_iso_dtm(invar=AESTDTC, outvar=ASTDTM);
------------------------------------------------------------------------------*/
%macro m_safe_iso_dtm(invar=, outvar=);
  length &outvar 8
         _sid_raw $40 _sid_d $10 _sid_t $20
         _sid_dt _sid_hh _sid_mm _sid_ss 8;
  format &outvar datetime20.;
  &outvar = .;
  if not missing(&invar) then do;
    _sid_raw = strip(&invar);
    _sid_d = scan(_sid_raw, 1, 'T');
    _sid_t = '';
    if index(_sid_raw, 'T') then _sid_t = scan(_sid_raw, 2, 'T');
    _sid_dt = .;
    _sid_hh = .;
    _sid_mm = .;
    _sid_ss = .;
    if length(_sid_d) = 10
       and substr(_sid_d, 5, 1) = '-'
       and substr(_sid_d, 8, 1) = '-'
       and notdigit(compress(substr(_sid_d, 1, 4) || substr(_sid_d, 6, 2) || substr(_sid_d, 9, 2))) = 0
    then _sid_dt = input(_sid_d, ?? yymmdd10.);
    if not missing(_sid_dt) and _sid_t ne '' then do;
      if length(_sid_t) >= 2 and notdigit(substr(_sid_t, 1, 2)) = 0 then
        _sid_hh = input(substr(_sid_t, 1, 2), 2.);
      if length(_sid_t) >= 5 and substr(_sid_t, 3, 1) = ':'
         and notdigit(substr(_sid_t, 4, 2)) = 0 then
        _sid_mm = input(substr(_sid_t, 4, 2), 2.);
      if length(_sid_t) >= 8 and substr(_sid_t, 6, 1) = ':'
         and notdigit(substr(_sid_t, 7, 2)) = 0 then
        _sid_ss = input(substr(_sid_t, 7, 2), 2.);
      else if not missing(_sid_hh) and not missing(_sid_mm) then
        _sid_ss = 0;
      if not missing(_sid_hh) and not missing(_sid_mm) and not missing(_sid_ss) then
        &outvar = dhms(_sid_dt, _sid_hh, _sid_mm, _sid_ss);
    end;
  end;
  drop _sid_raw _sid_d _sid_t _sid_dt _sid_hh _sid_mm _sid_ss;
%mend m_safe_iso_dtm;


/*------------------------------------------------------------------------------
  %m_derive_dy — DEPRECATED DATA-step snippet

  Prefer dataset-level %m_derive_vars_dy (admiral::derive_vars_dy port) in
  builders. Kept for legacy open-code / one-liner use only. Same relative-day
  formula (no Day 0).

  Usage:
    %m_derive_dy(date=ASTDT, ref_date=TRTSDT, outvar=ADY);
------------------------------------------------------------------------------*/
%macro m_derive_dy(date=, ref_date=, outvar=ADY);
  if missing(&date) or missing(&ref_date) then &outvar = .;
  else if &date >= &ref_date then &outvar = &date - &ref_date + 1;
  else &outvar = &date - &ref_date;
%mend m_derive_dy;
