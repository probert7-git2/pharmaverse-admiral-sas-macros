/*--------------------------------------------------------------
  Program Name : m_tt_safety_datasets.sas
  Purpose      : Dataset test_that mirrors for safety ADaM templates
  Date         : 19OCT2026
  Requires     : m_tt_harness.sas and m_tt_impl_safety.sas
  Datasets     : ADSL ADAE ADCM ADVS ADEG ADLB
  Covered R    : derive_vars_duration, derive_var_trtdurd, derive_vars_dy,
                 derive_var_chg, derive_var_pchg, derive_var_base,
                 derive_var_anrind, derive_var_analysis_ratio,
                 derive_var_atoxgr (combine), derive_param_qtc, derive_param_rr
--------------------------------------------------------------*/

%macro m_tt_dur_len;
  length case_id $120 _start_iso _end_iso _in_unit _out_unit _type
         _siso _eiso          _in_c _out_c _type_c _uu _out_hold _in_hold _out_hold2
         unit_var exp_unit $40;
%mend m_tt_dur_len;

%macro m_tti_base(in=, out=);
  %global TTI_ERR;
  %local _tt_dup;
  %let TTI_ERR = 0;
  proc sql noprint;
    select count(*) into :_tt_dup trimmed
    from (
      select usubjid, paramcd, basetype
      from &in
      where ablfl = 'Y'
      group by usubjid, paramcd, basetype
      having count(*) > 1
    );
  quit;
  %if &_tt_dup > 0 %then %do;
    %let TTI_ERR = 1;
    %return;
  %end;
  proc sql;
    create table &out as
    select a.*, b.src as base
    from &in a
    left join (
      select usubjid, paramcd, basetype, aval as src
      from &in
      where ablfl = 'Y'
    ) b
    on a.usubjid = b.usubjid
   and a.paramcd = b.paramcd
   and a.basetype = b.basetype;
  quit;
%mend m_tti_base;

%macro m_tti_dy_var_ok(var=);
  %local _v _n _ok;
  %let _v = &var;
  %let _n = %length(&_v);
  %let _ok = 0;
  %if &_n >= 3 %then %do;
    %if %upcase(%substr(&_v, %eval(&_n - 2))) = DTM %then %let _ok = 1;
  %end;
  %if &_ok = 0 and &_n >= 2 %then %do;
    %if %upcase(%substr(&_v, %eval(&_n - 1))) = DT %then %let _ok = 1;
  %end;
  %if &_ok = 0 %then %let TTI_ERR = 1;
%mend m_tti_dy_var_ok;

/* ---- derive_vars_duration (ADSL age, ADAE/ADCM ADURN) ---- */
%macro m_tt_derive_vars_duration;
  data work.tt_vdur;
    %m_tt_dur_len;
    /* Test 1: age in years, trunc, default add-one */
    case_id = 'derive_vars_duration Test 1 P01';
    _start_iso = '1984-09-06'; _end_iso = '2020-02-24';
    _in_unit = 'days'; _out_unit = 'years'; _type = 'duration';
    _floor_in = 1; _add_one = 1; _trunc_out = 1;
    %m_tti_duration;
    unit_var = upcase(_out_unit);
    if missing(_result) then unit_var = '';
    expected = 35; exp_unit = 'YEARS';
    output;
    case_id = 'derive_vars_duration Test 1 P02';
    _start_iso = '1985-01-01'; _end_iso = '';
    %m_tti_duration;
    unit_var = '';
    if not missing(_result) then unit_var = 'YEARS';
    expected = .; exp_unit = '';
    output;
    case_id = 'derive_vars_duration Test 1 P03';
    _start_iso = ''; _end_iso = '2021-03-10';
    %m_tti_duration;
    unit_var = ''; expected = .; exp_unit = '';
    output;
    case_id = 'derive_vars_duration Test 1 P04';
    _start_iso = ''; _end_iso = '';
    %m_tti_duration;
    unit_var = ''; expected = .; exp_unit = '';
    output;

    /* Test 2: days, negative duration does not add one */
    case_id = 'derive_vars_duration Test 2 P01';
    _start_iso = '2021-03-05'; _end_iso = '2021-03-02';
    _in_unit = 'days'; _out_unit = 'days'; _trunc_out = 0; _add_one = 1;
    %m_tti_duration;
    unit_var = 'DAYS'; expected = -3; exp_unit = 'DAYS';
    output;
    case_id = 'derive_vars_duration Test 2 P02';
    _start_iso = '2019-09-18'; _end_iso = '2019-09-18';
    %m_tti_duration;
    unit_var = 'DAYS'; expected = 1; exp_unit = 'DAYS';
    output;
    case_id = 'derive_vars_duration Test 2 P03';
    _start_iso = '1985-01-01'; _end_iso = '';
    %m_tti_duration;
    unit_var = ''; expected = .; exp_unit = '';
    output;

    /* Test 3: minutes, floor input, do not add one */
    case_id = 'derive_vars_duration Test 3 P01';
    _start_iso = '2019-08-09T04:30:56'; _end_iso = '2019-08-09T05:00:00';
    _in_unit = 'minutes'; _out_unit = 'minutes'; _add_one = 0; _floor_in = 1;
    %m_tti_duration;
    unit_var = 'MINUTES'; expected = 30; exp_unit = 'MINUTES';
    output;
    case_id = 'derive_vars_duration Test 3 P02';
    _start_iso = '2019-11-11T10:30:00'; _end_iso = '2019-11-11T11:30:00';
    %m_tti_duration;
    unit_var = 'MINUTES'; expected = 60; exp_unit = 'MINUTES';
    output;
    case_id = 'derive_vars_duration Test 3 P03';
    _start_iso = '2019-11-11T00:00:00'; _end_iso = '2019-11-11T04:00:00';
    %m_tti_duration;
    unit_var = 'MINUTES'; expected = 240; exp_unit = 'MINUTES';
    output;

    /* Test 4: calendar months */
    case_id = 'derive_vars_duration Test 4 P01';
    _start_iso = '2019-02-01T00:00:00'; _end_iso = '2019-03-01T00:00:00';
    _in_unit = 'months'; _out_unit = 'months'; _type = 'interval'; _add_one = 0;
    %m_tti_duration;
    unit_var = 'MONTHS'; expected = 1; exp_unit = 'MONTHS';
    output;
    case_id = 'derive_vars_duration Test 4 P02';
    _start_iso = '2020-02-01T00:00:00'; _end_iso = '2020-03-01T00:00:00';
    %m_tti_duration;
    unit_var = 'MONTHS'; expected = 1; exp_unit = 'MONTHS';
    output;

    /* Test 5: average-month duration, 2019 has 28 days and 2020 has 29 */
    case_id = 'derive_vars_duration Test 5 P01';
    _start_iso = '2019-02-01T00:00:00'; _end_iso = '2019-03-01T00:00:00';
    _type = 'duration';
    %m_tti_duration;
    unit_var = 'MONTHS'; expected = 28 / (365.25 / 12); exp_unit = 'MONTHS';
    output;
    case_id = 'derive_vars_duration Test 5 P02';
    _start_iso = '2020-02-01T00:00:00'; _end_iso = '2020-03-01T00:00:00';
    %m_tti_duration;
    unit_var = 'MONTHS'; expected = 29 / (365.25 / 12); exp_unit = 'MONTHS';
    output;
  run;

  %m_tt_assert_ds(
    ds=work.tt_vdur, actual=_result, expected=expected, id=case_id
  , desc='derive_vars_duration', tol=1e-8
  );
  %m_tt_assert_ds(
    ds=work.tt_vdur, actual=unit_var, expected=exp_unit, id=case_id
  , desc='derive_vars_duration unit', is_char=Y
  );
