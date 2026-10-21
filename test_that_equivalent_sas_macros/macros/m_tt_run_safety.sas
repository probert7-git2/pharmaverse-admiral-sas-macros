/*--------------------------------------------------------------
  Program Name : m_tt_run_safety.sas
  Purpose      : Run admiral test_that mirrors for safety ADaM
  Date         : 19OCT2026
  Datasets     : ADSL ADAE ADCM ADVS ADEG ADLB
  Example      : %m_tt_run_safety(dir=/path/to/test_that_equivalent_sas_macros/macros);
--------------------------------------------------------------*/

%macro m_tt_run_safety(dir=);
  %if %length(&dir) %then %do;
    %include "&dir/m_tt_harness.sas";
    %include "&dir/m_tt_impl_safety.sas";
    %include "&dir/m_tt_compute_duration.sas";
    %include "&dir/m_tt_derive_param_bmi.sas";
    %include "&dir/m_tt_derive_param_bsa.sas";
    %include "&dir/m_tt_derive_param_map.sas";
    %include "&dir/m_tt_safety_datasets.sas";
  %end;

  %m_tt_init;

  /* ADSL ADAE ADCM: duration, study day, treatment duration */
  %m_tt_compute_duration;
  %m_tt_derive_vars_duration;
  %m_tt_derive_var_trtdurd;
  %m_tt_derive_vars_dy;

  /* ADVS: BMI, BSA, MAP */
  %m_tt_compute_bmi;
  %m_tt_compute_bsa;
  %m_tt_compute_map;

  /* ADEG: QTc and RR */
  %m_tt_derive_param_qtc;
  %m_tt_derive_param_rr;

  /* ADVS ADEG ADLB: baseline, change, reference range */
  %m_tt_derive_var_base;
  %m_tt_derive_var_chg;
  %m_tt_derive_var_anrind;

  /* ADLB: analysis ratio and ATOXGR combine */
  %m_tt_derive_var_analysis_ratio;
  %m_tt_derive_var_atoxgr;

  %m_tt_summary;
%mend m_tt_run_safety;
