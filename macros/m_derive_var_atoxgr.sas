/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_derive_var_atoxgr.sas
  SAS Version                 : 9.4
  Purpose (short description) : CTCAE-style ATOXGR ports aligned with pharmaverse/admiral
  Author                      : Cursor Grok 4.5
  Date                        : 10AUG2026
  Input Datasets or Metadata  : Lab BDS with AVAL ANRLO ANRHI BASE BNRIND PCHG AVALU
                                metadata/atoxgr_criteria_ctcv5.csv
                                metadata/atoxgr_param_map.csv
  Modification Log            : 18AUG2026 - %m_derive_var_atoxgr combine_method=MAXABS
                                mirrors Track A R combine_tox (max abs grade, high wins
                                ties). Default ADMIRAL keeps low-first for CTCAE path.
                                13AUG2026 - Import meta via rename+LENGTH to avoid length/convert notes.
                                10AUG2026 - CTCAE v5 structured criteria evaluator (not ULN/LLN-only).
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Phase 2 BDS — lab toxicity grading (substantial port of derive_var_atoxgr*)

  Pharmaverse path:
    - Map PARAMCD -> ATOXDSCL / ATOXDSCH (%m_map_atoxdsc)
    - Grade each direction with meta criteria (%m_derive_var_atoxgr_dir_ctcae)
    - Combine to ATOXGR (%m_derive_var_atoxgr): ADMIRAL low-first, or MAXABS
      for Track A gold combine_tox

  CRIT_TYPE values in meta (SAS-evaluable stand-in for GRADE_CRITERIA_CODE):
    ULN_MULT, LLN_MULT, ULN_BASE, CREAT, ABS_LOW_LLN, ABS_HIGH_ULN1,
    HGB_HIGH, INR, FIBRINOGEN

  Legacy ULN/LLN-only helpers retained: %m_derive_var_atoxgr_dir,
  %m_derive_var_atoxgr_dir_meta
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


/*******************************************************************************
  %m_load_atoxgr_meta — import CTCAE criteria + PARAM map CSVs to work datasets
*******************************************************************************/
%macro m_load_atoxgr_meta(
  criteria_csv=
, param_map_csv=
, criteria_out=work.atoxgr_criteria_ctcv5
, param_map_out=work.atoxgr_param_map
);
  %local crit_csv map_csv;

  %if %length(&criteria_csv) = 0 %then
    %let crit_csv = &ROOT/metadata/atoxgr_criteria_ctcv5.csv;
  %else %let crit_csv = &criteria_csv;

  %if %length(&param_map_csv) = 0 %then
    %let map_csv = &ROOT/metadata/atoxgr_param_map.csv;
  %else %let map_csv = &param_map_csv;

  %if %sysfunc(fileexist(&crit_csv)) = 0 %then %do;
    %put ERROR: m_load_atoxgr_meta - criteria CSV not found: &crit_csv;
    %return;
  %end;
  %if %sysfunc(fileexist(&map_csv)) = 0 %then %do;
    %put ERROR: m_load_atoxgr_meta - param map CSV not found: &map_csv;
    %return;
  %end;

  proc import datafile="&crit_csv"
              out=work._atox_crit_imp
              dbms=csv replace;
       guessingrows=max;
       getnames=yes;
  run;

  proc import datafile="&map_csv"
              out=work._atox_map_imp
              dbms=csv replace;
       guessingrows=max;
       getnames=yes;
  run;

  data &criteria_out;
       length TERM $80 DIRECTION $1 CRIT_TYPE $20 UNIT_CHECK $40 VAR_CHECK $80 COMMENT $200
              G1 8 G2 8 G3 8 G4 8 G1_BASE 8 G2_BASE 8 G3_BASE 8 G4_BASE 8;
       set work._atox_crit_imp (rename=(
            TERM=__TERM DIRECTION=__DIRECTION CRIT_TYPE=__CRIT_TYPE
            UNIT_CHECK=__UNIT_CHECK VAR_CHECK=__VAR_CHECK COMMENT=__COMMENT
            G1=__G1 G2=__G2 G3=__G3 G4=__G4
            G1_BASE=__G1B G2_BASE=__G2B G3_BASE=__G3B G4_BASE=__G4B
       ));
       TERM       = strip(__TERM);
       DIRECTION  = upcase(strip(__DIRECTION));
       CRIT_TYPE  = upcase(strip(__CRIT_TYPE));
       UNIT_CHECK = strip(__UNIT_CHECK);
       VAR_CHECK  = strip(__VAR_CHECK);
       COMMENT    = strip(__COMMENT);
       G1 = input(cats(__G1), ?? best32.);
       G2 = input(cats(__G2), ?? best32.);
       G3 = input(cats(__G3), ?? best32.);
       G4 = input(cats(__G4), ?? best32.);
       G1_BASE = input(cats(__G1B), ?? best32.);
       G2_BASE = input(cats(__G2B), ?? best32.);
       G3_BASE = input(cats(__G3B), ?? best32.);
       G4_BASE = input(cats(__G4B), ?? best32.);
       drop __TERM __DIRECTION __CRIT_TYPE __UNIT_CHECK __VAR_CHECK __COMMENT
            __G1 __G2 __G3 __G4 __G1B __G2B __G3B __G4B;
  run;

  data &param_map_out;
       length PARAMCD $8 ATOXDSCL $80 ATOXDSCH $80 UNIT_PREF $40 COMMENT $200;
       set work._atox_map_imp (rename=(
            PARAMCD=__PARAMCD ATOXDSCL=__ATOXDSCL ATOXDSCH=__ATOXDSCH
            UNIT_PREF=__UNIT_PREF COMMENT=__COMMENT
       ));
       PARAMCD   = upcase(strip(__PARAMCD));
       ATOXDSCL  = strip(__ATOXDSCL);
       ATOXDSCH  = strip(__ATOXDSCH);
       UNIT_PREF = strip(__UNIT_PREF);
       COMMENT   = strip(__COMMENT);
       drop __PARAMCD __ATOXDSCL __ATOXDSCH __UNIT_PREF __COMMENT;
  run;

  proc datasets lib=work nolist;
       delete _atox_crit_imp _atox_map_imp;
  quit;

  %put NOTE: m_load_atoxgr_meta loaded &criteria_out and &param_map_out.;
