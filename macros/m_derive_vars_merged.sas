/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_derive_vars_merged.sas
  SAS Version                 : 9.4
  Purpose (short description) : admiral-style merged extreme datetime port
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Caller and add datasets
  Modification Log            : 09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  %m_derive_vars_merged — substantial SAS port of admiral::derive_vars_merged()

    Selects one row from dataset_add per by_vars (mode=first|last after order)
    and merges new_vars onto all rows of dataset.

    Implemented via %m_derive_vars_joined with join_type=all and filter_join=1
    (no conditional join window — that is derive_vars_joined).

    Example (ADSL treatment start from EX):
      %m_derive_vars_merged(
        dataset=work.adsl0
      , dataset_add=work.ex_ext
      , by_vars=STUDYID USUBJID
      , order=EXSTDTM EXSEQ
      , new_vars=TRTSDTM=EXSTDTM TRTSTMF=EXSTTMF
      , filter_add=%str(EXDOSE > 0 or (EXDOSE = 0 and index(upcase(EXTRT),'PLACEBO')))
      , mode=first
      , out=work.adsl1
      );
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/



%macro m_derive_vars_merged(
  dataset=
, dataset_add=
, by_vars=STUDYID USUBJID
, order=
, new_vars=
, filter_add=%str(1)
, mode=last
, exist_flag=
, true_value=Y
, false_value=
, missing_values=
, out=
);

  %if %length(&missing_values) %then %do;
    %put NOTE: m_derive_vars_merged missing_values= is not implemented in v1.;
  %end;
  %m_derive_vars_joined(
    dataset=&dataset
  , dataset_add=&dataset_add
  , by_vars=&by_vars
  , order=&order
  , new_vars=&new_vars
  , join_type=all
  , filter_add=&filter_add
  , filter_join=%str(1)
  , mode=&mode
  , exist_flag=&exist_flag
  , true_value=&true_value
  , false_value=&false_value
  , out=&out
  );

%mend m_derive_vars_merged;
