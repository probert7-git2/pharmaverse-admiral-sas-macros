/*--------------------------------------------------------------
  Program Name                : m_ex_single_pva.sas
  Purpose                     : Part B daily EX expansion (admiral ex_single)
  Origin                      : admiral data-raw/create_ex_single.R +
                                create_single_dose_dataset (QD path)
  Note                        : Lives only in SAS_mirrored_Admiral_safety_ADaM.
                                Do not edit safety_monitoring_system for Part B.
  Macro                       : %m_ex_single_pva
  Input                       : raw.ex (interval QD rows EXSTDTC-EXENDTC)
  Output default              : work.ex_single_pva (one row per dose day)
  Modification Log            : 23AUG2026 - Initial Part B QD expander.
                                Filter EXDOSE in (0, 54) for PVA/ex_single
                                parity (dose 81 titration excluded). Expand
                                calendar days start through end. Set daily
                                EXSTDTC=EXENDTC, EXDOSFRQ=ONCE. EXDOSE/EXDOSU
                                unchanged (QD dose level kept). ONCE single-day
                                rows pass through as one day. Keep EXROUTE for
                                ADAE LDOS_RTE (R ex_single drops EXROUTE -
                                Part B retains it).
                                23AUG2026 - Drop redundant LENGTH for
                                EXSTDTC/EXENDTC/EXDOSFRQ (already from SET).

  POLICY:
    Mirrors admiral::ex_single build for CDISC pilot (placebo 0 / active 54).
    Not a full create_single_dose_dataset port (no BID/TID lookup table).
--------------------------------------------------------------*/
%macro m_ex_single_pva(
  ex=raw.ex
, out=work.ex_single_pva
, dose_filter=%str(EXDOSE in (0, 54))
);

  %if %sysfunc(exist(&ex)) = 0 %then %do;
    %put ERROR: m_ex_single_pva requires &ex.;
    %return;
  %end;

  /* ---- Filter to PVA/ex_single dose levels - nonmissing interval ends ----
     admiral create_ex_single.R: filter(EXDOSE %in% c(0, 54)) then
     filter(!is.na(EXSTDTC), !is.na(EXENDTC)). */
  data work._ex_single_src;
    set &ex;
    length _stc $32 _enc $32;
    if &dose_filter;
    _stc = strip(EXSTDTC);
    _enc = strip(EXENDTC);
    if index(_stc, 'T') then _stc = scan(_stc, 1, 'T');
    if index(_enc, 'T') then _enc = scan(_enc, 1, 'T');
    if missing(_stc) or missing(_enc) then delete;
    if length(_stc) < 10 or length(_enc) < 10 then delete;
    _st = input(_stc, ?? yymmdd10.);
    _en = input(_enc, ?? yymmdd10.);
    if missing(_st) or missing(_en) then delete;
    if _en < _st then delete;
    drop _stc _enc;
  run;

  /* ---- Expand each interval row to one row per calendar day ----
     create_ex_single: seq(EXSTDTC, EXENDTC, by = "days"), then
     EXSTDTC = EXENDTC = that day, EXDOSFRQ = "ONCE".
     EXDOSE / EXDOSU stay as on the source interval (QD dose level unchanged).
     ONCE with start=end yields a single pass-through day. */
  data work._ex_single_exp;
    set work._ex_single_src;
    /* EXSTDTC/EXENDTC/EXDOSFRQ lengths already set by SET from EX - do not re-LENGTH. */
    format _day date9.;
    _exseq_src = EXSEQ;
    do _day = _st to _en;
      EXSTDTC = put(_day, yymmdd10.);
      EXENDTC = EXSTDTC;
      EXDOSFRQ = 'ONCE';
      output;
    end;
    drop _st _en _day;
  run;

  /* Renumber EXSEQ within subject by dose date (admiral arrange + row_number). */
  proc sort data=work._ex_single_exp;
    by STUDYID USUBJID EXSTDTC _exseq_src;
  run;

  data &out;
    set work._ex_single_exp;
    by STUDYID USUBJID;
    if first.USUBJID then EXSEQ = 0;
    EXSEQ + 1;
    drop _exseq_src;
  run;

  proc datasets lib=work nolist;
    delete _ex_single_src _ex_single_exp;
  quit;

  %m_nobs(ds=&out);
  %put NOTE: m_ex_single_pva complete -> &out (daily EX / EXDOSFRQ=ONCE);

%mend m_ex_single_pva;