%mend m_tt_derive_vars_duration;

/* ---- derive_var_trtdurd (ADSL) ---- */
%macro m_tt_derive_var_trtdurd;
  data work.tt_trtdurd;
    %m_tt_dur_len;
    case_id = 'TRTDURD is added';
    _start_iso = '2020-01-01'; _end_iso = '2020-02-24';
    _in_unit = 'days'; _out_unit = 'days'; _type = 'duration';
    _floor_in = 1; _add_one = 1; _trunc_out = 0;
    %m_tti_duration;
    expected = 55;
    output;
  run;
  %m_tt_assert_ds(
    ds=work.tt_trtdurd, actual=_result, expected=expected, id=case_id
  , desc='derive_var_trtdurd'
  );
%mend m_tt_derive_var_trtdurd;

/* ---- derive_vars_dy (ADAE ADCM ADVS ADEG ADLB) ---- */
%macro m_tt_dy_pair(id=, start=, end=, exp=);
  data work.tt_dy;
    %m_tt_dur_len;
    case_id = "&id";
    _start_iso = "&start";
    _end_iso = "&end";
    _in_unit = 'days'; _out_unit = 'days'; _type = 'duration';
    _floor_in = 1; _add_one = 1; _trunc_out = 0;
    %m_tti_duration;
    expected = &exp;
    output;
  run;
  %m_tt_assert_ds(
    ds=work.tt_dy, actual=_result, expected=expected, id=case_id
  , desc='derive_vars_dy'
  );
%mend m_tt_dy_pair;

