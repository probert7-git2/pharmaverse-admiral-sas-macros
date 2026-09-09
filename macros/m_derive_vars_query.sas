/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_derive_vars_query.sas
  SAS Version                 : 9.4
  Purpose (short description) : Derive SMQ/CQ query variables (AESI) like admiral derive_vars_query
  Author                      : Cursor Grok 4.5
  Date                        : 10AUG2026
  Input Datasets or Metadata  : ADAE-like dataset + queries CSV/dataset
                                metadata/aesi_queries_bladder.csv (example)
  Modification Log            : 13AUG2026 - Avoid LENGTH-after-SET warnings; force numeric query ids.
                                10AUG2026 - Initial substantial port for AESI / SMQ / CQ.

  --- Notes ---
  Pharmaverse has no derive_var_aesi. AESI are study-defined queries applied via
  derive_vars_query() / create_query_data(). This macro ports that pattern.

  Queries dataset columns (admiral vignette queries_dataset):
    PREFIX GRPNAME SRCVAR TERMCHAR and/or TERMNUM
    optional: GRPID SCOPE SCOPEN

  For each PREFIX creates:
    PREFIX||NAM (always)
    PREFIX||CD when GRPID present
    PREFIX||SC when SCOPE present
    PREFIX||SCN when SCOPEN present

  Matching is case-insensitive on TERMCHAR vs the named SRCVAR on analysis data.
  Demo SRCVAR values supported: AEDECOD, AETERM.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


/*******************************************************************************
  %m_load_query_data — import queries CSV
*******************************************************************************/
%macro m_load_query_data(
  queries_csv=
, out=work.aesi_queries
);
  %local qcsv;
  %if %length(&queries_csv) = 0 %then
    %let qcsv = &ROOT/metadata/aesi_queries_bladder.csv;
  %else %let qcsv = &queries_csv;

  %if %sysfunc(fileexist(&qcsv)) = 0 %then %do;
    %put ERROR: m_load_query_data - file not found: &qcsv;
    %return;
  %end;

  proc import datafile="&qcsv"
              out=work._aesi_q_imp
              dbms=csv replace;
       guessingrows=max;
       getnames=yes;
  run;

  /* LENGTH before SET; rename import vars so PDV lengths are not already set */
  data &out;
       length PREFIX $8 GRPNAME $200 SRCVAR $32 TERMCHAR $200 SCOPE $20 COMMENT $200
              GRPID 8 SCOPEN 8 TERMNUM 8;
       set work._aesi_q_imp (rename=(
            PREFIX=__PREFIX GRPNAME=__GRPNAME SRCVAR=__SRCVAR
            TERMCHAR=__TERMCHAR SCOPE=__SCOPE COMMENT=__COMMENT
            GRPID=__GRPID SCOPEN=__SCOPEN TERMNUM=__TERMNUM
       ));
       PREFIX   = upcase(strip(__PREFIX));
       GRPNAME  = strip(__GRPNAME);
       SRCVAR   = upcase(strip(__SRCVAR));
       TERMCHAR = strip(__TERMCHAR);
       SCOPE    = strip(__SCOPE);
       COMMENT  = strip(__COMMENT);
       /* Force numeric ids - PROC IMPORT may guess character */
       GRPID   = input(cats(__GRPID), ?? best32.);
       SCOPEN  = input(cats(__SCOPEN), ?? best32.);
       TERMNUM = input(cats(__TERMNUM), ?? best32.);
       drop __PREFIX __GRPNAME __SRCVAR __TERMCHAR __SCOPE __COMMENT
            __GRPID __SCOPEN __TERMNUM;
  run;

  proc datasets lib=work nolist;
       delete _aesi_q_imp;
  quit;

  %put NOTE: m_load_query_data -> &out;
%mend m_load_query_data;


