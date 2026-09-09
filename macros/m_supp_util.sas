/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_supp_util.sas
  SAS Version                 : 9.4
  Purpose (short description) : SUPP CT apply, subject flags, and parent merge utilities
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : SUPP* domains and metadata.supp_qnam_ct
  Modification Log            : 09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  SUPP parent/child merge utilities with controlled terminology (CT)

    Flow:
      1) %m_supp_apply_ct  — map QVAL → CODE via metadata.supp_qnam_ct;
                             unknown strings → work.supp_ct_violations (+ policy)
      2) %m_supp_qnam_flags — subject-level flags from CT-normalized SUPP
      3) %m_supp_merge_by_idvar — record-level QNAM onto parent (e.g. AE←SUPPAE)

    CT seed: SAS/metadata/supp_qnam_ct.sas  (extend as new QVAL text appears)

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
/*******************************************************************************
  %m_supp_apply_ct

  dataset_supp : SUPP-- (must have QNAM, QVAL)
  ct_ds        : CT metadata (default metadata.supp_qnam_ct)
  policy       :
      map     - replace QVAL with CODE when matched; unmatched → missing + log
      keep    - keep original QVAL when unmatched; still log
      error   - abort after logging if any unmatched non-missing QVAL
  out          : CT-normalized SUPP (adds QVAL_RAW, QVAL_CODE, CT_MATCH)
*******************************************************************************/



%macro m_supp_apply_ct(
  dataset_supp=
, ct_ds=metadata.supp_qnam_ct
, policy=map
, out=
, violations=work.supp_ct_violations
);

  %local pol n_bad;

  %if %length(&dataset_supp)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_supp_apply_ct requires dataset_supp= and out=.;
    %return;
  %end;
  %if %sysfunc(exist(&dataset_supp)) = 0 %then %do;
    %put ERROR: m_supp_apply_ct - &dataset_supp not found.;
    %return;
  %end;
  %if %sysfunc(exist(&ct_ds)) = 0 %then %do;
    /* Auto-load seed CT if init did not (common when metadata/ not uploaded yet) */
    %if %symexist(ROOT) %then %do;
      %if %sysfunc(fileexist(&ROOT/metadata/supp_qnam_ct.sas)) %then %do;
        %put NOTE: m_supp_apply_ct - loading &ROOT/metadata/supp_qnam_ct.sas;
        %include "&ROOT/metadata/supp_qnam_ct.sas";
      %end;
    %end;
  %end;
  %if %sysfunc(exist(&ct_ds)) = 0 %then %do;
    %put ERROR: m_supp_apply_ct - CT dataset &ct_ds not found.;
    %put ERROR: Upload SAS/metadata/supp_qnam_ct.sas to ODA and re-run init.;
    /* Still create empty out so callers do not cascade on missing WORK._SUPP_CT */
    data &out;
      set &dataset_supp;
      stop;
    run;
    data &violations;
      stop;
    run;
    %return;
  %end;

  %let pol = %upcase(&policy);

  data work._ct_key;
       set &ct_ds;
       where ALLOWED = 'Y';
       length _qnam_u $32 _dec_u $200;
       _qnam_u = upcase(strip(QNAM));
       _dec_u  = upcase(strip(DECODE));
    keep _qnam_u _dec_u CODE CLNAME;
  run;

  proc sort data=work._ct_key nodupkey;
       by _qnam_u _dec_u;
  run;

  data work._supp_in;
       set &dataset_supp;
       length _qnam_u $32 
              _dec_u $200 
              QVAL_RAW $200;
       QVAL_RAW = strip(QVAL);
       _qnam_u = upcase(strip(QNAM));
       _dec_u  = upcase(strip(QVAL_RAW));
  run;

  proc sort data=work._supp_in;
       by _qnam_u _dec_u;
  run;

  data &out &violations;
    length CT_MATCH $1 QVAL_CODE $40;
    merge work._supp_in(in=s) work._ct_key(in=c);
    by _qnam_u _dec_u;
    if s;
    CT_MATCH = 'N';
    QVAL_CODE = '';

    if missing(QVAL_RAW) then do;
      CT_MATCH = 'Y'; /* blank allowed */
      QVAL_CODE = '';
    end;
    else if c then do;
      CT_MATCH = 'Y';
      QVAL_CODE = strip(CODE);
    end;

    if CT_MATCH = 'N' and not missing(QVAL_RAW) then do;
      output &violations;
      %if &pol = MAP %then %do;
        QVAL = '';
      %end;
      %else %do;
        QVAL = QVAL_RAW;
      %end;
    end;
    else do;
      %if &pol = MAP %then %do;
        if not missing(QVAL_CODE) then QVAL = QVAL_CODE;
        else QVAL = QVAL_RAW;
      %end;
      %else %do;
        QVAL = QVAL_RAW;
      %end;
    end;

    drop _qnam_u _dec_u;
    output &out;
  run;

  proc sql noprint;
       select count(*) into :n_bad trimmed 
       from &violations;
  quit;

  %if &n_bad > 0 %then %do;
    %put WARNING: m_supp_apply_ct - &n_bad SUPP QVAL value(s) not in CT (&ct_ds).;
    %put WARNING: Review &violations and add DECODE synonyms to metadata/supp_qnam_ct.sas.;
    title "SUPP CT violations (add to metadata.supp_qnam_ct)";
    proc print data=&violations(obs=50);
      var STUDYID USUBJID QNAM QVAL_RAW QLABEL;
    run;
    title;
    %if &pol = ERROR %then %do;
      %put ERROR: m_supp_apply_ct policy=error and CT violations found. Aborting.;
      %abort cancel;
    %end;
  %end;
  %else %put NOTE: m_supp_apply_ct - all non-missing QVAL values matched CT.;

  proc datasets lib=work nolist;
       delete _ct_key 
              _supp_in;
  quit;

  %m_nobs(ds=&out);