%macro m_tt_derive_vars_dy;
  /* Test 1 */
  %m_tt_dy_pair(id=derive_vars_dy Test 1 ASTDY, start=2014-01-17T23:59:59, end=2014-01-18, exp=2);
  /* Test 2 */
  %m_tt_dy_pair(id=derive_vars_dy Test 2 PAT01 TRTSDY, start=2014-01-17T23:59:59, end=2014-01-17T23:59:59, exp=1);
  %m_tt_dy_pair(id=derive_vars_dy Test 2 PAT01 ASTDY, start=2014-01-17T23:59:59, end=2014-01-18, exp=2);
  %m_tt_dy_pair(id=derive_vars_dy Test 2 PAT01 AENDY, start=2014-01-17T23:59:59, end=2014-01-20, exp=4);
  %m_tt_dy_pair(id=derive_vars_dy Test 2 PAT01 DEATHDY, start=2014-01-17T23:59:59, end=2014-02-01, exp=16);
  %m_tt_dy_pair(id=derive_vars_dy Test 2 PAT02 ASTDY, start=2014-01-17T23:59:59, end=2014-01-17, exp=1);
  %m_tt_dy_pair(id=derive_vars_dy Test 2 PAT02 DEATHDY, start=2014-01-17T23:59:59, end=2014-03-01, exp=44);
  %m_tt_dy_pair(id=derive_vars_dy Test 2 PAT03 ASTDY, start=2014-01-17T23:59:59, end=2014-01-15, exp=-2);
  %m_tt_dy_pair(id=derive_vars_dy Test 2 PAT03 DEATHDY, start=2014-01-17T23:59:59, end=2014-05-01, exp=105);
  /* Test 3 and 6 and 7: lubridate reads letter O in the time as zero */
  %m_tt_dy_pair(id=derive_vars_dy Test 3 ASTDY, start=2014-01-17T23:59:59, end=2014-01-18T13:09:O9, exp=2);
  %m_tt_dy_pair(id=derive_vars_dy Test 3 AENDY, start=2014-01-17T23:59:59, end=2014-01-20, exp=4);
  %m_tt_dy_pair(id=derive_vars_dy Test 4 ASTDY, start=2014-01-17, end=2014-01-18, exp=2);
  %m_tt_dy_pair(id=derive_vars_dy Test 5 TRTSDY, start=2014-01-17, end=2014-01-17, exp=1);
  %m_tt_dy_pair(id=derive_vars_dy Test 5 ASTDY, start=2014-01-17, end=2014-01-18, exp=2);
  %m_tt_dy_pair(id=derive_vars_dy Test 5 AENDY, start=2014-01-17, end=2014-01-20, exp=4);
  %m_tt_dy_pair(id=derive_vars_dy Test 6 TRTSDY, start=2014-01-17, end=2014-01-17, exp=1);
  %m_tt_dy_pair(id=derive_vars_dy Test 6 ASTDY, start=2014-01-17, end=2014-01-18T13:09:O9, exp=2);
  %m_tt_dy_pair(id=derive_vars_dy Test 7 TRTSDY, start=2014-01-17T16:34:O9, end=2014-01-17T16:34:O9, exp=1);
  %m_tt_dy_pair(id=derive_vars_dy Test 7 ASTDY, start=2014-01-17T16:34:O9, end=2014-01-18T13:09:O9, exp=2);
  %m_tt_dy_pair(id=derive_vars_dy Test 7 AENDY, start=2014-01-17T16:34:O9, end=2014-01-20T08:29:05, exp=4);
  /* Test 9 and 10 are the same study day as Test 1, with an explicit name or an extra column */
  %m_tt_dy_pair(id=derive_vars_dy Test 9 ASTDY, start=2014-01-17T23:59:59, end=2014-01-18, exp=2);
  %m_tt_dy_pair(id=derive_vars_dy Test 10 ASTDY, start=2014-01-17T23:59:59, end=2014-01-18, exp=2);

  %global TTI_ERR;
  %let TTI_ERR = 0;
  %m_tti_dy_var_ok(var=TRTSDTW);
  %m_tti_dy_var_ok(var=ASTDTW);
  %m_tti_dy_var_ok(var=AENDTW);
  %m_tt_assert_flag(
    case_id=derive_vars_dy Test 8
  , actual=&TTI_ERR
  , expected=1
  , desc=%str(source vars must end in DT or DTM or be explicitly named)
  );
%mend m_tt_derive_vars_dy;