%mend m_load_atoxgr_meta;


/*******************************************************************************
  %m_map_atoxdsc — assign ATOXDSCL / ATOXDSCH from PARAMCD map (admiral pattern)
*******************************************************************************/
%macro m_map_atoxdsc(
  dataset=
, param_map=
, paramcd_var=PARAMCD
, out=
);
  %if %length(&dataset)=0 or %length(&param_map)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_map_atoxdsc requires dataset=, param_map=, out=.;
    %return;
  %end;

  proc sql;
       create table work._atox_mapj as
       select a.*, b.ATOXDSCL as _MAP_L, b.ATOXDSCH as _MAP_H
       from &dataset as a
       left join &param_map as b
         on upcase(strip(a.&paramcd_var)) = upcase(strip(b.PARAMCD))
       ;
  quit;

  data &out;
       set work._atox_mapj;
       length ATOXDSCL ATOXDSCH $80;
       if missing(ATOXDSCL) then ATOXDSCL = _MAP_L;
       if missing(ATOXDSCH) then ATOXDSCH = _MAP_H;
       drop _MAP_L _MAP_H;
  run;

  proc datasets lib=work nolist;
       delete _atox_mapj;
  quit;

  %m_nobs(ds=&out);
%mend m_map_atoxdsc;


/*******************************************************************************
  %m_derive_var_atoxgr_dir — ULN/LLN multiple method (substantial)

  Same cutoffs as Track A R gold tox_high / tox_low in export_r_adam_ref.R:
    high: >5x / >3x / >1.5x / >1x ULN -> 4/3/2/1 else 0
    low:  <0.25x / <0.5x / <0.75x / <1x LLN -> 4/3/2/1 else 0
  Ungradable (missing AVAL or non-positive limit) -> blank (R NA).
  Prefer %m_derive_var_atoxgr_dir_ctcae for submission-style CTCAE grading.
*******************************************************************************/
%macro m_derive_var_atoxgr_dir(
  dataset=
, new_var=
, criteria_direction=H
, aval_var=AVAL
, anrhi_var=ANRHI
, anrlo_var=ANRLO
, out=
);
  %local dir;

  %if %length(&dataset)=0 or %length(&new_var)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_derive_var_atoxgr_dir requires dataset=, new_var=, out=.;
    %return;
  %end;

  %let dir = %upcase(&criteria_direction);

  data &out;
    set &dataset;
    length &new_var $1;
    &new_var = '';

    %if &dir = H %then %do;
      if not missing(&aval_var) and not missing(&anrhi_var) and &anrhi_var > 0 then do;
        if &aval_var > 5 * &anrhi_var then &new_var = '4';
        else if &aval_var > 3 * &anrhi_var then &new_var = '3';
        else if &aval_var > 1.5 * &anrhi_var then &new_var = '2';
        else if &aval_var > &anrhi_var then &new_var = '1';
        else &new_var = '0';
      end;
    %end;
    %else %if &dir = L %then %do;
      if not missing(&aval_var) and not missing(&anrlo_var) and &anrlo_var > 0 then do;
        if &aval_var < 0.25 * &anrlo_var then &new_var = '4';
        else if &aval_var < 0.5 * &anrlo_var then &new_var = '3';
        else if &aval_var < 0.75 * &anrlo_var then &new_var = '2';
        else if &aval_var < &anrlo_var then &new_var = '1';
        else &new_var = '0';
      end;
    %end;
    %else %put ERROR: criteria_direction must be H or L.;
  run;

  %m_nobs(ds=&out);
