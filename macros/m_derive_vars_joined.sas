/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_derive_vars_joined.sas
  SAS Version                 : 9.4
  Purpose (short description) : admiral-style joined/last-dose derivation ports
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Caller base and add datasets
  Modification Log            : 17AUG2026 - Upcased NAME merge for label restore (case-safe).
                                15AUG2026 - Restore input var labels after PROC SQL join (out=).
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  %m_derive_vars_joined  — moderate SAS port of admiral::derive_vars_joined()

    Supported (core):
      dataset, dataset_add, by_vars, order, new_vars, join_type,
      filter_add, filter_join, mode, exist_flag / true_value / false_value, out

    join_type:
      all | left  — keep all rows of dataset; attach matching dataset_add rows
                    that satisfy filter_join (admiral "all" style for AE←EX)
      inner       — keep only dataset rows with ≥1 matching add row
      full | outer — accepted as synonyms for all (v1 port scope)

    Not in v1: right join (reverse dataset roles instead), before/after/containment,
      first_cond_*, tmp_obs_nr_var, join_vars suffix .join, check_type,
      missing_values, named exprs in order

    order:
      Space-separated tokens. Prefix DESC: for descending, e.g.
        order=DESC:EXSTDT DESC:EXSEQ
        order=EXSTDT EXSEQ
      Order variable names are taken from dataset_add (admiral rule). They are
      joined as temporary _dvj_ord* columns for PROC SORT, then dropped.

    new_vars:
      Space-separated NEW=OLD pairs (OLD is on dataset_add), e.g.
        new_vars=LDOSEDT=EXSTDT LDOSE=EXDOSE

    filter_add / filter_join:
      SAS expressions. In filter_join use a. for dataset and b. for dataset_add:
        filter_join=%str(b.EXSTDT <= a.AESTDT)

    mode:
      first | last — after sorting by by_vars + _dvj_obs + order, keep first/last
                     row per base observation (admiral order + mode first/last)
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_derive_vars_joined(
                              dataset=
                            , dataset_add=
                            , by_vars=USUBJID
                            , order=
                            , new_vars=
                            , join_type=all
                            , filter_add=%str(1)
                            , filter_join=%str(1)
                            , mode=last
                            , exist_flag=
                            , true_value=Y
                            , false_value=
                            , out=
                            );

  %local i 
         v 
         by_on 
         sel_new 
         sel_ord 
         sort_extra 
         nv_new 
         nv_old 
         jt 
         md
         n_by 
         last_by 
         ord_var 
         ord_desc 
         n_ord;

  %if %length(&dataset)=0 or 
      %length(&dataset_add)=0 or 
      %length(&out)=0 %then %do;
          %put ERROR: m_derive_vars_joined requires dataset=, dataset_add=, and out=.;
          %return;
  %end;

  %let jt = %upcase(&join_type);
  %let md = %upcase(&mode);

  %if &jt = FULL  or 
      &jt = OUTER or 
      &jt = FULLOUTER %then %let jt = ALL;

  %if &jt ne ALL  and 
      &jt ne LEFT and 
      &jt ne INNER %then %do;
          %if &jt = RIGHT %then %do;
              %put NOTE: join_type=right is not ported in v1 - swap dataset and dataset_add.;
          %end;
          %put ERROR: join_type must be all, left, inner, or full (alias for all). Got &join_type;
          %return;
  %end;

  %if &md ne FIRST and 
      &md ne LAST %then %do;
          %put ERROR: mode must be first or last. Got &mode;
          %return;
  %end;

  %if %length(&order) and %length(&mode)=0 %then %do;
      %put ERROR: mode= is required when order= is specified.;
      %return;
  %end;

  *---- by_vars ON clause: a.VAR = b.VAR ----;
  %let by_on =;
  %let i = 1;
  %let v = %scan(&by_vars, &i, %str( ));

  %do %while(%length(&v));
      %if &i > 1 %then %let by_on = &by_on and;
      %let by_on = &by_on a.&v = b.&v;
      %let i = %eval(&i + 1);
      %let v = %scan(&by_vars, &i, %str( ));
  %end;

  %if %length(&by_on)=0 %then %do;
      %put ERROR: by_vars= must list at least one variable.;
      %return;
  %end;

  *---- new_vars SELECT list: b.OLD as NEW ----;
  * Skip NEW if it already exists on dataset (avoids PROC SQL
  * "Variable X already exists on file WORK._DVJ_JOINED").;
  %local dsid_nv;
  %let dsid_nv = %sysfunc(open(&dataset, i));
  %if &dsid_nv = 0 %then %do;
      %put ERROR: m_derive_vars_joined cannot open &dataset.;
      %return;
  %end;

  %let sel_new =;
  %let i = 1;
  %let v = %scan(&new_vars, &i, %str( ));
  %do %while(%length(&v));
    %let nv_new = %scan(&v, 1, =);
    %let nv_old = %scan(&v, 2, =);
    %if %length(&nv_old)=0 %then %do;
      %let dsid_nv = %sysfunc(close(&dsid_nv));
      %put ERROR: new_vars token "&v" must be NEW=OLD.;
      %return;
    %end;
    %if %sysfunc(varnum(&dsid_nv, &nv_new)) > 0 %then %do;
      %put NOTE: m_derive_vars_joined - &nv_new already on &dataset - not re-created from join.;
    %end;
    %else %do;
      %let sel_new = &sel_new , b.&nv_old as &nv_new;
    %end;
    %let i = %eval(&i + 1);
    %let v = %scan(&new_vars, &i, %str( ));
  %end;
  %let dsid_nv = %sysfunc(close(&dsid_nv));

  *---- order vars from dataset_add as _dvj_ord1.. for SORT (admiral uses add-side names);
  *     new_vars renames mean EXSTDT is not on the joined table unless brought in here;
  %let sel_ord =;
  %let sort_extra =;
  %let n_ord = 0;
  %let i = 1;
  %let v = %scan(&order, &i, %str( ));
  %do %while(%length(&v));
    %let ord_desc = 0;
    %if %upcase(%scan(&v, 1, :)) = DESC %then %do;
      %let ord_var = %scan(&v, 2, :);
      %let ord_desc = 1;
    %end;
    %else %if %upcase(%scan(&v, 2, :)) = DESC %then %do;
      %let ord_var = %scan(&v, 1, :);
      %let ord_desc = 1;
    %end;
    %else %let ord_var = &v;

    %if %length(&ord_var)=0 %then %do;
      %put ERROR: could not parse order token "&v";
      %return;
    %end;

    %let n_ord = %eval(&n_ord + 1);
    %let sel_ord = &sel_ord , b.&ord_var as _dvj_ord&n_ord;
    /* PROC SORT: keyword DESCENDING must precede the variable name */
    %if &ord_desc %then
      %let sort_extra = &sort_extra descending _dvj_ord&n_ord;
    %else
      %let sort_extra = &sort_extra _dvj_ord&n_ord;

    %let i = %eval(&i + 1);
    %let v = %scan(&order, &i, %str( ));
  %end;

  *---- 1) filter dataset_add ----;
  data _dvj_add;
    set &dataset_add;
    where &filter_add;
  run;

  *---- 2) tag base rows ----;
  data _dvj_base;
    set &dataset;
    _dvj_obs = _N_;
  run;

  *---- 3) join (keep new_vars + order helper cols from dataset_add) ----;
  proc sql;
       create table _dvj_joined as
       select a.*
              %if %length(&sel_new) %then %do; &sel_new %end;
              %if %length(&sel_ord) %then %do; &sel_ord %end;
              , case when b.%scan(&by_vars, 1, %str( )) is not null then 1 else 0 end as _dvj_hit
       from _dvj_base as a
       %if &jt = INNER %then %do;
          inner join _dvj_add as b
       %end;
       %else %do;
          left join _dvj_add as b
       %end;
       on &by_on
       and (&filter_join)
    ;
  quit;

  *---- 4) extreme select by mode (admiral: order then first/last) ----;
  %if %length(&order) %then %do;
    proc sort data=_dvj_joined;
         by &by_vars _dvj_obs &sort_extra;
    run;

    data _dvj_out;
         set _dvj_joined;
         by &by_vars _dvj_obs;
         %if &md = FIRST %then %do;
            if first._dvj_obs;
         %end;
         %else %do;
            if last._dvj_obs;
         %end;
    run;
  %end;
  %else %do;
    * No order/mode: keep one arbitrary match per base row;
    * (preserves 1:1 with dataset rows);
    proc sort data=_dvj_joined;
         by &by_vars _dvj_obs;
    run;
    data _dvj_out;
        set _dvj_joined;
        by &by_vars _dvj_obs;
        if first._dvj_obs;
    run;
  %end;

  *---- 5) exist_flag + drop helpers ----;
  data &out;
    set _dvj_out;
    %if %length(&exist_flag) %then %do;
      length &exist_flag $1;
      if _dvj_hit = 1 then &exist_flag = "&true_value";
      else &exist_flag = "&false_value";
    %end;
    drop _dvj_obs _dvj_hit;
    %if &n_ord > 0 %then %do;
      drop _dvj_ord1-_dvj_ord&n_ord;
    %end;
  run;

  /* PROC SQL CREATE TABLE joins often drop labels - restore from input dataset */
  %local _out_lib _out_mem _n_relabel;
  %if %index(&out, %str(.)) %then %do;
    %let _out_lib = %upcase(%scan(&out, 1, %str(.)));
    %let _out_mem = %upcase(%scan(&out, 2, %str(.)));
  %end;
  %else %do;
    %let _out_lib = WORK;
    %let _out_mem = %upcase(&out);
  %end;

  proc contents data=&dataset out=work._dvj_in_lbl noprint;
  run;
  proc contents data=&out out=work._dvj_out_lbl noprint;
  run;
  /* Upcase NAME so merge is case-safe across engines / CONTENTS variants */
  data work._dvj_in_lbl;
    set work._dvj_in_lbl;
    name = upcase(strip(name));
  run;
  data work._dvj_out_lbl;
    set work._dvj_out_lbl;
    name = upcase(strip(name));
  run;
  proc sort data=work._dvj_in_lbl;
    by name;
  run;
  proc sort data=work._dvj_out_lbl;
    by name;
  run;
  data work._dvj_relabel;
    merge work._dvj_out_lbl (in=o keep=name)
          work._dvj_in_lbl (in=i keep=name label);
    by name;
    if o and i and not missing(label) and strip(label) ne '';
    keep name label;
  run;
  proc sql noprint;
    select count(*) into :_n_relabel trimmed from work._dvj_relabel;
  quit;
  %if &_n_relabel > 0 %then %do;
    data _null_;
      set work._dvj_relabel end=_eof;
      length _stmt $512 _lbl $256;
      if _n_ = 1 then
        call execute("proc datasets lib=&_out_lib nolist; modify &_out_mem;");
      _lbl = tranwrd(strip(label), "'", "''");
      /* cat() keeps space after "label " (cats would strip it) */
      _stmt = cat("label ", strip(name), "='", _lbl, "';");
      call execute(_stmt);
      if _eof then call execute("quit;");
    run;
    %put NOTE: m_derive_vars_joined restored &_n_relabel label(s) on &_out_lib..&_out_mem;
  %end;
  %else %put NOTE: m_derive_vars_joined - no input labels to restore onto &out;

  proc datasets lib=work nolist;
       delete _dvj_add 
              _dvj_base
              _dvj_joined
              _dvj_out
              _dvj_in_lbl
              _dvj_out_lbl
              _dvj_relabel;
  quit;

  %m_nobs(ds=&out);

