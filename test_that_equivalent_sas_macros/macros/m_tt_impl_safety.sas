/*--------------------------------------------------------------
  Program Name : m_tt_impl_safety.sas
  Purpose      : SAS mirrors of admiral helpers used by ADSL, ADAE,
                 ADCM, ADVS, ADEG, and ADLB templates
  Date         : 19OCT2026
  Call style   : from a DATA step. Inputs are columns already on the
                 PDV. Each snippet writes _result or a named column.
--------------------------------------------------------------*/

/* Map a time-unit token to seconds. Writes _secs. */
%macro m_tti_unit_secs(unitvar=);
  _uu = lowcase(strip(&unitvar));
  if _uu in ('year', 'years', 'yr', 'yrs', 'y') then _secs = 86400 * 365.25;
  else if _uu in ('month', 'months', 'mo', 'mos') then _secs = 86400 * 365.25 / 12;
  else if _uu in ('week', 'weeks', 'wk', 'wks', 'w') then _secs = 86400 * 7;
  else if _uu in ('day', 'days', 'd') then _secs = 86400;
  else if _uu in ('hour', 'hours', 'hr', 'hrs', 'h') then _secs = 3600;
  else if _uu in ('minute', 'minutes', 'min', 'mins') then _secs = 60;
  else if _uu in ('second', 'seconds', 'sec', 'secs', 's') then _secs = 1;
  else _secs = .;
%mend m_tti_unit_secs;

/* Canonical unit name in _canon from _uu. */
%macro m_tti_unit_canon(unitvar=, outvar=);
  _uu = lowcase(strip(&unitvar));
  if _uu in ('year', 'years', 'yr', 'yrs', 'y') then &outvar = 'years';
  else if _uu in ('month', 'months', 'mo', 'mos') then &outvar = 'months';
  else if _uu in ('week', 'weeks', 'wk', 'wks', 'w') then &outvar = 'weeks';
  else if _uu in ('day', 'days', 'd') then &outvar = 'days';
  else if _uu in ('hour', 'hours', 'hr', 'hrs', 'h') then &outvar = 'hours';
  else if _uu in ('minute', 'minutes', 'min', 'mins') then &outvar = 'minutes';
  else if _uu in ('second', 'seconds', 'sec', 'secs', 's') then &outvar = 'seconds';
  else &outvar = _uu;
%mend m_tti_unit_canon;

/*
  compute_duration
  Inputs: _start_iso _end_iso _in_unit _out_unit _type
          _floor_in _add_one _trunc_out (0/1)
  Output: _result
  Letter O in the ISO time is read as zero, matching lubridate on the
  admiral dy fixtures.
*/
%macro m_tti_duration;
  _siso = strip(_start_iso);
  _eiso = strip(_end_iso);
  _siso = tranwrd(_siso, 'O', '0');
  _eiso = tranwrd(_eiso, 'O', '0');
  if index(_siso, 'T') then do;
    if length(scan(substr(_siso, index(_siso, 'T') + 1), 1, ':')) = 1 then
      _siso = substr(_siso, 1, index(_siso, 'T')) || '0' || substr(_siso, index(_siso, 'T') + 1);
    _s = input(_siso, ?? e8601dt.);
  end;
  else _s = dhms(input(_siso, ?? e8601da.), 0, 0, 0);
  if index(_eiso, 'T') then do;
    if length(scan(substr(_eiso, index(_eiso, 'T') + 1), 1, ':')) = 1 then
      _eiso = substr(_eiso, 1, index(_eiso, 'T')) || '0' || substr(_eiso, index(_eiso, 'T') + 1);
    _e = input(_eiso, ?? e8601dt.);
  end;
  else _e = dhms(input(_eiso, ?? e8601da.), 0, 0, 0);

  %m_tti_unit_canon(unitvar=_in_unit, outvar=_in_c);
  %m_tti_unit_canon(unitvar=_out_unit, outvar=_out_c);
  _type_c = lowcase(strip(_type));

  if _floor_in and not missing(_s) then do;
    if _in_c = 'years' then _s = dhms(intnx('year', datepart(_s), 0, 'b'), 0, 0, 0);
    else if _in_c = 'months' then _s = dhms(intnx('month', datepart(_s), 0, 'b'), 0, 0, 0);
    else if _in_c = 'days' then _s = dhms(datepart(_s), 0, 0, 0);
    else if _in_c = 'hours' then _s = intnx('dthour', _s, 0, 'b');
    else if _in_c = 'minutes' then _s = intnx('dtminute', _s, 0, 'b');
    else if _in_c = 'seconds' then _s = intnx('dtsecond', _s, 0, 'b');
  end;
  if _floor_in and not missing(_e) then do;
    if _in_c = 'years' then _e = dhms(intnx('year', datepart(_e), 0, 'b'), 0, 0, 0);
    else if _in_c = 'months' then _e = dhms(intnx('month', datepart(_e), 0, 'b'), 0, 0, 0);
    else if _in_c = 'days' then _e = dhms(datepart(_e), 0, 0, 0);
    else if _in_c = 'hours' then _e = intnx('dthour', _e, 0, 'b');
    else if _in_c = 'minutes' then _e = intnx('dtminute', _e, 0, 'b');
    else if _in_c = 'seconds' then _e = intnx('dtsecond', _e, 0, 'b');
  end;

  if missing(_s) or missing(_e) then _result = .;
  else if _type_c = 'interval' and _out_c = 'months' then
    _result = intck('month', datepart(_s), datepart(_e));
  else if _type_c = 'interval' and _out_c = 'years' then
    _result = intck('year', datepart(_s), datepart(_e));
  else do;
    _out_hold = _out_unit;
    _out_unit = _out_c;
    %m_tti_unit_secs(unitvar=_out_unit);
    _out_secs = _secs;
    _out_unit = _out_hold;
    _result = (_e - _s) / _out_secs;
  end;

  if not missing(_result) and _add_one and _result >= 0 then do;
    _in_hold = _in_unit;
    _in_unit = _in_c;
    %m_tti_unit_secs(unitvar=_in_unit);
    _in_secs = _secs;
    _in_unit = _in_hold;
    _out_hold2 = _out_unit;
    _out_unit = _out_c;
    %m_tti_unit_secs(unitvar=_out_unit);
    _out_secs2 = _secs;
    _out_unit = _out_hold2;
    _result = _result + (_in_secs / _out_secs2);
  end;
  if _trunc_out and not missing(_result) then _result = int(_result);
