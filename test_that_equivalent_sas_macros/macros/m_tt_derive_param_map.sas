/*--------------------------------------------------------------
  Program Name : m_tt_derive_param_map.sas
  Purpose      : compute_map tests from test-derive_param_map.R (ADVS derive_param_map).
  Date         : 19OCT2026
  Requires     : m_tt_harness.sas and m_tt_impl_safety.sas
  Scope        : admiral test_that blocks used by safety ADaM
                 ADSL ADAE ADCM ADVS ADEG ADLB templates
--------------------------------------------------------------*/

%macro m_tt_compute_map;
  data work.m_tt_compute_map;
    length case_id $160 method $20;
    case_id = 'compute_map Test 1: MAP based on diastolic & systolic BP - single values';
    diabp = 51;
    sysbp = 121;
    hr = .;
    _hr_present = 0;
    %m_tti_map;
    _result = round(_result, 0.001);
    expected = 74.333;
    output;
    case_id = 'compute_map Test 2: MAP based on diastolic & systolic BP - vectors[1]';
    diabp = 51;
    sysbp = 121;
    hr = .;
    _hr_present = 0;
    %m_tti_map;
    _result = round(_result, 0.001);
    expected = 74.333;
    output;
    case_id = 'compute_map Test 2: MAP based on diastolic & systolic BP - vectors[2]';
    diabp = 61;
    sysbp = 141;
    hr = .;
    _hr_present = 0;
    %m_tti_map;
    _result = round(_result, 0.001);
    expected = 87.667;
    output;
    case_id = 'compute_map Test 3: MAP based on diastolic & systolic BP with missing values[1]';
    diabp = .;
    sysbp = 121;
    hr = .;
    _hr_present = 0;
    %m_tti_map;
    expected = .;
    output;
    case_id = 'compute_map Test 3: MAP based on diastolic & systolic BP with missing values[2]';
    diabp = 61;
    sysbp = .;
    hr = .;
    _hr_present = 0;
    %m_tti_map;
    expected = .;
    output;
    case_id = 'compute_map Test 4: MAP based on DBP & SBP & heart rate - single values';
    diabp = 51;
    sysbp = 121;
    hr = 59;
    _hr_present = 1;
    %m_tti_map;
    _result = round(_result, 0.001);
    expected = 73.039;
    output;
    case_id = 'compute_map Test 5: MAP based on diastolic, systolic BP & heart rate - vectors[1]';
    diabp = 51;
    sysbp = 121;
    hr = 59;
    _hr_present = 1;
    %m_tti_map;
    _result = round(_result, 0.001);
    expected = 73.039;
    output;
    case_id = 'compute_map Test 5: MAP based on diastolic, systolic BP & heart rate - vectors[2]';
    diabp = 91;
    sysbp = 101;
    hr = 62;
    _hr_present = 1;
    %m_tti_map;
    _result = round(_result, 0.001);
    expected = 94.255;
    output;
    case_id = 'compute_map Test 6: MAP based on DBP, SBP & heart rate - with missing values[1]';
    diabp = .;
    sysbp = 121;
    hr = 59;
    _hr_present = 1;
    %m_tti_map;
    expected = .;
    output;
    case_id = 'compute_map Test 6: MAP based on DBP, SBP & heart rate - with missing values[2]';
    diabp = 61;
    sysbp = .;
    hr = 62;
    _hr_present = 1;
    %m_tti_map;
    expected = .;
    output;
    case_id = 'compute_map Test 6: MAP based on DBP, SBP & heart rate - with missing values[3]';
    diabp = 51;
    sysbp = 121;
    hr = .;
    _hr_present = 1;
    %m_tti_map;
    expected = .;
    output;
  run;
  %m_tt_assert_ds(
  ds=work.m_tt_compute_map
, actual=_result
, expected=expected
, id=case_id
, desc='m_tt_compute_map'
);
%mend m_tt_compute_map;
