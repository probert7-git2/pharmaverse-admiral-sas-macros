/*--------------------------------------------------------------
  Program Name                : m_advs_pva.sas
  Purpose                     : Part B ADVS BDS vital signs (PVA-aligned)
  Origin                      : Adapted from Track A m_advs2.sas
  Note                        : Lives only in SAS_mirrored_Admiral_safety_ADaM.
                                Do not edit safety_monitoring_system for Part B.
  Macro                       : %m_advs_pva
  Input                       : raw.vs adam.adsl
  Output default              : adam.advs (Part B adam lib)
  Modification Log            : 24AUG2026 - Derive MAP/BMI/BSA (admiral template
                                ports). Sort/QC include ATPTN so orthostatic
                                positions do not collide. No orthostatic PARAMCD
                                on PVA - positions are ATPT only.
                                24AUG2026 - Baseline/CHG/PCHG vs PVA gold:
                                BASETYPE from ATPTN (admiral basetype map),
                                ABLFL = last ADT<=TRTSDT non-DTYPE per
                                USUBJID/PARAMCD/BASETYPE (not all pre-dose),
                                DTYPE=AVERAGE summary rows (screenings kept),
                                CHG/PCHG only when AVISITN>0, PCHG round 0.1.
                                24AUG2026 - Unit policy: PARAM embeds *standard*
                                unit; AVALU = standard unit; if SDTM VSSTRESU
                                differs, convert AVAL into the standard unit
                                (vitals: F->C, lb->kg, in->cm, etc.) so AVAL
                                and PARAM/AVALU stay consistent. Unmapped unit
                                pairs WARN and leave AVAL as-is pending map.
                                24AUG2026 - Part B %m_advs_pva from m_advs2.
                                Display sort USUBJID PARAMN PARAM AVISITN AVISIT
                                ATPTN ADT VSSEQ. No ADTM on PVA ADVS.
--------------------------------------------------------------*/
%macro m_advs_pva(
  vs=raw.vs
, adsl=adam.adsl
, out=adam.advs
);

  %if %sysfunc(exist(&vs)) = 0 %then %do;
    %put ERROR: m_advs_pva - dataset &vs not found.;
    %return;
  %end;
  %if %sysfunc(exist(&adsl)) = 0 %then %do;
    %put ERROR: m_advs_pva - dataset &adsl not found.;
    %return;
  %end;

  %put NOTE: m_advs_pva starting vs=&vs adsl=&adsl out=&out;

  /* PARAMN + standard unit. AVAL will be converted to this unit when source
     VSSTRESU differs (see _vs1q). */
  data work._paramn_vs;
    length PARAMCD $8 AVALU_STD $20;
    PARAMCD = 'SYSBP';  PARAMN = 1; AVALU_STD = 'mmHg';      output;
    PARAMCD = 'DIABP';  PARAMN = 2; AVALU_STD = 'mmHg';      output;
    PARAMCD = 'PULSE';  PARAMN = 3; AVALU_STD = 'beats/min'; output;
    PARAMCD = 'WEIGHT'; PARAMN = 4; AVALU_STD = 'kg';        output;
    PARAMCD = 'HEIGHT'; PARAMN = 5; AVALU_STD = 'cm';        output;
    PARAMCD = 'TEMP';   PARAMN = 6; AVALU_STD = 'C';         output;
    PARAMCD = 'MAP';    PARAMN = 7; AVALU_STD = 'mmHg';      output;
    PARAMCD = 'BMI';    PARAMN = 8; AVALU_STD = 'kg/m^2';    output;
    PARAMCD = 'BSA';    PARAMN = 9; AVALU_STD = 'm^2';       output;
  run;

  /* ADT via DTC->DT (admiral derive_vars_dt). Not DTM - PVA ADVS has no ADTM. */
  %m_derive_vars_dt(
    dataset=&vs
  , new_vars_prefix=A
  , dtc=VSDTC
  , highest_imputation=n
  , out=work._vs0
  );

  data work._vs1;
    set work._vs0;
    if not missing(VSSTRESN) and not missing(ADT);
    AVAL = VSSTRESN;
    length PARAMCD $8 AVALU $20 AVISIT $40 _pdec $100;
    PARAMCD = VSTESTCD;
    AVALU   = VSSTRESU;
    /* Decode stem for PARAM (unit applied after PARAMN merge). */
    select (upcase(strip(PARAMCD)));
      when ('SYSBP')  _pdec = 'Systolic Blood Pressure';
      when ('DIABP')  _pdec = 'Diastolic Blood Pressure';
      when ('PULSE')  _pdec = 'Pulse Rate';
      when ('WEIGHT') _pdec = 'Weight';
      when ('HEIGHT') _pdec = 'Height';
      when ('TEMP')   _pdec = 'Temperature';
      when ('MAP')    _pdec = 'Mean Arterial Pressure';
      when ('BMI')    _pdec = 'Body Mass Index';
      when ('BSA')    _pdec = 'Body Surface Area';
      otherwise       _pdec = strip(VSTEST);
    end;
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
    /* Keep VSTPT* for ATPT/BASETYPE (PVA position-specific baselines). */
    keep STUDYID USUBJID VSSEQ PARAMCD ADT AVAL AVALU _pdec
         VISIT VISITNUM AVISIT AVISITN VSTPT VSTPTNUM;
  run;

  /* PARAMN + AVALU_STD from PARAMCD (PARAM text does not use raw VSSTRESU). */
  %m_derive_vars_merged_lookup(
    dataset=work._vs1
  , dataset_add=work._paramn_vs
  , by_vars=PARAMCD
  , new_vars=PARAMN=PARAMN AVALU_STD=AVALU_STD
  , print_not_mapped=N
  , out=work._vs1p
  );

  /* PARAM embeds standard unit. AVALU <- standard unit. If SDTM unit differs,
     convert AVAL into the standard unit so value and unit stay aligned. */
  data work._vs1q;
    set work._vs1p;
    length PARAM $100 _usrc $40 _ustd $40;
    if missing(_pdec) or strip(_pdec) = '' then _pdec = strip(PARAMCD);

    _usrc = upcase(compress(strip(AVALU), ' '));
    _ustd = upcase(compress(strip(AVALU_STD), ' '));
    /* Synonym fold for compare */
    if _usrc in ('CELSIUS', 'DEGC', 'DEG.C', '°C') then _usrc = 'C';
    if _usrc in ('FAHRENHEIT', 'DEGF', 'DEG.F', '°F') then _usrc = 'F';
    if _usrc in ('LBS', 'POUND', 'POUNDS') then _usrc = 'LB';
    if _usrc in ('INCH', 'INCHES', '"') then _usrc = 'IN';
    if _usrc in ('BEATS/MIN', 'BEAT/MIN', 'BPM') then _usrc = 'BEATS/MIN';
    if _ustd = 'BEATS/MIN' then _ustd = 'BEATS/MIN';

    if not missing(AVALU_STD) and strip(AVALU_STD) ne '' then
      PARAM = catx(' ', strip(_pdec), cats('(', strip(AVALU_STD), ')'));
    else
      PARAM = strip(_pdec);

    if missing(AVALU_STD) or strip(AVALU_STD) = '' then do;
      /* no standard on map - keep SDTM as-is */
    end;
    else if missing(AVALU) or strip(AVALU) = '' or _usrc = _ustd
            or (_ustd = 'BEATS/MIN' and _usrc in ('BEATS/MIN', 'BPM'))
            or (_ustd = 'MMHG' and _usrc = 'MMHG') then do;
      AVALU = AVALU_STD;
    end;
    else do;
      /* Convert observed AVAL from source unit into standard unit */
      if upcase(strip(PARAMCD)) = 'TEMP' and _usrc = 'F' and _ustd = 'C' then do;
        AVAL = (AVAL - 32) * 5/9;
        AVALU = AVALU_STD;
        put "NOTE: m_advs_pva TEMP F->C USUBJID=" USUBJID " AVAL(std)=" AVAL;
      end;
      else if upcase(strip(PARAMCD)) = 'WEIGHT' and _usrc = 'LB' and _ustd = 'KG' then do;
        AVAL = AVAL * 0.45359237;
        AVALU = AVALU_STD;
        put "NOTE: m_advs_pva WEIGHT lb->kg USUBJID=" USUBJID " AVAL(std)=" AVAL;
      end;
      else if upcase(strip(PARAMCD)) = 'HEIGHT' and _usrc = 'IN' and _ustd = 'CM' then do;
        AVAL = AVAL * 2.54;
        AVALU = AVALU_STD;
        put "NOTE: m_advs_pva HEIGHT in->cm USUBJID=" USUBJID " AVAL(std)=" AVAL;
      end;
      else do;
        put "WARNING: m_advs_pva no conversion PARAMCD=" PARAMCD
            " from=" AVALU " to=" AVALU_STD " USUBJID=" USUBJID
            " - AVAL left in source unit; AVALU set to standard (REVIEW).";
        /* Prefer consistency: still label as standard only after conversion.
           Without a factor, keep source AVALU to avoid lying about AVAL scale. */
      end;
    end;

    drop _pdec AVALU_STD _usrc _ustd;
  run;

  %m_derive_vars_merged(
    dataset=work._vs1q
  , dataset_add=&adsl
  , by_vars=STUDYID USUBJID
  , order=USUBJID
  , new_vars=SITEID=SITEID SUBJID=SUBJID
             TRTSDT=TRTSDT TRTEDT=TRTEDT TRT01A=TRT01A TRT01P=TRT01P
  , filter_add=%str(1)
  , mode=first
  , out=work._vs1b
  );

  /* Timing + treatment. ABLFL is NOT all pre-dose - flagged after AVERAGE. */
  data work._vs2;
    set work._vs1b;
    format ADT TRTSDT TRTEDT date9.;
    length ATPT $100 DTYPE $20 BASETYPE $100 ABLFL $1 TRTA $100 TRTP $100;
    ATPTN = VSTPTNUM;
    ATPT  = VSTPT;
    DTYPE = '';
    ABLFL = '';
    /* admiral derive_basetype_records map (CDISC pilot ATPTN codes) */
    if ATPTN = 815 then BASETYPE = 'LAST: AFTER LYING DOWN FOR 5 MINUTES';
    else if ATPTN = 816 then BASETYPE = 'LAST: AFTER STANDING FOR 1 MINUTE';
    else if ATPTN = 817 then BASETYPE = 'LAST: AFTER STANDING FOR 3 MINUTES';
    else BASETYPE = 'LAST';
    TRTA = TRT01A;
    TRTP = TRT01P;
    drop VSTPT VSTPTNUM;
  run;

  %m_derive_vars_dy(
    dataset=work._vs2
  , reference_date=TRTSDT
  , source_vars=ADT
  , out=work._vs2b
  );

  /* Drop any SDTM MAP/BMI/BSA so derived params match PVA (template-derived). */
  data work._vs2b_core;
    set work._vs2b;
    if upcase(strip(PARAMCD)) in ('MAP', 'BMI', 'BSA') then delete;
  run;

  /* Computed params - admiral derive_param_map/bsa/bmi. MAP by ATPT so
     orthostatic positions stay distinct. HEIGHT carried once per subject. */
  %m_derive_param_map(
    dataset=work._vs2b_core
  , by_vars=STUDYID USUBJID SUBJID SITEID VISIT VISITNUM ADT ADY
            ATPT ATPTN AVISIT AVISITN TRTSDT TRTEDT TRT01A TRT01P TRTA TRTP
  , out=work._vs_map
  );

  %m_derive_param_bsa(
    dataset=work._vs_map
  , by_vars=STUDYID USUBJID SUBJID SITEID VISIT VISITNUM ADT ADY
            ATPT ATPTN AVISIT AVISITN TRTSDT TRTEDT TRT01A TRT01P TRTA TRTP
  , constant_by_vars=USUBJID
  , out=work._vs_bsa
  );

  %m_derive_param_bmi(
    dataset=work._vs_bsa
  , by_vars=STUDYID USUBJID SUBJID SITEID VISIT VISITNUM ADT ADY
            ATPT ATPTN AVISIT AVISITN TRTSDT TRTEDT TRT01A TRT01P TRTA TRTP
  , constant_by_vars=USUBJID
  , out=work._vs_bmi
  );

  /* PARAMN/AVALU/BASETYPE for derived rows (ports only set PARAMCD/PARAM/AVAL). */
  data work._vs2b_x;
    set work._vs_bmi;
    format ADT TRTSDT TRTEDT date9.;
    length AVALU $20 DTYPE $20 BASETYPE $100 ABLFL $1;
    if missing(PARAMN) then do;
      select (upcase(strip(PARAMCD)));
        when ('MAP')  PARAMN = 7;
        when ('BMI')  PARAMN = 8;
        when ('BSA')  PARAMN = 9;
        otherwise;
      end;
    end;
    if missing(AVALU) or strip(AVALU) = '' then do;
      select (upcase(strip(PARAMCD)));
        when ('MAP')  AVALU = 'mmHg';
        when ('BMI')  AVALU = 'kg/m^2';
        when ('BSA')  AVALU = 'm^2';
        otherwise;
      end;
    end;
    /* Re-apply PARAM unit style used for observed vitals. */
    if upcase(strip(PARAMCD)) = 'MAP' then
      PARAM = 'Mean Arterial Pressure (mmHg)';
    else if upcase(strip(PARAMCD)) = 'BMI' then
      PARAM = 'Body Mass Index (kg/m^2)';
    else if upcase(strip(PARAMCD)) = 'BSA' then
      PARAM = 'Body Surface Area (m^2)';
    if missing(DTYPE) then DTYPE = '';
    if missing(ABLFL) then ABLFL = '';
    if missing(BASETYPE) or strip(BASETYPE) = '' then do;
      if ATPTN = 815 then BASETYPE = 'LAST: AFTER LYING DOWN FOR 5 MINUTES';
      else if ATPTN = 816 then BASETYPE = 'LAST: AFTER STANDING FOR 1 MINUTE';
      else if ATPTN = 817 then BASETYPE = 'LAST: AFTER STANDING FOR 3 MINUTES';
      else BASETYPE = 'LAST';
    end;
  run;

  /* DTYPE=AVERAGE: mean AVAL per subject/param/visit-date (admiral template).
     Adds rows - does NOT drop individual screening/position records.
     ABLFL excludes these rows (is.na(DTYPE) in PVA). */
  proc sql;
    create table work._vs_avg as
    select STUDYID, USUBJID, SUBJID, SITEID
         , PARAMCD, PARAM, PARAMN, AVALU
         , AVISIT, AVISITN, ADT, ADY
         , TRTSDT, TRTEDT, TRT01A, TRT01P, TRTA, TRTP
         , mean(AVAL) as AVAL
         , 'AVERAGE' as DTYPE length=20
         , 'LAST' as BASETYPE length=100
         , '' as ATPT length=100
         , . as ATPTN
         , . as VSSEQ
         , . as VISITNUM
         , '' as VISIT length=200
         , '' as ABLFL length=1
    from work._vs2b_x
    where not missing(AVAL)
    group by STUDYID, USUBJID, SUBJID, SITEID
           , PARAMCD, PARAM, PARAMN, AVALU
           , AVISIT, AVISITN, ADT, ADY
           , TRTSDT, TRTEDT, TRT01A, TRT01P, TRTA, TRTP
    ;
  quit;

  data work._vs2c;
    set work._vs2b_x work._vs_avg;
    format ADT TRTSDT TRTEDT date9.;
  run;

  /* ABLFL = last non-missing AVAL with ADT<=TRTSDT and blank DTYPE,
     per USUBJID PARAMCD BASETYPE (admiral restrict_derivation + extreme last). */
  proc sort data=work._vs2c out=work._vs2c_s;
    by USUBJID PARAMCD BASETYPE ADT VISITNUM VSSEQ;
  run;

  data work._abl_cand;
    set work._vs2c_s;
    where not missing(AVAL)
      and not missing(TRTSDT)
      and ADT <= TRTSDT
      and missing(DTYPE);
  run;

  data work._abl_flg;
    set work._abl_cand;
    by USUBJID PARAMCD BASETYPE;
    if last.BASETYPE;
    ABLFL = 'Y';
    keep USUBJID PARAMCD BASETYPE ADT VISITNUM VSSEQ ABLFL;
  run;

  data work._vs2d;
    merge work._vs2c_s(in=a) work._abl_flg;
    by USUBJID PARAMCD BASETYPE ADT VISITNUM VSSEQ;
    if a;
    if missing(ABLFL) then ABLFL = '';
  run;

  /* BASE per BASETYPE (position-specific for SYSBP/DIABP/PULSE). */
  %m_derive_var_base(
    dataset=work._vs2d
  , by_vars=USUBJID PARAMCD BASETYPE
  , source_var=AVAL
  , new_var=BASE
  , filter=%str(ABLFL = 'Y')
  , out=work._vs3
  );

  %m_derive_var_chg(dataset=work._vs3, out=work._vs4);
  %m_derive_var_pchg(dataset=work._vs4, out=work._vs5);

  /* PVA: CHG/PCHG only for AVISITN > 0 (screening + Baseline stay missing).
     SAS preference: PCHG rounded to 1 decimal on computed rows. */
  data work._vs5b;
    set work._vs5;
    if missing(AVISITN) or AVISITN <= 0 then do;
      CHG = .;
      PCHG = .;
    end;
    else if not missing(PCHG) then PCHG = round(PCHG, 0.1);
  run;

  %m_derive_var_ontrtfl(
    dataset=work._vs5b
  , new_var=ONTRTFL
  , start_date=ADT
  , ref_start_date=TRTSDT
  , ref_end_date=TRTEDT
  , out=work._vs6
  );

  /* admiral filter_pre_timepoint: AVISIT=Baseline is not on-treatment. */
  data work._vs6b;
    set work._vs6;
    if upcase(strip(AVISIT)) = 'BASELINE' then ONTRTFL = '';
  run;

  data work._advs_preord;
    set work._vs6b;
    keep STUDYID USUBJID SUBJID SITEID VSSEQ PARAMCD PARAM PARAMN
         VISIT VISITNUM AVISIT AVISITN ATPT ATPTN BASETYPE DTYPE
         ADT ADY AVAL AVALU BASE CHG PCHG ABLFL ONTRTFL
         TRTSDT TRTEDT TRTA TRTP;
  run;

  /* Column order = PVA REF (refadvs). SAS-only AVALU next to AVAL. */
  %m_order_vars_like_ref(
    data=work._advs_preord
  , out=&out
  , refds=ref_pva.refadvs
  , fallback=STUDYID USUBJID SUBJID SITEID TRTP TRTA TRTSDT TRTEDT ADT ADY
             AVISIT AVISITN ATPT ATPTN PARAM PARAMCD PARAMN AVAL BASE
             BASETYPE CHG PCHG DTYPE ABLFL ONTRTFL VSSEQ VISITNUM VISIT
  , extra_after=AVALU:AVAL
  );

  /* Display / SORTEDBY - ATPTN required so lying/standing rows do not collide. */
  proc sort data=&out;
    by USUBJID PARAMN PARAM AVISITN AVISIT ATPTN ADT VSSEQ;
  run;

  proc datasets lib=work nolist;
    delete _paramn_vs _vs0 _vs1 _vs1p _vs1q _vs1b _vs2 _vs2b _vs2b_core
           _vs_map _vs_bsa _vs_bmi _vs2b_x _vs_avg _vs2c
           _vs2c_s _abl_cand _abl_flg _vs2d _vs3 _vs4 _vs5 _vs5b _vs6 _vs6b
           _advs_preord;
  quit;

  %m_nobs(ds=&out);
  /* One semicolon only - mid-message ";" ends %put and leaves trailing text as code (ERROR 180). */
  %put NOTE: m_advs_pva complete -> &out (ABLFL last pre/on-TRTSDT by BASETYPE - PCHG 1dp).;

%mend m_advs_pva;
