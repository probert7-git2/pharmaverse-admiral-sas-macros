/*--------------------------------------------------------------
  Program Name                : m_adlb_pva.sas
  Purpose                     : Part B ADLB BDS labs with baseline shift ATOXGR
  Origin                      : Adapted from Track A m_adlb.sas
  Note                        : Lives only in SAS_mirrored_Admiral_safety_ADaM.
                                Do not edit safety_monitoring_system for Part B.
  Macro                       : %m_adlb_pva
  Input                       : raw.lb adam.adsl
                                metadata/atoxgr_criteria_ctcv5.csv (CTCAE path)
                                metadata/atoxgr_param_map.csv (CTCAE path)
  Output default              : adam.adlb (Part B adam lib)
  Modification Log            : 24AUG2026 - Part B %m_adlb_pva from m_adlb.
                                tox_method=SIMPLE default (Track A gold).
                                SHIFT rebuild v2f from BNRIND/ANRIND.
                                Sort USUBJID PARAMCD AVISIT ADT LBSEQ (QC key).
                                24AUG2026 - Unit policy: PARAM may embed standard
                                unit when used; AVAL must be in that same standard
                                unit. SDTM LB already provides LBSTRESN/LBSTRESU as
                                the standardized result - use those for AVAL/AVALU.
                                Do not append raw/non-standard units into PARAM.
                                If original-result conversion is ever required,
                                convert AVAL to std then set AVALU=std (same as ADVS).
                                PARAM = LBTEST (decode). PARAMN from PARAMCD map.
                                24AUG2026 - PARAMN from PVA gold PARAMCD map
                                (refadlb.xpt). Display sort USUBJID PARAMN PARAM
                                AVISITN AVISIT ADT LBSEQ. No ADTM on PVA ADLB.
--------------------------------------------------------------*/
%macro m_adlb_pva(
                 lb=raw.lb
             , adsl=adam.adsl
             ,  out=adam.adlb
             , derive_tox=Y
             , tox_method=SIMPLE
             , criteria_csv=
             , param_map_csv=
             );

  %if %sysfunc(exist(&lb)) = 0 %then %do;
      %put ERROR: m_adlb_pva - dataset &lb not found.;
      %return;
  %end;

  %put NOTE: m_adlb_pva starting lb=&lb adsl=&adsl out=&out tox_method=&tox_method;

  /* PARAMN = unique PARAMCD->PARAMN from PVA gold refadlb.xpt */
  data work._paramn_lb;
    length PARAMCD $8;
    PARAMCD='ALB';    PARAMN=1;  output;
    PARAMCD='ALKPH';  PARAMN=2;  output;
    PARAMCD='ALT';    PARAMN=3;  output;
    PARAMCD='ANISO';  PARAMN=4;  output;
    PARAMCD='AST';    PARAMN=5;  output;
    PARAMCD='BASO';   PARAMN=6;  output;
    PARAMCD='BASOLE'; PARAMN=7;  output;
    PARAMCD='BILI';   PARAMN=8;  output;
    PARAMCD='BUN';    PARAMN=9;  output;
    PARAMCD='CA';     PARAMN=10; output;
    PARAMCD='CHOLES'; PARAMN=11; output;
    PARAMCD='CK';     PARAMN=12; output;
    PARAMCD='CL';     PARAMN=13; output;
    PARAMCD='COLOR';  PARAMN=14; output;
    PARAMCD='CREAT';  PARAMN=15; output;
    PARAMCD='EOS';    PARAMN=16; output;
    PARAMCD='EOSLE';  PARAMN=17; output;
    PARAMCD='GGT';    PARAMN=18; output;
    PARAMCD='GLUC';   PARAMN=19; output;
    PARAMCD='HBA1C';  PARAMN=20; output;
    PARAMCD='HCT';    PARAMN=21; output;
    PARAMCD='HGB';    PARAMN=22; output;
    PARAMCD='POTAS';  PARAMN=23; output;
    PARAMCD='KETON';  PARAMN=24; output;
    PARAMCD='LYMPH';  PARAMN=25; output;
    PARAMCD='LYMPHLE';PARAMN=26; output;
    PARAMCD='MACROC'; PARAMN=27; output;
    PARAMCD='MCH';    PARAMN=28; output;
    PARAMCD='MCHC';   PARAMN=29; output;
    PARAMCD='MCV';    PARAMN=30; output;
    PARAMCD='MICROC'; PARAMN=31; output;
    PARAMCD='MONO';   PARAMN=32; output;
    PARAMCD='MONOLE'; PARAMN=33; output;
    PARAMCD='PH';     PARAMN=34; output;
    PARAMCD='PHOS';   PARAMN=35; output;
    PARAMCD='PLAT';   PARAMN=36; output;
    PARAMCD='POIKIL'; PARAMN=37; output;
    PARAMCD='POLYCH'; PARAMN=38; output;
    PARAMCD='PROT';   PARAMN=39; output;
    PARAMCD='RBC';    PARAMN=40; output;
    PARAMCD='SODIUM'; PARAMN=41; output;
    PARAMCD='SPGRAV'; PARAMN=42; output;
    PARAMCD='TSH';    PARAMN=43; output;
    PARAMCD='URATE';  PARAMN=44; output;
    PARAMCD='UROBIL'; PARAMN=45; output;
    PARAMCD='VITB12'; PARAMN=46; output;
    PARAMCD='WBC';    PARAMN=47; output;
  run;

  /* ADT via DTC->DT (admiral derive_vars_dt, prefix=A). LBDTC may be ISO
     datetime - date part only. Do not use %m_derive_vars_dtm for ADT.
     PVA ADLB has no ADTM. */
  %m_derive_vars_dt(
    dataset=&lb
  , new_vars_prefix=A
  , dtc=LBDTC
  , highest_imputation=n
  , out=work._lb0
  );

  data work._lb1;
    set work._lb0;
    if not missing(LBSTRESN) and not missing(ADT);
    AVAL = LBSTRESN;
    length PARAMCD $8 PARAM $100 AVALU $40 AVALC $40 ANRIND $20 AVISIT $40;
    PARAMCD = LBTESTCD;
    /* PARAM = LBTEST (codelist). AVAL/AVALU from LBSTRESN/LBSTRESU = SDTM
       standardized result (already in the analysis unit). Never glue a
       non-standard original unit into PARAM; if ORRES conversion were needed,
       convert AVAL to std unit then set AVALU=std (see m_advs_pva). */
    PARAM   = LBTEST;
    AVALU   = LBSTRESU;
    AVALC   = LBSTRESC;
    ANRLO   = LBSTNRLO;
    ANRHI   = LBSTNRHI;
    ANRIND  = LBNRIND;
    length ABLFL_SRC $1;
    ABLFL_SRC = '';
    if not missing(LBBLFL) and upcase(strip(LBBLFL)) = 'Y' then ABLFL_SRC = 'Y';
    /* AVISIT/AVISITN - admiral Creating a BDS Finding ADaM timing pattern */
    length _vu $200;
    _vu = upcase(strip(VISIT));
    if missing(VISIT) then AVISIT = '';
    else if index(_vu, 'SCREEN') or index(_vu, 'UNSCHED')
         or index(_vu, 'RETRIEVAL') or index(_vu, 'AMBUL') then AVISIT = '';
    else AVISIT = propcase(strip(VISIT));
    if _vu = 'BASELINE' then AVISITN = 0;
    else if index(_vu, 'WEEK') then AVISITN = input(compress(_vu, , 'kd'), ?? best.);
    else AVISITN = .;
    drop _vu;
    keep STUDYID USUBJID LBSEQ PARAMCD PARAM ADT AVAL AVALC AVALU
         ANRLO ANRHI ANRIND ABLFL_SRC LBCAT VISIT VISITNUM AVISIT AVISITN;
  run;

  %m_derive_vars_merged_lookup(
    dataset=work._lb1
  , dataset_add=work._paramn_lb
  , by_vars=PARAMCD
  , new_vars=PARAMN=PARAMN
  , print_not_mapped=N
  , out=work._lb1p
  );

  /* Scope trace - the analysis-record filter is the only place rows leave ADLB */
  %m_nobs(ds=&lb);
  %m_nobs(ds=work._lb1p);

  /* ADSL dates/arms - admiral derive_vars_merged (not ad hoc left join) */
  %m_derive_vars_merged(
    dataset=work._lb1p
  , dataset_add=&adsl
  , by_vars=STUDYID USUBJID
  , order=USUBJID
  , new_vars=SITEID=SITEID SUBJID=SUBJID
             TRTSDT=TRTSDT TRTEDT=TRTEDT TRT01A=TRT01A TRT01P=TRT01P
  , filter_add=%str(1)
  , mode=first
  , out=work._lb1b
  );

  data work._lb2;
    set work._lb1b;
    format ADT TRTSDT TRTEDT date9.;
    length ABLFL $1 TRTA $100 TRTP $100;
    ABLFL = ABLFL_SRC;
    if ABLFL = '' and not missing(TRTSDT) and ADT < TRTSDT then ABLFL = 'Y';
    TRTA = TRT01A;
    TRTP = TRT01P;
    drop ABLFL_SRC;
  run;

  %m_derive_vars_dy(
    dataset=work._lb2
  , reference_date=TRTSDT
  , source_vars=ADT
  , out=work._lb2b
  );

  %m_derive_var_base(
                      dataset=work._lb2b
                    , by_vars=USUBJID PARAMCD
                    , source_var=AVAL
                    , new_var=BASE
                    , filter=%str(ABLFL = 'Y')
                    , out=work._lb3
                    );

  /* Character baselines - admiral derive_var_base with first-by-ADT/LBSEQ
     (order=) so multiple ABLFL='Y' rows pick the earliest visit, not SQL max. */
  %m_derive_var_base(
                      dataset=work._lb3
                    , by_vars=USUBJID PARAMCD
                    , source_var=AVALC
                    , new_var=BASEC
                    , filter=%str(ABLFL = 'Y')
                    , order=ADT LBSEQ
                    , out=work._lb3b
                    );

  %m_derive_var_base(
                      dataset=work._lb3b
                    , by_vars=USUBJID PARAMCD
                    , source_var=ANRIND
                    , new_var=BNRIND
                    , filter=%str(ABLFL = 'Y')
                    , order=ADT LBSEQ
                    , out=work._lb5
                    );

  %m_derive_var_chg(dataset=work._lb5,  out=work._lb6);
  %m_derive_var_pchg(dataset=work._lb6, out=work._lb7);

  /* SHIFT is built once in the final output step (not here). A prior
     %m_derive_var_bshift pass left SHIFT blank on ODA while BNRIND/ANRIND
     matched gold - avoid carrying a blank SHIFT through ONTRT/ATOX. */
  %m_derive_var_ontrtfl(
                         dataset=work._lb7
                       , new_var=ONTRTFL
                       , start_date=ADT
                       , ref_start_date=TRTSDT
                       , ref_end_date=TRTEDT
                       , out=work._lb9
                       );

  %if %upcase(&derive_tox) = Y %then %do;
    %if %upcase(&tox_method) = CTCAE %then %do;
      %m_load_atoxgr_meta(
                            criteria_csv=&criteria_csv
                          , param_map_csv=&param_map_csv
                          , criteria_out=work.atoxgr_criteria_ctcv5
                          , param_map_out=work.atoxgr_param_map
                          );
      %if %sysfunc(exist(work.atoxgr_criteria_ctcv5)) = 0
          or %sysfunc(exist(work.atoxgr_param_map)) = 0 %then %do;
        %put ERROR: m_adlb_pva - CTCAE metadata not loaded. Upload metadata/atoxgr_*.csv to ODA.;
        %return;
      %end;

      %m_map_atoxdsc(
                      dataset=work._lb9
                    , param_map=work.atoxgr_param_map
                    , out=work._lb9m
                    );

      %m_derive_var_atoxgr_dir_ctcae(
                                      dataset=work._lb9m
                                    , new_var=ATOXGRH
                                    , tox_description_var=ATOXDSCH
                                    , meta_criteria=work.atoxgr_criteria_ctcv5
                                    , criteria_direction=H
                                    , high_indicator=%str(HIGH)
                                    , out=work._lb10
                                    );

      %m_derive_var_atoxgr_dir_ctcae(
                                      dataset=work._lb10
                                    , new_var=ATOXGRL
                                    , tox_description_var=ATOXDSCL
                                    , meta_criteria=work.atoxgr_criteria_ctcv5
                                    , criteria_direction=L
                                    , low_indicator=%str(LOW)
                                    , out=work._lb11
                                    );

      %m_derive_var_atoxgr(
                            dataset=work._lb11
                          , lotox_description_var=ATOXDSCL
                          , hitox_description_var=ATOXDSCH
                          , out=work._lb12
                          );
    %end;
    %else %do;
      /* ULN/LLN multiples + Track A combine_tox (tox_method=SIMPLE) */
      %m_derive_var_atoxgr_dir(
                                dataset=work._lb9
                              , new_var=ATOXGRH
                              , criteria_direction=H
                              , out=work._lb10
                              );

      %m_derive_var_atoxgr_dir(
                                dataset=work._lb10
                              , new_var=ATOXGRL
                              , criteria_direction=L
                              , out=work._lb11
                              );

      data work._lb11b;
           set work._lb11;
           length ATOXDSCL ATOXDSCH $80;
           call missing(ATOXDSCL, ATOXDSCH);
      run;

      /* MAXABS = export_r_adam_ref.R combine_tox (not admiral low-first) */
      %m_derive_var_atoxgr(
                            dataset=work._lb11b
                          , combine_method=MAXABS
                          , out=work._lb12
                          );
    %end;
  %end;
  %else %do;
    data work._lb12;
         set work._lb9;
         length ATOXGRH ATOXGRL ATOXGR $2 ATOXDSCL ATOXDSCH $80;
         call missing(ATOXGRH, ATOXGRL, ATOXGR, ATOXDSCL, ATOXDSCH);
    run;
  %end;

  /* SHIFT = Track A paste(coalesce(BNRIND," "),"to",coalesce(ANRIND," ")).
     Built here only (no earlier bshift). LENGTH before SET. DROP=SHIFT only
     when SHIFT exists on _lb12 - unconditional drop ERRORs on ODA when the
     var was never referenced. Do not cat()/|| $40 temps - trailing pad
     becomes internal blanks (strip in QC cannot remove them). Missing-side
     space uses char literals - strip(byte(32)) and trimn(all-blank $40)
     both collapse the placeholder. */
  %local _dsid _has_shift _rc;
  %let _has_shift = 0;
  %let _dsid = %sysfunc(open(work._lb12, i));
  %if &_dsid %then %do;
       %let _has_shift = %eval(%sysfunc(varnum(&_dsid, SHIFT)) > 0);
       %let _rc = %sysfunc(close(&_dsid));
  %end;
  %put NOTE: m_adlb_pva SHIFT rebuild v2f - building SHIFT from BNRIND/ANRIND (has_shift=&_has_shift).;
  data work._adlb_preord;
       length SHIFT $200 _sf $40 _st $40;
       %if &_has_shift %then %do;
            set work._lb12(drop=SHIFT);
       %end;
       %else %do;
            set work._lb12;
       %end;
       if missing(BNRIND) and missing(ANRIND) then SHIFT = '';
       else do;
            _sf = strip(BNRIND);
            _st = strip(ANRIND);
            /* trimn keeps non-missing text without $40 pad. Missing side uses
               literals so gold "  to NORMAL" / "HIGH to  " spacing is preserved. */
            if missing(_sf) then SHIFT = '  to ' || trimn(_st);
            else if missing(_st) then SHIFT = trimn(_sf) || ' to  ';
            else SHIFT = trimn(_sf) || ' to ' || trimn(_st);
       end;
       drop _sf _st;
       keep STUDYID USUBJID SUBJID SITEID LBSEQ PARAMCD PARAM PARAMN LBCAT VISIT VISITNUM
            AVISIT AVISITN
            ADT ADY AVAL AVALC AVALU ANRLO ANRHI ANRIND
            BASE BASEC BNRIND CHG PCHG SHIFT ABLFL ONTRTFL
            ATOXDSCL ATOXDSCH ATOXGRH ATOXGRL ATOXGR
            TRTSDT TRTEDT TRTA TRTP;
  run;

  /* Column order = PVA REF (refadlb). SAS-only AVALU SHIFT LBCAT near related. */
  %m_order_vars_like_ref(
    data=work._adlb_preord
  , out=&out
  , refds=ref_pva.refadlb
  , fallback=STUDYID USUBJID SUBJID SITEID TRTP TRTA TRTSDT TRTEDT ADT ADY
             AVISIT AVISITN PARAM PARAMCD PARAMN AVAL AVALC BASE BASEC CHG
             PCHG ATOXGR ANRIND BNRIND ANRLO ANRHI ATOXGRL ATOXGRH ATOXDSCL
             ATOXDSCH ABLFL ONTRTFL LBSEQ VISITNUM VISIT
  , extra_after=LBCAT:PARAMN AVALU:AVAL SHIFT:BNRIND
  );

  /* Display / SORTEDBY order (PARAMN 1:1 with PARAMCD on PVA gold).
     LBSEQ final = within-day proxy (no ADTM on PVA ADLB). */
  proc sort data=&out;
       by USUBJID PARAMN PARAM AVISITN AVISIT ADT LBSEQ;
  run;

  %let _n_shift = 0;
  %let _n_bnr = 0;
  proc sql noprint;
       select count(*) into :_n_shift trimmed
       from &out
       where not missing(SHIFT);
       select count(*) into :_n_bnr trimmed
       from &out
       where not missing(BNRIND) or not missing(ANRIND);
  quit;
  %put NOTE: m_adlb_pva SHIFT rebuild v2f - non-missing SHIFT=&_n_shift rows with BNRIND or ANRIND=&_n_bnr.;
  %if &_n_bnr > 0 and &_n_shift = 0 %then %do;
       %put ERROR: m_adlb_pva - BNRIND/ANRIND present but SHIFT blank on all rows. SHIFT rebuild failed.;
  %end;

  proc datasets lib=work nolist;
       delete _paramn_lb _lb0 _lb1 _lb1p _lb1b _lb2 _lb2b _lb3 _lb3b _lb5 _lb6
              _lb7 _lb9 _lb9m _lb10 _lb11 _lb11b _lb12 _adlb_preord
              atoxgr_criteria_ctcv5 atoxgr_param_map;
  quit;

  %m_nobs(ds=&out);
  %put NOTE: m_adlb_pva complete -> &out;

%mend m_adlb_pva;
