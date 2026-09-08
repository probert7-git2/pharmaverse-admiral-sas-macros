/*--------------------------------------------------------------
  Program Name                : m_adcm_pva.sas
  Purpose                     : Part B ADCM OCCDS concomitant meds (PVA-aligned)
  Origin                      : Adapted from Track A m_adcm2.sas
  Note                        : Lives only in SAS_mirrored_Admiral_safety_ADaM.
                                Do not edit safety_monitoring_system for Part B.
  Macro                       : %m_adcm_pva
  Input                       : raw.cm adam.adsl
  Output default              : adam.adcm (Part B adam lib)
  Modification Log            : 26AUG2026 - Drop TRTEMFL (AE OCCDS, SAS-only vs
                                PVA). Restore SDTM CM copies CMDOSE/CMDOSU and
                                other CM passthroughs already on raw.cm. Keep
                                derived AST/AEN datetime flags. No AVAL/BDS add.
                                24AUG2026 - AST/AEN via DTM highest_imputation=M
                                (admiral ad_adcm.R / PVA). Prior hi=n left
                                partial CMSTDTC as missing ASTDT while PVA
                                imputed - caused equal-n key orphans (~5454)
                                and Aspirin rows with PVA date / SAS missing.
                                Date-safe TRTSDT min_dates post-pass (same as
                                m_adae_pva - avoid %m_derive_vars_dt datepart
                                pitfall on SAS date TRTSDT).
                                Optional EOSDT cap on imputed AENDT (AENDTF D/M)
                                matches admiral max_dates=DTHDT,EOSDT - PVA gold
                                may still year-end without EOS (QC POLICY
                                PVA_ADCM_AENDT_NO_EOS_CAP) - do not change SAS.
                                24AUG2026 - Part B %m_adcm_pva from m_adcm2.
                                DOSE round 1e-8 - QC criterion. Sort
                                USUBJID ASTDT CMDECOD CMSEQ (QC OCCDS key).
                                OCCDS - no PARAMN (unlike BDS ADVS/ADEG/ADLB).
--------------------------------------------------------------*/
%macro m_adcm_pva(
  cm=raw.cm
, adsl=adam.adsl
, out=adam.adcm
, end_window=30
);

  %if %sysfunc(exist(&cm)) = 0 or %sysfunc(exist(&adsl)) = 0 %then %do;
    %put ERROR: m_adcm_pva requires &cm and &adsl.;
    %return;
  %end;

  %put NOTE: m_adcm_pva starting cm=&cm adsl=&adsl out=&out;

  /* ADSL first - TRTSDT needed for admiral min_dates on AST (and DTHDT/EOSDT for AEN) */
  %m_derive_vars_merged(
    dataset=&cm
  , dataset_add=&adsl
  , by_vars=STUDYID USUBJID
  , order=USUBJID
  , new_vars=SITEID=SITEID SUBJID=SUBJID
             TRTSDT=TRTSDT TRTEDT=TRTEDT DTHDT=DTHDT EOSDT=EOSDT
             TRT01A=TRT01A TRT01P=TRT01P
  , mode=first
  , out=work._adcm_pva_0
  );

  /* ---- Analysis start/end (admiral inst/templates/ad_adcm.R) ----
     PVA/admiral: derive_vars_dtm hi=M + min_dates=TRTSDT (AST),
     hi=M date_imputation=last max_dates=DTHDT/EOSDT (AEN), then dtm_to_dt.
     Track A / prior Part B used derive_vars_dt hi=n - incomplete CMSTDTC
     stayed missing and keyed as orphans vs gold. */
  %m_derive_vars_dtm(
    dataset=work._adcm_pva_0
  , new_vars_prefix=AST
  , dtc=CMSTDTC
  , highest_imputation=M
  , date_imputation=first
  , time_imputation=first
  , flag_imputation=auto
  , out=work._adcm_pva_1
  );

  %m_derive_vars_dtm(
    dataset=work._adcm_pva_1
  , new_vars_prefix=AEN
  , dtc=CMENDTC
  , highest_imputation=M
  , date_imputation=last
  , time_imputation=last
  , flag_imputation=auto
  , max_dates=DTHDT
  , out=work._adcm_pva_2
  );

  %m_derive_vars_dtm_to_dt(
    dataset=work._adcm_pva_2
  , source_vars=ASTDTM AENDTM
  , out=work._adcm_pva_3
  );

  data work._adcm_pva_3b;
    set work._adcm_pva_3;
    format ASTDT AENDT TRTSDT TRTEDT DTHDT EOSDT date9.
           ASTDTM AENDTM datetime20.;
    if missing(ASTDT) and not missing(ASTDTM) then ASTDT = datepart(ASTDTM);
    if missing(AENDT) and not missing(AENDTM) then AENDT = datepart(AENDTM);
    /* Date-only CMSTDTC/CMENDTC: keep *TMF=H like PVA when no T in DTC */
    if not missing(ASTDTM) and missing(ASTTMF)
       and index(strip(CMSTDTC), 'T') = 0 then ASTTMF = 'H';
    if not missing(AENDTM) and missing(AENTMF)
       and index(strip(CMENDTC), 'T') = 0 then AENTMF = 'H';
  run;

  /* ---- admiral min_dates = TRTSDT (date-safe, same logic as m_adae_pva) ----
     Bump imputed ASTDT up to TRTSDT only when TRTSDT falls inside the
     incomplete CMSTDTC range (month if known, else year). */
  data work._adcm_pva_3c;
    set work._adcm_pva_3b;
    length _cms_dtc $32;
    _cms_dtc = strip(CMSTDTC);
    if index(_cms_dtc, 'T') then _cms_dtc = scan(_cms_dtc, 1, 'T');
    _cms_y = .; _cms_m = .; _cms_has_m = 0;
    if length(_cms_dtc) >= 4 and notdigit(substr(_cms_dtc, 1, 4)) = 0 then
      _cms_y = input(substr(_cms_dtc, 1, 4), 4.);
    if length(_cms_dtc) >= 7 and substr(_cms_dtc, 5, 1) = '-'
       and substr(_cms_dtc, 6, 2) ne '--'
       and notdigit(substr(_cms_dtc, 6, 2)) = 0 then do;
      _cms_m = input(substr(_cms_dtc, 6, 2), 2.);
      _cms_has_m = 1;
    end;

    if not missing(ASTDT) and not missing(TRTSDT)
       and upcase(ASTDTF) in ('D', 'M') then do;
      _ts = ifn(TRTSDT > 100000, datepart(TRTSDT), TRTSDT);
      _lo = .;
      _hi = .;
      if _cms_has_m and not missing(_cms_y) then do;
        _lo = mdy(_cms_m, 1, _cms_y);
        _hi = intnx('month', _lo, 0, 'e');
      end;
      else if not missing(_cms_y) then do;
        _lo = mdy(1, 1, _cms_y);
        _hi = mdy(12, 31, _cms_y);
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

    /* Optional EOSDT cap on imputed AENDT when EOS is before last-of-range
       (admiral max_dates includes EOSDT - DTHDT already via max_dates=) */
    if not missing(AENDT) and not missing(EOSDT)
       and upcase(AENDTF) in ('D', 'M') then do;
      _es = ifn(EOSDT > 100000, datepart(EOSDT), EOSDT);
      if not missing(_es) and _es < AENDT then AENDT = _es;
      if not missing(AENDTM) and not missing(AENDT) then
        AENDTM = dhms(AENDT, 23, 59, 59);
    end;

    drop _cms_dtc _cms_y _cms_m _cms_has_m _ts _lo _hi _hh _mm _ss _es;
  run;

  data work._adcm_pva_4;
    set work._adcm_pva_3c;
    ADT = ASTDT;
    format ASTDT AENDT ADT TRTSDT TRTEDT date9.;
    CMSEQ = input(cats(CMSEQ), ?? best32.);
    /* Round after input - CMDOSE char->num can leave ~1e-17 residuals vs R */
    DOSE = input(cats(CMDOSE), ?? best32.);
    if not missing(DOSE) then DOSE = round(DOSE, 1e-8);
    length DOSEU $20;
    DOSEU = CMDOSU;
  run;

  %m_derive_vars_dy(
    dataset=work._adcm_pva_4
  , reference_date=TRTSDT
  , source_vars=ASTDT AENDT ADY=ADT
  , out=work._adcm_pva_5
  );

  /* TRTEMFL is an AE OCCDS flag (derive_var_trtemfl). ad_adcm.R uses
     ONTRTFL/PREFL/FUPFL instead. PVA has no TRTEMFL - do not derive it. */
  %put NOTE: m_adcm_pva - TRTEMFL omitted (AE OCCDS - not on PVA ADCM / ad_adcm.R).;

  data work._adcm_preord;
    set work._adcm_pva_5;
    length TRTA $100 TRTP $100;
    TRTA = TRT01A;
    TRTP = TRT01P;
    format ASTDT AENDT ADT TRTSDT TRTEDT date9.;
    keep STUDYID USUBJID SUBJID SITEID CMSEQ
         ASTDT ASTDTM ASTDTF ASTTMF ASTDY
         AENDT AENDTM AENDTF AENTMF AENDY
         ADT ADY
         CMTRT CMDECOD CMROUTE CMDOSFRQ CMDOSE CMDOSU DOSE DOSEU
         CMCLAS CMDTC CMENDTC CMENDY CMINDC CMSPID CMSTDTC CMSTDY
         DOMAIN VISIT VISITDY VISITNUM
         TRTSDT TRTEDT TRTA TRTP;
  run;

  /* Remaining ADSL vars after OCCDS KEEP - template negate_vars(adsl_vars). */
  %m_adm_merge_remaining_adsl(
    dataset=work._adcm_preord
  , adsl=&adsl
  , refds=ref_pva.refadcm
  , out=work._adcm_preord2
  );

  /* Column order = PVA REF (refadcm). SAS-only ADT ADY DOSE DOSEU
     sit next to related PVA columns. TRTEMFL not on PVA - omitted. */
  %m_order_vars_like_ref(
    data=work._adcm_preord2
  , out=&out
  , refds=ref_pva.refadcm
  , fallback=STUDYID USUBJID SUBJID SITEID TRTP TRTA TRTSDT TRTEDT CMSEQ
             CMDECOD CMTRT ASTDT AENDT ASTDY AENDY CMDOSFRQ CMROUTE
             CMDOSE CMDOSU
  , extra_after=ADT:AENDT ADY:AENDY DOSE:CMDOSFRQ DOSEU:CMDOSFRQ
  );

  /* SORTEDBY / QC ID = OCCDS business + CMSEQ (final). Publishes dictionary SORTEDBY. */
  proc sort data=&out;
    by USUBJID ASTDT CMDECOD CMSEQ;
  run;

  proc datasets lib=work nolist;
    delete _adcm_pva_0 _adcm_pva_1 _adcm_pva_2 _adcm_pva_3 _adcm_pva_3b
           _adcm_pva_3c _adcm_pva_4 _adcm_pva_5
           _adcm_preord _adcm_preord2;
  quit;

  %m_nobs(ds=&out);
  %put NOTE: m_adcm_pva complete -> &out;

%mend m_adcm_pva;
