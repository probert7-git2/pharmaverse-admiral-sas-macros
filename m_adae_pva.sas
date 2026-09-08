/*--------------------------------------------------------------
  Program Name                : m_adae_pva.sas
  Purpose                     : Part B ADAE builder (PVA / admiral-template aligned)
  Origin                      : Adapted from Track A m_adae2.sas
  Note                        : Lives only in SAS_mirrored_Admiral_safety_ADaM.
                                Do not edit safety_monitoring_system for Part B.
  Macro                       : %m_adae_pva
  Input                       : raw.ae raw.ex adam.adsl (optional raw.suppae)
  Output default              : adam.adae (Part B adam lib)
  Modification Log            : 26AUG2026 - PVA-only SDTM AE passthroughs on KEEP
                                plus ASEVN/AOCCIFL from ad_adae.R. TRTEMFL stays.
                                AETRTEM is SUPPAE SAS-only - not on PVA.
                                23AUG2026 - ADURU = 'days' (lowercase) to
                                match pharmaverseadam / PVA gold (was 'DAYS').
                                23AUG2026 - Removed EOSDT AENDT post-cap
                                again (user: do not restore). Keep DTHDT via
                                max_dates= on AEN DTM only.
                                23AUG2026 - Last dose via %m_ex_single_pva
                                (admiral ex_single / PVA): EXDOSE in (0, 54),
                                daily EXSTDTC=EXENDTC ONCE rows, then join.
                                DOSEON/DOSEU blank unless LDOSEDT=ASTDT
                                (same-day - PVA second join). Root of residual
                                value_diffs~1148 after *DTM QC norm was
                                period-EX LDOSE (only ~42/1126 match).
                                23AUG2026 - Final OCCDS sort
                                USUBJID ASTDT AEDECOD ASEV AESEQ (QC CALLER key -
                                PVA package has no SORTEDBY / unstable row order).
                                Do not LENGTH-redeclare *TMF after SET - blank
                                ASTTMF vs PVA H on all 1191 date-only onsets.
                                TMF safety after DTM for date-only --DTC.
                                22AUG2026 - Part B %m_adae_pva from m_adae2.
                                Align AST/AEN to admiral ad_adae.R / PVA:
                                DTM highest_imputation=M (not Track A hi=D +
                                TE-relative clear). Date-safe min_dates=TRTSDT
                                post-pass (port datepart(TRTSDT) is unsafe on
                                SAS dates). Last EX on/before AE onset via DTM:
                                order=EXSTDTM EXSEQ (asc) + mode=last.
                                TRTEMFL = %m_derive_var_trtemfl only (no YM
                                post-pass). derive_aesi=N default (SMQ/CQ
                                SAS-only vs PVA).

  POLICY (intentional vs Track A):
    Track A %m_adae2 keeps hi=D + subject-relative TE onset (clear out-of-window
    partials) for FDA safety reporting. Part B mirrors pharmaverseadam /
    admiral template (hi=M first/last + min_dates) so ASTDT keys pair with PVA.
    Residual DATE_IMPUTE / var-width gaps vs PVA stay documented POLICY/mask.
--------------------------------------------------------------*/
%macro m_adae_pva(
  ae=raw.ae
, ex=raw.ex
, adsl=adam.adsl
, suppae=
, out=adam.adae
, end_window=30
, te_filter=%str(EXDOSE > 0 or (EXDOSE = 0 and index(upcase(EXTRT),'PLACEBO') > 0))
, derive_aesi=N
, aesi_queries_csv=
);

  %if %sysfunc(exist(&ae)) = 0 or %sysfunc(exist(&adsl)) = 0 %then %do;
    %put ERROR: m_adae_pva requires &ae and &adsl.;
    %return;
  %end;
  %if %sysfunc(exist(&ex)) = 0 %then %do;
    %put ERROR: m_adae_pva requires &ex.;
    %return;
  %end;

  /* ---- ADSL vars onto AE ---- */
  %m_derive_vars_merged(
    dataset=&ae
  , dataset_add=&adsl
  , by_vars=STUDYID USUBJID
  , order=USUBJID
  , new_vars=SITEID=SITEID SUBJID=SUBJID
             TRTSDT=TRTSDT TRTEDT=TRTEDT
             DTHDT=DTHDT EOSDT=EOSDT TRT01A=TRT01A TRT01P=TRT01P
  , filter_add=%str(1)
  , mode=first
  , out=work._adae_pva_0
  );

  /* ---- Analysis start/end datetimes (admiral ad_adae.R / PVA) ----
     highest_imputation=M: impute missing day or month (first / last).
     min_dates=TRTSDT applied in a date-safe post-pass below - do not rely on
     %m_derive_vars_dt min_dates= with a SAS *date* TRTSDT (datepart pitfall).
     Track A hi=D + TE-clear is intentional there - not used for Part B. */
  %m_derive_vars_dtm(
    dataset=work._adae_pva_0
  , new_vars_prefix=AST
  , dtc=AESTDTC
  , highest_imputation=M
  , date_imputation=first
  , time_imputation=first
  , flag_imputation=auto
  , out=work._adae_pva_1
  );

  %m_derive_vars_dtm(
    dataset=work._adae_pva_1
  , new_vars_prefix=AEN
  , dtc=AEENDTC
  , highest_imputation=M
  , date_imputation=last
  , time_imputation=last
  , flag_imputation=auto
  , max_dates=DTHDT
  , out=work._adae_pva_2
  );

  %m_derive_vars_dtm_to_dt(
    dataset=work._adae_pva_2
  , source_vars=ASTDTM AENDTM
  , out=work._adae_pva_3
  );

  data work._adae_pva_3b;
    set work._adae_pva_3;
    format ASTDT AENDT TRTSDT TRTEDT DTHDT EOSDT date9.
           ASTDTM AENDTM datetime20.;
    if missing(ASTDT) and not missing(ASTDTM) then ASTDT = datepart(ASTDTM);
    if missing(AENDT) and not missing(AENDTM) then AENDT = datepart(AENDTM);
    AESEQ = input(cats(AESEQ), ?? best32.);
    /* Date-only --DTC (pharmaversesdtm AE has no T): DTM time_imputation
       must leave *TMF=H. Re-assert if flags wiped - PVA ASTTMF=H on all
       1191 rows and AENTMF=H when AENDTM present. */
    if not missing(ASTDTM) and missing(ASTTMF)
       and index(strip(AESTDTC), 'T') = 0 then ASTTMF = 'H';
    if not missing(AENDTM) and missing(AENTMF)
       and index(strip(AEENDTC), 'T') = 0 then AENTMF = 'H';
  run;

  /* ---- admiral min_dates = TRTSDT (date-safe) ----
     Bump imputed ASTDT up to TRTSDT only when TRTSDT falls inside the
     incomplete AESTDTC range (month if known, else year). Pre-Tx first-of-
     month onsets (e.g. 2012-02 vs TRTSDT 2013-08) stay first-of-month -
     matching pharmaverseadam::adae, not Track A TE-clear. */
  data work._adae_pva_3c;
    set work._adae_pva_3b;
    length _aes_dtc $32;
    _aes_dtc = strip(AESTDTC);
    if index(_aes_dtc, 'T') then _aes_dtc = scan(_aes_dtc, 1, 'T');
    _aes_y = .; _aes_m = .; _aes_has_m = 0;
    if length(_aes_dtc) >= 4 and notdigit(substr(_aes_dtc, 1, 4)) = 0 then
      _aes_y = input(substr(_aes_dtc, 1, 4), 4.);
    if length(_aes_dtc) >= 7 and substr(_aes_dtc, 5, 1) = '-'
       and substr(_aes_dtc, 6, 2) ne '--'
       and notdigit(substr(_aes_dtc, 6, 2)) = 0 then do;
      _aes_m = input(substr(_aes_dtc, 6, 2), 2.);
      _aes_has_m = 1;
    end;

    if not missing(ASTDT) and not missing(TRTSDT)
       and upcase(ASTDTF) in ('D', 'M') then do;
      _ts = ifn(TRTSDT > 100000, datepart(TRTSDT), TRTSDT);
      _lo = .;
      _hi = .;
      if _aes_has_m and not missing(_aes_y) then do;
        _lo = mdy(_aes_m, 1, _aes_y);
        _hi = intnx('month', _lo, 0, 'e');
      end;
      else if not missing(_aes_y) then do;
        _lo = mdy(1, 1, _aes_y);
        _hi = mdy(12, 31, _aes_y);
      end;
      if not missing(_ts) and not missing(_lo) and not missing(_hi)
         and _ts > ASTDT and _ts <= _hi then do;
        ASTDT = _ts;
        if not missing(ASTDTM) then do;
          _hh = hour(ASTDTM); _mm = minute(ASTDTM); _ss = second(ASTDTM);
        end;
        else do;
          _hh = 0; _mm = 0; _ss = 0;
        end;
        ASTDTM = dhms(ASTDT, _hh, _mm, _ss);
      end;
    end;

    /* No EOSDT post-cap on AENDT - user removed; DTHDT only via max_dates=
       on %m_derive_vars_dtm (AEN). Do not restore EOS AEN bound. */

    drop _aes_dtc _aes_y _aes_m _aes_has_m _ts _lo _hi _hh _mm _ss;
  run;

  %m_derive_vars_dy(
    dataset=work._adae_pva_3c
  , reference_date=TRTSDT
  , source_vars=ASTDT AENDT
  , out=work._adae_pva_4
  );

  %m_derive_vars_duration(
    dataset=work._adae_pva_4
  , new_var=ADURN
  , start_date=ASTDT
  , end_date=AENDT
  , add_one=Y
  , out=work._adae_pva_5
  );

  /* ---- Daily EX (admiral::ex_single) then DTM for last-dose join ----
     Gold LDOSEDTM matches admiral::ex_single (1126/1126), not period EX
     (~42/1126). %m_ex_single_pva: EXDOSE in (0, 54), one day per dose,
     EXDOSFRQ=ONCE, EXDOSE/EXDOSU unchanged. Dose 81 titration excluded. */
  %m_ex_single_pva(
    ex=&ex
  , out=work.ex_single_pva
  );

  %m_derive_vars_dtm(
    dataset=work.ex_single_pva
  , new_vars_prefix=EXST
  , dtc=EXSTDTC
  , highest_imputation=n
  , time_imputation=first
  , flag_imputation=none
  , out=work._ex_pva_st
  );

  data work._ex_pva;
    set work._ex_pva_st;
    if &te_filter and not missing(EXSTDTM);
    format EXSTDT date9.;
    if not missing(EXSTDTM) then EXSTDT = datepart(EXSTDTM);
    else EXSTDT = .;
  run;

  /* Last daily dose on/before AE onset (admiral derive_vars_joined):
     EXSTDTM <= ASTDTM, ascending EXSTDTM EXSEQ + mode=last.
     DOSEON/DOSEU are same-day only - blank when LDOSEDT ne ASTDT (PVA
     second join: dose covering onset - daily start=end). */
  %m_derive_vars_joined(
    dataset=work._adae_pva_5
  , dataset_add=work._ex_pva
  , by_vars=STUDYID USUBJID
  , order=EXSTDTM EXSEQ
  , new_vars=LDOSEDTM=EXSTDTM LDOSEDT=EXSTDT DOSEON=EXDOSE DOSEU=EXDOSU
             LDOS_RTE=EXROUTE EXROUTE=EXROUTE EXTRT=EXTRT
  , join_type=all
  , filter_add=%str(not missing(EXSTDTM))
  , filter_join=%str(b.EXSTDTM <= a.ASTDTM)
  , mode=last
  , out=work._adae_pva_6a
  );

  data work._adae_pva_6;
    set work._adae_pva_6a;
    /* PVA DOSEON/DOSEU: EXDOSE on ASTDT only - not prior-day last dose amt */
    if missing(LDOSEDT) or missing(ASTDT) or LDOSEDT ne ASTDT then do;
      DOSEON = .;
      DOSEU = '';
    end;
  run;

  /* ---- TRTEMFL (admiral derive_var_trtemfl - no Track A YM post-pass) ---- */
  %m_derive_var_trtemfl(
    dataset=work._adae_pva_6
  , new_var=TRTEMFL
  , start_date=ASTDT
  , end_date=AENDT
  , trt_start_date=TRTSDT
  , trt_end_date=TRTEDT
  , end_window=&end_window
  , out=work._adae_pva_7
  );

  /* ---- SUPPAE AETRTEM (source TE flag) for QC / comparison ---- */
  %if %length(&suppae) and %sysfunc(exist(&suppae)) %then %do;
    %m_supp_merge_by_idvar(
      dataset=work._adae_pva_7
    , dataset_supp=&suppae
    , qnam=AETRTEM
    , new_var=AETRTEM
    , by_vars=STUDYID USUBJID
    , out=work._adae_pva_8
    );
  %end;
  %else %do;
    data work._adae_pva_8;
      set work._adae_pva_7;
      length AETRTEM $1;
      AETRTEM = '';
    run;
  %end;

  /* ---- Optional AESI (SAS-only vs PVA - default off) ---- */
  %if %upcase(&derive_aesi) = Y %then %do;
    %m_load_query_data(
      queries_csv=&aesi_queries_csv
    , out=work.aesi_queries_pva
    );
    %if %sysfunc(exist(work.aesi_queries_pva)) = 0 %then %do;
      %put ERROR: m_adae_pva - AESI queries dataset not loaded. Check aesi_queries_csv.;
      %return;
    %end;
    %m_derive_vars_query(
      dataset=work._adae_pva_8
    , dataset_queries=work.aesi_queries_pva
    , out=work._adae_pva_9
    , aesi_flag_var=AESIFL
    );
  %end;
  %else %do;
    data work._adae_pva_9;
      set work._adae_pva_8;
      length AESIFL $1 SMQ01NAM SMQ02NAM CQ01NAM CQ02NAM $200
             SMQ01SC SMQ02SC $20;
      length SMQ01CD SMQ02CD SMQ01SCN SMQ02SCN 8;
      call missing(AESIFL, SMQ01NAM, SMQ02NAM, CQ01NAM, CQ02NAM,
                   SMQ01CD, SMQ02CD, SMQ01SC, SMQ02SC, SMQ01SCN, SMQ02SCN);
    run;
  %end;

  data work._adae_pva_10;
    set work._adae_pva_9;
    /* ASTDTF/ASTTMF/AENDTF/AENTMF come from %m_derive_vars_dtm - do not
       LENGTH-redeclare them after SET (can leave blank vs PVA H). */
    length ASEV $20 AREL $50 TRTA $100 TRTP $100 ADURU $10 ASEVN 8;
    ASEV = AESEV;
    AREL = AEREL;
    TRTA = TRT01A;
    TRTP = TRT01P;
    if not missing(ADURN) then ADURU = 'days';
    /* ad_adae.R factor(ASEV, MILD MODERATE SEVERE DEATH THREATENING) */
    if upcase(strip(ASEV)) = 'MILD' then ASEVN = 1;
    else if upcase(strip(ASEV)) = 'MODERATE' then ASEVN = 2;
    else if upcase(strip(ASEV)) = 'SEVERE' then ASEVN = 3;
    else if upcase(strip(ASEV)) = 'DEATH THREATENING' then ASEVN = 4;
    else ASEVN = .;
    format ASTDT AENDT LDOSEDT TRTSDT TRTEDT date9.
           ASTDTM AENDTM LDOSEDTM datetime20.;
    label AESEV    = 'Severity/Intensity'
          AEREL    = 'Causality'
          ASEV     = 'Severity/Intensity'
          AREL     = 'Causality'
          ASEVN    = 'Analysis Severity (N)'
          LDOS_RTE = 'Last Dose Route Prior to AE'
          EXROUTE  = 'Route of Administration'
          EXTRT    = 'Name of Actual Treatment'
          DOSEON   = 'Dose at Event Onset'
          LDOSEDT  = 'Date of Last Dose Prior to Event'
          ADURN    = 'AE Duration (N)'
          ADURU    = 'AE Duration Units';
  run;

  /* ad_adae.R restrict_derivation(derive_var_extreme_flag) AOCCIFL
     first most-severe treatment-emergent AE per USUBJID. */
  %m_adm_restrict_extreme_flag(
    dataset=work._adae_pva_10
  , by_vars=USUBJID
  , order=DESC:ASEVN ASTDTM AESEQ
  , new_var=AOCCIFL
  , mode=first
  , filter=%str(upcase(strip(TRTEMFL))='Y')
  , out=work._adae_preord
  );

  data work._adae_preordk;
    set work._adae_preord;
    keep STUDYID USUBJID SUBJID SITEID AESEQ DOMAIN
         ASTDT ASTDTM ASTDTF ASTTMF ASTDY
         AENDT AENDTM AENDTF AENTMF AENDY
         ADURN ADURU
         AETERM AEDECOD AESOC
         AESTDTC AEENDTC AEDTC AESEV AEREL AESER
         AEACN AEBDSYCD AEBODSYS AEENDY AEHLGT AEHLGTCD AEHLT AEHLTCD
         AELLT AELLTCD AEOUT AEPTCD AESCAN AESCONG AESDISAB AESDTH
         AESHOSP AESLIFE AESOCCD AESOD AESPID AESTDY
         ASEV AREL ASEVN AOCCIFL
         TRTSDT TRTEDT TRTEMFL AETRTEM TRTA TRTP
         LDOSEDT LDOSEDTM DOSEON DOSEU LDOS_RTE EXROUTE EXTRT
         DTHDT EOSDT;
  run;

  /* Remaining ADSL vars after OCCDS KEEP - template negate_vars(adsl_vars). */
  %m_adm_merge_remaining_adsl(
    dataset=work._adae_preordk
  , adsl=&adsl
  , refds=ref_pva.refadae
  , out=work._adae_preord2
  );

  /* Column order = PVA REF (refadae). SAS-only AETRTEM LDOSEDT route vars
     sit next to related PVA columns. */
  %m_order_vars_like_ref(
    data=work._adae_preord2
  , out=&out
  , refds=ref_pva.refadae
  , fallback=STUDYID USUBJID SUBJID SITEID TRTSDT TRTEDT EOSDT DTHDT AESEQ
             AETERM AEDECOD AESOC AESTDTC ASTDT ASTDTM ASTDTF ASTTMF
             AEENDTC AENDT AENDTM AENDTF AENTMF ASTDY AENDY ADURN ADURU
             TRTEMFL AESER AESEV ASEV ASEVN AOCCIFL AEREL AREL LDOSEDTM DOSEON DOSEU
  , extra_after=TRTA:TRTEDT TRTP:TRTEDT AETRTEM:TRTEMFL LDOSEDT:LDOSEDTM
                LDOS_RTE:DOSEU EXROUTE:DOSEU EXTRT:DOSEU
  );

  /* OCCDS sort = QC match key (SORTEDBY). PVA package data has no SORTEDBY
     and is not stably ordered - SAS uses this OCCDS key for both build and QC. */
  proc sort data=&out;
    by USUBJID ASTDT AEDECOD ASEV AESEQ;
  run;

  proc datasets lib=work nolist;
    delete _adae_pva_0 _adae_pva_1 _adae_pva_2 _adae_pva_3 _adae_pva_3b
           _adae_pva_3c _adae_pva_4 _adae_pva_5 _adae_pva_6 _adae_pva_6a
           _adae_pva_7 _adae_pva_8 _adae_pva_9 _adae_pva_10
           _adae_preord _adae_preordk _adae_preord2
           ex_single_pva _ex_pva_st _ex_pva aesi_queries_pva;
  quit;

  %m_nobs(ds=&out);
  %put NOTE: m_adae_pva complete -> &out;

%mend m_adae_pva;