%mend m_derive_vars_joined;


/*******************************************************************************
  Convenience: AE ← last EX on/before AE onset (workflow template pattern).
  Preps ISO dates + EX dose filter, then calls %m_derive_vars_joined.
*******************************************************************************/
%macro m_ae_ex_lastdose(
  ae=raw.ae
, ex=raw.ex
, out=work.ae_ex
);

  %if not %sysfunc(exist(&ae)) %then %do;
    %put ERROR: m_ae_ex_lastdose: &ae does not exist - check raw SDTM under sdtm/.;
    %return;
  %end;

  %m_nobs(ds=&ae);
  %m_nobs(ds=&ex);

  /* Date path (*DT) - admiral derive_vars_dt / export_r_adam_ref.R.
     Not %m_derive_vars_dtm: targets are AESTDT/EXSTDT dates, not *DTM. */
  %m_derive_vars_dt(
    dataset=&ae
  , new_vars_prefix=AEST
  , dtc=AESTDTC
  , highest_imputation=n
  , out=work._ae2a
  );
  %m_derive_vars_dt(
    dataset=work._ae2a
  , new_vars_prefix=AEEN
  , dtc=AEENDTC
  , highest_imputation=n
  , out=work._ae2
  );

  %m_derive_vars_dt(
    dataset=&ex
  , new_vars_prefix=EXST
  , dtc=EXSTDTC
  , highest_imputation=n
  , out=work._ex2a
  );
  %m_derive_vars_dt(
    dataset=work._ex2a
  , new_vars_prefix=EXEN
  , dtc=EXENDTC
  , highest_imputation=n
  , out=work._ex2b
  );

  data _ex2;
    set work._ex2b;
    if not missing(EXSTDT) and (EXDOSE > 0 or upcase(strip(EXTRT)) = 'PLACEBO');
    keep USUBJID EXSEQ EXSTDT EXENDT EXTRT EXDOSE EXDOSU EXROUTE;
  run;

  /* Mirror R template: order=desc(EXSTDT), desc(EXSEQ), mode=last
     (admiral derive_vars_joined - same call as export_r_adam_ref.R) */
  %m_derive_vars_joined(
    dataset=work._ae2
  , dataset_add=_ex2
  , by_vars=USUBJID
  , order=DESC:EXSTDT DESC:EXSEQ
  , new_vars=LDOSEDT=EXSTDT LDOSE=EXDOSE LDOSEU=EXDOSU LDOSETRT=EXTRT LDOS_RTE=EXROUTE
  , join_type=all
  , filter_add=%str(not missing(EXSTDT))
  , filter_join=%str(b.EXSTDT <= a.AESTDT)
  , mode=last
  , out=&out
  );

  proc datasets lib=work nolist;
    delete _ae2a _ae2 _ex2a _ex2b _ex2;
  quit;

%mend m_ae_ex_lastdose;
