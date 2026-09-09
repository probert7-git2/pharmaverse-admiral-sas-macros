/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_derive_var_trtemfl.sas
  SAS Version                 : 9.4
  Purpose (short description) : TRTEMFL ONTRTFL and last-dose date/amt ports
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Caller AE/CM analysis dataset with TRT dates
  Modification Log            : 18AUG2026 - ADAE (%m_adae2) may post-adjust TRTEMFL when
                                onset day is missing and month+year intersects the TE window
                                (Y even if ASTDT missing - see m_adae2). Core case order here
                                unchanged. Window remains TRTEDT+end_window.
                                18AUG2026 - Header note: ADAE callers may impute ASTDT to
                                TRTSDT or TRTEDT+end_window before this macro (month+year
                                partials). Window here remains TRTEDT+end_window.
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Treatment-emergent / on-treatment / last-dose ports (ADSL/ADAE Phase 1)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
/*******************************************************************************
  %m_derive_var_trtemfl — substantial port of admiral::derive_var_trtemfl()

  Supported: start_date, end_date, trt_start_date, trt_end_date, end_window,
             initial_intensity + intensity (no group_var episode logic in v1).

  TE window upper bound: trt_end_date + end_window (ADAE/ADCM default end_window=30
  so TRTEDT+30). Not LDOSEDT+30. Case order matches admiral docs (simplified without
  group_var).
*******************************************************************************/


%macro m_derive_var_trtemfl(
                              dataset=
                            , new_var=TRTEMFL
                            , start_date=ASTDT
                            , end_date=AENDT
                            , trt_start_date=TRTSDT
                            , trt_end_date=
                            , end_window=
                            , initial_intensity=
                            , intensity=
                            , out=
                            );
  %local has_end has_win has_wors;

  %if %length(&dataset)=0 or 
      %length(&out)=0 %then %do;
      %put ERROR: m_derive_var_trtemfl requires dataset= and out=.;
      %return;
  %end;

  %let has_end = %eval(%length(&trt_end_date) > 0);
  %let has_win = %eval(%length(&end_window) > 0);
  %let has_wors = %eval(%length(&initial_intensity) > 0 and %length(&intensity) > 0);

  data &out;
    set &dataset;
    length &new_var $1;
    &new_var = '';

    /* date-part helpers */
    _st = .; _en = .; _ts = .; _te = .;
    if not missing(&start_date) then
      _st = ifn(&start_date > 100000, datepart(&start_date), &start_date);
    if not missing(&end_date) then
      _en = ifn(&end_date > 100000, datepart(&end_date), &end_date);
    if not missing(&trt_start_date) then
      _ts = ifn(&trt_start_date > 100000, datepart(&trt_start_date), &trt_start_date);
    %if &has_end %then %do;
      if not missing(&trt_end_date) then
        _te = ifn(&trt_end_date > 100000, datepart(&trt_end_date), &trt_end_date);
    %end;

    if missing(_ts) then &new_var = '';
    else if not missing(_en) and _en < _ts then &new_var = '';
    else if missing(_st) then &new_var = 'Y';
    else if _st >= _ts then do;
      %if &has_win and &has_end %then %do;
        if missing(_te) or _st <= _te + &end_window then &new_var = 'Y';
        else &new_var = '';
      %end;
      %else %if &has_win and not &has_end %then %do;
        %put WARNING: end_window has no effect without trt_end_date.;
        &new_var = 'Y';
      %end;
      %else %do;
        &new_var = 'Y';
      %end;
    end;
    %if &has_wors %then %do;
      else if _st < _ts
              and (missing(_en) or _en >= _ts)
              and not missing(&initial_intensity)
              and not missing(&intensity)
              and &initial_intensity < &intensity
      then &new_var = 'Y';
    %end;
    else &new_var = '';

    drop _st _en _ts _te;
  run;

  %m_nobs(ds=&out);
%mend m_derive_var_trtemfl;


