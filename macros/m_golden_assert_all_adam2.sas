/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_golden_assert_all_adam2.sas
  SAS Version                 : 9.4
  Purpose (short description) : SQL compare all golden-subject suites ACT vs EXP
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : work.gs_expected work.gs_*_actual
  Modification Log            : 18AUG2026 - Expected total 21 (GS-AE-03/04 TE-window cases).
                                16AUG2026 - Per-row PASS/FAIL (suite partial credit).
                                16AUG2026 - ADAE join on USUBJID+AESEQ (scenario AE only).
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Golden-subject SQL assertions (bladder onco_tte pattern).

  Compares production macro outputs to frozen work.gs_expected.
  Failures print mismatch tables and emit ERROR for %m_chklog.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_golden_assert_all_adam2;

  %global GOLDEN_PASS GOLDEN_FAIL;
  %local n_fail n_dt_fail n_dtm_fail n_epoch_fail n_te_fail n_ae_fail;
  %local n_dt_chk n_dtm_chk n_epoch_chk n_te_chk n_ae_chk;

  %if %symexist(GOLDEN_PASS)=0 %then %let GOLDEN_PASS=0;
  %if %symexist(GOLDEN_FAIL)=0 %then %let GOLDEN_FAIL=0;
  %let n_fail = 0;

  %if %sysfunc(exist(work.gs_expected)) = 0 %then %do;
    %let GOLDEN_FAIL = 21;
    %let GOLDEN_PASS = 0;
    %put ERROR: Golden subjects aborted - work.gs_expected missing.;
    %put ERROR: Check macros/m_gs_create_mock_adam2.sas (ODA forbids DATALINES in macros).;
    %return;
  %end;

  proc sql;
    create table work._gs_dt_chk as
    select e.TESTID, e.SUITE,
           e.EXP_ASTDT, a.ASTDT as ACT_ASTDT format=date9.,
           e.EXP_ASTDTF, a.ASTDTF as ACT_ASTDTF
    from work.gs_expected as e
    left join work.gs_dt_actual as a
      on e.TESTID = a.case_id
    where e.SUITE = 'DT';

    create table work._gs_dt_fail as
    select *
    from work._gs_dt_chk
    where coalesce(ACT_ASTDT, .) ne coalesce(EXP_ASTDT, .)
       or strip(coalesce(ACT_ASTDTF, '')) ne strip(coalesce(EXP_ASTDTF, ''));
  quit;

  %let n_dt_fail = 0;
  data _null_;
    if 0 then set work._gs_dt_fail nobs=n;
    call symputx('n_dt_fail', n);
    stop;
  run;
  data _null_;
    if 0 then set work._gs_dt_chk nobs=n;
    call symputx('n_dt_chk', n);
    stop;
  run;

  %if &n_dt_chk ne 6 %then %do;
    %let n_fail = %eval(&n_fail + 6);
    %let GOLDEN_FAIL = %eval(&GOLDEN_FAIL + 6);
    %put ERROR: Golden subjects DT suite - expected 6 oracle rows got &n_dt_chk;
  %end;
  %else %do;
    %let GOLDEN_PASS = %eval(&GOLDEN_PASS + &n_dt_chk - &n_dt_fail);
    %let GOLDEN_FAIL = %eval(&GOLDEN_FAIL + &n_dt_fail);
    %let n_fail = %eval(&n_fail + &n_dt_fail);
    %if &n_dt_fail > 0 %then %do;
      proc print data=work._gs_dt_fail;
        title "Golden subjects - partial date (DT) failures";
      run;
      title;
      %put ERROR: Golden subjects DT suite - &n_dt_fail mismatch(es).;
    %end;
    %else %put NOTE: [GOLDEN PASS] DT suite GS-DT-01 through GS-DT-06 as expected.;
  %end;

  proc sql;
    create table work._gs_dtm_chk as
    select e.TESTID, e.SUITE,
           e.EXP_ASTDT, a.ASTDT as ACT_ASTDT format=date9.,
           e.EXP_ASTDTF, a.ASTDTF as ACT_ASTDTF,
           e.EXP_ASTTMF, a.ASTTMF as ACT_ASTTMF,
           e.EXP_ASTDT_ISO, put(a.ASTDT, yymmdd10.) as ACT_ASTDT_ISO
    from work.gs_expected as e
    left join work.gs_dtm_actual as a
      on e.TESTID = a.case_id
    where e.SUITE = 'DTM';

    create table work._gs_dtm_fail as
    select *
    from work._gs_dtm_chk
    where coalesce(ACT_ASTDT, .) ne coalesce(EXP_ASTDT, .)
       or strip(coalesce(ACT_ASTDTF, '')) ne strip(coalesce(EXP_ASTDTF, ''))
       or strip(coalesce(ACT_ASTTMF, '')) ne strip(coalesce(EXP_ASTTMF, ''))
       or (strip(EXP_ASTDT_ISO) ne '' and strip(ACT_ASTDT_ISO) ne strip(EXP_ASTDT_ISO));
  quit;

  %let n_dtm_fail = 0;
  data _null_;
    if 0 then set work._gs_dtm_fail nobs=n;
    call symputx('n_dtm_fail', n);
    stop;
  run;
  data _null_;
    if 0 then set work._gs_dtm_chk nobs=n;
    call symputx('n_dtm_chk', n);
    stop;
  run;

  %if &n_dtm_chk ne 3 %then %do;
    %let n_fail = %eval(&n_fail + 3);
    %let GOLDEN_FAIL = %eval(&GOLDEN_FAIL + 3);
    %put ERROR: Golden subjects DTM suite - expected 3 oracle rows got &n_dtm_chk;
  %end;
  %else %do;
    %let GOLDEN_PASS = %eval(&GOLDEN_PASS + &n_dtm_chk - &n_dtm_fail);
    %let GOLDEN_FAIL = %eval(&GOLDEN_FAIL + &n_dtm_fail);
    %let n_fail = %eval(&n_fail + &n_dtm_fail);
    %if &n_dtm_fail > 0 %then %do;
      proc print data=work._gs_dtm_fail;
        title "Golden subjects - DTM M vs m failures";
      run;
      title;
      %put ERROR: Golden subjects DTM suite - &n_dtm_fail mismatch(es).;
    %end;
    %else %put NOTE: [GOLDEN PASS] DTM suite GS-DTM-01 through GS-DTM-03 as expected.;
  %end;

  proc sql;
    create table work._gs_epoch_chk as
    select e.TESTID, e.SUITE,
           e.EXP_ASTDT, a.ASTDT as ACT_ASTDT format=date9.,
           e.EXP_ASTDT_ISO, a.ACT_ASTDT_ISO
    from work.gs_expected as e
    left join work.gs_epoch_actual as a
      on e.TESTID = a.case_id
    where e.SUITE = 'EPOCH';

    create table work._gs_epoch_fail as
    select *
    from work._gs_epoch_chk
    where coalesce(ACT_ASTDT, .) ne coalesce(EXP_ASTDT, .)
       or strip(ACT_ASTDT_ISO) ne strip(EXP_ASTDT_ISO);
  quit;

  %let n_epoch_fail = 0;
  data _null_;
    if 0 then set work._gs_epoch_fail nobs=n;
    call symputx('n_epoch_fail', n);
    stop;
  run;
  data _null_;
    if 0 then set work._gs_epoch_chk nobs=n;
    call symputx('n_epoch_chk', n);
    stop;
  run;

  %if &n_epoch_chk ne 1 %then %do;
    %let n_fail = %eval(&n_fail + 1);
    %let GOLDEN_FAIL = %eval(&GOLDEN_FAIL + 1);
    %put ERROR: Golden subjects EPOCH suite - expected 1 oracle row got &n_epoch_chk;
  %end;
  %else %do;
    %let GOLDEN_PASS = %eval(&GOLDEN_PASS + &n_epoch_chk - &n_epoch_fail);
    %let GOLDEN_FAIL = %eval(&GOLDEN_FAIL + &n_epoch_fail);
    %let n_fail = %eval(&n_fail + &n_epoch_fail);
    %if &n_epoch_fail > 0 %then %do;
      proc print data=work._gs_epoch_fail;
        title "Golden subjects - SAS epoch / ISO calendar failures";
      run;
      title;
      %put ERROR: Golden subjects EPOCH suite - &n_epoch_fail mismatch(es).;
    %end;
    %else %put NOTE: [GOLDEN PASS] EPOCH suite GS-EPOCH-01 SAS date + yymmdd10 OK.;
  %end;

  proc sql;
    create table work._gs_te_chk as
    select e.TESTID, e.SUITE,
           e.EXP_TRTEMFL, a.TRTEMFL as ACT_TRTEMFL
    from work.gs_expected as e
    left join work.gs_te_actual as a
      on e.TESTID = a.case_id
    where e.SUITE = 'TRTEMFL';

    create table work._gs_te_fail as
    select *
    from work._gs_te_chk
    where strip(coalesce(ACT_TRTEMFL, '')) ne strip(coalesce(EXP_TRTEMFL, ''));
  quit;

  %let n_te_fail = 0;
  data _null_;
    if 0 then set work._gs_te_fail nobs=n;
    call symputx('n_te_fail', n);
    stop;
  run;
  data _null_;
    if 0 then set work._gs_te_chk nobs=n;
    call symputx('n_te_chk', n);
    stop;
  run;

  %if &n_te_chk ne 7 %then %do;
    %let n_fail = %eval(&n_fail + 7);
    %let GOLDEN_FAIL = %eval(&GOLDEN_FAIL + 7);
    %put ERROR: Golden subjects TRTEMFL suite - expected 7 oracle rows got &n_te_chk;
  %end;
  %else %do;
    %let GOLDEN_PASS = %eval(&GOLDEN_PASS + &n_te_chk - &n_te_fail);
    %let GOLDEN_FAIL = %eval(&GOLDEN_FAIL + &n_te_fail);
    %let n_fail = %eval(&n_fail + &n_te_fail);
    %if &n_te_fail > 0 %then %do;
      proc print data=work._gs_te_fail;
        title "Golden subjects - TRTEMFL failures";
      run;
      title;
      %put ERROR: Golden subjects TRTEMFL suite - &n_te_fail mismatch(es).;
    %end;
    %else %put NOTE: [GOLDEN PASS] TRTEMFL suite GS-TE-01 through GS-TE-07 as expected.;
  %end;

  proc sql;
    create table work._gs_ae_chk as
    select e.TESTID, e.USUBJID, e.AESEQ,
           e.EXP_ASTDT, a.ASTDT as ACT_ASTDT format=date9.,
           e.EXP_ASTDTF, a.ASTDTF as ACT_ASTDTF,
           e.EXP_ASTDT_ISO, put(a.ASTDT, yymmdd10.) as ACT_ASTDT_ISO,
           e.EXP_TRTEMFL, a.TRTEMFL as ACT_TRTEMFL
    from work.gs_expected as e
    left join work.gs_adae_actual as a
      on e.USUBJID = a.USUBJID and e.AESEQ = a.AESEQ
    where e.SUITE = 'ADAE';

    create table work._gs_ae_fail as
    select *
    from work._gs_ae_chk
    where (EXP_ASTDT > . and coalesce(ACT_ASTDT, .) ne EXP_ASTDT)
       or (missing(EXP_ASTDT) and not missing(ACT_ASTDT))
       or strip(coalesce(ACT_ASTDTF, '')) ne strip(coalesce(EXP_ASTDTF, ''))
       or (strip(EXP_ASTDT_ISO) ne '' and strip(ACT_ASTDT_ISO) ne strip(EXP_ASTDT_ISO))
       or strip(coalesce(ACT_TRTEMFL, '')) ne strip(coalesce(EXP_TRTEMFL, ''));
  quit;

  %let n_ae_fail = 0;
  data _null_;
    if 0 then set work._gs_ae_fail nobs=n;
    call symputx('n_ae_fail', n);
    stop;
  run;
  data _null_;
    if 0 then set work._gs_ae_chk nobs=n;
    call symputx('n_ae_chk', n);
    stop;
  run;

  %if &n_ae_chk ne 4 %then %do;
    %let n_fail = %eval(&n_fail + 4);
    %let GOLDEN_FAIL = %eval(&GOLDEN_FAIL + 4);
    %put ERROR: Golden subjects ADAE suite - expected 4 oracle rows got &n_ae_chk;
  %end;
  %else %do;
    %let GOLDEN_PASS = %eval(&GOLDEN_PASS + &n_ae_chk - &n_ae_fail);
    %let GOLDEN_FAIL = %eval(&GOLDEN_FAIL + &n_ae_fail);
    %let n_fail = %eval(&n_fail + &n_ae_fail);
    %if &n_ae_fail > 0 %then %do;
      proc print data=work._gs_ae_fail;
        title "Golden subjects - ADAE integration failures";
      run;
      title;
      %put ERROR: Golden subjects ADAE suite - &n_ae_fail mismatch(es).;
    %end;
    %else %put NOTE: [GOLDEN PASS] ADAE suite GS-AE-01 through GS-AE-04 as expected.;
  %end;

  proc datasets lib=work nolist;
    delete _gs_dt_chk _gs_dt_fail _gs_dtm_chk _gs_dtm_fail
           _gs_epoch_chk _gs_epoch_fail
           _gs_te_chk _gs_te_fail _gs_ae_chk _gs_ae_fail;
  quit;

  %if &n_fail > 0 %then %do;
    %put ERROR: Golden subjects assert_all - &n_fail mismatch(es) in scenario checks.;
  %end;

%mend m_golden_assert_all_adam2;
