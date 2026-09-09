/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_derive_vars_dtm.sas
  SAS Version                 : 9.4
  Purpose (short description) : admiral-style derive_vars_dtm and DTM-to-DT/TM ports
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Caller dataset with DTC character var
  Modification Log            : 18AUG2026 - Header: DTM path only (*DTM out, datetime20.).
                                Pair with %m_safe_iso_dtm for no-imputation DATA-step use.
                                Do not use this macro when the ADaM target is ADT / *DT -
                                use %m_derive_vars_dt / %m_safe_iso_date instead.
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  %m_derive_vars_dtm  — substantial SAS port of admiral::derive_vars_dtm()

    DTM PATH (datetime). Creates &new_vars_prefix.DTM (and optional *DTF / *TMF) from --DTC.
    Format datetime20. Time-part temps use $20 (never $21).

    Pairing:
      admiral derive_vars_dtm <->  %m_derive_vars_dtm  (dataset-level, date+time impute)
                              <->  %m_safe_iso_dtm    (DATA-step snippet, no impute)
      admiral derive_vars_dt  <->  %m_derive_vars_dt / %m_safe_iso_date  (separate path)

    Supported (v1):
      highest_imputation = n | D | M | h | m | s  (mapped to date+time levels)
      date_imputation    = first | last | mid | dd | mm-dd
      time_imputation    = first | last | hh:mm:ss
      flag_imputation    = auto | date | time | both | none
      ignore_seconds_flag= Y|N (default Y - no seconds TMF from seconds alone)

    Uses %m_derive_vars_dt for the date part when highest_imputation in (n,D,M),
    then attaches time. For highest_imputation n: requires full date; time may
    still be imputed via time_imputation if present components allow.

    Simplified v1 strategy:
      1) Derive date via same rules as derive_vars_dt (hi limited to n/D/M).
      2) Parse time; impute missing h/m/s per time_imputation.
      3) Combine with DHMS().
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_derive_vars_dtm(
  dataset=
, new_vars_prefix=
, dtc=
, highest_imputation=n
, date_imputation=first
, time_imputation=first
, flag_imputation=auto
, ignore_seconds_flag=Y
, min_dates=
, max_dates=
, out=
);

  %local hi hi_raw fi dtmvar dtfvar tmfvar do_date_flag do_time_flag date_hi;

  %if %length(&dataset)=0 or %length(&new_vars_prefix)=0 or %length(&dtc)=0
      or %length(&out)=0 %then %do;
    %put ERROR: m_derive_vars_dtm requires dataset=, new_vars_prefix=, dtc=, out=.;
    %return;
  %end;

  %let hi_raw = &highest_imputation;
  %let hi = %upcase(&hi_raw);
  %let fi = %upcase(&flag_imputation);
  %let dtmvar = &new_vars_prefix.DTM;
  %let dtfvar = &new_vars_prefix.DTF;
  %let tmfvar = &new_vars_prefix.TMF;

  /* admiral: n/D/M (uppercase M = month) are date levels; h/m/s lowercase = time only */
  %if &hi_raw = h or &hi_raw = m or &hi_raw = s %then %let date_hi = N;
  %else %if &hi = N %then %let date_hi = N;
  %else %if &hi = D or &hi = M %then %let date_hi = &hi;
  %else %do;
    %put ERROR: highest_imputation must be n/D/M (date) or h/m/s (time). Got &highest_imputation;
    %return;
  %end;

  %let do_date_flag = 0;
  %let do_time_flag = 0;
  %if &fi = DATE or &fi = BOTH %then %let do_date_flag = 1;
  %if &fi = TIME or &fi = BOTH %then %let do_time_flag = 1;
  %if &fi = AUTO %then %do;
    /* Case-sensitive: date_hi must be compared upcased */
    %if %upcase(&date_hi) ne N %then %let do_date_flag = 1;
    %let do_time_flag = 1;
  %end;

  /* Date portion first */
  %m_derive_vars_dt(
    dataset=&dataset
  , new_vars_prefix=_MDTM_
  , dtc=&dtc
  , highest_imputation=&date_hi
  , date_imputation=&date_imputation
  , flag_imputation=%sysfunc(ifc(&do_date_flag,date,none))
  , min_dates=&min_dates
  , max_dates=&max_dates
  , out=work._mdtm_date
  );

  data &out;
    set work._mdtm_date;
    length _tpart $20 _timf $1
           _hh _mm _ss _has_h _has_m _has_s 8;
    format &dtmvar datetime20.;
    &dtmvar = .;
    %if &do_date_flag %then %do;
      length &dtfvar $1;
      &dtfvar = _MDTM_DTF;
    %end;
    %if &do_time_flag %then %do;
      length &tmfvar $1;
      &tmfvar = '';
    %end;

    if missing(_MDTM_DT) then goto _done_dtm;

    _tpart = '';
    if index(strip(&dtc), 'T') then _tpart = scan(strip(&dtc), 2, 'T');
    _has_h = 0; _has_m = 0; _has_s = 0;
    _hh = .; _mm = .; _ss = .;
    _timf = '';

    if _tpart ne '' then do;
      if length(_tpart) >= 2 and notdigit(substr(_tpart, 1, 2)) = 0 then do;
        _hh = input(substr(_tpart, 1, 2), 2.);
        _has_h = 1;
      end;
      if length(_tpart) >= 5 and substr(_tpart, 3, 1) = ':'
         and notdigit(substr(_tpart, 4, 2)) = 0 then do;
        _mm = input(substr(_tpart, 4, 2), 2.);
        _has_m = 1;
      end;
      if length(_tpart) >= 8 and substr(_tpart, 6, 1) = ':'
         and notdigit(substr(_tpart, 7, 2)) = 0 then do;
        _ss = input(substr(_tpart, 7, 2), 2.);
        _has_s = 1;
      end;
    end;

    /* Impute time components */
    if not _has_h then do;
      if %upcase("&time_imputation") = "LAST" then _hh = 23;
      else if index("&time_imputation", ':') then
        _hh = input(scan("&time_imputation", 1, ':'), ?? 2.);
      else _hh = 0;
      _timf = 'H';
    end;
    if not _has_m then do;
      if %upcase("&time_imputation") = "LAST" then _mm = 59;
      else if index("&time_imputation", ':') then
        _mm = input(scan("&time_imputation", 2, ':'), ?? 2.);
      else _mm = 0;
      if _timf = '' then _timf = 'M';
    end;
    if not _has_s then do;
      if %upcase("&time_imputation") = "LAST" then _ss = 59;
      else if index("&time_imputation", ':') then
        _ss = input(scan("&time_imputation", 3, ':'), ?? 2.);
      else _ss = 0;
      if _timf = '' and %upcase("&ignore_seconds_flag") ne "Y"
         and %upcase("&ignore_seconds_flag") ne "TRUE"
      then _timf = 'S';
    end;

    /* For highest_imputation=n: if any date part was missing, date is missing
       already. If DTC had no time, still impute time (admiral default first). */
    &dtmvar = dhms(_MDTM_DT, _hh, _mm, _ss);

    %if &do_time_flag %then %do;
      if _timf ne '' then &tmfvar = _timf;
    %end;

  _done_dtm:
    /* _MDTM_DTF exists only when date flag was requested from %m_derive_vars_dt.
       Dropping it when absent triggers WARNING: never been referenced. */
    drop _MDTM_DT
    %if &do_date_flag %then %do; _MDTM_DTF %end;
    _tpart _hh _mm _ss _has_h _has_m _has_s _timf;
  run;

  proc datasets lib=work nolist;
    delete _mdtm_date;
  quit;

  %m_nobs(ds=&out);

