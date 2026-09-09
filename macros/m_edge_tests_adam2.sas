/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_edge_tests_adam2.sas
  SAS Version                 : 9.4
  Purpose (short description) : Edge tests on built ADaM2 keys, flags, and counts
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : adam.adsl adae adtte advs adeg adcm adlb
  Modification Log            : 09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Edge / regression tests for ADaM2 (callable from suite or standalone).

  Requires: init_libnames_oda, m_util already included.



  ODA-safe: avoid PROC SQL HAVING, missing() in SQL WHERE, and '' in IN lists.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/



%macro m_edge_tests_adam2;

       %put NOTE: ===== m_edge_tests_adam2 starting =====;

  %macro _edge_nobs_if(ds);
         %if %sysfunc(exist(&ds)) %then %do;
             %m_nobs(ds=&ds);
         %end;
         %else %do;
             %put WARNING: [edge] Expected dataset &ds not found.;
         %end;
  %mend _edge_nobs_if;

  %_edge_nobs_if(adam.adsl);
  %_edge_nobs_if(adam.adae);
  %_edge_nobs_if(adam.adtte);
  %_edge_nobs_if(adam.advs);
  %_edge_nobs_if(adam.adeg);
  %_edge_nobs_if(adam.adcm);
  %_edge_nobs_if(adam.adlb);

  %macro _edge_sql_count(ds, where, msg);
         %local _n;
         %let _n = 0;
         %if %sysfunc(exist(&ds)) %then %do;
             proc sql noprint;
                  select count(*) into :_n trimmed 
                  from &ds where &where;
             quit;

             %if %sysevalf(&_n > 0) %then %put WARNING: [edge &msg] &_n rows flagged;
         %end;
  %mend _edge_sql_count;

  %_edge_sql_count(adam.adsl, USUBJID is null, ADSL missing USUBJID);
  %_edge_sql_count(adam.adae, USUBJID is null or AESEQ is null, ADAE missing USUBJID/AESEQ);
  %_edge_sql_count(adam.adtte, USUBJID is null or PARAMCD is null, ADTTE missing USUBJID/PARAMCD);
  %_edge_sql_count(adam.advs, USUBJID is null or VSSEQ is null or PARAMCD is null, ADVS missing keys/PARAMCD);
  %_edge_sql_count(adam.adeg, USUBJID is null or EGSEQ is null or PARAMCD is null, ADEG missing keys/PARAMCD);
  %_edge_sql_count(adam.adcm, USUBJID is null or CMSEQ is null, ADCM missing USUBJID/CMSEQ);


  %macro _edge_dup(ds, keys, label);
         %local _nd dsid;
         %let _nd = 0;
         %if %sysfunc(exist(&ds)) %then %do;
             proc sort data=&ds 
                        out=work._edgsort_&label;
                  by &keys;
             run;
             proc sort data = work._edgsort_&label nodupkey 
                     dupout = work._dup_&label;
                  by &keys;
             run;

             %if %sysfunc(exist(work._dup_&label)) %then %do;
                 %let dsid = %sysfunc(open(work._dup_&label, i));
                 %let _nd  = %sysfunc(attrn(&dsid, nlobs));
                 %let dsid = %sysfunc(close(&dsid));
             %end;
             %if %sysevalf(&_nd > 0) %then %do;
                 %put WARNING: [edge &label] &_nd duplicate key row(s) on &keys;
                 proc print data=work._dup_&label(obs=10);
                 run;
             %end;
             %else %put NOTE: [edge &label] no duplicate keys on &keys;

             proc datasets lib=work nolist;
                  delete _edgsort_&label 
                         _dup_&label;

             quit;
        %end;
  %mend _edge_dup;

  %_edge_dup(adam.adae, USUBJID AESEQ, ADAE);
  %_edge_dup(adam.adtte, USUBJID PARAMCD, ADTTE);
  %_edge_dup(adam.advs, USUBJID VSSEQ, ADVS);
  %_edge_dup(adam.adeg, USUBJID EGSEQ, ADEG);
  %_edge_dup(adam.adcm, USUBJID CMSEQ, ADCM);


  %macro _edge_bad_flag(ds, var, label);
         %local _n;
         %let _n = 0;
         %if %sysfunc(exist(&ds)) %then %do;
         data _null_;
              if 0 then set &ds(keep=&var);
              set &ds end=_eof;
              if not missing(&var) and strip(&var) ne '' and strip(&var) ne 'Y' then _n + 1;
              if _eof then call symputx('_n', put(_n, best.));
              retain _n 0;
         run;
         %if %sysevalf(&_n > 0) %then %put WARNING: [edge &label] &_n unexpected &var values;
    %end;
  %mend _edge_bad_flag;

  %_edge_bad_flag(adam.adae, TRTEMFL, ADAE);
  %_edge_bad_flag(adam.advs, ABLFL, ADVS);
  %_edge_sql_count(adam.adtte, CNSR is not null and CNSR not in (0, 1), ADTTE invalid CNSR);

  %macro _edge_ncompare(sasds, refds, label);
         %if %sysfunc(exist(&sasds)) and %sysfunc(exist(&refds)) %then %do;
             %let dsid = %sysfunc(open(&sasds, i));
             %let ns = %sysfunc(attrn(&dsid, nlobs));
             %let dsid = %sysfunc(close(&dsid));
             %let dsid = %sysfunc(open(&refds, i));
             %let nr = %sysfunc(attrn(&dsid, nlobs));
             %let dsid = %sysfunc(close(&dsid));
             %put NOTE: [edge &label] n SAS=&ns ref=&nr;
             %if &ns ne &nr %then %put WARNING: [edge &label] row count differs from ref;
         %end;
  %mend _edge_ncompare;

  %_edge_ncompare(adam.adsl, ref.ref_adsl, ADSL);
  %_edge_ncompare(adam.adae, ref.ref_adae, ADAE);
  %_edge_ncompare(adam.adtte, ref.ref_adttee, ADTTE);
  %_edge_ncompare(adam.advs, ref.ref_advs, ADVS);
  %_edge_ncompare(adam.adeg, ref.ref_adeg, ADEG);
  %_edge_ncompare(adam.adcm, ref.ref_adcm, ADCM);
  %_edge_ncompare(adam.adlb, ref.ref_adlb, ADLB);

  %put NOTE: ===== m_edge_tests_adam2 complete =====;

%mend m_edge_tests_adam2;

