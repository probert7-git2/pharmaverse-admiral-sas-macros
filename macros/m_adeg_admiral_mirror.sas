/*--------------------------------------------------------------
  Program Name                : m_adeg_admiral_mirror.sas
  Purpose                     : ADEG via 1:1 Admiral ad_adeg.R call order
  Approach                    : Pure R-template reverse-engineering.
                                Does NOT steer from PVA REF BASE analysis.
  Template                    : admiral inst/templates/ad_adeg.R
                                (vendored: SAS/R/admiral_templates/ad_adeg.R)
  Macro                       : %m_adeg_admiral_mirror
  Input                       : eg adsl (Part B libs)
  Output default              : adam.adeg
  Note                        : Legacy approximate builder remains
                                %m_adeg_pva (not invoked when create uses mirror)
--------------------------------------------------------------*/
%macro m_adeg_admiral_mirror(
  eg=raw.eg
, adsl=adam.adsl
, out=adam.adeg
);

  %if %sysfunc(exist(&eg)) = 0 %then %do;
    %put ERROR: m_adeg_admiral_mirror - dataset &eg not found.;
    %return;
  %end;
  %if %sysfunc(exist(&adsl)) = 0 %then %do;
    %put ERROR: m_adeg_admiral_mirror - dataset &adsl not found.;
    %return;
  %end;

  %put NOTE: m_adeg_admiral_mirror - pure ad_adeg.R 1:1 sequence starting.;

  /* ---- Lookups from ad_adeg.R (param_lookup / range_lookup) ---- */
  data work._adm_param_lookup;
    length EGTESTCD $8 PARAMCD $8 PARAM $80;
    EGTESTCD='ECGINT'; PARAMCD='EGINTP'; PARAM='ECG Interpretation'; PARAMN=1; output;
    EGTESTCD='HR';     PARAMCD='HR';     PARAM='Heart Rate (beats/min)'; PARAMN=2; output;
    EGTESTCD='RR';     PARAMCD='RR';     PARAM='RR Duration (ms)'; PARAMN=3; output;
    EGTESTCD='RRR';    PARAMCD='RRR';    PARAM='RR Duration Rederived (ms)'; PARAMN=4; output;
    EGTESTCD='QT';     PARAMCD='QT';     PARAM='QT Duration (ms)'; PARAMN=10; output;
    EGTESTCD='QTCBR';  PARAMCD='QTCBR';  PARAM="QTcB - Bazett's Correction Formula Rederived (ms)"; PARAMN=11; output;
    EGTESTCD='QTCFR';  PARAMCD='QTCFR';  PARAM="QTcF - Fridericia's Correction Formula Rederived (ms)"; PARAMN=12; output;
    EGTESTCD='QTLCR';  PARAMCD='QTLCR';  PARAM="QTlc - Sagie's Correction Formula Rederived (ms)"; PARAMN=13; output;
  run;

  data work._adm_range_lookup;
    length PARAMCD $8;
    PARAMCD='EGINTP'; ANRLO=.;    ANRHI=.;    output;
    PARAMCD='HR';     ANRLO=40;   ANRHI=100;  output;
    PARAMCD='RR';     ANRLO=600;  ANRHI=1500; output;
    PARAMCD='QT';     ANRLO=350;  ANRHI=450;  output;
    PARAMCD='RRR';    ANRLO=600;  ANRHI=1500; output;
    PARAMCD='QTCBR';  ANRLO=350;  ANRHI=450;  output;
    PARAMCD='QTCFR';  ANRLO=350;  ANRHI=450;  output;
    PARAMCD='QTLCR';  ANRLO=350;  ANRHI=450;  output;
  run;

  /* ---- convert_blanks_to_na(eg) ---- */
  %m_adm_convert_blanks_to_na(dataset=&eg, out=work._adm_eg0);

  /* ---- derive_vars_merged(adsl_vars) ---- */
  %m_adm_derive_vars_merged(
    dataset=work._adm_eg0
  , dataset_add=&adsl
  , by_vars=STUDYID USUBJID
  , new_vars=TRTSDT=TRTSDT TRTEDT=TRTEDT TRT01A=TRT01A TRT01P=TRT01P
  , filter_add=%str(1)
  , mode=first
  , out=work._adm_01
  );

  /* ---- derive_vars_dtm(new_vars_prefix=A, dtc=EGDTC) ---- */
  %m_adm_derive_vars_dtm(
    dataset=work._adm_01
  , new_vars_prefix=A
  , dtc=EGDTC
  , highest_imputation=n
  , time_imputation=first
  , flag_imputation=auto
  , out=work._adm_02
  );

  /* ---- derive_vars_dy(reference_date=TRTSDT, source_vars=ADTM) ---- */
  %m_adm_derive_vars_dy(
    dataset=work._adm_02
  , reference_date=TRTSDT
  , source_vars=ADTM
  , out=work._adm_03
  );

  /* ---- derive_vars_merged_lookup(PARAMCD only) ---- */
  %m_adm_derive_vars_merged_lookup(
    dataset=work._adm_03
  , dataset_add=work._adm_param_lookup
  , by_vars=EGTESTCD
  , new_vars=PARAMCD=PARAMCD
  , print_not_mapped=N
  , out=work._adm_04
  );

  /* ---- mutate(AVAL, AVALC) ---- */
  %m_adm_adeg_mutate_aval(dataset=work._adm_04, out=work._adm_05);

  /* by_vars shared by derive_param_* in ad_adeg.R */
  %local _param_by;
  %let _param_by = STUDYID USUBJID TRTSDT TRTEDT TRT01A TRT01P
                   VISIT VISITNUM EGTPT EGTPTNUM ADTM ADY;

  /* ---- derive_param_rr ---- */
  %m_adm_derive_param_rr(
    dataset=work._adm_05
  , by_vars=&_param_by
  , set_values=%str(PARAMCD=RRR)
  , hr_code=HR
  , filter=%str(EGSTAT ne 'NOT DONE' or missing(EGSTAT))
  , out=work._adm_06
  );

  /* ---- derive_param_qtc Bazett / Fridericia / Sagie ---- */
  %m_adm_derive_param_qtc(
    dataset=work._adm_06
  , by_vars=&_param_by
  , method=Bazett
  , set_values=%str(PARAMCD=QTCBR)
  , qt_code=QT
  , rr_code=RR
  , filter=%str(EGSTAT ne 'NOT DONE' or missing(EGSTAT))
  , out=work._adm_07
  );

  %m_adm_derive_param_qtc(
    dataset=work._adm_07
  , by_vars=&_param_by
  , method=Fridericia
  , set_values=%str(PARAMCD=QTCFR)
  , qt_code=QT
  , rr_code=RR
  , filter=%str(EGSTAT ne 'NOT DONE' or missing(EGSTAT))
  , out=work._adm_08
  );

  %m_adm_derive_param_qtc(
    dataset=work._adm_08
  , by_vars=&_param_by
  , method=Sagie
  , set_values=%str(PARAMCD=QTLCR)
  , qt_code=QT
  , rr_code=RR
  , filter=%str(EGSTAT ne 'NOT DONE' or missing(EGSTAT))
  , out=work._adm_09
  );

  /* ---- mutate timing (ADT ATPT AVISIT AVISITN) ---- */
  %m_adm_adeg_mutate_timing(dataset=work._adm_09, out=work._adm_10);

  /* ---- derive_summary_records (mean / DTYPE=AVERAGE, n>=2, ne EGINTP) ---- */
  %m_adm_derive_summary_records(
    dataset=work._adm_10
  , by_vars=STUDYID USUBJID TRTSDT TRTEDT TRT01A TRT01P PARAMCD AVISITN AVISIT ADT ADY
  , analysis_var=AVAL
  , summary_fun=mean
  , dtype_value=AVERAGE
  , having_n_ge=2
  , having_extra=%str(max(upcase(strip(PARAMCD))) ne 'EGINTP')
  , out=work._adm_11
  );

  /* ---- derive_var_ontrtfl (window 30, filter_pre_timepoint Baseline) ---- */
  %m_adm_derive_var_ontrtfl(
    dataset=work._adm_11
  , new_var=ONTRTFL
  , start_date=ADT
  , ref_start_date=TRTSDT
  , ref_end_date=TRTEDT
  , ref_end_window=30
  , filter_pre_timepoint=%str(strip(AVISIT) = 'Baseline')
  , out=work._adm_12
  );

  /* ---- derive_vars_merged(range_lookup) ---- */
  %m_adm_derive_vars_merged(
    dataset=work._adm_12
  , dataset_add=work._adm_range_lookup
  , by_vars=PARAMCD
  , new_vars=ANRLO=ANRLO ANRHI=ANRHI
  , filter_add=%str(1)
  , mode=first
  , out=work._adm_13
  );

  /* ---- derive_var_anrind ---- */
  %m_adm_derive_var_anrind(dataset=work._adm_13, out=work._adm_14);

  /* ---- derive_basetype_records ("BASELINE DAY 1" = TRUE) ---- */
  %m_adm_derive_basetype_records(
    dataset=work._adm_14
  , basetype_value=%str(BASELINE DAY 1)
  , out=work._adm_15
  );

  /* ---- restrict_derivation(derive_var_extreme_flag -> ABLFL)
       filter and args copied from ad_adeg.R (not REF-tuned) ---- */
  %m_adm_restrict_extreme_flag(
    dataset=work._adm_15
  , by_vars=STUDYID USUBJID BASETYPE PARAMCD
  , order=ADT VISITNUM EGSEQ
  , new_var=ABLFL
  , mode=last
  , filter=%str(
      (not missing(AVAL) or not missing(AVALC))
      and not missing(TRTSDT) and ADT <= TRTSDT
      and not missing(BASETYPE)
      and upcase(strip(DTYPE)) = 'AVERAGE'
      and upcase(strip(PARAMCD)) ne 'EGINTP'
    )
  , out=work._adm_16
  );

  /* ---- derive_var_base BASE / BASEC / BNRIND ---- */
  %m_adm_derive_var_base(
    dataset=work._adm_16
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , source_var=AVAL
  , new_var=BASE
  , filter=%str(ABLFL = 'Y')
  , out=work._adm_17
  );

  %m_adm_derive_var_base(
    dataset=work._adm_17
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , source_var=AVALC
  , new_var=BASEC
  , filter=%str(ABLFL = 'Y')
  , order=ADT
  , out=work._adm_18
  );

  %m_adm_derive_var_base(
    dataset=work._adm_18
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , source_var=ANRIND
  , new_var=BNRIND
  , filter=%str(ABLFL = 'Y')
  , order=ADT
  , out=work._adm_19
  );

  /* ---- restrict_derivation(derive_var_chg / pchg), filter AVISITN > 0 ---- */
  %m_adm_restrict_derive_var_chg(
    dataset=work._adm_19
  , filter=%str(AVISITN > 0)
  , out=work._adm_20
  );

  %m_adm_restrict_derive_var_pchg(
    dataset=work._adm_20
  , filter=%str(AVISITN > 0)
  , out=work._adm_21
  );

  /* ---- restrict_derivation(derive_var_extreme_flag -> ANL01FL) ---- */
  %m_adm_restrict_extreme_flag(
    dataset=work._adm_21
  , by_vars=USUBJID PARAMCD AVISIT ATPT DTYPE
  , order=ADT AVAL
  , new_var=ANL01FL
  , mode=last
  , filter=%str(
      not missing(AVISITN)
      and (ONTRTFL = 'Y' or ABLFL = 'Y')
      and upcase(strip(DTYPE)) = 'AVERAGE'
    )
  , out=work._adm_22
  );

  /* ---- mutate(TRTP, TRTA) ---- */
  %m_adm_adeg_mutate_trt(dataset=work._adm_22, out=work._adm_23);

  /* ---- derive_var_obs_number(ASEQ) ---- */
  %m_adm_derive_var_obs_number(
    dataset=work._adm_23
  , new_var=ASEQ
  , by_vars=STUDYID USUBJID
  , order=PARAMCD ADT AVISITN VISITNUM ATPTN DTYPE
  , out=work._adm_24
  );

  /* ---- derive_vars_cat AVALCAT1 / CHGCAT1 ---- */
  %m_adm_derive_vars_cat(dataset=work._adm_24, kind=AVALCAT1, out=work._adm_25);
  %m_adm_derive_vars_cat(dataset=work._adm_25, kind=CHGCAT1, out=work._adm_26);

  /* ---- overlay PARAM PARAMN (always replace blanks from derive_param) ---- */
  proc sort data=work._adm_param_lookup out=work._adm_plu nodupkey;
    by PARAMCD;
  run;
  proc sort data=work._adm_26 out=work._adm_pbase;
    by PARAMCD;
  run;
  data work._adm_27;
    merge work._adm_pbase(in=a) work._adm_plu(keep=PARAMCD PARAM PARAMN);
    by PARAMCD;
    if a;
  run;
  proc datasets lib=work nolist;
    delete _adm_plu _adm_pbase;
  quit;
  %put NOTE: ADEG PARAM PARAMN overlay ADM_PARAM_OVERLAY=20260825N.;
  %if %sysfunc(exist(work._adm_27)) = 0 %then %do;
    %put ERROR: m_adeg_admiral_mirror overlay did not create work._adm_27.;
    %return;
  %end;

  /* ---- remaining ADSL vars
       Template: select(adsl, !!!negate_vars(adsl_vars)). ---- */
  %m_adm_merge_remaining_adsl(
    dataset=work._adm_27
  , adsl=&adsl
  , refds=ref_pva.refadeg
  , out=work._adm_28
  );

  /* Presentation order (not an Admiral derive step) */
  %m_order_vars_like_ref(
    data=work._adm_28
  , out=&out
  , refds=ref_pva.refadeg
  , fallback=STUDYID USUBJID SUBJID SITEID TRTP TRTA TRTSDT TRTEDT
             ADT ADTM ADY AVISIT AVISITN ATPT ATPTN PARAM PARAMCD PARAMN
             AVAL AVALC BASE BASEC BASETYPE CHG PCHG DTYPE ANRIND BNRIND
             ANRLO ANRHI ABLFL ANL01FL ONTRTFL ASEQ EGSEQ VISITNUM VISIT
  );

  proc sort data=&out;
    by USUBJID PARAMCD AVISITN AVISIT ADT ATPTN DTYPE ASEQ;
  run;

  proc datasets lib=work nolist;
    delete _adm_param_lookup _adm_range_lookup
           _adm_eg0 _adm_01 _adm_02 _adm_03 _adm_04 _adm_05
           _adm_06 _adm_07 _adm_08 _adm_09 _adm_10 _adm_11
           _adm_12 _adm_13 _adm_14 _adm_15 _adm_16 _adm_17
           _adm_18 _adm_19 _adm_20 _adm_21 _adm_22 _adm_23
           _adm_24 _adm_25 _adm_26 _adm_27 _adm_28;
  quit;

  %m_nobs(ds=&out);
  %put NOTE: m_adeg_admiral_mirror complete -> &out;

%mend m_adeg_admiral_mirror;
