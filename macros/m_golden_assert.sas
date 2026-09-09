/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_golden_assert.sas
  SAS Version                 : 9.4
  Purpose (short description) : Golden-subject assertion and setup validation helpers
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : work.gs_expected and derivation outputs
  Modification Log            : 18AUG2026 - Setup/summary expect 21 rows (GS-AE-03/04 added).
                                17AUG2026 - m_golden_write_output always writes a diagnostic
                                marker plus an end-of-run sentinel NOTE.
                                16AUG2026 - ERROR (not WARNING) when zero artifacts written.
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Golden-subject assertion helpers.

  Each case is a synthetic row with a known data pattern and an
  expected derived value. Failures emit ERROR lines for %m_chklog.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~`*/


%macro m_golden_init;
      %global GOLDEN_PASS 
              GOLDEN_FAIL;
      %let GOLDEN_PASS = 0;
      %let GOLDEN_FAIL = 0;
%mend m_golden_init;


/* Verify mock data built correctly before running derivations (ODA DATALINES guard) */
%macro m_golden_validate_setup;

  %global GOLDEN_PASS GOLDEN_FAIL;
  %local _n_exp _n_mfirst _n_te _ok;
  %let _ok = 1;

  %if %symexist(GOLDEN_PASS)=0 %then %let GOLDEN_PASS=0;
  %if %symexist(GOLDEN_FAIL)=0 %then %let GOLDEN_FAIL=0;

  %if %sysfunc(exist(work.gs_expected)) = 0 %then %do;
    %let _ok = 0;
    %put ERROR: [GOLDEN SETUP FAIL] work.gs_expected missing - mock macro did not finish.;
    %put ERROR: Upload local SAS/macros/m_gs_create_mock_adam2.sas (GS_MOCK_ODA_SAFE_V5) to ODA.;
    %put ERROR: ODA path: ~/safety_monitoring_system/SAS/macros/m_gs_create_mock_adam2.sas;
    %put ERROR: Confirm log shows NOTE: GS_MOCK_ODA_SAFE_V5 and that the file has no DATALINES.;
  %end;

  %if &_ok %then %do;
    data _null_;
      if 0 then set work.gs_expected nobs=n;
      call symputx('_n_exp', n);
      stop;
    run;
    %if &_n_exp ne 21 %then %do;
      %let _ok = 0;
      %put ERROR: [GOLDEN SETUP FAIL] gs_expected has &_n_exp rows - expected 21.;
    %end;
  %end;

  %if &_ok %then %do;
    %if %sysfunc(exist(work.gs_dt_in_mfirst)) = 0 %then %do;
      %let _ok = 0;
      %put ERROR: [GOLDEN SETUP FAIL] work.gs_dt_in_mfirst missing.;
    %end;
    %else %do;
      data _null_;
        if 0 then set work.gs_dt_in_mfirst nobs=n;
        call symputx('_n_mfirst', n);
        stop;
      run;
      %if &_n_mfirst ne 3 %then %do;
        %let _ok = 0;
        %put ERROR: [GOLDEN SETUP FAIL] gs_dt_in_mfirst has &_n_mfirst obs - expected 3.;
        %put ERROR: ODA blocks DATALINES inside macros - use explicit OUTPUT rows.;
      %end;
    %end;
  %end;

  %if &_ok %then %do;
    %if %sysfunc(exist(work.gs_te_in)) = 0 %then %do;
      %let _ok = 0;
      %put ERROR: [GOLDEN SETUP FAIL] work.gs_te_in missing.;
    %end;
    %else %do;
      data _null_;
        if 0 then set work.gs_te_in nobs=n;
        call symputx('_n_te', n);
        stop;
      run;
      %if &_n_te ne 7 %then %do;
        %let _ok = 0;
        %put ERROR: [GOLDEN SETUP FAIL] gs_te_in has &_n_te obs - expected 7.;
      %end;
    %end;
  %end;

  %if &_ok %then %do;
    %put NOTE: [GOLDEN SETUP OK] gs_expected=&_n_exp rows gs_dt_in_mfirst=&_n_mfirst gs_te_in=&_n_te;
  %end;
  %else %do;
    %let GOLDEN_FAIL = 21;
    %let GOLDEN_PASS = 0;
  %end;

%mend m_golden_validate_setup;


%macro m_golden_pass(case_id=, desc=);
  %let GOLDEN_PASS = %eval(&GOLDEN_PASS + 1);
  %put NOTE: [GOLDEN PASS] &case_id - &desc;
%mend m_golden_pass;


%macro m_golden_fail(case_id=, desc=, expected=, actual=);
  %let GOLDEN_FAIL = %eval(&GOLDEN_FAIL + 1);
  %put ERROR: [GOLDEN FAIL] &case_id - &desc;
  %put ERROR: [GOLDEN FAIL]   expected=&expected actual=&actual;
%mend m_golden_fail;


%macro m_golden_assert_char(case_id=, actual=, expected=, desc=);
  %local _act _exp;
  %let _act = %quote(&actual);
  %let _exp = %quote(&expected);
  %if %superq(_act) = %superq(_exp) %then %m_golden_pass(case_id=&case_id, desc=&desc);
  %else %m_golden_fail(case_id=&case_id, desc=&desc, expected=&expected, actual=&actual);
%mend m_golden_assert_char;


%macro m_golden_assert_num(case_id=, actual=, expected=, desc=);
  %local _act _exp;
  %let _act = &actual;
  %let _exp = &expected;
  %if %sysevalf(&_act = &_exp) %then %m_golden_pass(case_id=&case_id, desc=&desc);
  %else %m_golden_fail(case_id=&case_id, desc=&desc, expected=&expected, actual=&actual);
%mend m_golden_assert_num;


%macro m_golden_assert_from_ds(
  case_id=
, ds=
, var=
, expected=
, desc=
, is_char=N
, format=
);
  %local _act _dsid _type;

  %if not %sysfunc(exist(&ds)) %then %do;
    %m_golden_fail(case_id=&case_id, desc=Dataset &ds missing, expected=&expected, actual=);
    %return;
  %end;

  %if %upcase(&is_char) = Y %then %do;
    proc sql noprint;
      select strip(&var) into :_act trimmed
        from &ds
        where case_id = "&case_id";
    quit;
  %end;
  %else %do;
    proc sql noprint;
      select coalesce(&var, .) into :_act trimmed
        from &ds
        where case_id = "&case_id";
    quit;
  %end;

  %if %sqlobs = 0 %then %do;
    %m_golden_fail(case_id=&case_id, desc=No row in &ds for case_id, expected=&expected, actual=);
    %return;
  %end;

  %if %upcase(&is_char) = Y %then %do;
    %m_golden_assert_char(case_id=&case_id, actual=&_act, expected=&expected, desc=&desc);
  %end;
  %else %do;
    %if %length(&expected) = 0 or &expected = . %then %do;
      %if %length(&_act) = 0 or &_act = . %then %m_golden_pass(case_id=&case_id, desc=&desc);
      %else %m_golden_fail(case_id=&case_id, desc=&desc, expected=., actual=&_act);
    %end;
    %else %if %sysevalf(&_act = &expected) %then %m_golden_pass(case_id=&case_id, desc=&desc);
    %else %m_golden_fail(case_id=&case_id, desc=&desc, expected=&expected, actual=&_act);
  %end;
%mend m_golden_assert_from_ds;


%macro m_golden_summary(out=work.golden_summary);
  %global GOLDEN_PASS GOLDEN_FAIL;
  %if %symexist(GOLDEN_PASS)=0 %then %let GOLDEN_PASS=0;
  %if %symexist(GOLDEN_FAIL)=0 %then %let GOLDEN_FAIL=0;

  data &out;
    length metric $32 value 8;
    metric = 'PASS'; value = &GOLDEN_PASS; output;
    metric = 'FAIL'; value = &GOLDEN_FAIL; output;
    metric = 'TOTAL'; value = %eval(&GOLDEN_PASS + &GOLDEN_FAIL); output;
  run;

  %put NOTE: ===== Golden subjects: &GOLDEN_PASS passed, &GOLDEN_FAIL failed =====;
  %if %eval(&GOLDEN_PASS + &GOLDEN_FAIL) ne 21 %then %do;
    %put ERROR: Golden subjects did not run all 21 assertions - check setup errors above.;
  %end;
  %else %if &GOLDEN_PASS = 21 %then %put NOTE: Golden subjects validation PASSED - all 21 scenarios OK.;
  %else %if &GOLDEN_FAIL > 0 %then %put ERROR: Golden subject testing reported &GOLDEN_FAIL failure(s).;
%mend m_golden_summary;


/*--------------------------------------------------------------
  Persist golden-subject results to libname goldout (&OUTDIR from init).

  Requires init_libnames_oda.sas (assigns goldout, OUTDIR, GOLDOUT_PATH).

  Writes a diagnostic marker (_golden_write_output_&prefix..txt) on every call,
  so an empty output folder proves this macro never reached the write step.
--------------------------------------------------------------*/
%macro m_golden_write_output(
  summary=work.golden_summary
, log_issues=work.golden_log_issues
, logfile=
, prefix=golden_subjects
);

  %local _copy _n_written _marker;

  %m_ensure_goldout;

  %if %sysfunc(libref(goldout)) ne 0 %then %do;
    %put ERROR: m_golden_write_output - libname goldout not assigned.;
    %put ERROR: Run setup/init_libnames_oda.sas before this macro.;
    %return;
  %end;

  %let _n_written = 0;

  %put NOTE: m_golden_write_output OUTDIR=&OUTDIR GOLDOUT_PATH=&GOLDOUT_PATH;

  %if %sysfunc(exist(&summary)) %then %do;
    data goldout.&prefix._summary;
      set &summary;
    run;
    %if %sysfunc(exist(goldout.&prefix._summary)) %then %let _n_written = %eval(&_n_written + 1);
    %else %put ERROR: m_golden_write_output failed goldout.&prefix._summary;
  %end;
  %else %put WARNING: m_golden_write_output - &summary not found, skip summary.;

  %if %sysfunc(exist(&log_issues)) %then %do;
    data goldout.&prefix._log_issues;
      set &log_issues;
    run;
    %if %sysfunc(exist(goldout.&prefix._log_issues)) %then %let _n_written = %eval(&_n_written + 1);
    %else %put ERROR: m_golden_write_output failed goldout.&prefix._log_issues;
  %end;
  %else %put WARNING: m_golden_write_output - &log_issues not found, skip log issues.;

  %if %sysfunc(exist(work.gs_expected)) %then %do;
    data goldout.&prefix._expected;
      set work.gs_expected;
    run;
    %if %sysfunc(exist(goldout.&prefix._expected)) %then %let _n_written = %eval(&_n_written + 1);
    %else %put ERROR: m_golden_write_output failed goldout.&prefix._expected;
  %end;

  %if %length(&logfile) and %sysfunc(fileexist(&logfile)) %then %do;
    %let _copy = &OUTDIR/&prefix..log;
    data _null_;
      infile "&logfile" length=_ll truncover end=_eof;
      input _line $varying400. _ll;
      file "&_copy";
      put _line;
    run;
    %if %sysfunc(fileexist(&_copy)) %then %do;
      %put NOTE: Golden log copy: &_copy;
      %let _n_written = %eval(&_n_written + 1);
    %end;
    %else %put ERROR: m_golden_write_output failed log copy &_copy;
  %end;

  /* Marker is diagnostic only - never counts as a successful archive item */
  %let _marker = &OUTDIR/_golden_write_output_&prefix..txt;
  data _null_;
    file "&_marker";
    put "prefix=&prefix";
    put "outdir=&OUTDIR";
    put "goldout_path=&GOLDOUT_PATH";
    put "items=&_n_written";
  run;

  %if &_n_written = 0 %then %do;
    %put ERROR: m_golden_write_output wrote nothing - check upstream datasets and OUTDIR.;
    %put ERROR: Diagnostic marker was still written: &_marker;
  %end;
  %else %do;
    %put NOTE: Golden output written to &GOLDOUT_PATH (&_n_written artifact(s)).;
    %put NOTE:   goldout.&prefix._summary goldout.&prefix._log_issues;
    %if %sysfunc(exist(goldout.&prefix._expected)) %then %put NOTE:   goldout.&prefix._expected;
    %put NOTE: m_golden_write_output marker: &_marker;
  %end;

  /* Sentinel - search the Studio Log for "m_golden_write_output end" */
  %put NOTE: m_golden_write_output end prefix=&prefix items=&_n_written;

%mend m_golden_write_output;
