/*--------------------------------------------------------------
  Program Name                : m_qc_sdtm_issues_pva.sas
  Purpose                     : Flag apparent data issues that impact Part B
                                ADaM processing (informational QC) - SDTM
                                incoming AE issues and known PVA/ADaM gold quirks
  Note                        : Lives only in SAS_mirrored_Admiral_safety_ADaM.
                                Do not edit safety_monitoring_system for Part B.
                                Dataset name adam.qc_sdtm_issues is historical
                                (now SDTM + ADAM via SOURCE column).
  Macro                       : %m_qc_sdtm_issues_pva
  Input                       : raw.ae (SDTM AE), ref_pva.refadae / refadcm (PVA gold)
  Output default              : adam.qc_sdtm_issues (Part B adam lib)
  Scope v1                    : AE SDTM rules + PVA ADAE *DTM date-collapse
                                + PVA ADCM AENDT year-end-without-EOS catalog
  Modification Log            : 24AUG2026 - Add PVA_ADCM_AENDT_NO_EOS_CAP from
                                refadcm (known year-end AENDT without EOSDT cap).
                                24AUG2026 - SOURCE covers SDTM|ADAM. Add
                                PVA_ADAE_DTM_DATE_COLLAPSE catalog row from
                                refadae date-scale *DTM scan. AE missing no
                                longer skips ADAM scan.
                                22AUG2026 - Initial AE incoming-issue scan.
--------------------------------------------------------------*/
%macro m_qc_sdtm_issues_pva(
  ae=raw.ae
, refadae=ref_pva.refadae
, refadcm=ref_pva.refadcm
, out=adam.qc_sdtm_issues
);

  %local _n_iss _ae_ok _adam_ok _adcm_ok _n_dtm_scale _n_adcm_ye;

  /* Shell structure always written so adam.qc_sdtm_issues exists after create */
  data work._qc_sdtm_shell;
    length ISSUE_ID $48 DOMAIN $8 USUBJID $40
           KEY_VARS $80 KEY_TXT $200
           ISSUE_TYPE $32 ISSUE_DESC $500
           EXAMPLE_SEQS $200 SOURCE $8;
    length N_ROWS 8;
    call missing(of _all_);
    stop;
  run;

  %let _ae_ok = 0;
  %if %sysfunc(exist(&ae)) %then %do;
    %let _ae_ok = 1;
  %end;

  %let _adam_ok = 0;
  %if %sysfunc(exist(&refadae)) %then %do;
    %let _adam_ok = 1;
  %end;

  %let _adcm_ok = 0;
  %if %sysfunc(exist(&refadcm)) %then %do;
    %let _adcm_ok = 1;
  %end;

  /* ---- SDTM AE rules (skip gracefully if AE missing) ---- */
  %if &_ae_ok = 0 %then %do;
    data work._qc_sev work._qc_dup work._qc_miss;
      set work._qc_sdtm_shell;
      stop;
    run;
    %put NOTE: m_qc_sdtm_issues_pva - &ae missing - SDTM AE rules skipped.;
  %end;
  %else %do;

  /* ---- Rule 1: AE_SEV_SAME_DATES
     Same USUBJID + AEDECOD + AESTDTC + AEENDTC with more than one distinct AESEV.
     Clinically unexpected - impacts OCCDS uniqueness / TE window attribution. ---- */
  proc sql;
    create table work._qc_sev_keys as
    select USUBJID
         , AEDECOD
         , AESTDTC
         , AEENDTC
         , count(*) as N_ROWS
         , count(distinct upcase(strip(AESEV))) as N_SEV
    from &ae
    where not missing(USUBJID) and not missing(AEDECOD)
    group by USUBJID, AEDECOD, AESTDTC, AEENDTC
    having calculated N_SEV > 1
    ;
  quit;

  proc sql;
    create table work._qc_sev_detail as
    select k.USUBJID
         , k.AEDECOD
         , k.AESTDTC
         , k.AEENDTC
         , k.N_ROWS
         , a.AESEQ
         , a.AESEV
    from work._qc_sev_keys as k
    inner join &ae as a
      on k.USUBJID = a.USUBJID
     and k.AEDECOD = a.AEDECOD
     and ((missing(k.AESTDTC) and missing(a.AESTDTC)) or k.AESTDTC = a.AESTDTC)
     and ((missing(k.AEENDTC) and missing(a.AEENDTC)) or k.AEENDTC = a.AEENDTC)
    ;
  quit;

  proc sort data=work._qc_sev_detail;
    by USUBJID AEDECOD AESTDTC AEENDTC AESEQ;
  run;

  data work._qc_sev;
    length DOMAIN $8 USUBJID $40 KEY_VARS $80 KEY_TXT $200
           ISSUE_TYPE $32 ISSUE_DESC $500 EXAMPLE_SEQS $200 SOURCE $8;
    length N_ROWS 8;
    set work._qc_sev_detail;
    by USUBJID AEDECOD AESTDTC AEENDTC;
    retain EXAMPLE_SEQS;
    if first.AEENDTC then EXAMPLE_SEQS = '';
    if not missing(AESEQ) then EXAMPLE_SEQS = catx(', ', EXAMPLE_SEQS, cats(AESEQ));
    if last.AEENDTC then do;
      DOMAIN     = 'AE';
      SOURCE     = 'SDTM';
      ISSUE_TYPE = 'AE_SEV_SAME_DATES';
      KEY_VARS   = 'USUBJID AEDECOD AESTDTC AEENDTC';
      KEY_TXT    = catx(' | ', USUBJID, AEDECOD, AESTDTC, AEENDTC);
      ISSUE_DESC = catx(' ',
        'Multiple AESEV values for same USUBJID/AEDECOD with identical AESTDTC/AEENDTC.',
        'Clinically unexpected - impacts OCCDS uniqueness and TE window attribution.');
      output;
    end;
    keep DOMAIN USUBJID KEY_VARS KEY_TXT ISSUE_TYPE ISSUE_DESC N_ROWS EXAMPLE_SEQS SOURCE;
  run;

  /* ---- Rule 2: AE_DUP_SEQ
     Duplicate USUBJID + AEDECOD + AESEQ (non-unique AE occurrence key). ---- */
  proc sql;
    create table work._qc_dup_keys as
    select USUBJID
         , AEDECOD
         , AESEQ
         , count(*) as N_ROWS
    from &ae
    where not missing(USUBJID) and not missing(AESEQ)
    group by USUBJID, AEDECOD, AESEQ
    having calculated N_ROWS > 1
    ;
  quit;

  data work._qc_dup;
    length DOMAIN $8 USUBJID $40 KEY_VARS $80 KEY_TXT $200
           ISSUE_TYPE $32 ISSUE_DESC $500 EXAMPLE_SEQS $200 SOURCE $8;
    length N_ROWS 8;
    set work._qc_dup_keys;
    DOMAIN       = 'AE';
    SOURCE       = 'SDTM';
    ISSUE_TYPE   = 'AE_DUP_SEQ';
    KEY_VARS     = 'USUBJID AEDECOD AESEQ';
    KEY_TXT      = catx(' | ', USUBJID, AEDECOD, cats(AESEQ));
    EXAMPLE_SEQS = cats(AESEQ);
    ISSUE_DESC   = catx(' ',
      'Duplicate USUBJID/AEDECOD/AESEQ rows in SDTM AE.',
      'Breaks unique AE occurrence identity used in ADAE joins and QC keep-last.');
    keep DOMAIN USUBJID KEY_VARS KEY_TXT ISSUE_TYPE ISSUE_DESC N_ROWS EXAMPLE_SEQS SOURCE;
  run;

  /* ---- Rule 3: AE_MISSING_AESTDTC
     AEDECOD present but AESTDTC missing - onset unavailable for ASTDT / TE. ---- */
  data work._qc_miss;
    length DOMAIN $8 USUBJID $40 KEY_VARS $80 KEY_TXT $200
           ISSUE_TYPE $32 ISSUE_DESC $500 EXAMPLE_SEQS $200 SOURCE $8;
    length N_ROWS 8;
    set &ae;
    where not missing(AEDECOD) and missing(AESTDTC);
    DOMAIN       = 'AE';
    SOURCE       = 'SDTM';
    ISSUE_TYPE   = 'AE_MISSING_AESTDTC';
    KEY_VARS     = 'USUBJID AEDECOD AESEQ';
    KEY_TXT      = catx(' | ', USUBJID, AEDECOD, cats(AESEQ));
    EXAMPLE_SEQS = cats(AESEQ);
    N_ROWS       = 1;
    ISSUE_DESC   = catx(' ',
      'AEDECOD present with missing AESTDTC.',
      'Onset unavailable for ASTDT imputation and treatment-emergent windowing.');
    keep DOMAIN USUBJID KEY_VARS KEY_TXT ISSUE_TYPE ISSUE_DESC N_ROWS EXAMPLE_SEQS SOURCE;
  run;

  %end; /* &_ae_ok */

  /* ---- Rule ADAM-1: PVA_ADAE_DTM_DATE_COLLAPSE (dataset-level catalog)
     PVA/pharmaverseadam ADAE stores ASTDTM/AENDTM/LDOSEDTM as SAS date-scale
     (equal to *DT) with DATE format - export/Date-collapse artifact vs
     CDISC/admiral datetime + TMF. One summary row when any nonmiss *DTM is
     in (0, 100000). Do not count this gold quirk against SAS ADAE. ---- */
  %if &_adam_ok = 0 %then %do;
    data work._qc_adam_dtm;
      set work._qc_sdtm_shell;
      stop;
    run;
    %put NOTE: m_qc_sdtm_issues_pva - &refadae missing - ADAM DTM catalog skipped.;
  %end;
  %else %do;

  %let _n_dtm_scale = 0;
  proc sql noprint;
    select count(*) into :_n_dtm_scale trimmed
    from &refadae
    where (not missing(ASTDTM) and ASTDTM > 0 and ASTDTM < 100000)
       or (not missing(AENDTM) and AENDTM > 0 and AENDTM < 100000)
       or (not missing(LDOSEDTM) and LDOSEDTM > 0 and LDOSEDTM < 100000)
    ;
  quit;

  data work._qc_adam_dtm;
    length DOMAIN $8 USUBJID $40 KEY_VARS $80 KEY_TXT $200
           ISSUE_TYPE $32 ISSUE_DESC $500 EXAMPLE_SEQS $200 SOURCE $8;
    length N_ROWS 8;
    if &_n_dtm_scale > 0 then do;
      DOMAIN       = 'ADAE';
      SOURCE       = 'ADAM';
      USUBJID      = '';
      ISSUE_TYPE   = 'PVA_ADAE_DTM_DATE_COLLAPSE';
      KEY_VARS     = 'ASTDTM AENDTM LDOSEDTM';
      KEY_TXT      = 'refadae date-scale *DTM (export Date-collapse)';
      EXAMPLE_SEQS = '';
      N_ROWS       = &_n_dtm_scale;
      ISSUE_DESC   = catx(' ',
        'PVA/pharmaverseadam ADAE stores ASTDTM/AENDTM/LDOSEDTM as SAS date-scale',
        '(equal to *DT) with DATE format - export/Date-collapse artifact vs',
        'CDISC/admiral datetime + TMF.',
        'Do not treat SAS full datetime as a builder defect against this gold.',
        'Part B QC %m_qc_norm_dtm_scale promotes on compare copies only.');
      output;
    end;
    stop;
    keep DOMAIN USUBJID KEY_VARS KEY_TXT ISSUE_TYPE ISSUE_DESC N_ROWS EXAMPLE_SEQS SOURCE;
  run;

  %if &_n_dtm_scale = 0 %then
    %put NOTE: m_qc_sdtm_issues_pva - &refadae has no date-scale *DTM - no PVA_ADAE_DTM_DATE_COLLAPSE row.;
  %else
    %put NOTE: m_qc_sdtm_issues_pva - PVA_ADAE_DTM_DATE_COLLAPSE catalog row (N_ROWS=&_n_dtm_scale).;

  %end; /* &_adam_ok */

  /* ---- Rule ADAM-2: PVA_ADCM_AENDT_NO_EOS_CAP
     PVA/pharmaverseadam ADCM imputes partial CMENDTC to year-end (e.g. 31DEC)
     without capping by EOSDT. admiral ad_adcm.R uses hi=M date_imputation=last
     and max_dates=DTHDT,EOSDT - SAS %m_adcm_pva matches that. Catalog when
     refadcm has the known index case (01-718-1170 AENDT=31DEC2013). Do not
     change SAS AENDT to match PVA. ---- */
  %if &_adcm_ok = 0 %then %do;
    data work._qc_adam_adcm;
      set work._qc_sdtm_shell;
      stop;
    run;
    %put NOTE: m_qc_sdtm_issues_pva - &refadcm missing - ADCM AENDT catalog skipped.;
  %end;
  %else %do;

  %let _n_adcm_ye = 0;
  /* AENDT may be SAS date-scale on gold XPT - compare to mdy(12,31,2013) */
  proc sql noprint;
    select count(*) into :_n_adcm_ye trimmed
    from &refadcm
    where upcase(strip(USUBJID)) = '01-718-1170'
      and not missing(AENDT)
      and (
           (AENDT > 0 and AENDT < 100000 and AENDT = mdy(12, 31, 2013))
        or (AENDT >= 100000 and datepart(AENDT) = mdy(12, 31, 2013))
      )
    ;
  quit;

  data work._qc_adam_adcm;
    length DOMAIN $8 USUBJID $40 KEY_VARS $80 KEY_TXT $200
           ISSUE_TYPE $32 ISSUE_DESC $500 EXAMPLE_SEQS $200 SOURCE $8;
    length N_ROWS 8;
    if &_n_adcm_ye > 0 then do;
      DOMAIN       = 'ADCM';
      SOURCE       = 'ADAM';
      USUBJID      = '01-718-1170';
      ISSUE_TYPE   = 'PVA_ADCM_AENDT_NO_EOS_CAP';
      KEY_VARS     = 'USUBJID CMSEQ AENDT';
      KEY_TXT      = '01-718-1170 | CMENDTC=2013-11 | PVA AENDT=31DEC2013';
      EXAMPLE_SEQS = '20';
      N_ROWS       = &_n_adcm_ye;
      ISSUE_DESC   = catx(' ',
        'PVA/pharmaverseadam ADCM imputes partial CMENDTC to year-end without EOSDT cap.',
        'Index case: USUBJID=01-718-1170 CMENDTC=2013-11 EOSDT=03NOV2013 -',
        'PVA AENDT=31DEC2013 vs SAS/admiral AENDT=03NOV2013',
        '(hi=M date_imputation=last max_dates=DTHDT,EOSDT).',
        'Part B QC marks ADCM AENDT/AENDY-only diffs as POLICY - keep SAS.');
      output;
    end;
    stop;
    keep DOMAIN USUBJID KEY_VARS KEY_TXT ISSUE_TYPE ISSUE_DESC N_ROWS EXAMPLE_SEQS SOURCE;
  run;

  %if &_n_adcm_ye = 0 %then
    %put NOTE: m_qc_sdtm_issues_pva - &refadcm has no 01-718-1170 year-end AENDT - no PVA_ADCM_AENDT_NO_EOS_CAP row.;
  %else
    %put NOTE: m_qc_sdtm_issues_pva - PVA_ADCM_AENDT_NO_EOS_CAP catalog row (N_ROWS=&_n_adcm_ye).;

  %end; /* &_adcm_ok */

  /* ---- Stack SDTM + ADAM findings ----
     Future (BDS): append LB/EG/VS issue sets here with DOMAIN/ISSUE_TYPE
     codes such as LB_MISSING_LBDTC - keep SOURCE=SDTM.
     Future ADAM gold quirks: append with SOURCE=ADAM. ---- */
  data work._qc_data_all;
    set work._qc_sev
        work._qc_dup
        work._qc_miss
        work._qc_adam_dtm
        work._qc_adam_adcm
        work._qc_sdtm_shell;
  run;

  data &out;
    length ISSUE_ID $48;
    set work._qc_data_all;
    ISSUE_ID = cats(ISSUE_TYPE, '_', put(_n_, z4.));
    label
      ISSUE_ID     = 'Issue identifier'
      DOMAIN       = 'Domain (SDTM or ADaM)'
      USUBJID      = 'Unique Subject Identifier'
      KEY_VARS     = 'Grouping / key variables'
      KEY_TXT      = 'Key values (pipe-separated)'
      ISSUE_TYPE   = 'Issue type code'
      ISSUE_DESC   = 'Issue description'
      N_ROWS       = 'Rows contributing to issue'
      EXAMPLE_SEQS = 'Example *SEQ values'
      SOURCE       = 'Data source (SDTM or ADAM)'
    ;
  run;

  %let _n_iss = 0;
  data _null_;
    if 0 then set &out nobs=_n;
    call symputx('_n_iss', _n, 'l');
    stop;
  run;

  %put NOTE: m_qc_sdtm_issues_pva - &_n_iss issue row(s) written to &out.;

  proc datasets lib=work nolist;
    delete _qc_sdtm_shell _qc_sev_keys _qc_sev_detail _qc_sev
           _qc_dup_keys _qc_dup _qc_miss _qc_adam_dtm _qc_adam_adcm _qc_data_all;
  quit;

%mend m_qc_sdtm_issues_pva;
