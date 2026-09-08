/*--------------------------------------------------------------
  Program Name                : m_adeg_pva.sas
  Purpose                     : Part B ADEG BDS ECG (PVA-aligned)
  Origin                      : Adapted from Track A m_adeg2.sas
  Note                        : Lives only in SAS_mirrored_Admiral_safety_ADaM.
                                Do not edit safety_monitoring_system for Part B.
  Macro                       : %m_adeg_pva
  Input                       : raw.eg adam.adsl
  Output default              : adam.adeg (Part B adam lib)
  POLICY                      : AVALU = ms (CDISC CT 24JUN2022). PVA gold may
                                still use deprecated msec - QC marks POLICY.
  Modification Log            : 24AUG2026 - Baseline vs PVA REF / admiral
                                ad_adeg.R: DTYPE=AVERAGE (additive, n>=2,
                                PARAMCD ne EGINTP), BASETYPE=BASELINE DAY 1,
                                ABLFL = last AVERAGE with ADT<=TRTSDT (not all
                                pre-dose, not mean of six screenings), BASE from
                                that row, CHG/PCHG only when AVISITN>0, ATPT from
                                EGTPT, ONTRTFL window 30d + Baseline clear.
                                24AUG2026 - Part B %m_adeg_pva from m_adeg2.
                                Sort USUBJID PARAMCD AVISIT ADT EGSEQ (QC key).
                                24AUG2026 - PARAMN from PVA gold PARAMCD map
                                (refadeg.xpt). ADTM via derive_vars_dtm on EGDTC
                                (midnight when no time). Display sort USUBJID
                                PARAMN PARAM AVISITN AVISIT ADT ADTM EGSEQ.
--------------------------------------------------------------*/
%macro m_adeg_pva(
  eg=raw.eg
, adsl=adam.adsl
, out=adam.adeg
);

  %if %sysfunc(exist(&eg)) = 0 %then %do;
    %put ERROR: m_adeg_pva - dataset &eg not found.;
    %return;
  %end;
  %if %sysfunc(exist(&adsl)) = 0 %then %do;
    %put ERROR: m_adeg_pva - dataset &adsl not found.;
    %return;
  %end;

  %put NOTE: m_adeg_pva starting eg=&eg adsl=&adsl out=&out;

  /* AVALU: CDISC SDTM CT (24JUN2022) submission value for milliseconds is ms.
     msec is deprecated. Align ADEG with EGSTRESU / current CT (FDA follows CDISC).
     PARAMN = unique PARAMCD->PARAMN from PVA gold refadeg.xpt.
     QTCF (builder) shares PARAMN 12 with gold QTCFR. */
  data work._param_map_eg;
    length EGTESTCD $8 PARAMCD $8 PARAM $60 AVALU $20;
    EGTESTCD='EGINTP'; PARAMCD='EGINTP'; PARAM='ECG Interpretation';              AVALU='';         PARAMN=1;  output;
    EGTESTCD='HR';     PARAMCD='HR';     PARAM='Heart Rate';                        AVALU='beats/min'; PARAMN=2;  output;
    EGTESTCD='RR';     PARAMCD='RR';     PARAM='RR Interval';                       AVALU='ms';        PARAMN=3;  output;
    EGTESTCD='RRR';    PARAMCD='RRR';    PARAM='RR Duration Rederived';          AVALU='ms';        PARAMN=4;  output;
    EGTESTCD='QT';     PARAMCD='QT';     PARAM='QT Interval';                       AVALU='ms';        PARAMN=10; output;
    EGTESTCD='QTCBR';  PARAMCD='QTCBR';  PARAM='QTcB Bazett Rederived';           AVALU='ms';        PARAMN=11; output;
    EGTESTCD='QTCFR';  PARAMCD='QTCFR';  PARAM='QTcF Fridericia Rederived';       AVALU='ms';        PARAMN=12; output;
    EGTESTCD='QTCF';   PARAMCD='QTCF';   PARAM='QT Interval Corrected (Fridericia)'; AVALU='ms'; PARAMN=12; output;
    EGTESTCD='QTLCR';  PARAMCD='QTLCR';  PARAM='QTlc Sagie Rederived';            AVALU='ms';        PARAMN=13; output;
    EGTESTCD='PR';     PARAMCD='PR';     PARAM='PR Interval';                       AVALU='ms';        PARAMN=.;  output;
  run;

  /* ADT via DTC->DT (date-only path). */
  %m_derive_vars_dt(
    dataset=&eg
  , new_vars_prefix=A
  , dtc=EGDTC
  , highest_imputation=n
  , out=work._eg0
  );

  /* ADTM via DTC->DTM. Uses EGDTC time when present - else admiral-style
     first (midnight) time imputation. PVA gold ADTM is date-scale in XPT -
     QC DTM norm handles compare. */
  %put NOTE: m_adeg_pva - deriving ADTM from EGDTC via derive_vars_dtm (midnight when time absent).;
  %m_derive_vars_dtm(
    dataset=work._eg0
  , new_vars_prefix=A
  , dtc=EGDTC
  , highest_imputation=n
  , time_imputation=first
  , flag_imputation=auto
  , out=work._eg0b
  );

  data work._eg1;
    set work._eg0b;
    if not missing(EGSTRESN) and not missing(ADT);
    AVAL = EGSTRESN;
    /* Safety fill if ADTM still missing but ADT present */
    if missing(ADTM) and not missing(ADT) then ADTM = dhms(ADT, 0, 0, 0);
    format ADTM datetime20.;
    length AVISIT $40;
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
    /* Keep EGTPT* for ATPT (PVA triplicate positions). */
    keep STUDYID USUBJID EGSEQ EGTESTCD EGTEST EGSTRESU ADT ADTM AVAL
         VISIT VISITNUM AVISIT AVISITN EGTPT EGTPTNUM;
  run;

  %m_derive_vars_merged_lookup(
    dataset=work._eg1
  , dataset_add=work._param_map_eg
  , by_vars=EGTESTCD
  , new_vars=PARAMCD=PARAMCD PARAM=PARAM AVALU=AVALU PARAMN=PARAMN
  , print_not_mapped=N
  , out=work._eg2
  );

  data work._eg2b;
    set work._eg2;
    if missing(PARAMCD) then PARAMCD = EGTESTCD;
    if missing(PARAM)   then PARAM   = EGTEST;
    if missing(AVALU)   then AVALU   = EGSTRESU;
    /* Normalize deprecated msec to current CT submission value ms. */
    if upcase(strip(AVALU)) in ('MS', 'MSEC') then AVALU = 'ms';
    keep STUDYID USUBJID EGSEQ PARAMCD PARAM PARAMN ADT ADTM AVAL AVALU
         VISIT VISITNUM AVISIT AVISITN EGTPT EGTPTNUM;
  run;

  %m_derive_vars_merged(
    dataset=work._eg2b
  , dataset_add=&adsl
  , by_vars=STUDYID USUBJID
  , order=USUBJID
  , new_vars=SITEID=SITEID SUBJID=SUBJID
             TRTSDT=TRTSDT TRTEDT=TRTEDT TRT01A=TRT01A TRT01P=TRT01P
  , filter_add=%str(1)
  , mode=first
  , out=work._eg2c
  );

  /* Timing + treatment. ABLFL is NOT all pre-dose - flagged after AVERAGE. */
  data work._eg3;
    set work._eg2c;
    format ADT TRTSDT TRTEDT date9.;
    format ADTM datetime20.;
    length ATPT $100 DTYPE $20 BASETYPE $100 ABLFL $1 TRTA $100 TRTP $100;
    ATPTN = EGTPTNUM;
    ATPT  = EGTPT;
    DTYPE = '';
    ABLFL = '';
    /* admiral derive_basetype_records: single basetype for ADEG */
    BASETYPE = 'BASELINE DAY 1';
    TRTA = TRT01A;
    TRTP = TRT01P;
    drop EGTPT EGTPTNUM;
  run;

  %m_derive_vars_dy(
    dataset=work._eg3
  , reference_date=TRTSDT
  , source_vars=ADT
  , out=work._eg3b
  );

  /* DTYPE=AVERAGE: mean AVAL per subject/param/visit-date (admiral ad_adeg.R).
     Adds rows when n>=2 and PARAMCD ne EGINTP - does NOT drop triplicates.
     ABLFL targets these AVERAGE rows (opposite of ADVS blank-DTYPE rule). */
  proc sql;
    create table work._eg_avg as
    select STUDYID, USUBJID, SUBJID, SITEID
         , PARAMCD, PARAM, PARAMN, AVALU
         , AVISIT, AVISITN, ADT, ADY
         , TRTSDT, TRTEDT, TRT01A, TRT01P, TRTA, TRTP
         , mean(AVAL) as AVAL
         , min(ADTM) as ADTM
         , 'AVERAGE' as DTYPE length=20
         , 'BASELINE DAY 1' as BASETYPE length=100
         , '' as ATPT length=100
         , . as ATPTN
         , . as EGSEQ
         , . as VISITNUM
         , '' as VISIT length=200
         , '' as ABLFL length=1
    from work._eg3b
    where not missing(AVAL)
      and upcase(strip(PARAMCD)) ne 'EGINTP'
    group by STUDYID, USUBJID, SUBJID, SITEID
           , PARAMCD, PARAM, PARAMN, AVALU
           , AVISIT, AVISITN, ADT, ADY
           , TRTSDT, TRTEDT, TRT01A, TRT01P, TRTA, TRTP
    having count(*) >= 2
    ;
  quit;

  data work._eg3c;
    set work._eg3b work._eg_avg;
    format ADT TRTSDT TRTEDT date9.;
    format ADTM datetime20.;
  run;

  /* ABLFL = last AVERAGE with ADT<=TRTSDT (admiral restrict + extreme last).
     Order ADT VISITNUM EGSEQ. When Baseline exists, that visit AVERAGE wins -
     NOT the mean of the six screening triplicate values. */
  proc sort data=work._eg3c out=work._eg3c_s;
    by USUBJID PARAMCD BASETYPE ADT VISITNUM EGSEQ;
  run;

  data work._abl_cand;
    set work._eg3c_s;
    where not missing(AVAL)
      and not missing(TRTSDT)
      and ADT <= TRTSDT
      and upcase(strip(DTYPE)) = 'AVERAGE'
      and upcase(strip(PARAMCD)) ne 'EGINTP';
  run;

  data work._abl_flg;
    set work._abl_cand;
    by USUBJID PARAMCD BASETYPE;
    if last.BASETYPE;
    ABLFL = 'Y';
    keep USUBJID PARAMCD BASETYPE ADT VISITNUM EGSEQ ABLFL;
  run;

  data work._eg3d;
    merge work._eg3c_s(in=a) work._abl_flg;
    by USUBJID PARAMCD BASETYPE ADT VISITNUM EGSEQ;
    if a;
    if missing(ABLFL) then ABLFL = '';
  run;

  /* BASE from ABLFL AVERAGE row (Baseline triplicate mean when present). */
  %m_derive_var_base(
    dataset=work._eg3d
  , by_vars=USUBJID PARAMCD BASETYPE
  , source_var=AVAL
  , new_var=BASE
  , filter=%str(ABLFL = 'Y')
  , out=work._eg4
  );

  %m_derive_var_chg(dataset=work._eg4, out=work._eg5);
  %m_derive_var_pchg(dataset=work._eg5, out=work._eg6);

  /* PVA / admiral: CHG/PCHG only for AVISITN > 0 (screen + Baseline stay missing). */
  data work._eg6b;
    set work._eg6;
    if missing(AVISITN) or AVISITN <= 0 then do;
      CHG = .;
      PCHG = .;
    end;
  run;

  %m_derive_var_ontrtfl(
    dataset=work._eg6b
  , new_var=ONTRTFL
  , start_date=ADT
  , ref_start_date=TRTSDT
  , ref_end_date=TRTEDT
  , ref_end_window=30
  , out=work._eg7
  );

  /* admiral filter_pre_timepoint: AVISIT=Baseline is not on-treatment. */
  data work._eg7b;
    set work._eg7;
    if upcase(strip(AVISIT)) = 'BASELINE' then ONTRTFL = '';
  run;

  data work._adeg_preord;
    set work._eg7b;
    keep STUDYID USUBJID SUBJID SITEID EGSEQ PARAMCD PARAM PARAMN
         VISIT VISITNUM AVISIT AVISITN ATPT ATPTN BASETYPE DTYPE
         ADT ADTM ADY AVAL AVALU BASE CHG PCHG ABLFL ONTRTFL
         TRTSDT TRTEDT TRTA TRTP;
  run;

  /* Column order = PVA REF (refadeg). SAS-only AVALU next to AVAL. */
  %m_order_vars_like_ref(
    data=work._adeg_preord
  , out=&out
  , refds=ref_pva.refadeg
  , fallback=STUDYID USUBJID SUBJID SITEID TRTP TRTA TRTSDT TRTEDT ADT ADTM ADY
             AVISIT AVISITN ATPT ATPTN PARAM PARAMCD PARAMN AVAL BASE
             BASETYPE CHG PCHG DTYPE ABLFL ONTRTFL EGSEQ VISITNUM VISIT
  , extra_after=AVALU:AVAL
  );

  /* Display / SORTEDBY - PARAMN first among params, ADTM before EGSEQ proxy. */
  proc sort data=&out;
    by USUBJID PARAMN PARAM AVISITN AVISIT ADT ADTM EGSEQ;
  run;

  proc datasets lib=work nolist;
    delete _param_map_eg _eg0 _eg0b _eg1 _eg2 _eg2b _eg2c _eg3 _eg3b
           _eg_avg _eg3c _eg3c_s _abl_cand _abl_flg _eg3d
           _eg4 _eg5 _eg6 _eg6b _eg7 _eg7b _adeg_preord;
  quit;

  %m_nobs(ds=&out);
  %put NOTE: m_adeg_pva complete -> &out (ABLFL last AVERAGE ADT<=TRTSDT).;

%mend m_adeg_pva;
