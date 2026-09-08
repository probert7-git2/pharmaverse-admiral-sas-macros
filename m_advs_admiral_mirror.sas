/*--------------------------------------------------------------
  Program Name                : m_advs_admiral_mirror.sas
  Purpose                     : ADVS via 1:1 Admiral ad_advs.R call order
  Approach                    : Pure R-template reverse-engineering.
                                Does NOT steer from PVA REF BASE analysis.
  Template                    : admiral inst/templates/ad_advs.R
                                (vendored: SAS/R/admiral_templates/ad_advs.R)
  Macro                       : %m_advs_admiral_mirror
  Input                       : vs adsl (Part B libs)
  Output default              : adam.advs
  Note                        : Legacy approximate builder remains
                                %m_advs_pva (selectable via ADVS_BUILDER=pva)
--------------------------------------------------------------*/
%macro m_advs_admiral_mirror(
  vs=raw.vs
, adsl=adam.adsl
, out=adam.advs
);

  %if %sysfunc(exist(&vs)) = 0 %then %do;
    %put ERROR: m_advs_admiral_mirror - dataset &vs not found.;
    %return;
  %end;
  %if %sysfunc(exist(&adsl)) = 0 %then %do;
    %put ERROR: m_advs_admiral_mirror - dataset &adsl not found.;
    %return;
  %end;

  %put NOTE: m_advs_admiral_mirror - pure ad_advs.R 1:1 sequence starting.;

  /* ---- Lookups from ad_advs.R ---- */
  data work._adm_vs_param_lookup;
    length VSTESTCD $8 PARAMCD $8 PARAM $80;
    VSTESTCD='SYSBP';  PARAMCD='SYSBP';  PARAM='Systolic Blood Pressure (mmHg)'; PARAMN=1; output;
    VSTESTCD='DIABP';  PARAMCD='DIABP';  PARAM='Diastolic Blood Pressure (mmHg)'; PARAMN=2; output;
    VSTESTCD='PULSE';  PARAMCD='PULSE';  PARAM='Pulse Rate (beats/min)'; PARAMN=3; output;
    VSTESTCD='WEIGHT'; PARAMCD='WEIGHT'; PARAM='Weight (kg)'; PARAMN=4; output;
    VSTESTCD='HEIGHT'; PARAMCD='HEIGHT'; PARAM='Height (cm)'; PARAMN=5; output;
    VSTESTCD='TEMP';   PARAMCD='TEMP';   PARAM='Temperature (C)'; PARAMN=6; output;
    VSTESTCD='MAP';    PARAMCD='MAP';    PARAM='Mean Arterial Pressure (mmHg)'; PARAMN=7; output;
    VSTESTCD='BMI';    PARAMCD='BMI';    PARAM='Body Mass Index(kg/m^2)'; PARAMN=8; output;
    VSTESTCD='BSA';    PARAMCD='BSA';    PARAM='Body Surface Area(m^2)'; PARAMN=9; output;
  run;

  data work._adm_vs_range_lookup;
    length PARAMCD $8;
    PARAMCD='SYSBP'; ANRLO=90;   ANRHI=130; A1LO=70; A1HI=140; output;
    PARAMCD='DIABP'; ANRLO=60;   ANRHI=80;  A1LO=40; A1HI=90;  output;
    PARAMCD='PULSE'; ANRLO=60;   ANRHI=100; A1LO=40; A1HI=110; output;
    PARAMCD='TEMP';  ANRLO=36.5; ANRHI=37.5; A1LO=35; A1HI=38;  output;
  run;

  /* ---- convert_blanks_to_na(vs) ---- */
  %m_adm_convert_blanks_to_na(dataset=&vs, out=work._adm_vs0);

  /* ---- derive_vars_merged(adsl_vars) ---- */
  %m_adm_derive_vars_merged(
    dataset=work._adm_vs0
  , dataset_add=&adsl
  , by_vars=STUDYID USUBJID
  , new_vars=TRTSDT=TRTSDT TRTEDT=TRTEDT TRT01A=TRT01A TRT01P=TRT01P
  , filter_add=%str(1)
  , mode=first
  , out=work._adm_vs01
  );

  /* ---- derive_vars_dt(new_vars_prefix=A, dtc=VSDTC) ---- */
  %m_adm_derive_vars_dt(
    dataset=work._adm_vs01
  , new_vars_prefix=A
  , dtc=VSDTC
  , highest_imputation=n
  , out=work._adm_vs02
  );

  /* ---- derive_vars_dy(reference_date=TRTSDT, source_vars=ADT) ---- */
  %m_adm_derive_vars_dy(
    dataset=work._adm_vs02
  , reference_date=TRTSDT
  , source_vars=ADT
  , out=work._adm_vs03
  );

  /* ---- derive_vars_merged_lookup(PARAMCD only) ---- */
  %m_adm_derive_vars_merged_lookup(
    dataset=work._adm_vs03
  , dataset_add=work._adm_vs_param_lookup
  , by_vars=VSTESTCD
  , new_vars=PARAMCD=PARAMCD
  , print_not_mapped=N
  , out=work._adm_vs04
  );

  /* ---- mutate(AVAL) ---- */
  %m_adm_advs_mutate_aval(dataset=work._adm_vs04, out=work._adm_vs05);

  /* by_vars shared by derive_param_* in ad_advs.R */
  %local _param_by;
  %let _param_by = STUDYID USUBJID TRTSDT TRTEDT TRT01A TRT01P
                   VISIT VISITNUM ADT ADY VSTPT VSTPTNUM;

  /* ---- derive_param_map / bsa / bmi (PARAMCD only - PARAM later) ---- */
  %m_adm_derive_param_map(
    dataset=work._adm_vs05
  , by_vars=&_param_by
  , set_values=%str(PARAMCD=MAP)
  , filter=%str(VSSTAT ne 'NOT DONE' or missing(VSSTAT))
  , out=work._adm_vs06
  );

  %m_adm_derive_param_bsa(
    dataset=work._adm_vs06
  , by_vars=&_param_by
  , set_values=%str(PARAMCD=BSA)
  , constant_by_vars=USUBJID
  , filter=%str(VSSTAT ne 'NOT DONE' or missing(VSSTAT))
  , out=work._adm_vs07
  );

  %m_adm_derive_param_bmi(
    dataset=work._adm_vs07
  , by_vars=&_param_by
  , set_values=%str(PARAMCD=BMI)
  , constant_by_vars=USUBJID
  , filter=%str(VSSTAT ne 'NOT DONE' or missing(VSSTAT))
  , out=work._adm_vs08
  );

  /* ---- mutate timing ---- */
  %m_adm_advs_mutate_timing(dataset=work._adm_vs08, out=work._adm_vs09);

  /* ---- derive_summary_records (mean / DTYPE=AVERAGE, filter !is.na(AVAL)) ---- */
  %m_adm_derive_summary_records(
    dataset=work._adm_vs09
  , by_vars=STUDYID USUBJID TRTSDT TRTEDT TRT01A TRT01P PARAMCD AVISITN AVISIT ADT ADY
  , analysis_var=AVAL
  , summary_fun=mean
  , dtype_value=AVERAGE
  , having_n_ge=1
  , where_filter=%str(not missing(AVAL))
  , out=work._adm_vs10
  );

  /* ---- derive_var_ontrtfl (no ref_end_window in ad_advs.R - default 0) ---- */
  %m_adm_derive_var_ontrtfl(
    dataset=work._adm_vs10
  , new_var=ONTRTFL
  , start_date=ADT
  , ref_start_date=TRTSDT
  , ref_end_date=TRTEDT
  , ref_end_window=0
  , filter_pre_timepoint=%str(strip(AVISIT) = 'Baseline')
  , out=work._adm_vs11
  );

  /* ---- derive_vars_merged(range_lookup) + derive_var_anrind ---- */
  %m_adm_derive_vars_merged(
    dataset=work._adm_vs11
  , dataset_add=work._adm_vs_range_lookup
  , by_vars=PARAMCD
  , new_vars=ANRLO=ANRLO ANRHI=ANRHI A1LO=A1LO A1HI=A1HI
  , filter_add=%str(1)
  , mode=first
  , out=work._adm_vs12
  );

  /* ANRLO/ANRHI path (A1LO/A1HI full branch not mirrored - same as ADEG port) */
  %m_adm_derive_var_anrind(dataset=work._adm_vs12, out=work._adm_vs13);

  /* ---- derive_basetype_records (ATPTN map) ---- */
  %m_adm_derive_basetype_map(
    dataset=work._adm_vs13
  , mode=ADVS
  , out=work._adm_vs14
  );

  /* ---- restrict_derivation ABLFL: last ADT<=TRTSDT blank DTYPE ---- */
  %m_adm_restrict_extreme_flag(
    dataset=work._adm_vs14
  , by_vars=STUDYID USUBJID BASETYPE PARAMCD
  , order=ADT VISITNUM VSSEQ
  , new_var=ABLFL
  , mode=last
  , filter=%str(
      not missing(AVAL)
      and not missing(TRTSDT) and ADT <= TRTSDT
      and not missing(BASETYPE)
      and missing(DTYPE)
    )
  , out=work._adm_vs15
  );

  /* ---- derive_var_base BASE / BNRIND (BASEC commented out in template) ---- */
  %m_adm_derive_var_base(
    dataset=work._adm_vs15
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , source_var=AVAL
  , new_var=BASE
  , filter=%str(ABLFL = 'Y')
  , out=work._adm_vs16
  );

  %m_adm_derive_var_base(
    dataset=work._adm_vs16
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , source_var=ANRIND
  , new_var=BNRIND
  , filter=%str(ABLFL = 'Y')
  , order=ADT
  , out=work._adm_vs17
  );

  /* ---- restrict_derivation CHG / PCHG, filter AVISITN > 0 ---- */
  %m_adm_restrict_derive_var_chg(
    dataset=work._adm_vs17
  , filter=%str(AVISITN > 0)
  , out=work._adm_vs18
  );

  %m_adm_restrict_derive_var_pchg(
    dataset=work._adm_vs18
  , filter=%str(AVISITN > 0)
  , out=work._adm_vs19
  );

  /* ---- restrict_derivation ANL01FL ---- */
  %m_adm_restrict_extreme_flag(
    dataset=work._adm_vs19
  , by_vars=USUBJID PARAMCD AVISIT ATPT DTYPE
  , order=ADT AVAL
  , new_var=ANL01FL
  , mode=last
  , filter=%str(not missing(AVISITN) and ONTRTFL = 'Y')
  , out=work._adm_vs20
  );

  /* ---- derive_extreme_records EoT LOV (COUNT-critical) ---- */
  %m_adm_derive_extreme_records(
    dataset=work._adm_vs20
  , by_vars=STUDYID USUBJID PARAMCD ATPTN
  , order=ADT AVISITN AVAL
  , mode=last
  , filter_add=%str(
      AVISITN > 4 and AVISITN <= 13
      and ANL01FL = 'Y'
      and missing(DTYPE)
    )
  , set_avisit=%str(End of Treatment)
  , set_avisitn=99
  , set_dtype=LOV
  , out=work._adm_vs21
  );

  /* ---- mutate TRTP TRTA ---- */
  %m_adm_mutate_trt(dataset=work._adm_vs21, out=work._adm_vs22);

  /* ---- derive_var_obs_number ASEQ ---- */
  %m_adm_derive_var_obs_number(
    dataset=work._adm_vs22
  , new_var=ASEQ
  , by_vars=STUDYID USUBJID
  , order=PARAMCD ADT AVISITN VISITNUM ATPTN DTYPE
  , out=work._adm_vs23
  );

  /* ---- derive_vars_cat HEIGHT ---- */
  %m_adm_advs_derive_vars_cat(dataset=work._adm_vs23, out=work._adm_vs24);

  /* ---- overlay PARAM PARAMN (always replace blanks / keep CT) ---- */
  proc sort data=work._adm_vs_param_lookup out=work._adm_plu nodupkey;
    by PARAMCD;
  run;
  proc sort data=work._adm_vs24 out=work._adm_pbase;
    by PARAMCD;
  run;
  data work._adm_vs25;
    merge work._adm_pbase(in=a) work._adm_plu(keep=PARAMCD PARAM PARAMN);
    by PARAMCD;
    if a;
  run;
  proc datasets lib=work nolist;
    delete _adm_plu _adm_pbase;
  quit;
  %put NOTE: ADVS PARAM PARAMN overlay ADM_PARAM_OVERLAY=20260825N.;
  %if %sysfunc(exist(work._adm_vs25)) = 0 %then %do;
    %put ERROR: m_advs_admiral_mirror overlay did not create work._adm_vs25.;
    %return;
  %end;

  /* ---- remaining ADSL vars
       Template: select(adsl, !!!negate_vars(adsl_vars)). ---- */
  %m_adm_merge_remaining_adsl(
    dataset=work._adm_vs25
  , adsl=&adsl
  , refds=ref_pva.refadvs
  , out=work._adm_vs26
  );

  %m_order_vars_like_ref(
    data=work._adm_vs26
  , out=&out
  , refds=ref_pva.refadvs
  , fallback=STUDYID USUBJID SUBJID SITEID TRTP TRTA TRTSDT TRTEDT
             ADT ADY AVISIT AVISITN ATPT ATPTN PARAM PARAMCD PARAMN
             AVAL BASE BASETYPE CHG PCHG DTYPE ANRIND BNRIND
             ANRLO ANRHI ABLFL ANL01FL ONTRTFL ASEQ VSSEQ VISITNUM VISIT
  );

  proc sort data=&out;
    by USUBJID PARAMCD AVISITN AVISIT ATPTN ADT DTYPE ASEQ;
  run;

  proc datasets lib=work nolist;
    delete _adm_vs_param_lookup _adm_vs_range_lookup
           _adm_vs0 _adm_vs01 _adm_vs02 _adm_vs03 _adm_vs04 _adm_vs05
           _adm_vs06 _adm_vs07 _adm_vs08 _adm_vs09 _adm_vs10 _adm_vs11
           _adm_vs12 _adm_vs13 _adm_vs14 _adm_vs15 _adm_vs16 _adm_vs17
           _adm_vs18 _adm_vs19 _adm_vs20 _adm_vs21 _adm_vs22 _adm_vs23
           _adm_vs24 _adm_vs25 _adm_vs26;
  quit;

  %m_nobs(ds=&out);
  %put NOTE: m_advs_admiral_mirror complete -> &out;

%mend m_advs_admiral_mirror;