%mend m_tti_duration;

/* compute_bmi. height cm, weight kg. height 0 -> missing. */
%macro m_tti_bmi;
  if missing(height) or missing(weight) or height = 0 then _result = .;
  else _result = weight / (height * height / 10000);
%mend m_tti_bmi;

/* compute_bsa. method is a character column. */
%macro m_tti_bsa;
  if missing(height) or missing(weight) then _result = .;
  else if method = 'Mosteller' then _result = sqrt(height * weight / 3600);
  else if method = 'DuBois-DuBois' then _result = 0.007184 * height**0.725 * weight**0.425;
  else if method = 'Haycock' then _result = 0.024265 * height**0.3964 * weight**0.5378;
  else if method = 'Gehan-George' then _result = 0.0235 * height**0.42246 * weight**0.51456;
  else if method = 'Boyd' then
    _result = 0.0003207 * (height**0.3) *
              ((1000 * weight)**(0.7285 - (0.0188 * log10(1000 * weight))));
  else if method = 'Fujimoto' then _result = 0.008883 * height**0.663 * weight**0.444;
  else if method = 'Takahira' then _result = 0.007241 * height**0.725 * weight**0.425;
  else _result = .;
%mend m_tti_bsa;

%macro m_tti_bsa_method_ok(method=);
  %global TTI_ERR;
  %let TTI_ERR = 1;
  %if %superq(method) = Mosteller or %superq(method) = Haycock
      or %superq(method) = Boyd or %superq(method) = Fujimoto
      or %superq(method) = Takahira
      or %superq(method) = %str(DuBois-DuBois)
      or %superq(method) = %str(Gehan-George) %then %let TTI_ERR = 0;
%mend m_tti_bsa_method_ok;

/* compute_map. _hr_present=0 selects the two-argument formula. */
%macro m_tti_map;
  if missing(diabp) or missing(sysbp) then _result = .;
  else if not _hr_present then _result = (2 * diabp + sysbp) / 3;
  else if missing(hr) then _result = .;
  else _result = diabp + 0.01 * exp(4.14 - 40.74 / hr) * (sysbp - diabp);
%mend m_tti_map;

/* compute_qtc. qt and rr in ms. */
%macro m_tti_qtc;
  if missing(qt) or missing(rr) or missing(method) then _result = .;
  else if method = 'Bazett' then _result = qt / sqrt(rr / 1000);
  else if method = 'Fridericia' then _result = qt / (rr / 1000)**(1/3);
  else if method = 'Sagie' then _result = 1000 * (qt / 1000 + 0.154 * (1 - rr / 1000));
  else _result = .;
