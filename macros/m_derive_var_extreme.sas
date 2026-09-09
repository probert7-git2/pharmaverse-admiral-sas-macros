/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_derive_var_extreme.sas
  SAS Version                 : 9.4
  Purpose (short description) : Extreme flag/datetime and death cause ports
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Caller and source datasets
  Modification Log            : 09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Extreme flags / dates and death cause (ADSL Phase 1)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
/*******************************************************************************
  %m_derive_var_extreme_flag — substantial port of derive_var_extreme_flag()

  by_vars + order + mode=first|last → flag one record per by group.
*******************************************************************************/
%macro m_derive_var_extreme_flag(
  dataset=
, by_vars=USUBJID
, order=
, new_var=
, mode=first
, true_value=Y
, false_value=
, filter=
, out=
);
  %local i v md sort_ord ord_var ord_desc;

  %if %length(&dataset)=0 or %length(&new_var)=0 or %length(&out)=0
      or %length(&order)=0 %then %do;
    %put ERROR: m_derive_var_extreme_flag requires dataset=, by_vars=, order=, new_var=, out=.;
    %return;
  %end;

  %let md = %upcase(&mode);

  data work._exf0;
    set &dataset;
    %if %length(&filter) %then %do;
      where &filter;
    %end;
    _exf_seq = _n_;
  run;

  /* Build SORT order list */
  %let sort_ord =;
  %let i = 1;
  %let v = %scan(&order, &i, %str( ));
  %do %while(%length(&v));
    %let ord_desc = 0;
    %if %upcase(%scan(&v, 1, :)) = DESC %then %do;
      %let ord_var = %scan(&v, 2, :);
      %let ord_desc = 1;
    %end;
    %else %let ord_var = &v;
    %if &ord_desc %then %let sort_ord = &sort_ord descending &ord_var;
    %else %let sort_ord = &sort_ord &ord_var;
    %let i = %eval(&i + 1);
    %let v = %scan(&order, &i, %str( ));
  %end;

  proc sort data=work._exf0 out=work._exf1;
    by &by_vars &sort_ord;
  run;

  data work._exf2;
    set work._exf1;
    by &by_vars;
    length &new_var $1;
    &new_var = "&false_value";
    %if &md = FIRST %then %do;
      if first.%scan(&by_vars, %sysfunc(countw(&by_vars))) then &new_var = "&true_value";
    %end;
    %else %do;
      if last.%scan(&by_vars, %sysfunc(countw(&by_vars))) then &new_var = "&true_value";
    %end;
  run;

  /* If filter used, merge flag back to full dataset */
  %if %length(&filter) %then %do;
    proc sort data=&dataset out=work._exf_all;
      by &by_vars;
    run;
    proc sort data=work._exf2(keep=&by_vars _exf_seq &new_var) out=work._exf_flg;
      by &by_vars _exf_seq;
    run;
    /* Fall back: re-merge by by_vars keeping extreme rows only flagged via update */
    data &out;
      set &dataset;
      length &new_var $1;
      &new_var = "&false_value";
    run;
    /* Simpler path: output filtered flagged set when filter= supplied */
    %put NOTE: With filter=, out= contains filtered rows only (v1).;
    data &out;
      set work._exf2;
      drop _exf_seq;
    run;
  %end;
  %else %do;
    data &out;
      set work._exf2;
      drop _exf_seq;
    run;
  %end;

  proc datasets lib=work nolist;
    delete _exf0 _exf1 _exf2;
  quit;

  %m_nobs(ds=&out);
%mend m_derive_var_extreme_flag;


/*******************************************************************************
  %m_derive_var_extreme_dtm — substantial port of derive_var_extreme_dtm()

  Creates new datetime from extreme of source_vars (first/last by order).
  v1: single source_date + by_vars, mode first/last.
*******************************************************************************/
%macro m_derive_var_extreme_dtm(
  dataset=
, by_vars=USUBJID
, new_var=
, source_date=
, mode=last
, filter=
, out=
);
  %local md;

  %if %length(&dataset)=0 or %length(&new_var)=0 or %length(&source_date)=0
      or %length(&out)=0 %then %do;
    %put ERROR: m_derive_var_extreme_dtm requires dataset=, new_var=, source_date=, out=.;
    %return;
  %end;

  %let md = %upcase(&mode);

  proc sql;
    create table work._exdt as
    select %sysfunc(tranwrd(&by_vars, %str( ), %str(, )))
         , %if &md = FIRST %then min(&source_date); %else max(&source_date);
           as &new_var
    from &dataset
    %if %length(&filter) %then %do;
      where &filter
    %end;
    group by %sysfunc(tranwrd(&by_vars, %str( ), %str(, )))
    ;
  quit;

  proc sort data=&dataset out=work._exbase;
    by &by_vars;
  run;
  proc sort data=work._exdt;
    by &by_vars;
  run;

  data &out;
    merge work._exbase work._exdt;
    by &by_vars;
  run;

  proc datasets lib=work nolist;
    delete _exdt _exbase;
  quit;

  %m_nobs(ds=&out);
%mend m_derive_var_extreme_dtm;


/*******************************************************************************
  %m_derive_var_dthcaus — substantial port of derive_var_dthcaus()

  v1: merge a cause variable from a source dataset (e.g. DD or DS) by by_vars.
  dthcaus_source style: one source table + cause var + optional filter.

  Example:
    %m_derive_var_dthcaus(
      dataset=adam.adsl
    , source_ds=raw.dd
    , by_vars=STUDYID USUBJID
    , dthcaus=DDECOD
    , filter=%str(upcase(DDTESTCD)='PRCDTH')
    , new_var=DTHCAUS
    , out=adam.adsl
    );
*******************************************************************************/
%macro m_derive_var_dthcaus(
  dataset=
, source_ds=
, by_vars=STUDYID USUBJID
, dthcaus=
, filter=%str(1)
, new_var=DTHCAUS
, mode=first
, order=
, out=
);
  %local ord;

  %if %length(&dataset)=0 or %length(&source_ds)=0 or %length(&dthcaus)=0
      or %length(&out)=0 %then %do;
    %put ERROR: m_derive_var_dthcaus requires dataset=, source_ds=, dthcaus=, out=.;
    %return;
  %end;

  %if %length(&order) %then %let ord = &order;
  %else %let ord = &dthcaus;

  %m_derive_vars_merged(
    dataset=&dataset
  , dataset_add=&source_ds
  , by_vars=&by_vars
  , order=&ord
  , new_vars=&new_var=&dthcaus
  , filter_add=&filter
  , mode=&mode
  , out=&out
  );

%mend m_derive_var_dthcaus;