%mend m_derive_vars_dtm;


/*******************************************************************************
  %m_derive_vars_dtm_to_dt — port of admiral::derive_vars_dtm_to_dt()
  source_vars: space-separated *DTM names; creates matching *DT
*******************************************************************************/
%macro m_derive_vars_dtm_to_dt(
  dataset=
, source_vars=
, out=
);
  %local i v dtvar;

  %if %length(&dataset)=0 or %length(&source_vars)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_derive_vars_dtm_to_dt requires dataset=, source_vars=, out=.;
    %return;
  %end;

  data &out;
    set &dataset;
    %let i = 1;
    %let v = %scan(&source_vars, &i, %str( ));
    %do %while(%length(&v));
      %let dtvar = %sysfunc(prxchange(s/DTM$/DT/, 1, &v));
      %if &dtvar = &v %then %let dtvar = &v.DT;
      format &dtvar date9.;
      if not missing(&v) then &dtvar = datepart(&v);
      else &dtvar = .;
      %let i = %eval(&i + 1);
      %let v = %scan(&source_vars, &i, %str( ));
    %end;
  run;

  %m_nobs(ds=&out);
%mend m_derive_vars_dtm_to_dt;


/*******************************************************************************
  %m_derive_vars_dtm_to_tm — port of admiral::derive_vars_dtm_to_tm()
  source_vars: space-separated *DTM names; creates matching *TM (time)
*******************************************************************************/
%macro m_derive_vars_dtm_to_tm(
  dataset=
, source_vars=
, out=
);
  %local i v tmvar;

  %if %length(&dataset)=0 or %length(&source_vars)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_derive_vars_dtm_to_tm requires dataset=, source_vars=, out=.;
    %return;
  %end;

  data &out;
    set &dataset;
    %let i = 1;
    %let v = %scan(&source_vars, &i, %str( ));
    %do %while(%length(&v));
      %if %upcase(%substr(&v, %length(&v)-2)) = DTM %then
        %let tmvar = %substr(&v, 1, %length(&v)-1);
      /* TRTSDTM -> TRTSTM : replace DTM with TM */
      %let tmvar = %sysfunc(prxchange(s/DTM$/TM/, 1, &v));
      format &tmvar time8.;
      if not missing(&v) then &tmvar = timepart(&v);
      else &tmvar = .;
      %let i = %eval(&i + 1);
      %let v = %scan(&source_vars, &i, %str( ));
    %end;
  run;

  %m_nobs(ds=&out);
%mend m_derive_vars_dtm_to_tm;
