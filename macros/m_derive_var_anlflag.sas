/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_derive_var_anlflag.sas
  SAS Version                 : 9.4
  Purpose (short description) : Analysis flag and criterion flag ports
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Caller analysis dataset
  Modification Log            : 09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Phase 2 BDS — analysis / criterion flags
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
/*******************************************************************************
  %m_derive_var_anlflag — substantial port for ANLzzFL-style analysis flags

  (User list: derive_var_anlflag). Sets new_var='Y' when condition is true.
*******************************************************************************/
%macro m_derive_var_anlflag(
  dataset=
, new_var=ANL01FL
, condition=
, true_value=Y
, false_value=
, out=
);
  %if %length(&dataset)=0 or %length(&condition)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_derive_var_anlflag requires dataset=, condition=, out=.;
    %return;
  %end;

  data &out;
    set &dataset;
    length &new_var $1;
    &new_var = "&false_value";
    if &condition then &new_var = "&true_value";
  run;

  %m_nobs(ds=&out);
%mend m_derive_var_anlflag;


/*******************************************************************************
  %m_derive_vars_crit_flag — substantial port of derive_vars_crit_flag()

  description: constant character text in v1
  values_yn=N: CRITyFL = Y or blank; CRITy only when Y
  values_yn=Y: CRITyFL = Y/N (missing AVAL-style unknowns become N if
               condition is false in SAS); CRITy always = description
*******************************************************************************/
%macro m_derive_vars_crit_flag(
  dataset=
, crit_nr=1
, condition=
, description=
, values_yn=N
, create_numeric_flag=N
, out=
);
  %local crit fl fn;

  %if %length(&dataset)=0 or %length(&condition)=0 or %length(&description)=0
      or %length(&out)=0 %then %do;
    %put ERROR: m_derive_vars_crit_flag requires dataset=, condition=, description=, out=.;
    %return;
  %end;

  %let crit = CRIT&crit_nr;
  %let fl   = CRIT&crit_nr.FL;
  %let fn   = CRIT&crit_nr.FN;

  data &out;
    set &dataset;
    length &crit $200 &fl $1;
    &fl = '';
    &crit = '';

    %if %upcase(&values_yn) = Y or %upcase(&values_yn) = TRUE %then %do;
      &crit = "&description";
      if &condition then &fl = 'Y';
      else &fl = 'N';
    %end;
    %else %do;
      if &condition then do;
        &fl = 'Y';
        &crit = "&description";
      end;
    %end;

    %if %upcase(&create_numeric_flag) = Y or %upcase(&create_numeric_flag) = TRUE %then %do;
      &fn = .;
      if &fl = 'Y' then &fn = 1;
      else if &fl = 'N' then &fn = 0;
    %end;
  run;

  %m_nobs(ds=&out);
%mend m_derive_vars_crit_flag;