/* ---- derive_var_chg and derive_var_pchg (ADVS ADEG ADLB) ---- */
%macro m_tt_derive_var_chg;
  data work.tt_chg;
    length case_id $80;
    case_id = 'CHG Test 1'; aval = 10.12; base = 10.12; output;
    case_id = 'CHG Test 1'; aval = 9.7; base = 10.12; output;
    case_id = 'CHG Test 1'; aval = 15.01; base = 10.12; output;
    case_id = 'CHG Test 1'; aval = 8.35; base = 8.35; output;
    case_id = 'CHG Test 1'; aval = .; base = 8.35; output;
    case_id = 'CHG Test 1'; aval = 8.35; base = 8.35; output;
    case_id = 'CHG Test 1'; aval = 29; base = 29; output;
    case_id = 'CHG Test 1'; aval = 19.7; base = 29; output;
    case_id = 'CHG Test 1'; aval = 18.01; base = 29; output;
    case_id = 'CHG Test 1'; aval = 8.9; base = 8.9; output;
    case_id = 'CHG Test 1'; aval = 9; base = 8.9; output;
    case_id = 'CHG Test 1'; aval = 5.35; base = 8.9; output;
  run;
  data work.tt_chg;
    set work.tt_chg;
    %m_tti_chg;
    if _n_ = 1 then expected = 0;
    else if _n_ = 2 then expected = -0.42;
    else if _n_ = 3 then expected = 4.89;
    else if _n_ = 4 then expected = 0;
    else if _n_ = 5 then expected = .;
    else if _n_ = 6 then expected = 0;
    else if _n_ = 7 then expected = 0;
    else if _n_ = 8 then expected = -9.3;
    else if _n_ = 9 then expected = -10.99;
    else if _n_ = 10 then expected = 0;
    else if _n_ = 11 then expected = 0.1;
    else if _n_ = 12 then expected = -3.55;
  run;
  %m_tt_assert_ds(ds=work.tt_chg, actual=chg, expected=expected, id=case_id, desc='derive_var_chg Test 1');

  data work.tt_pchg;
    length case_id $80;
    case_id = 'PCHG Test 2'; aval = -10.12; base = -10.12; output;
    case_id = 'PCHG Test 2'; aval = -9.7; base = -10.12; output;
    case_id = 'PCHG Test 2'; aval = -15.01; base = -10.12; output;
    case_id = 'PCHG Test 2'; aval = 8.35; base = 8.35; output;
    case_id = 'PCHG Test 2'; aval = .; base = 8.35; output;
    case_id = 'PCHG Test 2'; aval = 8.35; base = 8.35; output;
    case_id = 'PCHG Test 2'; aval = 29; base = 29; output;
    case_id = 'PCHG Test 2'; aval = 19.7; base = 29; output;
    case_id = 'PCHG Test 2'; aval = 18.01; base = 29; output;
    case_id = 'PCHG Test 2'; aval = 8.9; base = 8.9; output;
    case_id = 'PCHG Test 2'; aval = 9; base = 8.9; output;
    case_id = 'PCHG Test 2'; aval = 5.35; base = 8.9; output;
    case_id = 'PCHG Test 3'; aval = 0; base = 0; output;
    case_id = 'PCHG Test 3'; aval = 1.7; base = 0; output;
    case_id = 'PCHG Test 3'; aval = 3.01; base = 0; output;
  run;
  data work.tt_pchg;
    set work.tt_pchg;
    %m_tti_pchg;
    if case_id = 'PCHG Test 3' then expected = .;
    else if _n_ = 1 then expected = 0;
    else if _n_ = 2 then expected = 4.150198;
    else if _n_ = 3 then expected = -48.32016;
    else if _n_ = 4 then expected = 0;
    else if _n_ = 5 then expected = .;
    else if _n_ = 6 then expected = 0;
    else if _n_ = 7 then expected = 0;
    else if _n_ = 8 then expected = -32.06897;
    else if _n_ = 9 then expected = -37.89655;
    else if _n_ = 10 then expected = 0;
    else if _n_ = 11 then expected = 1.123596;
    else if _n_ = 12 then expected = -39.88764;
  run;
  %m_tt_assert_ds(
    ds=work.tt_pchg, actual=pchg, expected=expected, id=case_id
  , desc='derive_var_pchg', tol=1e-4
  );
%mend m_tt_derive_var_chg;

/* ---- derive_var_base (ADVS ADEG ADLB) ---- */
%macro m_tt_derive_var_base;
  data work.tt_base_in;
    length studyid usubjid paramcd ablfl basetype anl01fl $12;
    studyid = 'TEST01'; basetype = 'LAST'; anl01fl = 'Y';
    usubjid = 'PAT01'; paramcd = 'PARAM01'; aseq = 1; aval = 10.12; ablfl = 'Y'; output;
    usubjid = 'PAT01'; paramcd = 'PARAM01'; aseq = 2; aval = 9.7; ablfl = ''; output;
    usubjid = 'PAT01'; paramcd = 'PARAM01'; aseq = 3; aval = 15.01; ablfl = ''; output;
    usubjid = 'PAT01'; paramcd = 'PARAM02'; aseq = 1; aval = 8.35; ablfl = 'Y'; output;
    usubjid = 'PAT01'; paramcd = 'PARAM02'; aseq = 2; aval = .; ablfl = ''; output;
    usubjid = 'PAT01'; paramcd = 'PARAM02'; aseq = 3; aval = 8.35; ablfl = ''; output;
    usubjid = 'PAT02'; paramcd = 'PARAM01'; aseq = 1; aval = 29; ablfl = 'Y'; output;
    usubjid = 'PAT02'; paramcd = 'PARAM01'; aseq = 2; aval = 19.7; ablfl = ''; output;
    usubjid = 'PAT02'; paramcd = 'PARAM01'; aseq = 3; aval = 18.01; ablfl = ''; output;
    usubjid = 'PAT02'; paramcd = 'PARAM02'; aseq = 1; aval = 8.9; ablfl = 'Y'; output;
    usubjid = 'PAT02'; paramcd = 'PARAM02'; aseq = 2; aval = 9; ablfl = ''; output;
    usubjid = 'PAT02'; paramcd = 'PARAM02'; aseq = 3; aval = 5.35; ablfl = ''; output;
  run;
  %m_tti_base(in=work.tt_base_in, out=work.tt_base1);
  data work.tt_base1;
    set work.tt_base1;
    length case_id $40;
    case_id = 'derive_var_base Test 1';
    expected = aval;
    if usubjid = 'PAT01' and paramcd = 'PARAM01' then expected = 10.12;
    if usubjid = 'PAT01' and paramcd = 'PARAM02' then expected = 8.35;
    if usubjid = 'PAT02' and paramcd = 'PARAM01' then expected = 29;
    if usubjid = 'PAT02' and paramcd = 'PARAM02' then expected = 8.9;
  run;
  %m_tt_assert_ds(ds=work.tt_base1, actual=base, expected=expected, id=case_id, desc='derive_var_base Test 1');

  data work.tt_base2_in;
    length studyid usubjid paramcd ablfl basetype $12;
    studyid = 'TEST01'; basetype = 'LAST';
    usubjid = 'PAT01'; paramcd = 'PARAM01'; aseq = 1; aval = 10.12; ablfl = 'Y'; output;
    usubjid = 'PAT01'; paramcd = 'PARAM01'; aseq = 2; aval = 9.7; ablfl = ''; output;
    usubjid = 'PAT01'; paramcd = 'PARAM01'; aseq = 3; aval = 15.01; ablfl = ''; output;
    usubjid = 'PAT01'; paramcd = 'PARAM02'; aseq = 1; aval = 4.9; ablfl = ''; output;
    usubjid = 'PAT01'; paramcd = 'PARAM02'; aseq = 2; aval = 7.1; ablfl = ''; output;
    usubjid = 'PAT01'; paramcd = 'PARAM02'; aseq = 3; aval = 8.35; ablfl = ''; output;
  run;
  %m_tti_base(in=work.tt_base2_in, out=work.tt_base2);
  data work.tt_base2;
    set work.tt_base2;
    length case_id $40;
    case_id = 'derive_var_base Test 2';
    if paramcd = 'PARAM01' then expected = 10.12;
    else expected = .;
  run;
  %m_tt_assert_ds(ds=work.tt_base2, actual=base, expected=expected, id=case_id, desc='derive_var_base Test 2');

  %global TTI_ERR;
  data work.tt_base4_in;
    length studyid usubjid paramcd ablfl basetype avalc $12;
    studyid = 'TEST01'; basetype = 'LAST';
    usubjid = 'PAT01'; paramcd = 'PARAM01'; avalc = 'LOW'; ablfl = 'Y'; output;
    usubjid = 'PAT01'; paramcd = 'PARAM01'; avalc = 'MEDIUM'; ablfl = 'Y'; output;
    usubjid = 'PAT01'; paramcd = 'PARAM01'; avalc = 'LOW'; ablfl = ''; output;
    usubjid = 'PAT02'; paramcd = 'PARAM02'; avalc = 'HIGH'; ablfl = 'Y'; output;
    usubjid = 'PAT02'; paramcd = 'PARAM02'; avalc = 'HIGH'; ablfl = 'Y'; output;
  run;
  %m_tti_base(in=work.tt_base4_in, out=work.tt_base4);
  %m_tt_assert_flag(
    case_id=derive_var_base Test 4
  , actual=&TTI_ERR
  , expected=1
  , desc=%str(multiple baseline records are an error)
  );