/*******************************************************************************
  %m_derive_var_ontrtfl — substantial port of admiral::derive_var_ontrtfl()

  Flags when analysis date is on/after start and on/before end (+ optional
  window). filter_pre_timepoint not in v1.
*******************************************************************************/
%macro m_derive_var_ontrtfl(
                              dataset=
                            , new_var=ONTRTFL
                            , start_date=ASTDT
                            , end_date=
                            , ref_start_date=TRTSDT
                            , ref_end_date=TRTEDT
                            , ref_end_window=
                            , out=
                            );

  %if %length(&dataset)=0 or 
      %length(&out)=0 %then %do;
      %put ERROR: m_derive_var_ontrtfl requires dataset= and out=.;
      %return;
  %end;

  data &out;
    set &dataset;
    length &new_var $1;
    &new_var = '';

    _a = .; _rs = .; _re = .;
    if not missing(&start_date) then
      _a = ifn(&start_date > 100000, datepart(&start_date), &start_date);
    if not missing(&ref_start_date) then
      _rs = ifn(&ref_start_date > 100000, datepart(&ref_start_date), &ref_start_date);
    %if %length(&ref_end_date) %then %do;
      if not missing(&ref_end_date) then
        _re = ifn(&ref_end_date > 100000, datepart(&ref_end_date), &ref_end_date);
    %end;

    if not missing(_a) and not missing(_rs) and _a >= _rs then do;
      %if %length(&ref_end_date) %then %do;
        if missing(_re) then &new_var = 'Y';
        else do;
          _lim = _re;
          %if %length(&ref_end_window) %then %do;
            _lim = _re + &ref_end_window;
          %end;
          if _a <= _lim then &new_var = 'Y';
        end;
      %end;
      %else %do;
        &new_var = 'Y';
      %end;
    end;

    drop _a _rs _re
    %if %length(&ref_end_window) %then %do; _lim %end;
    ;
  run;

  %m_nobs(ds=&out);
%mend m_derive_var_ontrtfl;


/*******************************************************************************
  Last dose helpers — wrap %m_derive_vars_joined (admiral last-dose pattern)

  %m_derive_var_last_dose_date / _dtm / _amt
*******************************************************************************/
%macro m_derive_var_last_dose_date(
                                     dataset=
                                   , dataset_ex=
                                   , by_vars=USUBJID
                                   , order=DESC:EXSTDT DESC:EXSEQ
                                   , new_var=LDOSEDT
                                   , dose_date=EXSTDT
                                   , analysis_date=ASTDT
                                   , filter_ex=%str(EXDOSE > 0 or upcase(EXTRT) = 'PLACEBO')
                                   , out=
                                   );
  %m_derive_vars_joined(
                          dataset=&dataset
                        , dataset_add=&dataset_ex
                        , by_vars=&by_vars
                        , order=&order
                        , new_vars=&new_var=&dose_date
                        , join_type=all
                        , filter_add=&filter_ex
                        , filter_join=%str(b.&dose_date <= a.&analysis_date)
                        , mode=last
                        , out=&out
                        );
%mend m_derive_var_last_dose_date;


%macro m_derive_var_last_dose_dtm(
                                    dataset=
                                  , dataset_ex=
                                  , by_vars=USUBJID
                                  , order=DESC:EXSTDTM DESC:EXSEQ
                                  , new_var=LDOSEDTM
                                  , dose_date=EXSTDTM
                                  , analysis_date=ASTDTM
                                  , filter_ex=%str(EXDOSE > 0 or upcase(EXTRT) = 'PLACEBO')
                                  , out=
                                  );

       %m_derive_var_last_dose_date(
                                     dataset=&dataset
                                   , dataset_ex=&dataset_ex
                                   , by_vars=&by_vars
                                   , order=&order
                                   , new_var=&new_var
                                   , dose_date=&dose_date
                                   , analysis_date=&analysis_date
                                   , filter_ex=&filter_ex
                                   , out=&out
                                   );

%mend m_derive_var_last_dose_dtm;




%macro m_derive_var_last_dose_amt(
                                    dataset=
                                  , dataset_ex=
                                  , by_vars=USUBJID
                                  , order=DESC:EXSTDT DESC:EXSEQ
                                  , new_var=LDOSE
                                  , dose_date=EXSTDT
                                  , dose_amt=EXDOSE
                                  , analysis_date=ASTDT
                                  , filter_ex=%str(EXDOSE > 0 or upcase(EXTRT) = 'PLACEBO')
                                  , out=
                                  );
         %m_derive_vars_joined(
                                 dataset=&dataset
                               , dataset_add=&dataset_ex
                               , by_vars=&by_vars
                               , order=&order
                               , new_vars=&new_var=&dose_amt
                               , join_type=all
                               , filter_add=&filter_ex
                               , filter_join=%str(b.&dose_date <= a.&analysis_date)
                               , mode=last
                               , out=&out
                               );
%mend m_derive_var_last_dose_amt;