/*******************************************************************************
  %m_derive_vars_query — substantial port of admiral::derive_vars_query()
*******************************************************************************/
%macro m_derive_vars_query(
  dataset=
, dataset_queries=
, out=
, aesi_flag_var=AESIFL
);
  %local npref i pref nam_var cd_var sc_var scn_var has_cd has_sc has_scn;

  %if %length(&dataset)=0 or %length(&dataset_queries)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_derive_vars_query requires dataset=, dataset_queries=, out=.;
    %return;
  %end;
  %if %sysfunc(exist(&dataset_queries)) = 0 %then %do;
    %put ERROR: m_derive_vars_query - queries dataset &dataset_queries not found.;
    %return;
  %end;

  proc sql noprint;
       create table work._q_pref as
       select distinct PREFIX
       from &dataset_queries
       where not missing(PREFIX)
       order by PREFIX
       ;
       select count(*) into :npref trimmed from work._q_pref;
  quit;

  %if &npref = 0 %then %do;
    %put WARNING: m_derive_vars_query - no PREFIX values in queries dataset.;
    data &out;
         set &dataset;
    run;
    %return;
  %end;

  data work._q_out;
       set &dataset;
       _rowid = _n_;
       %if %length(&aesi_flag_var) %then %do;
         length &aesi_flag_var $1;
         &aesi_flag_var = '';
       %end;
  run;

  %do i = 1 %to &npref;
    data _null_;
         set work._q_pref (firstobs=&i obs=&i);
         call symputx('pref', strip(PREFIX), 'l');
    run;

    %let nam_var = &pref.NAM;
    %let cd_var  = &pref.CD;
    %let sc_var  = &pref.SC;
    %let scn_var = &pref.SCN;

    proc sql noprint;
         select max(case when not missing(GRPID) then 1 else 0 end)
              , max(case when not missing(SCOPE) and strip(SCOPE) ^= '' then 1 else 0 end)
              , max(case when not missing(SCOPEN) then 1 else 0 end)
         into :has_cd trimmed, :has_sc trimmed, :has_scn trimmed
         from &dataset_queries
         where PREFIX = "&pref"
         ;
    quit;

    data work._q_terms;
         set &dataset_queries;
         where PREFIX = "&pref";
         length TERM_U $200;
         if not missing(TERMCHAR) and strip(TERMCHAR) ^= '' then TERM_U = upcase(strip(TERMCHAR));
         else call missing(TERM_U);
         if missing(TERM_U) then delete;
    run;

    data work._q_hit;
         length GRPNAME $200 SCOPE $20 SRCVAR $32 TERM_U $200;
         if _n_ = 1 then do;
              declare hash h(dataset: 'work._q_terms', multidata: 'y');
              h.defineKey('SRCVAR', 'TERM_U');
              h.defineData('GRPNAME', 'GRPID', 'SCOPE', 'SCOPEN');
              h.defineDone();
         end;
         set work._q_out (keep=_rowid AEDECOD AETERM);
         call missing(GRPNAME, GRPID, SCOPE, SCOPEN);
         _hit = 0;

         SRCVAR = 'AEDECOD';
         TERM_U = upcase(strip(AEDECOD));
         if not missing(TERM_U) then do;
              rc = h.find();
              if rc = 0 then _hit = 1;
         end;

         if not _hit then do;
              SRCVAR = 'AETERM';
              TERM_U = upcase(strip(AETERM));
              if not missing(TERM_U) then do;
                   rc = h.find();
                   if rc = 0 then _hit = 1;
              end;
         end;

         if _hit then output;
         keep _rowid GRPNAME GRPID SCOPE SCOPEN;
    run;

    proc sort data=work._q_hit;
         by _rowid;
    run;

    data work._q_out;
         merge work._q_out (in=a)
               work._q_hit (in=b rename=(GRPNAME=_QN GRPID=_QCD SCOPE=_QSC SCOPEN=_QSCN));
         by _rowid;
         length &nam_var $200;
         if a;
         if b then do;
              &nam_var = _QN;
              %if &has_cd = 1 %then %do;
                length &cd_var 8;
                &cd_var = _QCD;
              %end;
              %if &has_sc = 1 %then %do;
                length &sc_var $20;
                &sc_var = _QSC;
              %end;
              %if &has_scn = 1 %then %do;
                length &scn_var 8;
                &scn_var = _QSCN;
              %end;
              %if %length(&aesi_flag_var) %then %do;
                &aesi_flag_var = 'Y';
              %end;
         end;
         else do;
              call missing(&nam_var);
              %if &has_cd = 1 %then %do; call missing(&cd_var); %end;
              %if &has_sc = 1 %then %do; call missing(&sc_var); %end;
              %if &has_scn = 1 %then %do; call missing(&scn_var); %end;
         end;
         drop _QN _QCD _QSC _QSCN;
    run;
  %end;

  data &out;
       set work._q_out;
       drop _rowid;
  run;

  proc datasets lib=work nolist;
       delete _q_pref _q_out _q_hit _q_terms;
  quit;

  %m_nobs(ds=&out);
  %put NOTE: m_derive_vars_query complete -> &out;
%mend m_derive_vars_query;