%mend m_tt_derive_var_base;

/* ---- derive_var_anrind (ADVS ADEG ADLB) ---- */
%macro m_tt_derive_var_anrind;
  data work.tt_anr;
    length case_id $48 usubjid paramcd $12 anrind exp_ind $12;
    signif_dig = 15; _use_a1 = 1;
    case_id = 'derive_var_anrind Test 1';
    usubjid = 'P01'; paramcd = 'PUL'; aseq = 1; aval = 70; anrlo = 60; anrhi = 100; a1lo = 40; a1hi = 110; exp_ind = 'NORMAL'; output;
    usubjid = 'P01'; paramcd = 'PUL'; aseq = 2; aval = 57; anrlo = 60; anrhi = 100; a1lo = 40; a1hi = 110; exp_ind = 'LOW'; output;
    usubjid = 'P01'; paramcd = 'PUL'; aseq = 3; aval = 60; anrlo = 60; anrhi = 100; a1lo = 40; a1hi = 110; exp_ind = 'NORMAL'; output;
    usubjid = 'P01'; paramcd = 'DIABP'; aseq = 1; aval = 102; anrlo = 60; anrhi = 80; a1lo = 40; a1hi = 90; exp_ind = 'HIGH HIGH'; output;
    usubjid = 'P02'; paramcd = 'PUL'; aseq = 1; aval = 109; anrlo = 60; anrhi = 100; a1lo = 40; a1hi = 110; exp_ind = 'HIGH'; output;
    usubjid = 'P02'; paramcd = 'PUL'; aseq = 2; aval = 100; anrlo = 60; anrhi = 100; a1lo = 40; a1hi = 110; exp_ind = 'NORMAL'; output;
    usubjid = 'P02'; paramcd = 'DIABP'; aseq = 1; aval = 80; anrlo = 60; anrhi = 80; a1lo = 40; a1hi = 90; exp_ind = 'NORMAL'; output;
    usubjid = 'P03'; paramcd = 'PUL'; aseq = 1; aval = 39; anrlo = 60; anrhi = 100; a1lo = 40; a1hi = 110; exp_ind = 'LOW LOW'; output;
    usubjid = 'P03'; paramcd = 'PUL'; aseq = 2; aval = 40; anrlo = 60; anrhi = 100; a1lo = 40; a1hi = 110; exp_ind = 'LOW'; output;

    case_id = 'derive_var_anrind Test 3'; _use_a1 = 0;
    a1lo = .; a1hi = .;
    usubjid = 'P01'; paramcd = 'DIABP'; aseq = 1; aval = 102; anrlo = 60; anrhi = 80; exp_ind = 'HIGH'; output;
    usubjid = 'P03'; paramcd = 'PUL'; aseq = 1; aval = 39; anrlo = 60; anrhi = 100; exp_ind = 'LOW'; output;

    case_id = 'derive_var_anrind Test 4'; _use_a1 = 1;
    usubjid = 'P01'; paramcd = 'PUL'; aseq = 1; aval = 70; anrlo = 60; anrhi = 100; a1lo = .; a1hi = .; exp_ind = 'NORMAL'; output;
    usubjid = 'P01'; paramcd = 'PUL'; aseq = 2; aval = 39; anrlo = 60; anrhi = 100; a1lo = .; a1hi = .; exp_ind = 'LOW'; output;
    usubjid = 'P01'; paramcd = 'DIABP'; aseq = 1; aval = 102; anrlo = 60; anrhi = 80; a1lo = 40; a1hi = 90; exp_ind = 'HIGH HIGH'; output;

    case_id = 'derive_var_anrind Test 5';
    usubjid = 'P01'; paramcd = 'PUL'; aseq = 1; aval = 101; anrlo = .; anrhi = 100; a1lo = .; a1hi = 120; exp_ind = 'HIGH'; output;
    usubjid = 'P01'; paramcd = 'PUL'; aseq = 2; aval = 99; anrlo = .; anrhi = 100; a1lo = .; a1hi = 120; exp_ind = 'NORMAL'; output;
    usubjid = 'P01'; paramcd = 'PUL'; aseq = 3; aval = 123; anrlo = .; anrhi = 100; a1lo = .; a1hi = 120; exp_ind = 'HIGH HIGH'; output;
    usubjid = 'P01'; paramcd = 'DIABP'; aseq = 1; aval = 102; anrlo = 60; anrhi = .; a1lo = 40; a1hi = .; exp_ind = 'NORMAL'; output;
    usubjid = 'P02'; paramcd = 'DIABP'; aseq = 1; aval = 58; anrlo = 60; anrhi = .; a1lo = 40; a1hi = .; exp_ind = 'LOW'; output;
    usubjid = 'P03'; paramcd = 'PUL'; aseq = 1; aval = 39; anrlo = .; anrhi = 100; a1lo = .; a1hi = 120; exp_ind = 'NORMAL'; output;

    case_id = 'derive_var_anrind Test 6'; _use_a1 = 0;
    usubjid = 'P01'; paramcd = 'PUL'; aseq = 1; aval = .; anrlo = 60; anrhi = 100; a1lo = .; a1hi = .; exp_ind = ''; output;

    case_id = 'derive_var_anrind Test 7'; _use_a1 = 0;
    usubjid = 'P01'; paramcd = 'PUL'; aseq = 1; aval = 1.1 * 100; anrlo = 60; anrhi = 110; signif_dig = 15; exp_ind = 'NORMAL'; output;
    case_id = 'derive_var_anrind Test 8';
    signif_dig = 17; exp_ind = 'HIGH'; output;
  run;
  data work.tt_anr;
    set work.tt_anr;
    %m_tti_anrind;
  run;
  %m_tt_assert_ds(
    ds=work.tt_anr, actual=anrind, expected=exp_ind, id=case_id
  , desc='derive_var_anrind', is_char=Y
  );
