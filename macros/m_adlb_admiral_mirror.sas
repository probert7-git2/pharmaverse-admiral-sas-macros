/*--------------------------------------------------------------
  Program Name                : m_adlb_admiral_mirror.sas
  Purpose                     : ADLB via 1:1 Admiral ad_adlb.R call order
  Approach                    : Pure R-template reverse-engineering.
                                Does NOT steer from PVA REF BASE analysis.
  Template                    : admiral inst/templates/ad_adlb.R
                                (vendored: SAS/R/admiral_templates/ad_adlb.R)
  Macro                       : %m_adlb_admiral_mirror
  Input                       : lb adsl (Part B libs)
  Output default              : adam.adlb
  Note                        : Legacy approximate builder remains
                                %m_adlb_pva (selectable via ADLB_BUILDER=pva)
--------------------------------------------------------------*/
%macro m_adlb_admiral_mirror(
  lb=raw.lb
, adsl=adam.adsl
, out=adam.adlb
);

  %if %sysfunc(exist(&lb)) = 0 %then %do;
    %put ERROR: m_adlb_admiral_mirror - dataset &lb not found.;
    %return;
  %end;
  %if %sysfunc(exist(&adsl)) = 0 %then %do;
    %put ERROR: m_adlb_admiral_mirror - dataset &adsl not found.;
    %return;
  %end;

  %put NOTE: m_adlb_admiral_mirror - pure ad_adlb.R 1:1 sequence starting.;

  /* ---- param_lookup from ad_adlb.R ---- */
  data work._adm_lb_param_lookup;
    length LBTESTCD $8 PARAMCD $8 PARAM $80;
    LBTESTCD='ALB';     PARAMCD='ALB';     PARAM='Albumin (g/L)'; PARAMN=1; output;
    LBTESTCD='ALP';     PARAMCD='ALKPH';   PARAM='Alkaline Phosphatase (U/L)'; PARAMN=2; output;
    LBTESTCD='ALT';     PARAMCD='ALT';     PARAM='Alanine Aminotransferase (U/L)'; PARAMN=3; output;
    LBTESTCD='ANISO';   PARAMCD='ANISO';   PARAM='Anisocytes'; PARAMN=4; output;
    LBTESTCD='AST';     PARAMCD='AST';     PARAM='Aspartate Aminotransferase (U/L)'; PARAMN=5; output;
    LBTESTCD='BASO';    PARAMCD='BASO';    PARAM='Basophils Abs (10^9/L)'; PARAMN=6; output;
    LBTESTCD='BASOLE';  PARAMCD='BASOLE';  PARAM='Basophils/Leukocytes (FRACTION)'; PARAMN=7; output;
    LBTESTCD='BILI';    PARAMCD='BILI';    PARAM='Bilirubin (umol/L)'; PARAMN=8; output;
    LBTESTCD='BUN';     PARAMCD='BUN';     PARAM='Blood Urea Nitrogen (mmol/L)'; PARAMN=9; output;
    LBTESTCD='CA';      PARAMCD='CA';      PARAM='Calcium (mmol/L)'; PARAMN=10; output;
    LBTESTCD='CHOL';    PARAMCD='CHOLES';  PARAM='Cholesterol (mmol/L)'; PARAMN=11; output;
    LBTESTCD='CK';      PARAMCD='CK';      PARAM='Creatinine Kinase (U/L)'; PARAMN=12; output;
    LBTESTCD='CL';      PARAMCD='CL';      PARAM='Chloride (mmol/L)'; PARAMN=13; output;
    LBTESTCD='COLOR';   PARAMCD='COLOR';   PARAM='Color'; PARAMN=14; output;
    LBTESTCD='CREAT';   PARAMCD='CREAT';   PARAM='Creatinine (umol/L)'; PARAMN=15; output;
    LBTESTCD='EOS';     PARAMCD='EOS';     PARAM='Eosinophils (10^9/L)'; PARAMN=16; output;
    LBTESTCD='EOSLE';   PARAMCD='EOSLE';   PARAM='Eosinophils/Leukocytes (FRACTION)'; PARAMN=17; output;
    LBTESTCD='GGT';     PARAMCD='GGT';     PARAM='Gamma Glutamyl Transferase (U/L)'; PARAMN=18; output;
    LBTESTCD='GLUC';    PARAMCD='GLUC';    PARAM='Glucose (mmol/L)'; PARAMN=19; output;
    LBTESTCD='HBA1C';   PARAMCD='HBA1C';   PARAM='Hemoglobin A1C (1)'; PARAMN=20; output;
    LBTESTCD='HCT';     PARAMCD='HCT';     PARAM='Hematocrit (1)'; PARAMN=21; output;
    LBTESTCD='HGB';     PARAMCD='HGB';     PARAM='Hemoglobin (mmol/L)'; PARAMN=22; output;
    LBTESTCD='K';       PARAMCD='POTAS';   PARAM='Potassium (mmol/L)'; PARAMN=23; output;
    LBTESTCD='KETONES'; PARAMCD='KETON';   PARAM='Ketones'; PARAMN=24; output;
    LBTESTCD='LYM';     PARAMCD='LYMPH';   PARAM='Lymphocytes Abs (10^9/L)'; PARAMN=25; output;
    LBTESTCD='LYMLE';   PARAMCD='LYMPHLE'; PARAM='Lymphocytes/Leukocytes (FRACTION)'; PARAMN=26; output;
    LBTESTCD='MACROCY'; PARAMCD='MACROC';  PARAM='Macrocytes'; PARAMN=27; output;
    LBTESTCD='MCH';     PARAMCD='MCH';     PARAM='Ery. Mean Corpuscular Hemoglobin (fmol(Fe))'; PARAMN=28; output;
    LBTESTCD='MCHC';    PARAMCD='MCHC';    PARAM='Ery. Mean Corpuscular HGB Concentration (mmol/L)'; PARAMN=29; output;
    LBTESTCD='MCV';     PARAMCD='MCV';     PARAM='Ery. Mean Corpuscular Volume (f/L)'; PARAMN=30; output;
    LBTESTCD='MICROCY'; PARAMCD='MICROC';  PARAM='Microcytes'; PARAMN=31; output;
    LBTESTCD='MONO';    PARAMCD='MONO';    PARAM='Monocytes (10^9/L)'; PARAMN=32; output;
    LBTESTCD='MONOLE';  PARAMCD='MONOLE';  PARAM='Monocytes/Leukocytes (FRACTION)'; PARAMN=33; output;
    LBTESTCD='PH';      PARAMCD='PH';      PARAM='pH'; PARAMN=34; output;
    LBTESTCD='PHOS';    PARAMCD='PHOS';    PARAM='Phosphate (mmol/L)'; PARAMN=35; output;
    LBTESTCD='PLAT';    PARAMCD='PLAT';    PARAM='Platelet (10^9/L)'; PARAMN=36; output;
    LBTESTCD='POIKILO'; PARAMCD='POIKIL';  PARAM='Poikilocytes'; PARAMN=37; output;
    LBTESTCD='POLYCHR'; PARAMCD='POLYCH';  PARAM='Polychromasia'; PARAMN=38; output;
    LBTESTCD='PROT';    PARAMCD='PROT';    PARAM='Protein (g/L)'; PARAMN=39; output;
    LBTESTCD='RBC';     PARAMCD='RBC';     PARAM='Erythrocytes (TI/L)'; PARAMN=40; output;
    LBTESTCD='SODIUM';  PARAMCD='SODIUM';  PARAM='Sodium (mmol/L)'; PARAMN=41; output;
    LBTESTCD='SPGRAV';  PARAMCD='SPGRAV';  PARAM='Specific Gravity'; PARAMN=42; output;
    LBTESTCD='TSH';     PARAMCD='TSH';     PARAM='Thyrotropin (mU/L)'; PARAMN=43; output;
    LBTESTCD='URATE';   PARAMCD='URATE';   PARAM='Urate (umol/L)'; PARAMN=44; output;
    LBTESTCD='UROBIL';  PARAMCD='UROBIL';  PARAM='Urobilinogen'; PARAMN=45; output;
    LBTESTCD='VITB12';  PARAMCD='VITB12';  PARAM='Vitamin B12 (pmol/L)'; PARAMN=46; output;
    LBTESTCD='WBC';     PARAMCD='WBC';     PARAM='Leukocytes (10^9/L)'; PARAMN=47; output;
  run;

  /* ---- convert_blanks_to_na(lb) ---- */
  %m_adm_convert_blanks_to_na(dataset=&lb, out=work._adm_lb0);

  /* Ensure DOMAIN present for by_vars (SDTM LB usually has it) */
  data work._adm_lb0b;
    set work._adm_lb0;
    length DOMAIN $2;
    if missing(DOMAIN) or strip(DOMAIN) = '' then DOMAIN = 'LB';
  run;

  /* ---- derive_vars_merged(adsl_vars) ---- */
  %m_adm_derive_vars_merged(
    dataset=work._adm_lb0b
  , dataset_add=&adsl
  , by_vars=STUDYID USUBJID
  , new_vars=TRTSDT=TRTSDT TRTEDT=TRTEDT TRT01A=TRT01A TRT01P=TRT01P
  , filter_add=%str(1)
  , mode=first
  , out=work._adm_lb01
  );

  /* ---- derive_vars_dt / derive_vars_dy ---- */
  %m_adm_derive_vars_dt(
    dataset=work._adm_lb01
  , new_vars_prefix=A
  , dtc=LBDTC
  , highest_imputation=n
  , out=work._adm_lb02
  );

  %m_adm_derive_vars_dy(
    dataset=work._adm_lb02
  , reference_date=TRTSDT
  , source_vars=ADT
  , out=work._adm_lb03
  );

  /* ---- derive_vars_merged_lookup PARAMCD PARAM PARAMN ---- */
  %m_adm_derive_vars_merged_lookup(
    dataset=work._adm_lb03
  , dataset_add=work._adm_lb_param_lookup
  , by_vars=LBTESTCD
  , new_vars=PARAMCD=PARAMCD PARAM=PARAM PARAMN=PARAMN
  , print_not_mapped=N
  , out=work._adm_lb04
  );

  /* ---- mutate PARCAT1 AVAL AVALC ANRLO ANRHI ---- */
  %m_adm_adlb_mutate_aval(dataset=work._adm_lb04, out=work._adm_lb05);

  %local _param_by;
  %let _param_by = STUDYID USUBJID TRTSDT TRTEDT TRT01A TRT01P
                   DOMAIN VISIT VISITNUM ADT ADY;

  /* ---- derive_param_wbc_abs BASO / LYMPH (skip if abs exists) ---- */
  /* ad_adlb.R omits diff_type - admiral default is fraction (PARAM FRACTION). */
  %m_adm_derive_param_wbc_abs(
    dataset=work._adm_lb05
  , by_vars=&_param_by
  , wbc_code=WBC
  , diff_code=BASOLE
  , set_values=%str(PARAMCD=BASO)
  , diff_type=fraction
  , out=work._adm_lb06a
  );
  %m_adm_adlb_patch_wbc_abs(
    dataset=work._adm_lb06a
  , paramcd=BASO
  , param=%str(Basophils Abs (10^9/L))
  , paramn=6
  , out=work._adm_lb06
  );

  %m_adm_derive_param_wbc_abs(
    dataset=work._adm_lb06
  , by_vars=&_param_by
  , wbc_code=WBC
  , diff_code=LYMPHLE
  , set_values=%str(PARAMCD=LYMPH)
  , diff_type=fraction
  , out=work._adm_lb07a
  );
  %m_adm_adlb_patch_wbc_abs(
    dataset=work._adm_lb07a
  , paramcd=LYMPH
  , param=%str(Lymphocytes Abs (10^9/L))
  , paramn=25
  , out=work._adm_lb07
  );

  /* ---- mutate timing (SCREEN -> Baseline) ---- */
  %m_adm_adlb_mutate_timing(dataset=work._adm_lb07, out=work._adm_lb08);

  /* ---- derive_var_ontrtfl ---- */
  %m_adm_derive_var_ontrtfl(
    dataset=work._adm_lb08
  , new_var=ONTRTFL
  , start_date=ADT
  , ref_start_date=TRTSDT
  , ref_end_date=TRTEDT
  , ref_end_window=0
  , filter_pre_timepoint=%str(strip(AVISIT) = 'Baseline')
  , out=work._adm_lb09
  );

  /* ---- derive_var_anrind ---- */
  %m_adm_derive_var_anrind(dataset=work._adm_lb09, out=work._adm_lb10);

  /* ---- BASETYPE = LAST (template mutate, not multi basetype) ---- */
  %m_adm_derive_basetype_map(dataset=work._adm_lb10, mode=LAST, out=work._adm_lb11);

  /* ---- ABLFL last ADT<=TRTSDT ---- */
  %m_adm_restrict_extreme_flag(
    dataset=work._adm_lb11
  , by_vars=STUDYID USUBJID BASETYPE PARAMCD
  , order=ADT VISITNUM LBSEQ
  , new_var=ABLFL
  , mode=last
  , filter=%str(
      not missing(AVAL)
      and not missing(TRTSDT) and ADT <= TRTSDT
      and not missing(BASETYPE)
    )
  , out=work._adm_lb12
  );

  /* ---- BASE / BASEC / BNRIND ---- */
  %m_adm_derive_var_base(
    dataset=work._adm_lb12
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , source_var=AVAL
  , new_var=BASE
  , filter=%str(ABLFL = 'Y')
  , out=work._adm_lb13
  );

  %m_adm_derive_var_base(
    dataset=work._adm_lb13
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , source_var=AVALC
  , new_var=BASEC
  , filter=%str(ABLFL = 'Y')
  , order=ADT
  , out=work._adm_lb14
  );

  %m_adm_derive_var_base(
    dataset=work._adm_lb14
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , source_var=ANRIND
  , new_var=BNRIND
  , filter=%str(ABLFL = 'Y')
  , order=ADT
  , out=work._adm_lb15
  );

  /* ---- CHG / PCHG restricted AVISITN > 0 ---- */
  %m_adm_restrict_derive_var_chg(
    dataset=work._adm_lb15
  , filter=%str(AVISITN > 0)
  , out=work._adm_lb16
  );

  %m_adm_restrict_derive_var_pchg(
    dataset=work._adm_lb16
  , filter=%str(AVISITN > 0)
  , out=work._adm_lb17
  );

  /* ---- grade_lookup + ATOXGR/BTOXGR (ad_adlb.R CTCAE path) ---- */
  %m_adm_adlb_merge_grade_lookup(dataset=work._adm_lb17, out=work._adm_lb18);
  %m_adm_adlb_derive_atoxgr(dataset=work._adm_lb18, out=work._adm_lb19a);

  %m_adm_derive_var_base(
    dataset=work._adm_lb19a
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , source_var=ATOXGRL
  , new_var=BTOXGRL
  , filter=%str(ABLFL = 'Y')
  , out=work._adm_lb19b
  );
  %m_adm_derive_var_base(
    dataset=work._adm_lb19b
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , source_var=ATOXGRH
  , new_var=BTOXGRH
  , filter=%str(ABLFL = 'Y')
  , out=work._adm_lb19c
  );
  %m_adm_derive_var_base(
    dataset=work._adm_lb19c
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , source_var=ATOXGR
  , new_var=BTOXGR
  , filter=%str(ABLFL = 'Y')
  , out=work._adm_lb19
  );

  /* ---- R2BASE / R2ANRLO / R2ANRHI (real) ---- */
  %m_adm_derive_var_analysis_ratio(
    dataset=work._adm_lb19
  , numer_var=AVAL
  , denom_var=BASE
  , new_var=R2BASE
  , out=work._adm_lb20
  );
  %m_adm_derive_var_analysis_ratio(
    dataset=work._adm_lb20
  , numer_var=AVAL
  , denom_var=ANRLO
  , new_var=R2ANRLO
  , out=work._adm_lb21
  );
  %m_adm_derive_var_analysis_ratio(
    dataset=work._adm_lb21
  , numer_var=AVAL
  , denom_var=ANRHI
  , new_var=R2ANRHI
  , out=work._adm_lb22
  );

  /* ---- SHIFT1 (BNRIND->ANRIND) + SHIFT2 (BTOXGR->ATOXGR, tox-mapped rows) ---- */
  %m_adm_derive_var_shift(
    dataset=work._adm_lb22
  , new_var=SHIFT1
  , from_var=BNRIND
  , to_var=ANRIND
  , out=work._adm_lb23
  );
  %m_adm_derive_var_shift(
    dataset=work._adm_lb23
  , new_var=SHIFT2
  , from_var=BTOXGR
  , to_var=ATOXGR
  , out=work._adm_lb24a
  );
  data work._adm_lb24;
    set work._adm_lb24a;
    if missing(ATOXDSCL) and missing(ATOXDSCH) then call missing(SHIFT2);
  run;

  /* ---- ANL01FL / LVOTFL ---- */
  %m_adm_restrict_extreme_flag(
    dataset=work._adm_lb24
  , by_vars=USUBJID PARAMCD AVISIT
  , order=ADT AVAL
  , new_var=ANL01FL
  , mode=last
  , filter=%str(not missing(AVISITN) and ONTRTFL = 'Y')
  , out=work._adm_lb25
  );

  %m_adm_restrict_extreme_flag(
    dataset=work._adm_lb25
  , by_vars=USUBJID PARAMCD
  , order=ADT AVAL
  , new_var=LVOTFL
  , mode=last
  , filter=%str(ONTRTFL = 'Y')
  , out=work._adm_lb26
  );

  /* ---- mutate TRTP TRTA ---- */
  %m_adm_mutate_trt(dataset=work._adm_lb26, out=work._adm_lb27);

  /* ---- extreme records MINIMUM / MAXIMUM / LOV (COUNT-critical) ---- */
  %m_adm_derive_extreme_records(
    dataset=work._adm_lb27
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , order=AVAL ADT AVISITN
  , mode=first
  , filter_add=%str(not missing(AVAL) and ONTRTFL = 'Y')
  , set_avisit=%str(POST-BASELINE MINIMUM)
  , set_avisitn=9997
  , set_dtype=MINIMUM
  , out=work._adm_lb28
  );

  %m_adm_derive_extreme_records(
    dataset=work._adm_lb28
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , order=DESC:AVAL ADT AVISITN
  , mode=first
  , filter_add=%str(not missing(AVAL) and ONTRTFL = 'Y')
  , set_avisit=%str(POST-BASELINE MAXIMUM)
  , set_avisitn=9998
  , set_dtype=MAXIMUM
  , out=work._adm_lb29
  );

  %m_adm_derive_extreme_records(
    dataset=work._adm_lb29
  , by_vars=STUDYID USUBJID PARAMCD BASETYPE
  , order=ADT AVISITN
  , mode=last
  , filter_add=%str(ONTRTFL = 'Y')
  , set_avisit=%str(POST-BASELINE LAST)
  , set_avisitn=9999
  , set_dtype=LOV
  , out=work._adm_lb30
  );

  /* ---- ASEQ ---- */
  %m_adm_derive_var_obs_number(
    dataset=work._adm_lb30
  , new_var=ASEQ
  , by_vars=STUDYID USUBJID
  , order=PARAMCD ADT AVISITN VISITNUM
  , out=work._adm_lb31
  );

  /* ---- overlay PARAM PARAMN on all rows (source + derived) ---- */
  proc sort data=work._adm_lb_param_lookup out=work._adm_plu nodupkey;
    by PARAMCD;
  run;
  proc sort data=work._adm_lb31 out=work._adm_pbase;
    by PARAMCD;
  run;
  data work._adm_lb31p;
    merge work._adm_pbase(in=a) work._adm_plu(keep=PARAMCD PARAM PARAMN);
    by PARAMCD;
    if a;
  run;
  proc datasets lib=work nolist;
    delete _adm_plu _adm_pbase;
  quit;
  %put NOTE: ADLB PARAM PARAMN overlay ADM_PARAM_OVERLAY=20260825N.;
  %if %sysfunc(exist(work._adm_lb31p)) = 0 %then %do;
    %put ERROR: m_adlb_admiral_mirror overlay did not create work._adm_lb31p.;
    %return;
  %end;

  /* ---- remaining ADSL vars
       Template: select(adsl, !!!negate_vars(adsl_vars)). ---- */
  %m_adm_merge_remaining_adsl(
    dataset=work._adm_lb31p
  , adsl=&adsl
  , refds=ref_pva.refadlb
  , out=work._adm_lb32
  );

  %m_order_vars_like_ref(
    data=work._adm_lb32
  , out=&out
  , refds=ref_pva.refadlb
  , fallback=STUDYID USUBJID SUBJID SITEID TRTP TRTA TRTSDT TRTEDT
             ADT ADY AVISIT AVISITN PARAM PARAMCD PARAMN PARCAT1
             AVAL AVALC BASE BASEC BASETYPE CHG PCHG DTYPE
             ANRIND BNRIND ANRLO ANRHI ABLFL ANL01FL LVOTFL ONTRTFL
             ATOXDSCL ATOXDSCH ATOXGRL ATOXGRH ATOXGR
             BTOXGRL BTOXGRH BTOXGR SHIFT1 SHIFT2
             ASEQ LBSEQ VISITNUM VISIT
  );

  proc sort data=&out;
    by USUBJID PARAMCD AVISITN AVISIT ADT DTYPE ASEQ;
  run;

  proc datasets lib=work nolist;
    delete _adm_lb_param_lookup
           _adm_lb0 _adm_lb0b _adm_lb01 _adm_lb02 _adm_lb03 _adm_lb04
           _adm_lb05 _adm_lb06a _adm_lb06 _adm_lb07a _adm_lb07
           _adm_lb08 _adm_lb09 _adm_lb10 _adm_lb11 _adm_lb12
           _adm_lb13 _adm_lb14 _adm_lb15 _adm_lb16 _adm_lb17
           _adm_lb18 _adm_lb19a _adm_lb19b _adm_lb19c _adm_lb19
           _adm_lb20 _adm_lb21 _adm_lb22
           _adm_lb23 _adm_lb24a _adm_lb24 _adm_lb25 _adm_lb26 _adm_lb27
           _adm_lb28 _adm_lb29 _adm_lb30 _adm_lb31 _adm_lb31p _adm_lb32;
  quit;

  %m_nobs(ds=&out);
  %put NOTE: m_adlb_admiral_mirror complete -> &out;

%mend m_adlb_admiral_mirror;