%mend m_tti_qtc;

/* compute_rr from heart rate. */
%macro m_tti_rr;
  if missing(hr) or hr = 0 then _result = .;
  else _result = 60000 / hr;
%mend m_tti_rr;

/* derive_var_chg / derive_var_pchg */
%macro m_tti_chg;
  if missing(aval) or missing(base) then chg = .;
  else chg = aval - base;
%mend m_tti_chg;

%macro m_tti_pchg;
  if missing(aval) or missing(base) or base = 0 then pchg = .;
  else pchg = (aval - base) / abs(base) * 100;
%mend m_tti_pchg;

/* derive_var_analysis_ratio. numer/denom, missing when denom is 0. */
%macro m_tti_ratio;
  if missing(numer) or missing(denom) or denom = 0 then _result = .;
  else _result = numer / denom;
%mend m_tti_ratio;

/*
  derive_var_atoxgr combine step.
  Inputs ATOXDSCL ATOXDSCH ATOXGRL ATOXGRH. Writes ATOXGR.
*/
%macro m_tti_atoxgr;
  if missing(ATOXGRL) and missing(ATOXGRH) then ATOXGR = '';
  else if not missing(ATOXGRL) and ATOXGRL >= '1' then ATOXGR = cats('-', ATOXGRL);
  else if not missing(ATOXGRH) and ATOXGRH >= '1' then ATOXGR = ATOXGRH;
  else if (ATOXGRL = '0' or missing(ATOXDSCL)) and ATOXGRH = '0' then ATOXGR = '0';
  else if (ATOXGRH = '0' or missing(ATOXDSCH)) and ATOXGRL = '0' then ATOXGR = '0';
  else ATOXGR = '';
%mend m_tti_atoxgr;

/* R signif(). Writes _sig from _x using _dig. */
%macro m_tti_signif;
  if missing(_x) then _sig = .;
  else if _x = 0 then _sig = 0;
  else do;
    _p10 = floor(log10(abs(_x)));
    _fac = 10 ** (_dig - _p10 - 1);
    _sig = round(_x * _fac) / _fac;
  end;
%mend m_tti_signif;

/*
  derive_var_anrind.
  Columns AVAL ANRLO ANRHI and, when _use_a1 = 1, A1LO A1HI.
  _dig is significant digits. Writes ANRIND.
*/
%macro m_tti_anrind;
  _a1lo = .;
  _a1hi = .;
  _dig = signif_dig;
  _x = AVAL; %m_tti_signif; _av = _sig;
  _x = ANRLO; %m_tti_signif; _lo = _sig;
  _x = ANRHI; %m_tti_signif; _hi = _sig;
  if _use_a1 then do;
    _x = A1LO; %m_tti_signif; _a1lo = _sig;
    _x = A1HI; %m_tti_signif; _a1hi = _sig;
  end;
  /* Missing bounds stay missing. SAS treats . as smaller than every number. */
  if not missing(_av) and not missing(_lo) and missing(_hi) and _av >= _lo then ANRIND = 'NORMAL';
  else if not missing(_av) and not missing(_hi) and missing(_lo) and _av <= _hi then ANRIND = 'NORMAL';
  else if not missing(_av) and not missing(_lo) and not missing(_hi) and _av >= _lo and _av <= _hi then ANRIND = 'NORMAL';
  else if _use_a1 and not missing(_av) and not missing(_lo) and _av < _lo and (missing(A1LO) or _av >= _a1lo) then ANRIND = 'LOW';
  else if not _use_a1 and not missing(_av) and not missing(_lo) and _av < _lo then ANRIND = 'LOW';
  else if _use_a1 and not missing(_av) and not missing(_hi) and _av > _hi and (missing(A1HI) or _av <= _a1hi) then ANRIND = 'HIGH';
  else if not _use_a1 and not missing(_av) and not missing(_hi) and _av > _hi then ANRIND = 'HIGH';
  else if _use_a1 and not missing(_av) and not missing(_a1lo) and _av < _a1lo then ANRIND = 'LOW LOW';
  else if _use_a1 and not missing(_av) and not missing(_a1hi) and _av > _a1hi then ANRIND = 'HIGH HIGH';
  else ANRIND = '';
%mend m_tti_anrind;