%mend m_tt_derive_var_anrind;

/* ---- derive_var_analysis_ratio (ADLB) ---- */
%macro m_tt_derive_var_analysis_ratio;
  data work.tt_ratio;
    length case_id $40 usubjid paramcd $8 which $8;
    case_id = 'analysis_ratio Test 1';
    usubjid = 'P01'; paramcd = 'ALT'; seq = 1; aval = 27; base = 27; anrlo = 6; anrhi = 34; output;
    seq = 2; aval = 41; output;
    seq = 3; aval = 17; output;
    usubjid = 'P02'; paramcd = 'ALB'; seq = 1; aval = 38; base = 38; anrlo = 33; anrhi = 49; output;
    seq = 2; aval = 39; output;
    seq = 3; aval = 37; output;
    case_id = 'analysis_ratio Test 2';
    usubjid = 'P01'; paramcd = 'ALT'; seq = 3; aval = .; base = 0; anrlo = 0; anrhi = 0; output;
    usubjid = 'P02'; paramcd = 'ALB'; seq = 1; aval = 0; base = 0; anrlo = 0; anrhi = 0; output;
  run;
  data work.tt_ratio_long;
    set work.tt_ratio;
    length case_id2 $60;
    numer = aval; denom = base; which = 'BASE';
    %m_tti_ratio;
    case_id2 = catx(' ', case_id, usubjid, paramcd, seq, which);
    if case_id = 'analysis_ratio Test 1' and usubjid = 'P01' and seq = 1 then expected = 1;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P01' and seq = 2 then expected = 1.52;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P01' and seq = 3 then expected = 0.63;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P02' and seq = 1 then expected = 1;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P02' and seq = 2 then expected = 1.03;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P02' and seq = 3 then expected = 0.974;
    else expected = .;
    output;
    numer = aval; denom = anrlo; which = 'ANRLO';
    %m_tti_ratio;
    case_id2 = catx(' ', case_id, usubjid, paramcd, seq, which);
    if case_id = 'analysis_ratio Test 1' and usubjid = 'P01' and seq = 1 then expected = 4.5;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P01' and seq = 2 then expected = 6.83;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P01' and seq = 3 then expected = 2.83;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P02' and seq = 1 then expected = 1.15;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P02' and seq = 2 then expected = 1.18;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P02' and seq = 3 then expected = 1.12;
    else expected = .;
    output;
    numer = aval; denom = anrhi; which = 'ANRHI';
    %m_tti_ratio;
    case_id2 = catx(' ', case_id, usubjid, paramcd, seq, which);
    if case_id = 'analysis_ratio Test 1' and usubjid = 'P01' and seq = 1 then expected = 0.794;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P01' and seq = 2 then expected = 1.21;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P01' and seq = 3 then expected = 0.5;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P02' and seq = 1 then expected = 0.776;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P02' and seq = 2 then expected = 0.796;
    else if case_id = 'analysis_ratio Test 1' and usubjid = 'P02' and seq = 3 then expected = 0.755;
    else expected = .;
    output;
  run;
  %m_tt_assert_ds(
    ds=work.tt_ratio_long, actual=_result, expected=expected, id=case_id2
  , desc='derive_var_analysis_ratio', tol=0.01
  );
