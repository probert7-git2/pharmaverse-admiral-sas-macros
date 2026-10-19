/*--------------------------------------------------------------
  Program Name : m_tt_derive_param_bmi.sas
  Purpose      : compute_bmi tests from test-derive_param_bmi.R (ADVS derive_param_bmi).
  Date         : 19OCT2026
  Requires     : m_tt_harness.sas and m_tt_impl_safety.sas
  Scope        : admiral test_that blocks used by safety ADaM
                 ADSL ADAE ADCM ADVS ADEG ADLB templates
--------------------------------------------------------------*/

%macro m_tt_compute_bmi;
  data work.m_tt_compute_bmi;
    length case_id $160 method $20;
    case_id = 'compute_bmi Test 1: BMI calculation - single height & weight values';
    height = 180;
    weight = 75;
    %m_tti_bmi;
    _result = round(_result, 0.001);
    expected = 23.148;
    output;
    case_id = 'compute_bmi Test 2: compute_bmi BMI calculation - height & weight vectors[1]';
    height = 180;
    weight = 75;
    %m_tti_bmi;
    _result = round(_result, 0.001);
    expected = 23.148;
    output;
    case_id = 'compute_bmi Test 2: compute_bmi BMI calculation - height & weight vectors[2]';
    height = 200;
    weight = 100;
    %m_tti_bmi;
    _result = round(_result, 0.001);
    expected = 25;
    output;
    case_id = 'compute_bmi Test 3: BMI height & weight vectors - missing values[1]';
    height = .;
    weight = 75;
    %m_tti_bmi;
    expected = .;
    output;
    case_id = 'compute_bmi Test 3: BMI height & weight vectors - missing values[2]';
    height = 200;
    weight = .;
    %m_tti_bmi;
    expected = .;
    output;
    case_id = 'compute_bmi Test 3: BMI height & weight vectors - missing values[3]';
    height = 0;
    weight = 75;
    %m_tti_bmi;
    expected = .;
    output;
  run;
  %m_tt_assert_ds(
  ds=work.m_tt_compute_bmi
, actual=_result
, expected=expected
, id=case_id
, desc='m_tt_compute_bmi'
);
%mend m_tt_compute_bmi;