%mend m_derive_var_atoxgr_dir;


/*******************************************************************************
  %m_derive_var_atoxgr_dir_meta — grade from simple ULN/LLN cutoff meta
*******************************************************************************/
%macro m_derive_var_atoxgr_dir_meta(
  dataset=
, new_var=
, tox_description_var=
, meta_criteria=
, criteria_direction=H
, aval_var=AVAL
, anrhi_var=ANRHI
, anrlo_var=ANRLO
, out=
);
  %local dir;

  %if %length(&dataset)=0 or %length(&new_var)=0 or %length(&meta_criteria)=0
      or %length(&tox_description_var)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_derive_var_atoxgr_dir_meta missing required arguments.;
    %return;
  %end;

  %let dir = %upcase(&criteria_direction);

  proc sql;
    create table work._toxm as
    select *
    from &meta_criteria
    where upcase(DIRECTION) = "&dir"
    ;
  quit;

  proc sql;
    create table work._toxj as
    select a.*, b.G1, b.G2, b.G3, b.G4
    from &dataset as a
    left join work._toxm as b
      on upcase(strip(a.&tox_description_var)) = upcase(strip(b.TERM))
    ;
  quit;

  data &out;
    set work._toxj;
    length &new_var $1;
    &new_var = '';
    if not missing(&aval_var) and not missing(G1) then do;
      %if &dir = H %then %do;
        if not missing(&anrhi_var) and &anrhi_var > 0 then do;
          if not missing(G4) and &aval_var > G4 * &anrhi_var then &new_var = '4';
          else if not missing(G3) and &aval_var > G3 * &anrhi_var then &new_var = '3';
          else if not missing(G2) and &aval_var > G2 * &anrhi_var then &new_var = '2';
          else if &aval_var > G1 * &anrhi_var then &new_var = '1';
          else &new_var = '0';
        end;
      %end;
      %else %do;
        if not missing(&anrlo_var) and &anrlo_var > 0 then do;
          if not missing(G4) and &aval_var < G4 * &anrlo_var then &new_var = '4';
          else if not missing(G3) and &aval_var < G3 * &anrlo_var then &new_var = '3';
          else if not missing(G2) and &aval_var < G2 * &anrlo_var then &new_var = '2';
          else if &aval_var < G1 * &anrlo_var then &new_var = '1';
          else &new_var = '0';
        end;
      %end;
    end;
    drop G1 G2 G3 G4;
  run;

  proc datasets lib=work nolist;
    delete _toxm _toxj;
  quit;

  %m_nobs(ds=&out);
%mend m_derive_var_atoxgr_dir_meta;