%mend m_tt_derive_var_analysis_ratio;

/* ---- derive_var_atoxgr combine (ADLB). Directional CTCAE tests stay in R. ---- */
%macro m_tt_derive_var_atoxgr;
  data work.tt_atox;
    length case_id $40 ATOXDSCL ATOXDSCH $20 ATOXGRL ATOXGRH ATOXGR exp_gr $2;
    case_id = 'derive_var_atoxgr Test 1';
    ATOXDSCL = ''; ATOXDSCH = ''; ATOXGRL = ''; ATOXGRH = ''; exp_gr = ''; output;
    ATOXDSCL = 'Hypophosphatemia'; ATOXDSCH = ''; ATOXGRL = ''; ATOXGRH = ''; exp_gr = ''; output;
    ATOXDSCL = ''; ATOXDSCH = 'Hyperglycemia'; ATOXGRL = ''; ATOXGRH = ''; exp_gr = ''; output;
    ATOXDSCL = 'Hypoglycemia'; ATOXDSCH = 'Hyperglycemia'; ATOXGRL = ''; ATOXGRH = ''; exp_gr = ''; output;
    ATOXDSCL = 'Hypoglycemia'; ATOXDSCH = 'Hyperglycemia'; ATOXGRL = ''; ATOXGRH = '0'; exp_gr = ''; output;
    ATOXDSCL = 'Hypoglycemia'; ATOXDSCH = 'Hyperglycemia'; ATOXGRL = '0'; ATOXGRH = ''; exp_gr = ''; output;

    case_id = 'derive_var_atoxgr Test 2';
    ATOXDSCL = 'Hypoglycemia'; ATOXDSCH = 'Hyperglycemia'; ATOXGRL = '0'; ATOXGRH = '0'; exp_gr = '0'; output;
    ATOXDSCL = ''; ATOXDSCH = 'INR Increased'; ATOXGRL = ''; ATOXGRH = '0'; exp_gr = '0'; output;
    ATOXDSCL = 'Hypophosphatemia'; ATOXDSCH = ''; ATOXGRL = '0'; ATOXGRH = ''; exp_gr = '0'; output;

    case_id = 'derive_var_atoxgr Test 3';
    ATOXDSCL = 'Hypoglycemia'; ATOXDSCH = 'Hyperglycemia'; ATOXGRL = ''; ATOXGRH = '1'; exp_gr = '1'; output;
    ATOXDSCL = 'Hypoglycemia'; ATOXDSCH = 'Hyperglycemia'; ATOXGRL = '0'; ATOXGRH = '4'; exp_gr = '4'; output;
    ATOXDSCL = ''; ATOXDSCH = 'INR Increased'; ATOXGRL = ''; ATOXGRH = '2'; exp_gr = '2'; output;

    case_id = 'derive_var_atoxgr Test 4';
    ATOXDSCL = 'Hypoglycemia'; ATOXDSCH = 'Hyperglycemia'; ATOXGRL = '3'; ATOXGRH = ''; exp_gr = '-3'; output;
    ATOXDSCL = 'Hypoglycemia'; ATOXDSCH = 'Hyperglycemia'; ATOXGRL = '1'; ATOXGRH = '0'; exp_gr = '-1'; output;
    ATOXDSCL = 'Hypophosphatemia'; ATOXDSCH = ''; ATOXGRL = '4'; ATOXGRH = ''; exp_gr = '-4'; output;
  run;
  data work.tt_atox;
    set work.tt_atox;
    %m_tti_atoxgr;
  run;
  %m_tt_assert_ds(
    ds=work.tt_atox, actual=ATOXGR, expected=exp_gr, id=case_id
  , desc='derive_var_atoxgr', is_char=Y
  );
%mend m_tt_derive_var_atoxgr;

/* ---- derive_param_qtc (ADEG) ---- */
%macro m_tt_qtc_build(method=, paramcd=);
  proc sql;
    create table work.tt_qtc_new as
    select q.usubjid, "&paramcd" as paramcd length=8, q.visit,
           case
             when "&method" = 'Bazett' then q.aval / sqrt(r.aval / 1000)
             when "&method" = 'Fridericia' then q.aval / (r.aval / 1000)**(1/3)
             when "&method" = 'Sagie' then 1000 * (q.aval / 1000 + 0.154 * (1 - r.aval / 1000))
             else .
           end as _result
    from work.tt_qtc_in q
    inner join work.tt_qtc_in r
      on q.usubjid = r.usubjid and q.visit = r.visit
    where q.paramcd = 'QT' and r.paramcd = 'RR'
      and q.aval is not null and r.aval is not null;
  quit;
