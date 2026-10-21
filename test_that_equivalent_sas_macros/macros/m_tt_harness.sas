/*--------------------------------------------------------------
  Program Name : m_tt_harness.sas
  Purpose      : Pass/fail counters for admiral test_that mirrors
  Date         : 19OCT2026
  Notes        : Same log contract as %m_golden_assert_num (NOTE on
                 pass, ERROR with expected and actual on fail).
                 Kept local because %m_golden_summary expects 21 rows
                 and %m_golden_assert_num rejects missing values.
--------------------------------------------------------------*/

%macro m_tt_init;
  %global TT_PASS TT_FAIL;
  %let TT_PASS = 0;
  %let TT_FAIL = 0;
%mend m_tt_init;

%macro m_tt_pass(case_id=, desc=);
  %let TT_PASS = %eval(&TT_PASS + 1);
  %put NOTE: [TT PASS] &case_id - &desc;
%mend m_tt_pass;

%macro m_tt_fail(case_id=, desc=, expected=, actual=);
  %let TT_FAIL = %eval(&TT_FAIL + 1);
  %put ERROR: [TT FAIL] &case_id - &desc;
  %put ERROR: [TT FAIL] expected=&expected actual=&actual;
%mend m_tt_fail;

/* One row in &ds. &id is a variable. Numeric compare uses absolute tol. */
%macro m_tt_assert_ds(
  ds=
, actual=
, expected=
, id=
, desc=
, tol=1e-8
, is_char=N
);
  %local _np _nf;
  %let _np = 0;
  %let _nf = 0;

  %if not %sysfunc(exist(&ds)) %then %do;
    %m_tt_fail(case_id=&desc, desc=Dataset &ds missing, expected=, actual=);
    %return;
  %end;

  data _null_;
    set &ds end=_last;
    length _idc _actc _expc $200;
    retain _np _nf 0;
    _idc = strip(vvalue(&id));
    %if %upcase(&is_char) = Y %then %do;
      _actc = strip(&actual);
      _expc = strip(&expected);
      if _actc = _expc then _np + 1;
      else do;
        _nf + 1;
        put "ERROR: [TT FAIL] " _idc " &desc";
        put "ERROR: [TT FAIL] expected=" _expc " actual=" _actc;
      end;
    %end;
    %else %do;
      if missing(&actual) and missing(&expected) then _np + 1;
      else if missing(&actual) or missing(&expected) then do;
        _nf + 1;
        put "ERROR: [TT FAIL] " _idc " &desc";
        put "ERROR: [TT FAIL] expected=" &expected " actual=" &actual;
      end;
      else if abs(&actual - &expected) <= &tol then _np + 1;
      else do;
        _nf + 1;
        put "ERROR: [TT FAIL] " _idc " &desc";
        put "ERROR: [TT FAIL] expected=" &expected " actual=" &actual;
      end;
    %end;
    if _last then do;
      call symputx('_np', _np, 'L');
      call symputx('_nf', _nf, 'L');
    end;
  run;

  %let TT_PASS = %eval(&TT_PASS + &_np);
  %let TT_FAIL = %eval(&TT_FAIL + &_nf);
  %if &_nf = 0 %then %put NOTE: [TT PASS] &desc (&_np row(s)).;
%mend m_tt_assert_ds;

%macro m_tt_assert_flag(case_id=, actual=, expected=, desc=);
  %if &actual = &expected %then %m_tt_pass(case_id=&case_id, desc=&desc);
  %else %m_tt_fail(case_id=&case_id, desc=&desc, expected=&expected, actual=&actual);
%mend m_tt_assert_flag;

%macro m_tt_summary;
  %global TT_PASS TT_FAIL;
  %if %symexist(TT_PASS) = 0 %then %let TT_PASS = 0;
  %if %symexist(TT_FAIL) = 0 %then %let TT_FAIL = 0;
  %put NOTE: ===== Safety ADaM test_that mirrors: &TT_PASS passed, &TT_FAIL failed =====;
  %if &TT_FAIL > 0 %then %put ERROR: Safety ADaM test_that mirrors reported &TT_FAIL failure(s).;
  %else %put NOTE: Safety ADaM test_that mirrors PASSED.;
%mend m_tt_summary;