/*******************************************************************************
  %m_derive_var_atoxgr_dir_ctcae — CTCAE directional grade (substantial port)

  Evaluates structured CRIT_TYPE metadata (admiral atoxgr_criteria_ctcv5 intent)
  using AVAL, ANRHI/ANRLO, BASE, BNRIND, PCHG, and optional UNIT_CHECK vs AVALU.

  high_indicator / low_indicator: values in BNRIND treated as abnormal baseline
  (default HIGH / LOW). Used by ULN_BASE terms (ALT/AST/ALP/BILI/GGT).
*******************************************************************************/
%macro m_derive_var_atoxgr_dir_ctcae(
  dataset=
, new_var=
, tox_description_var=
, meta_criteria=
, criteria_direction=H
, aval_var=AVAL
, anrhi_var=ANRHI
, anrlo_var=ANRLO
, base_var=BASE
, bnrind_var=BNRIND
, pchg_var=PCHG
, avalu_var=AVALU
, high_indicator=%str(HIGH)
, low_indicator=%str(LOW)
, out=
);
  %local dir;

  %if %length(&dataset)=0 or %length(&new_var)=0 or %length(&meta_criteria)=0
      or %length(&tox_description_var)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_derive_var_atoxgr_dir_ctcae missing required arguments.;
    %return;
  %end;

  %let dir = %upcase(&criteria_direction);

  proc sql;
    create table work._ctcae_m as
    select *
    from &meta_criteria
    where upcase(strip(DIRECTION)) = "&dir"
    ;
  quit;

  proc sql;
    create table work._ctcae_j as
    select a.*
         , b.CRIT_TYPE as _CRIT
         , b.UNIT_CHECK as _UNIT
         , b.G1 as _G1, b.G2 as _G2, b.G3 as _G3, b.G4 as _G4
         , b.G1_BASE as _G1B, b.G2_BASE as _G2B, b.G3_BASE as _G3B, b.G4_BASE as _G4B
    from &dataset as a
    left join work._ctcae_m as b
      on upcase(strip(a.&tox_description_var)) = upcase(strip(b.TERM))
    ;
  quit;

  data &out;
    set work._ctcae_j;
    length &new_var $1 _hi_abn $1 _lo_abn $1 _unit_ok $1;
    &new_var = '';
    _hi_abn = 'N';
    _lo_abn = 'N';
    _unit_ok = 'Y';

    if missing(&tox_description_var) or missing(_CRIT) then do;
      /* unmapped / no criteria for this direction */
    end;
    else do;
      /* unit gate: grade only when UNIT_CHECK blank or matches AVALU (case-insensitive) */
      if not missing(_UNIT) and not missing(&avalu_var) then do;
        if upcase(strip(&avalu_var)) ^= upcase(strip(_UNIT)) then _unit_ok = 'N';
      end;

      if _unit_ok = 'Y' and not missing(&aval_var) then do;
        if not missing(&bnrind_var) then do;
          if indexw(upcase("&high_indicator"), upcase(strip(&bnrind_var))) then _hi_abn = 'Y';
          if indexw(upcase("&low_indicator"), upcase(strip(&bnrind_var))) then _lo_abn = 'Y';
        end;

        /* ---- ULN multiples ---- */
        if _CRIT = 'ULN_MULT' then do;
          if missing(&anrhi_var) or &anrhi_var <= 0 then &new_var = '';
          else do;
            if not missing(_G4) and &aval_var > _G4 * &anrhi_var then &new_var = '4';
            else if not missing(_G3) and &aval_var > _G3 * &anrhi_var then &new_var = '3';
            else if not missing(_G2) and &aval_var > _G2 * &anrhi_var then &new_var = '2';
            else if not missing(_G1) and &aval_var > _G1 * &anrhi_var then &new_var = '1';
            else &new_var = '0';
          end;
        end;

        /* ---- LLN multiples ---- */
        else if _CRIT = 'LLN_MULT' then do;
          if missing(&anrlo_var) or &anrlo_var <= 0 then &new_var = '';
          else do;
            if not missing(_G4) and &aval_var < _G4 * &anrlo_var then &new_var = '4';
            else if not missing(_G3) and &aval_var < _G3 * &anrlo_var then &new_var = '3';
            else if not missing(_G2) and &aval_var < _G2 * &anrlo_var then &new_var = '2';
            else if not missing(_G1) and &aval_var < _G1 * &anrlo_var then &new_var = '1';
            else &new_var = '0';
          end;
        end;

        /* ---- ULN or BASE depending on abnormal HIGH baseline (ALT/AST/ALP/BILI/GGT) ---- */
        else if _CRIT = 'ULN_BASE' then do;
          if missing(&anrhi_var) then &new_var = '';
          else if _hi_abn = 'Y' then do;
            if missing(&base_var) then &new_var = '';
            else do;
              if not missing(_G4B) and &aval_var > _G4B * &base_var then &new_var = '4';
              else if not missing(_G3B) and &aval_var > _G3B * &base_var then &new_var = '3';
              else if not missing(_G2B) and &aval_var > _G2B * &base_var then &new_var = '2';
              else if not missing(_G1B) and &aval_var >= _G1B * &base_var then &new_var = '1';
              else &new_var = '0';
            end;
          end;
          else do;
            if &anrhi_var <= 0 then &new_var = '';
            else do;
              if not missing(_G4) and &aval_var > _G4 * &anrhi_var then &new_var = '4';
              else if not missing(_G3) and &aval_var > _G3 * &anrhi_var then &new_var = '3';
              else if not missing(_G2) and &aval_var > _G2 * &anrhi_var then &new_var = '2';
              else if not missing(_G1) and &aval_var > _G1 * &anrhi_var then &new_var = '1';
              else &new_var = '0';
            end;
          end;
        end;

        /* ---- Creatinine increased (OR of ULN and BASE branches) ---- */
        else if _CRIT = 'CREAT' then do;
          if not missing(&anrhi_var) and &anrhi_var > 0 and not missing(_G4)
             and &aval_var > _G4 * &anrhi_var then &new_var = '4';
          else if (not missing(&anrhi_var) and &anrhi_var > 0 and not missing(_G3)
                   and &aval_var > _G3 * &anrhi_var)
               or (not missing(&base_var) and not missing(_G3B)
                   and &aval_var > _G3B * &base_var) then &new_var = '3';
          else if (not missing(&anrhi_var) and &anrhi_var > 0 and not missing(_G2)
                   and &aval_var > _G2 * &anrhi_var)
               or (not missing(&base_var) and not missing(_G2B)
                   and &aval_var > _G2B * &base_var) then &new_var = '2';
          else if missing(&anrhi_var) then &new_var = '';
          else if not missing(_G1) and &aval_var > _G1 * &anrhi_var then &new_var = '1';
          else &new_var = '0';
        end;

        /* ---- Absolute low with G1 = < LLN (anemia, neutropenia, platelets, ...) ---- */
        else if _CRIT = 'ABS_LOW_LLN' then do;
          if not missing(_G4) and &aval_var < _G4 then &new_var = '4';
          else if not missing(_G3) and &aval_var < _G3 then &new_var = '3';
          else if not missing(_G2) and &aval_var < _G2 then &new_var = '2';
          else if missing(&anrlo_var) then &new_var = '';
          else if &aval_var < &anrlo_var then &new_var = '1';
          else &new_var = '0';
        end;

        /* ---- Absolute high with G1 = > ULN (electrolytes, glucose) ---- */
        else if _CRIT = 'ABS_HIGH_ULN1' then do;
          if not missing(_G4) and &aval_var > _G4 then &new_var = '4';
          else if not missing(_G3) and &aval_var > _G3 then &new_var = '3';
          else if not missing(_G2) and &aval_var > _G2 then &new_var = '2';
          else if missing(&anrhi_var) then &new_var = '';
          else if &aval_var > &anrhi_var then &new_var = '1';
          else &new_var = '0';
        end;

        /* ---- Hemoglobin increased: offsets above ULN in g/L ---- */
        else if _CRIT = 'HGB_HIGH' then do;
          if missing(&anrhi_var) then &new_var = '';
          else do;
            if not missing(_G3) and &aval_var > &anrhi_var + _G3 then &new_var = '3';
            else if not missing(_G2) and &aval_var > &anrhi_var + _G2 then &new_var = '2';
            else if &aval_var > &anrhi_var then &new_var = '1';
            else &new_var = '0';
          end;
        end;

        /* ---- INR increased (absolute OR baseline multiples, worst case) ---- */
        else if _CRIT = 'INR' then do;
          if (not missing(_G3) and &aval_var > _G3)
             or (not missing(&base_var) and not missing(_G3) and &aval_var > _G3 * &base_var)
             then &new_var = '3';
          else if (not missing(_G2) and &aval_var > _G2)
             or (not missing(&base_var) and not missing(_G2) and &aval_var > _G2 * &base_var)
             then &new_var = '2';
          else if (not missing(_G1) and &aval_var > _G1)
             or (not missing(&base_var) and &aval_var > &base_var)
             then &new_var = '1';
          else if missing(&base_var) and (missing(_G1) or &aval_var <= _G1) then &new_var = '0';
          else &new_var = '0';
        end;

        /* ---- Fibrinogen decreased (LLN multiples + PCHG branches) ---- */
        else if _CRIT = 'FIBRINOGEN' then do;
          if &aval_var < 0.5 then &new_var = '4';
          else if missing(&anrlo_var) then &new_var = '';
          else if &aval_var < _G4 * &anrlo_var
               or (&aval_var < &anrlo_var and not missing(&pchg_var) and &pchg_var <= -75)
               then &new_var = '4';
          else if &aval_var < _G3 * &anrlo_var
               or (&aval_var < &anrlo_var and not missing(&pchg_var) and &pchg_var <= -50)
               then &new_var = '3';
          else if &aval_var < _G2 * &anrlo_var
               or (&aval_var < &anrlo_var and not missing(&pchg_var) and &pchg_var <= -25)
               then &new_var = '2';
          else if &aval_var < &anrlo_var then &new_var = '1';
          else &new_var = '0';
        end;

        /* unknown CRIT_TYPE: leave grade missing */
      end;
    end;

    drop _CRIT _UNIT _G1 _G2 _G3 _G4 _G1B _G2B _G3B _G4B _hi_abn _lo_abn _unit_ok;
  run;

  proc datasets lib=work nolist;
    delete _ctcae_m _ctcae_j;
  quit;

  %m_nobs(ds=&out);