%mend m_tt_qtc_build;

%macro m_tt_derive_param_qtc;
  data work.tt_qtc_in;
    length usubjid $12 paramcd $8 visit $8;
    usubjid = '01-701-1015'; paramcd = 'QT'; aval = 370; visit = 'WEEK 2'; output;
    usubjid = '01-701-1015'; paramcd = 'RR'; aval = 710; visit = 'WEEK 2'; output;
    usubjid = '01-701-1028'; paramcd = 'QT'; aval = 480; visit = 'WEEK 2'; output;
    usubjid = '01-701-1028'; paramcd = 'QT'; aval = 350; visit = 'WEEK 3'; output;
    usubjid = '01-701-1028'; paramcd = 'RR'; aval = 842; visit = 'WEEK 2'; output;
  run;
  %m_tt_qtc_build(method=Bazett, paramcd=QTCBR);
  data work.tt_qtc_bz;
    set work.tt_qtc_new;
    length case_id $40;
    case_id = cats('QTC Test 1 ', usubjid);
    if usubjid = '01-701-1015' then expected = 370 / sqrt(710 / 1000);
    else expected = 480 / sqrt(842 / 1000);
  run;
  %m_tt_assert_ds(ds=work.tt_qtc_bz, actual=_result, expected=expected, id=case_id, desc='derive_param_qtc Test 1 Bazett');

  %m_tt_qtc_build(method=Fridericia, paramcd=QTCFR);
  data work.tt_qtc_fr;
    set work.tt_qtc_new;
    length case_id $40;
    case_id = cats('QTC Test 2 ', usubjid);
    if usubjid = '01-701-1015' then expected = 370 / 710**(1/3) * 10;
    else expected = 480 / 842**(1/3) * 10;
  run;
  %m_tt_assert_ds(ds=work.tt_qtc_fr, actual=_result, expected=expected, id=case_id, desc='derive_param_qtc Test 2 Fridericia');

  %m_tt_qtc_build(method=Sagie, paramcd=QTLCR);
  data work.tt_qtc_sg;
    set work.tt_qtc_new;
    length case_id $40;
    case_id = cats('QTC Test 3 ', usubjid);
    if usubjid = '01-701-1015' then expected = 370 + 154 * (1 - 710 / 1000);
    else expected = 480 + 154 * (1 - 842 / 1000);
  run;
  %m_tt_assert_ds(ds=work.tt_qtc_sg, actual=_result, expected=expected, id=case_id, desc='derive_param_qtc Test 3 Sagie');

  data work.tt_qtc_in;
    set work.tt_qtc_in;
    if paramcd = 'RR' then aval = .;
  run;
  %m_tt_qtc_build(method=Bazett, paramcd=QTCBR);
  %local _nq;
  proc sql noprint;
    select count(*) into :_nq trimmed from work.tt_qtc_new;
  quit;
  %m_tt_assert_flag(
    case_id=derive_param_qtc Test 4
  , actual=&_nq
  , expected=0
  , desc=%str(no QTc row when RR is missing)
  );
%mend m_tt_derive_param_qtc;

/* ---- derive_param_rr (ADEG) ---- */
%macro m_tt_derive_param_rr;
  data work.tt_rr_in;
    length usubjid $12 paramcd $8 visit $12;
    usubjid = '01-701-1015'; paramcd = 'HR'; aval = 70.14; visit = 'BASELINE'; output;
    usubjid = '01-701-1015'; paramcd = 'HR'; aval = 62.66; visit = 'WEEK 1'; output;
    usubjid = '01-701-1015'; paramcd = 'RR'; aval = 710; visit = 'WEEK 2'; output;
    usubjid = '01-701-1028'; paramcd = 'HR'; aval = 85.45; visit = 'BASELINE'; output;
    usubjid = '01-701-1028'; paramcd = 'HR'; aval = 56.54; visit = 'WEEK 3'; output;
    usubjid = '01-701-1028'; paramcd = 'RR'; aval = 842; visit = 'WEEK 2'; output;
  run;
  data work.tt_rr_new;
    set work.tt_rr_in;
    length case_id $48;
    where paramcd = 'HR' and not missing(aval);
    hr = aval;
    %m_tti_rr;
    case_id = cats('RR Test 1 ', usubjid, ' ', visit);
    expected = 60000 / hr;
  run;
  %m_tt_assert_ds(ds=work.tt_rr_new, actual=_result, expected=expected, id=case_id, desc='derive_param_rr Test 1');

  data work.tt_rr_in;
    set work.tt_rr_in;
    if paramcd = 'HR' then aval = .;
  run;
  data work.tt_rr_none;
    set work.tt_rr_in;
    where paramcd = 'HR' and not missing(aval);
  run;
  %local _nr;
  proc sql noprint;
    select count(*) into :_nr trimmed from work.tt_rr_none;
  quit;
  %m_tt_assert_flag(
    case_id=derive_param_rr Test 2
  , actual=&_nr
  , expected=0
  , desc=%str(no rederived RR when heart rate is missing)
  );
%mend m_tt_derive_param_rr;
