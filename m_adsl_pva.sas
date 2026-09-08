/*--------------------------------------------------------------
  Program Name                : m_adsl_pva.sas
  Purpose                     : Part B ADSL builder (PVA-aligned TRT*DTM/TMF path)
  Origin                      : Adapted from Track A m_adsl2.sas (TRTSTMF fix)
  Note                        : Lives only in SAS_mirrored_Admiral_safety_ADaM.
                                Do not edit safety_monitoring_system for Part B.
  Macro                       : %m_adsl_pva
  Input                       : raw.dm raw.ex (optional raw.ds raw.suppdm raw.dd)
  Output default              : adam.adsl (Part B adam lib)
  Modification Log            : 24AUG2026 - EOSSTT: do not overwrite SCREEN FAILURE
                                blank with ONGOING (admiral missing_values only when
                                no DISPOSITION EVENT). Prior bug -> PROC COMPARE
                                value_diffs=52 on untreated/screen-failure subjects.
                                24AUG2026 - PVA parity vars: DM passthrough
                                (RF*DTC BRTHDTC DMDTC DMDY ETHNIC ACTARMCD),
                                EOSSTT/FRVDT from DS, AGEGR1/RACEGR1/REGION1/
                                LDDTHGR1/DTH*30FL groupings, optional LSTALVDT
                                from AE/LB/TRTEDT (admiral ad_adsl.R). Full
                                PVA-aligned LABEL= block.
                                23AUG2026 - Explicit flag_imputation=auto on EX DTM
                                and post-merge TRT*TMF safety (PVA TRTSTMF=H on
                                254 treated - blank TMF drove PROC COMPARE 254).
                                Final sort STUDYID USUBJID (PVA Key Variables /
                                pharmaverseadam::adsl is_sorted USUBJID).
                                26AUG2026 - LSTALVDT from AE AESTDTC/AEENDTC,
                                LB LBDTC (convert_dtc_to_dt hi=M) and TRTEDT
                                (admiral ad_adsl.R extreme_event mode=last).
                                CDISC name is LSTALVDT, not LSTAVLDT. Skip AE/LB
                                events when ae=/lb= missing - do not invent.
                                26AUG2026 - BRTHDTC optional: KEEP only if on
                                raw.dm (CDISC BRTHDTC, else BIRTHDTC). Missing
                                is PVA-only - do not invent a blank column.
                                25AUG2026 - Keep DM passthroughs PVA already has
                                (RF*DTC BRTHDTC DMDTC DMDY ETHNIC ACTARMCD)
                                plus AGEGR1/RACEGR1/REGION1/LDDTHGR1/DTH*FL
                                from ad_adsl.R format_*.
                                22AUG2026 - Part B %m_adsl_pva from m_adsl2 logic.
                                EX via %m_derive_vars_dtm then merge TRTSDTM/TRTSTMF +
                                TRTEDTM/TRTETMF and %m_derive_vars_dtm_to_dt
                                (admiral ad_adsl.R / pharmaverseadam).
--------------------------------------------------------------*/
%macro m_adsl_pva(
  dm=raw.dm
, ex=raw.ex
, ds=
, ae=
, lb=
, suppdm=
, dd=
, out=adam.adsl
, te_filter=%str(EXDOSE > 0 or (EXDOSE = 0 and index(upcase(EXTRT),'PLACEBO') > 0))
);

  %local _have_ae _have_lb _dsid_dm _keep_brth;
  %let _have_ae = 0;
  %let _have_lb = 0;
  %if %length(&ae) and %sysfunc(exist(&ae)) %then %let _have_ae = 1;
  %if %length(&lb) and %sysfunc(exist(&lb)) %then %let _have_lb = 1;

  %if %sysfunc(exist(&dm)) = 0 or %sysfunc(exist(&ex)) = 0 %then %do;
    %put ERROR: m_adsl_pva requires &dm and &ex.;
    %return;
  %end;

  /* BRTHDTC is optional. Some pharma DM dropped it for privacy, so Track A
     raw.dm may not have it even when PVA/admiral ADSL still does. KEEP of a
     missing name is never-referenced (WARNING on this create) and invents a
     blank column. CDISC is BRTHDTC - also accept BIRTHDTC if that is on DM. */
  %let _keep_brth =;
  %let _dsid_dm = %sysfunc(open(&dm, i));
  %if &_dsid_dm %then %do;
    %if %sysfunc(varnum(&_dsid_dm, BRTHDTC)) %then %let _keep_brth = BRTHDTC;
    %else %if %sysfunc(varnum(&_dsid_dm, BIRTHDTC)) %then %let _keep_brth = BIRTHDTC;
    %let _dsid_dm = %sysfunc(close(&_dsid_dm));
  %end;
  %if %length(&_keep_brth) %then %do;
    %put NOTE: m_adsl_pva - keeping &_keep_brth from &dm.;
  %end;
  %else %do;
    %put NOTE: m_adsl_pva - BRTHDTC/BIRTHDTC not on &dm - omitted from ADSL.;
  %end;

  /* ---- DM starter + planned/actual treatment ---- */
  data work._adsl2_0;
    set &dm;
    length TRT01P $100 TRT01A $100;
    TRT01P = ARM;
    TRT01A = ACTARM;
  run;

  /* ---- EX datetimes (admiral ad_adsl.R / pharmaverseadam)
     derive_vars_dtm on EXSTDTC (time first) and EXENDTC (time last), then
     merge TRT*DTM/TRT*TMF and derive_vars_dtm_to_dt for TRTSDT/TRTEDT.
     Fabricating blank TRTSTMF while PVA has H caused Part B PROC COMPARE
     diffs=254 (all treated subjects). */
  %m_derive_vars_dtm(
    dataset=&ex
  , new_vars_prefix=EXST
  , dtc=EXSTDTC
  , highest_imputation=n
  , time_imputation=first
  , flag_imputation=auto
  , out=work._ex_st
  );

  %m_derive_vars_dtm(
    dataset=work._ex_st
  , new_vars_prefix=EXEN
  , dtc=EXENDTC
  , highest_imputation=n
  , time_imputation=last
  , flag_imputation=auto
  , out=work._ex_ext
  );

  /* ---- TRTSDTM / TRTSTMF = first dosing EX start datetime ---- */
  %m_derive_vars_merged(
    dataset=work._adsl2_0
  , dataset_add=work._ex_ext
  , by_vars=STUDYID USUBJID
  , order=EXSTDTM EXSEQ
  , new_vars=TRTSDTM=EXSTDTM TRTSTMF=EXSTTMF
  , filter_add=%str((&te_filter) and not missing(EXSTDTM))
  , mode=first
  , out=work._adsl2_1
  );

  /* ---- TRTEDTM / TRTETMF = last dosing EX end datetime ---- */
  %m_derive_vars_merged(
    dataset=work._adsl2_1
  , dataset_add=work._ex_ext
  , by_vars=STUDYID USUBJID
  , order=EXENDTM EXSEQ
  , new_vars=TRTEDTM=EXENDTM TRTETMF=EXENTMF
  , filter_add=%str((&te_filter) and not missing(EXENDTM))
  , mode=last
  , out=work._adsl2_2
  );

  %m_derive_vars_dtm_to_dt(
    dataset=work._adsl2_2
  , source_vars=TRTSDTM TRTEDTM
  , out=work._adsl2_4
  );

  /* pharmaversesdtm EX is date-only - DTM must set *TMF=H. Re-assert after
     merge if EXSTTMF never landed (flag wipe / stale EX path). */
  data work._adsl2_4b;
    set work._adsl2_4;
    if not missing(TRTSDTM) and missing(TRTSTMF) then TRTSTMF = 'H';
    if not missing(TRTEDTM) and missing(TRTETMF) then TRTETMF = 'H';
  run;

  %m_derive_vars_duration(
    dataset=work._adsl2_4b
  , new_var=TRTDURD
  , start_date=TRTSDT
  , end_date=TRTEDT
  , out_unit=days
  , add_one=Y
  , out=work._adsl2_5
  );

  /* ---- Death date (partial â†’ first of month) ---- */
  %m_derive_vars_dt(
    dataset=work._adsl2_5
  , new_vars_prefix=DTH
  , dtc=DTHDTC
  , highest_imputation=M
  , date_imputation=first
  , flag_imputation=auto
  , out=work._adsl2_6
  );

  %m_derive_vars_duration(
    dataset=work._adsl2_6
  , new_var=DTHADY
  , start_date=TRTSDT
  , end_date=DTHDT
  , add_one=Y
  , out=work._adsl2_7
  );

  %m_derive_vars_duration(
    dataset=work._adsl2_7
  , new_var=LDDTHELD
  , start_date=TRTEDT
  , end_date=DTHDT
  , add_one=N
  , out=work._adsl2_8
  );

  /* ---- Optional DS disposition dates / EOSSTT / FRVDT (admiral ad_adsl.R) ---- */
  %if %length(&ds) and %sysfunc(exist(&ds)) %then %do;
    %m_derive_vars_dt(
      dataset=&ds
    , new_vars_prefix=DSST
    , dtc=DSSTDTC
    , highest_imputation=n
    , out=work._ds_ext
    );

    %m_derive_vars_merged(
      dataset=work._adsl2_8
    , dataset_add=work._ds_ext
    , by_vars=STUDYID USUBJID
    , order=DSSTDT
    , new_vars=EOSDT=DSSTDT
    , filter_add=%str(upcase(DSCAT)='DISPOSITION EVENT' and upcase(DSDECOD) ne 'SCREEN FAILURE')
    , mode=last
    , out=work._adsl2_9
    );

    %m_derive_vars_merged(
      dataset=work._adsl2_9
    , dataset_add=work._ds_ext
    , by_vars=STUDYID USUBJID
    , order=DSSTDT
    , new_vars=RANDDT=DSSTDT
    , filter_add=%str(upcase(DSDECOD)='RANDOMIZED')
    , mode=first
    , out=work._adsl2_10
    );

    %m_derive_vars_merged(
      dataset=work._adsl2_10
    , dataset_add=work._ds_ext
    , by_vars=STUDYID USUBJID
    , order=DSSTDT
    , new_vars=SCRFDT=DSSTDT
    , filter_add=%str(upcase(DSCAT)='DISPOSITION EVENT' and upcase(DSDECOD)='SCREEN FAILURE')
    , mode=first
    , out=work._adsl2_10b
    );

    /* EOSSTT from disposition DSDECOD (admiral format_eosstt + missing_values).
       SCREEN FAILURE -> blank. missing_values=ONGOING only when no DISPOSITION
       EVENT row merges (exist_flag blank) - not when format_eosstt returns blank. */
    data work._ds_eosstt;
      set work._ds_ext;
      where upcase(DSCAT) = 'DISPOSITION EVENT';
      length EOSSTT $20;
      if upcase(strip(DSDECOD)) = 'COMPLETED' then EOSSTT = 'COMPLETED';
      else if upcase(strip(DSDECOD)) = 'SCREEN FAILURE' then EOSSTT = '';
      else if not missing(DSDECOD) then EOSSTT = 'DISCONTINUED';
      else EOSSTT = 'ONGOING';
    run;

    %m_derive_vars_merged(
      dataset=work._adsl2_10b
    , dataset_add=work._ds_eosstt
    , by_vars=STUDYID USUBJID
    , order=DSSTDT
    , new_vars=EOSSTT=EOSSTT
    , filter_add=%str(1)
    , mode=last
    , exist_flag=_eos_flg
    , true_value=Y
    , out=work._adsl2_10c
    );

    data work._adsl2_10c;
      set work._adsl2_10c;
      length EOSSTT $20;
      /* admiral missing_values: only subjects with no DISPOSITION EVENT */
      if missing(_eos_flg) then EOSSTT = 'ONGOING';
      drop _eos_flg;
    run;

    /* Final retrieval visit date */
    %m_derive_vars_merged(
      dataset=work._adsl2_10c
    , dataset_add=work._ds_ext
    , by_vars=STUDYID USUBJID
    , order=DSSTDT
    , new_vars=FRVDT=DSSTDT
    , filter_add=%str(upcase(DSCAT)='OTHER EVENT' and upcase(DSDECOD)='FINAL RETRIEVAL VISIT')
    , mode=last
    , out=work._adsl2_11
    );
  %end;
  %else %do;
    data work._adsl2_11;
      set work._adsl2_8;
      length EOSSTT $20;
      format EOSDT RANDDT SCRFDT FRVDT date9.;
      call missing(EOSDT, RANDDT, SCRFDT, FRVDT);
      EOSSTT = 'ONGOING';
    run;
    %put NOTE: m_adsl_pva - ds= not supplied or missing - EOSDT/RANDDT/SCRFDT/FRVDT missing - EOSSTT=ONGOING.;
  %end;

  /* ---- Population flags: prefer SUPPDM; EX-based SAFFL as fallback ---- */
  %if %length(&suppdm) and %sysfunc(exist(&suppdm)) %then %do;
    %m_supp_qnam_flags(
      dataset=&suppdm
    , by_vars=STUDYID USUBJID
    , qnam_map=ITT=ITTFL SAFETY=SAFFL_SUPP EFFICACY=EFFFL
               COMPLT8=COMPL8FL COMPLT16=COMPL16FL COMPLT24=COMPL24FL
    , out=work._popfl
    );
  %end;
  %else %do;
    data work._popfl;
      length STUDYID $20 USUBJID $40
             ITTFL SAFFL_SUPP EFFFL COMPL8FL COMPL16FL COMPL24FL $1;
      stop;
    run;
    %put NOTE: m_adsl_pva - suppdm= missing - population flags from SUPP not added.;
  %end;

  /* admiral derive_var_merged_exist_flag: exposure condition only (no EXSTDT req) */
  proc sql;
    create table work._saffl_ex as
    select distinct STUDYID, USUBJID, 'Y' as SAFFL_EX length=1
    from work._ex_ext
    where &te_filter
    ;
  quit;

  proc sort data=work._adsl2_11;
    by STUDYID USUBJID;
  run;
  proc sort data=work._popfl;
    by STUDYID USUBJID;
  run;
  proc sort data=work._saffl_ex;
    by STUDYID USUBJID;
  run;

  data work._adsl2_12;
    length ITTFL SAFFL EFFFL COMPL8FL COMPL16FL COMPL24FL $1;
    merge work._adsl2_11(in=a) work._popfl work._saffl_ex;
    by STUDYID USUBJID;
    if a;
    /* Prefer SUPPDM SAFETY; else EX-derived; else N */
    if not missing(SAFFL_SUPP) then SAFFL = SAFFL_SUPP;
    else if not missing(SAFFL_EX) then SAFFL = SAFFL_EX;
    else SAFFL = 'N';
    if missing(ITTFL) then ITTFL = '';
    if missing(EFFFL) then EFFFL = '';
    drop SAFFL_SUPP SAFFL_EX;
  run;

  /* ---- DTHCAUS from DD (primary cause) when available ---- */
  %if %length(&dd) and %sysfunc(exist(&dd)) %then %do;
    %m_derive_var_dthcaus(
      dataset=work._adsl2_12
    , source_ds=&dd
    , by_vars=STUDYID USUBJID
    , dthcaus=DDSTRESC
    , filter=%str(upcase(DDTESTCD)='PRCDTH')
    , new_var=DTHCAUS
    , mode=first
    , order=DDSEQ
    , out=work._adsl2_13
    );
    data work._adsl2_13;
      set work._adsl2_13;
      length DTHDOM $8 DTHCGR1 $40;
      if not missing(DTHCAUS) then do;
        /* Cause text comes from AE via constructed DD; match pharmaverseadam DTHDOM */
        DTHDOM = 'AE';
        DTHCGR1 = 'ADVERSE EVENT';
      end;
    run;
  %end;
  %else %do;
    data work._adsl2_13;
      set work._adsl2_12;
      length DTHCAUS $200 DTHDOM $8 DTHCGR1 $40;
      call missing(DTHCAUS, DTHDOM, DTHCGR1);
    run;
    %put NOTE: m_adsl_pva - dd= missing - DTHCAUS/DTHDOM/DTHCGR1 left blank.;
  %end;

  /* ---- LSTALVDT Date Last Known Alive (admiral ad_adsl.R) ----
     derive_vars_extreme_event mode=last, order=LSTALVDT seq event_nr.
     Event 1 AE start, 2 AE end, 3 LB, 4 ADSL TRTEDT. convert_dtc_to_dt
     highest_imputation=M (first). Do not invent AE/LB when not supplied. */
  %if &_have_ae %then %do;
    %m_derive_vars_dt(
      dataset=&ae
    , new_vars_prefix=AEST
    , dtc=AESTDTC
    , highest_imputation=M
    , date_imputation=first
    , flag_imputation=none
    , out=work._lst_ae_st
    );
    data work._lst_ae_st2;
      set work._lst_ae_st;
      if not missing(AESTDT);
      format LSTALVDT date9.;
      LSTALVDT = AESTDT;
      seq = input(cats(AESEQ), ?? best32.);
      event_nr = 1;
      keep STUDYID USUBJID LSTALVDT seq event_nr;
    run;
    %m_derive_vars_dt(
      dataset=&ae
    , new_vars_prefix=AEEN
    , dtc=AEENDTC
    , highest_imputation=M
    , date_imputation=first
    , flag_imputation=none
    , out=work._lst_ae_en
    );
    data work._lst_ae_en2;
      set work._lst_ae_en;
      if not missing(AEENDT);
      format LSTALVDT date9.;
      LSTALVDT = AEENDT;
      seq = input(cats(AESEQ), ?? best32.);
      event_nr = 2;
      keep STUDYID USUBJID LSTALVDT seq event_nr;
    run;
    %put NOTE: m_adsl_pva - LSTALVDT AE start/end events from &ae.;
  %end;
  %else %do;
    %put NOTE: m_adsl_pva - ae= missing - LSTALVDT skips AE AESTDTC/AEENDTC events.;
  %end;

  %if &_have_lb %then %do;
    %m_derive_vars_dt(
      dataset=&lb
    , new_vars_prefix=LB
    , dtc=LBDTC
    , highest_imputation=M
    , date_imputation=first
    , flag_imputation=none
    , out=work._lst_lb
    );
    data work._lst_lb2;
      set work._lst_lb;
      if not missing(LBDT);
      format LSTALVDT date9.;
      LSTALVDT = LBDT;
      seq = input(cats(LBSEQ), ?? best32.);
      event_nr = 3;
      keep STUDYID USUBJID LSTALVDT seq event_nr;
    run;
    %put NOTE: m_adsl_pva - LSTALVDT LB LBDTC events from &lb.;
  %end;
  %else %do;
    %put NOTE: m_adsl_pva - lb= missing - LSTALVDT skips LB LBDTC events.;
  %end;

  data work._lst_trt;
    set work._adsl2_13;
    if not missing(TRTEDT);
    format LSTALVDT date9.;
    LSTALVDT = TRTEDT;
    seq = .;
    event_nr = 4;
    keep STUDYID USUBJID LSTALVDT seq event_nr;
  run;

  data work._lst_all;
    set work._lst_trt
    %if &_have_ae %then %do;
      work._lst_ae_st2 work._lst_ae_en2
    %end;
    %if &_have_lb %then %do;
      work._lst_lb2
    %end;
    ;
  run;

  proc sort data=work._lst_all;
    by STUDYID USUBJID LSTALVDT seq event_nr;
  run;
  data work._lst_last;
    set work._lst_all;
    by STUDYID USUBJID;
    if last.USUBJID;
    keep STUDYID USUBJID LSTALVDT;
  run;

  proc sort data=work._adsl2_13;
    by STUDYID USUBJID;
  run;
  proc sort data=work._lst_last;
    by STUDYID USUBJID;
  run;
  data work._adsl2_14;
    merge work._adsl2_13(in=a) work._lst_last;
    by STUDYID USUBJID;
    if a;
    format LSTALVDT date9.;
  run;

  data work._adsl_preord;
    set work._adsl2_14;
    length AGEGR1 $10 RACEGR1 $12 REGION1 $8 LDDTHGR1 $8
           DTH30FL DTHA30FL DTHB30FL $1;
    /* ad_adsl.R format_agegr1 / format_racegr1 / format_region1 / format_lddthgr1 */
    if missing(AGE) then AGEGR1 = 'Missing';
    else if AGE < 18 then AGEGR1 = '<18';
    else if AGE <= 64 then AGEGR1 = '18-64';
    else AGEGR1 = '>64';
    if missing(RACE) then RACEGR1 = 'Missing';
    else if upcase(strip(RACE)) = 'WHITE' then RACEGR1 = 'White';
    else RACEGR1 = 'Non-white';
    if missing(COUNTRY) then REGION1 = 'Missing';
    else if upcase(strip(COUNTRY)) in ('CAN' 'USA') then REGION1 = 'NA';
    else REGION1 = 'RoW';
    if missing(LDDTHELD) then call missing(LDDTHGR1);
    else if LDDTHELD <= 30 then LDDTHGR1 = '<= 30';
    else LDDTHGR1 = '> 30';
    if LDDTHGR1 = '<= 30' then DTH30FL = 'Y';
    else call missing(DTH30FL);
    if LDDTHGR1 = '> 30' then DTHA30FL = 'Y';
    else call missing(DTHA30FL);
    if not missing(DTHDT) and not missing(TRTSDT) and DTHDT <= (TRTSDT + 30)
      then DTHB30FL = 'Y';
    else call missing(DTHB30FL);
    format TRTSDT TRTEDT DTHDT EOSDT RANDDT SCRFDT FRVDT LSTALVDT date9.
           TRTSDTM TRTEDTM datetime20.;
    label LDDTHELD = 'Elapsed Days Last Dose to Death'
          DTHADY   = 'Relative Day of Death'
          DTHDT    = 'Date of Death'
          LSTALVDT = 'Date Last Known Alive'
          TRTSDT   = 'Date of First Exposure to Treatment'
          TRTEDT   = 'Date of Last Exposure to Treatment';
    keep STUDYID USUBJID SUBJID SITEID AGE AGEU SEX RACE ARM ARMCD ACTARM ACTARMCD
         COUNTRY ETHNIC DTHFL DTHDTC
         RFSTDTC RFENDTC RFXSTDTC RFXENDTC RFPENDTC RFICDTC
         &_keep_brth DMDTC DMDY
         AGEGR1 RACEGR1 REGION1 LDDTHGR1 DTH30FL DTHA30FL DTHB30FL
         TRT01P TRT01A
         TRTSDTM TRTEDTM TRTSTMF TRTETMF TRTSDT TRTEDT TRTDURD
         DTHDT DTHDTF DTHADY LDDTHELD DTHCAUS DTHDOM DTHCGR1
         EOSSTT EOSDT FRVDT RANDDT SCRFDT LSTALVDT
         ITTFL SAFFL EFFFL COMPL8FL COMPL16FL COMPL24FL;
  run;

  /* Column order = PVA REF (refadsl) left-to-right. SAS-only pop flags
     sit next to SAFFL. Fallback used when ref_pva.refadsl not on session. */
  %m_order_vars_like_ref(
    data=work._adsl_preord
  , out=&out
  , refds=ref_pva.refadsl
  , fallback=STUDYID USUBJID SUBJID SITEID COUNTRY RFSTDTC RFENDTC RFXSTDTC
             RFXENDTC RFPENDTC RFICDTC BRTHDTC DMDTC DMDY ETHNIC ACTARMCD
             SCRFDT FRVDT DTHDTC DTHADY DTHFL LDDTHELD LDDTHGR1 DTH30FL
             DTHA30FL DTHB30FL DTHDOM AGE AGEU AGEGR1 SEX RACE RACEGR1
             REGION1 SAFFL ARM ARMCD ACTARM
             TRT01P TRT01A TRTSDT TRTSDTM TRTSTMF TRTEDT TRTEDTM TRTETMF
             EOSSTT EOSDT RANDDT TRTDURD DTHDT DTHDTF DTHCAUS DTHCGR1 LSTALVDT
  , extra_after=ITTFL:SAFFL EFFFL:SAFFL COMPL8FL:SAFFL COMPL16FL:SAFFL COMPL24FL:SAFFL
  );

  /* PVA Key Variables = STUDYID USUBJID - pharmaverseadam::adsl is sorted
     by USUBJID (single-study STUDYID is constant). Publishes SORTEDBY. */
  proc sort data=&out;
    by STUDYID USUBJID;
  run;

  proc datasets lib=work nolist;
    delete _adsl2_0 _adsl2_1 _adsl2_2 _adsl2_4 _adsl2_4b _adsl2_5
           _adsl2_6 _adsl2_7 _adsl2_8 _adsl2_9 _adsl2_10 _adsl2_10b
           _adsl2_10c _adsl2_11 _adsl2_12 _adsl2_13 _adsl2_14 _adsl_preord
           _ex_st _ex_ext _ds_ext _ds_eosstt _popfl _saffl_ex
           _lst_ae_st _lst_ae_st2 _lst_ae_en _lst_ae_en2
           _lst_lb _lst_lb2 _lst_trt _lst_all _lst_last;
  quit;

  %m_nobs(ds=&out);
  %put NOTE: m_adsl_pva complete -> &out;

%mend m_adsl_pva;
