/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_gs_create_mock_adam2.sas
  SAS Version                 : 9.4
  Purpose (short description) : Create golden-subject mock inputs and frozen gs_expected oracle
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : None (synthetic fixtures) - see validation/gs_mock_spec_adam2.md
  Modification Log            : 18AUG2026 - GS-AE-03 TE rule 2 (month in window ->
                                window end). GS-AE-04 outside window day-missing ->
                                ASTDT missing (no first-of-month). GS_MOCK_ODA_SAFE_V7.
                                18AUG2026 - GS-AE-01 expects conservative DTM hi=D
                                (ASTDT=01JAN2020 via TE rule 1) - not Track A gold hi=n missing.
                                GS_MOCK_ODA_SAFE_V6.
                                17AUG2026 - *DTC LENGTH $10 (was $20/$32). GS_MOCK_ODA_SAFE_V5.
                                16AUG2026 - Reset EXP_* each oracle row (retain bug).
                                16AUG2026 - GS-DTM-01 ASTTMF=H (admiral DTM time impute).
                                16AUG2026 - GS-TE-05/06 leap-2020 TRTEDT+30 boundary.
                                16AUG2026 - GS-AE expected AESEQ=1 (avoid multi-AE join).
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  %m_gs_create_mock_adam2 - mock ADaM2 inputs and frozen expected oracle

  Spec: validation/gs_mock_spec_adam2.md
  Creates: gs_dt_in batches, gs_te_in, gs_adsl/gs_ae/gs_ex, gs_expected
  ODA RULE: never use DATALINES or CARDS inside this macro - explicit OUTPUT only
  Version stamp: GS_MOCK_ODA_SAFE_V7 (look for this NOTE in the log after upload)