%mend m_supp_apply_ct;


/*******************************************************************************
  %m_supp_qnam_flags — pivot SUPP QNAM/QVAL to subject-level flags (CT-aware)
*******************************************************************************/
%macro m_supp_qnam_flags(
  dataset=
, by_vars=STUDYID USUBJID
, qnam_map=
, out=
, apply_ct=Y
, ct_ds=metadata.supp_qnam_ct
, ct_policy=map
);
  %local i tok qnam flag by_csv _src;

  %if %length(&dataset)=0 or %length(&qnam_map)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_supp_qnam_flags requires dataset=, qnam_map=, out=.;
    %return;
  %end;
  %if %sysfunc(exist(&dataset)) = 0 %then %do;
    %put ERROR: m_supp_qnam_flags - &dataset not found.;
    %return;
  %end;

  %let _src = &dataset;
  %if %upcase(&apply_ct) = Y %then %do;
    %m_supp_apply_ct(
      dataset_supp=&dataset
    , ct_ds=&ct_ds
    , policy=&ct_policy
    , out=work._supp_ct
    );
    %let _src = work._supp_ct;
  %end;

  proc sort data=&_src out=work._supp0;
    by &by_vars;
  run;

  data &out;
    set work._supp0;
    by &by_vars;
    length
    %let i = 1;
    %let tok = %scan(&qnam_map, &i, %str( ));
    %do %while(%length(&tok));
      %let flag = %scan(&tok, 2, =);
      &flag $1
      %let i = %eval(&i + 1);
      %let tok = %scan(&qnam_map, &i, %str( ));
    %end;
    ;
    retain
    %let i = 1;
    %let tok = %scan(&qnam_map, &i, %str( ));
    %do %while(%length(&tok));
      %let flag = %scan(&tok, 2, =);
      &flag
      %let i = %eval(&i + 1);
      %let tok = %scan(&qnam_map, &i, %str( ));
    %end;
    ;
    if first.%scan(&by_vars, %sysfunc(countw(&by_vars))) then do;
      %let i = 1;
      %let tok = %scan(&qnam_map, &i, %str( ));
      %do %while(%length(&tok));
        %let flag = %scan(&tok, 2, =);
        &flag = '';
        %let i = %eval(&i + 1);
        %let tok = %scan(&qnam_map, &i, %str( ));
      %end;
    end;

    %let i = 1;
    %let tok = %scan(&qnam_map, &i, %str( ));
    %do %while(%length(&tok));
      %let qnam = %scan(&tok, 1, =);
      %let flag = %scan(&tok, 2, =);
      if upcase(strip(QNAM)) = "%upcase(&qnam)" then &flag = strip(QVAL);
      %let i = %eval(&i + 1);
      %let tok = %scan(&qnam_map, &i, %str( ));
    %end;

    if last.%scan(&by_vars, %sysfunc(countw(&by_vars)));
    keep &by_vars
    %let i = 1;
    %let tok = %scan(&qnam_map, &i, %str( ));
    %do %while(%length(&tok));
      %let flag = %scan(&tok, 2, =);
      &flag
      %let i = %eval(&i + 1);
      %let tok = %scan(&qnam_map, &i, %str( ));
    %end;
    ;
  run;

  proc datasets lib=work nolist;
       delete _supp0
              _supp_ct;
  quit;

  %m_nobs(ds=&out);
%mend m_supp_qnam_flags;


/*******************************************************************************
  %m_supp_merge_by_idvar — merge SUPP QNAM onto parent (CT-aware)
*******************************************************************************/
%macro m_supp_merge_by_idvar(
                               dataset=
                             , dataset_supp=
                             , qnam=
                             , new_var=
                             , by_vars=STUDYID USUBJID
                             , out=
                             , apply_ct=Y
                             , ct_ds=metadata.supp_qnam_ct
                             , ct_policy=map
                            );
  %local _supp;

  %if %length(&dataset)=0 or %length(&dataset_supp)=0 or %length(&qnam)=0
      or %length(&new_var)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_supp_merge_by_idvar missing required args.;
    %return;
  %end;

  %let _supp = &dataset_supp;
  %if %upcase(&apply_ct) = Y %then %do;
    %m_supp_apply_ct(
      dataset_supp=&dataset_supp
    , ct_ds=&ct_ds
    , policy=&ct_policy
    , out=work._supp_ct2
    );
    %let _supp = work._supp_ct2;
  %end;

  data work._supprow;
       set &_supp;
       where upcase(strip(QNAM)) = "%upcase(&qnam)";
       length _idvar $32;
       _idvar = upcase(strip(IDVAR));
       if _idvar = 'AESEQ' then AESEQ = input(cats(IDVARVAL), ?? best32.);
       keep &by_vars AESEQ QVAL;
       rename QVAL = &new_var;
  run;

  proc sort data = &dataset
             out = work._par;
       by &by_vars AESEQ;
  run;
  proc sort data=work._supprow;
       by &by_vars AESEQ;
  run;

  data &out;
       merge work._par(in=a)
             work._supprow;
       by &by_vars AESEQ;
       if a;
  run;

  proc datasets lib=work nolist;
       delete _supprow 
              _par 
              _supp_ct2;
  quit;

  %m_nobs(ds=&out);
%mend m_supp_merge_by_idvar;
