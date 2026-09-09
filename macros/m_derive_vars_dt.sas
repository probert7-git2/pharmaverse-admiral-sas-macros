/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_derive_vars_dt.sas
  SAS Version                 : 9.4
  Purpose (short description) : admiral-style derive_vars_dt port for partial ISO dates
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Caller dataset with DTC character var
  Modification Log            : 18AUG2026 - Header: DTC path only (*DT out). Pair with
                                %m_safe_iso_date for no-imputation DATA-step use. Do not
                                use this macro when the ADaM target is *DTM - use
                                %m_derive_vars_dtm / %m_safe_iso_dtm instead.
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  %m_derive_vars_dt  — substantial SAS port of admiral::derive_vars_dt()

    DTC PATH (date only). Creates &new_vars_prefix.DT (and optional *DTF) from --DTC.
    ISO datetime character is accepted - date part before 'T' only (same as admiral).
    Output is SAS date (date9.), never datetime20.

    Pairing:
      admiral derive_vars_dt  <->  %m_derive_vars_dt  (dataset-level, imputation/flags)
                              <->  %m_safe_iso_date   (DATA-step snippet, hi=n, no flags)
      admiral derive_vars_dtm <->  %m_derive_vars_dtm / %m_safe_iso_dtm  (separate path)

    Supported (v1):
      highest_imputation = n | D | M
      date_imputation    = first | last | mid | dd | mm-dd (e.g. 15 or 06-15)
      flag_imputation    = auto | date | none
      preserve           = N (not implemented in v1)
      min_dates / max_dates = single SAS date/datetime variable names (optional)

    Not in v1: highest_imputation=Y with year imputation bounds lists,
               preserve=TRUE day-when-month-missing edge cases beyond mid.

    Example (ADT-like from *DTC, including datetime-like LBDTC):
      %m_derive_vars_dt(
        dataset=work.ae
      , new_vars_prefix=AST
      , dtc=AESTDTC
      , highest_imputation=n
      , out=work.ae2
      );
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_derive_vars_dt(
  dataset=
, new_vars_prefix=
, dtc=
, highest_imputation=n
, date_imputation=first
, flag_imputation=auto
, min_dates=
, max_dates=
, preserve=N
, out=
);

  %local hi hi_raw fi di dtvar dtfvar do_flag;

  %if %length(&dataset)=0 or %length(&new_vars_prefix)=0 or %length(&dtc)=0
      or %length(&out)=0 %then %do;
    %put ERROR: m_derive_vars_dt requires dataset=, new_vars_prefix=, dtc=, out=.;
    %return;
  %end;

  %let hi_raw = &highest_imputation;
  %let hi = %upcase(&hi_raw);
  %let fi = %upcase(&flag_imputation);
  %let di = %lowcase(&date_imputation);
  %let dtvar  = &new_vars_prefix.DT;
  %let dtfvar = &new_vars_prefix.DTF;

  /* admiral: h/m/s lowercase are time-level — belong in %m_derive_vars_dtm only */
  %if &hi_raw = h or &hi_raw = m or &hi_raw = s %then %do;
    %put ERROR: highest_imputation=&hi_raw is time-level - use %m_derive_vars_dtm not _dt.;
    %return;
  %end;

  %if &hi ne N and &hi ne D and &hi ne M %then %do;
    %put ERROR: highest_imputation must be n, D, or M (Y not in v1). Got &highest_imputation;
    %return;
  %end;

  %if %upcase(&preserve) = Y or %upcase(&preserve) = TRUE %then %do;
    %put NOTE: m_derive_vars_dt preserve= is not implemented in v1.;
  %end;
  %let do_flag = 0;
  %if &fi = DATE %then %let do_flag = 1;
  %else %if &fi = AUTO and &hi ne N %then %let do_flag = 1;

  data &out;
    set &dataset;
    length _dtc $10 _yy $4 _mm $2 _dd $2 _dtf $1
           _y _m _d _imp_m _imp_d _has_y _has_m _has_d 8;
    format &dtvar date9.;
    &dtvar = .;
    %if &do_flag %then %do;
      length &dtfvar $1;
      &dtfvar = '';
    %end;

    _dtc = strip(&dtc);
    _yy = ''; _mm = ''; _dd = '';
    _has_y = 0; _has_m = 0; _has_d = 0;
    _dtf = '';
    _imp_m = .; _imp_d = .;

    if missing(_dtc) or _dtc = '' then goto _done_dt;

    /* Strip time portion if present */
    if index(_dtc, 'T') then _dtc = scan(_dtc, 1, 'T');

    /* Parse yyyy-mm-dd with optional --- missing month */
    if length(_dtc) >= 4 and notdigit(substr(_dtc, 1, 4)) = 0 then do;
      _yy = substr(_dtc, 1, 4);
      _has_y = 1;
    end;
    else goto _done_dt;

    if length(_dtc) >= 7 then do;
      if substr(_dtc, 5, 1) = '-' then do;
        if substr(_dtc, 6, 2) = '--' then _has_m = 0;
        else if notdigit(substr(_dtc, 6, 2)) = 0 then do;
          _mm = substr(_dtc, 6, 2);
          _has_m = 1;
        end;
      end;
    end;

    if length(_dtc) >= 10 then do;
      if substr(_dtc, 8, 1) = '-' and notdigit(substr(_dtc, 9, 2)) = 0 then do;
        _dd = substr(_dtc, 9, 2);
        _has_d = 1;
      end;
    end;

    /* No imputation: require full yyyy-mm-dd */
    if "&hi" = "N" then do;
      if _has_y and _has_m and _has_d then
        &dtvar = mdy(input(_mm, 2.), input(_dd, 2.), input(_yy, 4.));
      goto _done_dt;
    end;

    /* Need at least year; for D also need month */
    if not _has_y then goto _done_dt;
    if "&hi" = "D" and not _has_m then goto _done_dt;

    _y = input(_yy, 4.);
    if _has_m then _m = input(_mm, 2.);
    else _m = .;
    if _has_d then _d = input(_dd, 2.);
    else _d = .;

    /* Impute month if missing and allowed */
    if missing(_m) then do;
      if "&hi" = "M" then do;
        if "&di" = "first" then _imp_m = 1;
        else if "&di" = "last" then _imp_m = 12;
        else if "&di" = "mid" then _imp_m = 6;
        else if index("&di", '-') > 0 then
          _imp_m = input(scan("&di", 1, '-'), ?? 2.);
        else _imp_m = 1;
        _m = _imp_m;
        _dtf = 'M';
      end;
      else goto _done_dt;
    end;

    /* Impute day if missing and allowed */
    if missing(_d) then do;
      if "&hi" = "D" or "&hi" = "M" then do;
        if "&di" = "first" then _imp_d = 1;
        else if "&di" = "last" then _imp_d = day(intnx('month', mdy(_m, 1, _y), 0, 'e'));
        else if "&di" = "mid" then do;
          if missing(_imp_m) and _has_m = 0 and "&hi" = "M" then _imp_d = 30; /* mid year Jun 30 already set month */
          else if not _has_m and "&di" = "mid" then _imp_d = 30;
          else _imp_d = 15;
        end;
        else if index("&di", '-') > 0 then
          _imp_d = input(scan("&di", 2, '-'), ?? 2.);
        else
          _imp_d = input("&di", ?? 2.);
        if missing(_imp_d) then _imp_d = 1;
        _d = _imp_d;
        if _dtf = '' then _dtf = 'D';
      end;
      else goto _done_dt;
    end;

    /* Mid-year special: missing month+day -> Jun 30 */
    if "&di" = "mid" and _dtf = 'M' and not _has_d then do;
      _m = 6;
      _d = 30;
    end;

    &dtvar = mdy(_m, _d, _y);
    if missing(&dtvar) then do;
      /* last-day overflow safety */
      &dtvar = .;
      _dtf = '';
    end;

    /* Optional min/max date bounds (single variable each) */
    %if %length(&min_dates) %then %do;
      if not missing(&dtvar) and not missing(&min_dates) then do;
        if datepart(&min_dates) > &dtvar and datepart(&min_dates) <=
           mdy(_m, day(intnx('month', mdy(_m, 1, _y), 0, 'e')), _y)
        then &dtvar = datepart(&min_dates);
      end;
    %end;
    %if %length(&max_dates) %then %do;
      if not missing(&dtvar) and not missing(&max_dates) then do;
        if datepart(&max_dates) < &dtvar and datepart(&max_dates) >= mdy(_m, 1, _y)
        then &dtvar = datepart(&max_dates);
      end;
    %end;

  _done_dt:
    %if &do_flag %then %do;
      if not missing(&dtvar) and _dtf ne '' then &dtfvar = _dtf;
    %end;
    drop _dtc _yy _mm _dd _y _m _d _imp_m _imp_d _has_y _has_m _has_d _dtf;
  run;

  %m_nobs(ds=&out);

%mend m_derive_vars_dt;