*/
%macro m_gs_create_mock_adam2;

  %put NOTE: GS_MOCK_ODA_SAFE_V7 - m_gs_create_mock_adam2 using explicit OUTPUT rows (no DATALINES).;

  * --- Partial-date unit inputs (hi=M di=first batch) ---;
  data work.gs_dt_in_mfirst;
       length case_id $40 aestdtc $10;
       case_id = 'GS-DT-01'; aestdtc = '2020-06-15'; output;
       case_id = 'GS-DT-02'; aestdtc = '2020-06--'; output;
       case_id = 'GS-DT-03'; aestdtc = '2020----'; output;
  run;

  data work.gs_dt_in_mid;
       length case_id $40 aestdtc $10;
       case_id = 'GS-DT-04';
       aestdtc = '2020----';
  run;

  data work.gs_dt_in_n;
       length case_id $40 aestdtc $10;
       case_id = 'GS-DT-05';
       aestdtc = '2020-06--';
  run;

  data work.gs_dt_in_last;
       length case_id $40 aestdtc $10;
       case_id = 'GS-DT-06';
       aestdtc = '2020-06--';
  run;

  * --- DTM: admiral M (month) vs m (minutes) ---;
  data work.gs_dtm_in_M;
       length case_id $40 aestdtc $10;
       case_id = 'GS-DTM-01';
       aestdtc = '2020-06--';
  run;

  data work.gs_dtm_in_m_partial;
       length case_id $40 aestdtc $10;
       case_id = 'GS-DTM-02';
       aestdtc = '2020-06--';
  run;

  data work.gs_dtm_in_m_full;
       length case_id $40 aestdtc $10;
       case_id = 'GS-DTM-03';
       aestdtc = '2020-06-15';
  run;

  * --- Epoch: SAS 1960 calendar vs ISO text (QC compare pattern) ---;
  data work.gs_epoch_in;
       length case_id $40 aestdtc $10;
       case_id = 'GS-EPOCH-01';
       aestdtc = '2020-01-15';
  run;

  * --- TRTEMFL unit inputs (ODA-safe explicit rows) ---;
  data work.gs_te_in;
       length case_id $40 aesev0 $20 aesev $20;
       format astdt aendt trtsdt trtedt date9.;
       case_id = 'GS-TE-01'; astdt = .; aendt = .;
       trtsdt = .; trtedt = '31JAN2020'd; aesev0 = ''; aesev = ''; output;
       case_id = 'GS-TE-02'; astdt = .; aendt = '25DEC2019'd;
       trtsdt = '01JAN2020'd; trtedt = '31JAN2020'd; aesev0 = ''; aesev = ''; output;
       case_id = 'GS-TE-03'; astdt = .; aendt = '15JAN2020'd;
       trtsdt = '01JAN2020'd; trtedt = '31JAN2020'd; aesev0 = ''; aesev = ''; output;
       case_id = 'GS-TE-04'; astdt = '10JAN2020'd; aendt = '15JAN2020'd;
       trtsdt = '01JAN2020'd; trtedt = '31JAN2020'd; aesev0 = ''; aesev = ''; output;
       /* 2020 leap: TRTEDT+30 = 01MAR2020 (not 02MAR - that is non-leap) */
       case_id = 'GS-TE-05'; astdt = '01MAR2020'd; aendt = .;
       trtsdt = '01JAN2020'd; trtedt = '31JAN2020'd; aesev0 = ''; aesev = ''; output;
       case_id = 'GS-TE-06'; astdt = '02MAR2020'd; aendt = .;
       trtsdt = '01JAN2020'd; trtedt = '31JAN2020'd; aesev0 = ''; aesev = ''; output;
       case_id = 'GS-TE-07'; astdt = '25DEC2019'd; aendt = '15JAN2020'd;
       trtsdt = '01JAN2020'd; trtedt = .; aesev0 = 'MILD'; aesev = 'MODERATE'; output;
  run;

  * --- ADAE2 integration mock ---;
  data work.gs_adsl;
       length STUDYID $20 USUBJID $40 TRT01A TRT01P $100;
       format TRTSDT TRTEDT DTHDT EOSDT date9. TRTSDTM TRTEDTM datetime20.;
       STUDYID = 'GOLDSTUDY';
       TRTSDT = '01JAN2020'd;
       TRTEDT = '31JAN2020'd;
       TRTSDTM = dhms(TRTSDT, 0, 0, 0);
       TRTEDTM = dhms(TRTEDT, 23, 59, 59);
       DTHDT = .;
       EOSDT = .;
       TRT01A = 'Drug A';
       TRT01P = 'Drug A';
       USUBJID = 'GS-AE-01';
       output;
       USUBJID = 'GS-AE-02';
       output;
       USUBJID = 'GS-AE-03';
       output;
       USUBJID = 'GS-AE-04';
       output;
  run;

  data work.gs_ae;
       /* *DTC LENGTH $10 - first assign 2020-01-- (len 9) truncated 2020-03-15 without it */
       length STUDYID $20 USUBJID $40 AETERM AEDECOD AESOC AESEV AEREL $200
              AESTDTC AEENDTC $10 AESER $1;
       STUDYID = 'GOLDSTUDY';
       USUBJID = 'GS-AE-01';
       AESEQ = 1;
       AESTDTC = '2020-01--';
       AEENDTC = '2020-01-20';
       AETERM = 'Headache';
       AEDECOD = 'Headache';
       AESOC = 'NERVOUS SYSTEM';
       AESEV = 'MILD';
       AEREL = 'POSSIBLE';
       AESER = 'N';
       output;
       /* Bladder-cancer AESI examples for SMQ/CQ query demo */
       AESEQ = 2;
       AESTDTC = '2020-01-10';
       AEENDTC = '2020-01-18';
       AETERM = 'Blood in urine';
       AEDECOD = 'Haematuria';
       AESOC = 'RENAL AND URINARY';
       AESEV = 'MODERATE';
       AEREL = 'POSSIBLE';
       AESER = 'N';
       output;
       USUBJID = 'GS-AE-02';
       AESEQ = 1;
       AESTDTC = '2020-03-15';
       AEENDTC = '2020-03-20';
       AETERM = 'Nausea';
       AEDECOD = 'Nausea';
       AESOC = 'GASTROINTESTINAL';
       AESEV = 'MILD';
       AEREL = 'POSSIBLE';
       AESER = 'N';
       output;
       AESEQ = 2;
       AESTDTC = '2020-01-12';
       AEENDTC = '2020-01-16';
       AETERM = 'UTI';
       AEDECOD = 'Urinary tract infection';
       AESOC = 'INFECTIONS';
       AESEV = 'MILD';
       AEREL = 'POSSIBLE';
       AESER = 'N';
       output;
       AESEQ = 3;
       AESTDTC = '2020-01-20';
       AEENDTC = '2020-01-25';
       AETERM = 'AKI';
       AEDECOD = 'Acute kidney injury';
       AESOC = 'RENAL AND URINARY';
       AESEV = 'SEVERE';
       AEREL = 'POSSIBLE';
       AESER = 'Y';
       output;
       /* TE rule 2: Feb 2020 intersects [01JAN2020, 01MAR2020] -> window end */
       USUBJID = 'GS-AE-03';
       AESEQ = 1;
       AESTDTC = '2020-02--';
       AEENDTC = '2020-02-20';
       AETERM = 'Fatigue';
       AEDECOD = 'Fatigue';
       AESOC = 'GENERAL';
       AESEV = 'MILD';
       AEREL = 'POSSIBLE';
       AESER = 'N';
       output;
       /* Outside TE window: Jun 2020 - no subject-relative day -> ASTDT missing */
       USUBJID = 'GS-AE-04';
       AESEQ = 1;
       AESTDTC = '2020-06--';
       AEENDTC = '2020-06-20';
       AETERM = 'Rash';
       AEDECOD = 'Rash';
       AESOC = 'SKIN';
       AESEV = 'MILD';
       AEREL = 'POSSIBLE';
       AESER = 'N';
       output;
  run;

  data work.gs_ex;
       length STUDYID $20 USUBJID $40 EXTRT EXDOSU EXROUTE $100 EXSTDTC $10;
       STUDYID = 'GOLDSTUDY';
       USUBJID = 'GS-AE-01';
       EXSEQ = 1;
       EXSTDTC = '2020-01-01';
       EXDOSE = 100;
       EXTRT = 'Drug A';
       EXDOSU = 'mg';
       EXROUTE = 'ORAL';
       output;
       USUBJID = 'GS-AE-02';
       EXSEQ = 1;
       EXSTDTC = '2020-01-05';
       EXDOSE = 100;
       EXTRT = 'Drug A';
       EXDOSU = 'mg';
       EXROUTE = 'INTRAVENOUS';
       output;
       USUBJID = 'GS-AE-03';
       EXSEQ = 1;
       EXSTDTC = '2020-01-01';
       EXDOSE = 100;
       EXTRT = 'Drug A';
       EXDOSU = 'mg';
       EXROUTE = 'ORAL';
       output;
       USUBJID = 'GS-AE-04';
       EXSEQ = 1;
       EXSTDTC = '2020-01-01';
       EXDOSE = 100;
       EXTRT = 'Drug A';
       EXDOSU = 'mg';
       EXROUTE = 'ORAL';
       output;
  run;

  * --- Frozen expected oracle (do not auto-regenerate on each run) ---;
  /* Reset ALL EXP_* / AESEQ before every OUTPUT - SAS retains otherwise. */
  data work.gs_expected;
       length TESTID $12 SUITE $12 USUBJID $40 EXP_ASTDTF EXP_ASTTMF EXP_TRTEMFL $1 EXP_ASTDT_ISO $10;
       format EXP_ASTDT EXP_AENDT date9.;
       AESEQ = .;
       EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-DT-01'; SUITE = 'DT'; USUBJID = 'GS-DT-01'; EXP_ASTDT = mdy(6,15,2020); EXP_ASTDTF = ''; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-DT-02'; SUITE = 'DT'; USUBJID = 'GS-DT-02'; EXP_ASTDT = mdy(6,1,2020); EXP_ASTDTF = 'D'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-DT-03'; SUITE = 'DT'; USUBJID = 'GS-DT-03'; EXP_ASTDT = mdy(1,1,2020); EXP_ASTDTF = 'M'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-DT-04'; SUITE = 'DT'; USUBJID = 'GS-DT-04'; EXP_ASTDT = mdy(6,30,2020); EXP_ASTDTF = 'M'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-DT-05'; SUITE = 'DT'; USUBJID = 'GS-DT-05'; EXP_ASTDT = .; EXP_ASTDTF = ''; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-DT-06'; SUITE = 'DT'; USUBJID = 'GS-DT-06'; EXP_ASTDT = mdy(6,30,2020); EXP_ASTDTF = 'D'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       /* admiral derive_vars_dtm(hi=M): imputes day + time -> ASTTMF=H */
       TESTID = 'GS-DTM-01'; SUITE = 'DTM'; USUBJID = 'GS-DTM-01';
         EXP_ASTDT = mdy(6,1,2020); EXP_ASTDTF = 'D'; EXP_ASTTMF = 'H'; EXP_ASTDT_ISO = '2020-06-01'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-DTM-02'; SUITE = 'DTM'; USUBJID = 'GS-DTM-02';
         EXP_ASTDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_ASTDT_ISO = ''; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-DTM-03'; SUITE = 'DTM'; USUBJID = 'GS-DTM-03';
         EXP_ASTDT = mdy(6,15,2020); EXP_ASTDTF = ''; EXP_ASTTMF = 'H'; EXP_ASTDT_ISO = '2020-06-15'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-EPOCH-01'; SUITE = 'EPOCH'; USUBJID = 'GS-EPOCH-01';
         EXP_ASTDT = mdy(1,15,2020); EXP_ASTDT_ISO = '2020-01-15'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-TE-01'; SUITE = 'TRTEMFL'; USUBJID = 'GS-TE-01'; EXP_TRTEMFL = ''; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-TE-02'; SUITE = 'TRTEMFL'; USUBJID = 'GS-TE-02'; EXP_TRTEMFL = ''; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-TE-03'; SUITE = 'TRTEMFL'; USUBJID = 'GS-TE-03'; EXP_TRTEMFL = 'Y'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-TE-04'; SUITE = 'TRTEMFL'; USUBJID = 'GS-TE-04'; EXP_TRTEMFL = 'Y'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-TE-05'; SUITE = 'TRTEMFL'; USUBJID = 'GS-TE-05'; EXP_TRTEMFL = 'Y'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-TE-06'; SUITE = 'TRTEMFL'; USUBJID = 'GS-TE-06'; EXP_TRTEMFL = ''; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-TE-07'; SUITE = 'TRTEMFL'; USUBJID = 'GS-TE-07'; EXP_TRTEMFL = 'Y'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       /* AESEQ=1 = scenario AE only (extra AESI demo rows stay in mock).
          Partial AESTDTC 2020-01-- - same month/year as TRTSDT -> ASTDT=TRTSDT
          (TE-aware rule 1). TRTEMFL=Y. */
       TESTID = 'GS-AE-01'; SUITE = 'ADAE'; USUBJID = 'GS-AE-01'; AESEQ = 1;
         EXP_ASTDT = mdy(1,1,2020); EXP_ASTDTF = 'D'; EXP_ASTDT_ISO = '2020-01-01';
         EXP_TRTEMFL = 'Y'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       TESTID = 'GS-AE-02'; SUITE = 'ADAE'; USUBJID = 'GS-AE-02'; AESEQ = 1;
         EXP_ASTDT = mdy(3,15,2020); EXP_ASTDTF = ''; EXP_ASTDT_ISO = '2020-03-15'; EXP_TRTEMFL = ''; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       /* TE rule 2: 2020-02-- intersects window -> ASTDT=TRTEDT+30=01MAR2020 */
       TESTID = 'GS-AE-03'; SUITE = 'ADAE'; USUBJID = 'GS-AE-03'; AESEQ = 1;
         EXP_ASTDT = mdy(3,1,2020); EXP_ASTDTF = 'D'; EXP_ASTDT_ISO = '2020-03-01';
         EXP_TRTEMFL = 'Y'; output;
       AESEQ = .; EXP_ASTDT = .; EXP_AENDT = .; EXP_ASTDTF = ''; EXP_ASTTMF = ''; EXP_TRTEMFL = ''; EXP_ASTDT_ISO = '';
       /* Outside window: 2020-06-- - no TE day -> ASTDT missing (not 01JUN).
          TRTEMFL blank (out-of-window YM override - not admiral missing-start=Y). */
       TESTID = 'GS-AE-04'; SUITE = 'ADAE'; USUBJID = 'GS-AE-04'; AESEQ = 1;
         EXP_ASTDT = .; EXP_ASTDTF = ''; EXP_ASTDT_ISO = '';
         EXP_TRTEMFL = ''; output;
  run;

  %put NOTE: GS_MOCK_ODA_SAFE_V7 - mock inputs and work.gs_expected created successfully.;

%mend m_gs_create_mock_adam2;