%mend m_derive_var_atoxgr_dir_ctcae;


/*******************************************************************************
  %m_derive_var_atoxgr — substantial port of derive_var_atoxgr()

  combine_method=ADMIRAL (default) — admiral low-first precedence:
    - both missing -> missing
    - low grade >= 1 -> "-n"
    - high grade >= 1 -> "n"
    - either direction normal (0) with other 0 or missing description -> "0"

  combine_method=MAXABS (aliases COMBINE_TOX / TRACKA) — Track A R gold
  export_r_adam_ref.R combine_tox():
    - both missing -> missing
    - only high graded -> character(hi) including "0"
    - only low graded: 0 -> "0", else "-n"
    - both 0 -> "0"
    - else max abs grade (high wins ties): hi>=lo -> "n", else "-n"
*******************************************************************************/
%macro m_derive_var_atoxgr(
  dataset=
, low_var=ATOXGRL
, high_var=ATOXGRH
, lotox_description_var=ATOXDSCL
, hitox_description_var=ATOXDSCH
, new_var=ATOXGR
, combine_method=ADMIRAL
, out=
);
  %local cmb;

  %if %length(&dataset)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_derive_var_atoxgr requires dataset= and out=.;
    %return;
  %end;

  %let cmb = %upcase(&combine_method);

  data &out;
    set &dataset;
    length &new_var $2;
    &new_var = '';
    _lo = input(strip(&low_var), ?? best.);
    _hi = input(strip(&high_var), ?? best.);

    %if &cmb = MAXABS or &cmb = COMBINE_TOX or &cmb = TRACKA %then %do;
      /* Track A gold combine_tox - not admiral low-first */
      if missing(_lo) and missing(_hi) then &new_var = '';
      else if missing(_lo) then &new_var = strip(put(_hi, 1.));
      else if missing(_hi) and _lo = 0 then &new_var = '0';
      else if missing(_hi) then &new_var = cats('-', put(_lo, 1.));
      else if _hi = 0 and _lo = 0 then &new_var = '0';
      else if _hi >= _lo then &new_var = strip(put(_hi, 1.));
      else &new_var = cats('-', put(_lo, 1.));
    %end;
    %else %do;
      /* admiral derive_var_atoxgr precedence (low first) */
      if missing(_lo) and missing(_hi) then &new_var = '';
      else if not missing(_lo) and _lo >= 1 then &new_var = cats('-', put(_lo, 1.));
      else if not missing(_hi) and _hi >= 1 then &new_var = strip(put(_hi, 1.));
      else if (_lo = 0 or missing(&lotox_description_var)) and _hi = 0 then &new_var = '0';
      else if (_hi = 0 or missing(&hitox_description_var)) and _lo = 0 then &new_var = '0';
      else &new_var = '';
    %end;

    drop _lo _hi;
  run;

  %m_nobs(ds=&out);
%mend m_derive_var_atoxgr;
