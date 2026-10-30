/*--------------------------------------------------------------
  Original Reporting Effort   : pharmaverse-admiral-sas-macros
  Program Name                : m_derive_param_computed_join.sas
  SAS Version                 : 9.4
  Purpose (short description) : Readable join form of derive_param_computed
  Author                      : Cursor
  Date                        : 30OCT2026
  Input Datasets or Metadata  : Caller BDS dataset, one row per PARAMCD
  Modification Log            : 30OCT2026 - Initial readable equivalent of
                                %m_derive_param_computed.

  %m_derive_param_computed_join

  Same arguments as %m_derive_param_computed. The findings input has one
  row per parameter. WEIGHT and HEIGHT for the same subject and visit are
  two incoming rows. This macro puts those rows side by side, calculates
  one AVAL, and appends that row to the original dataset.

  Pairing is a DATA step MERGE rather than SQL. A missing AVISIT or a
  missing time point is a real group in the admiral templates. PROC SQL
  treats two missing keys as not equal, so those rows would not pair.

  A parameter may occur only once inside a by_vars group. A second WEIGHT
  at the same visit and time point stops the macro. There is no rule for
  which of the two values to keep.

  constant_by_vars / constant_parameters carry a value that is not
  collected at every visit. HEIGHT measured once per subject is merged
  onto every WEIGHT visit for that subject.

  Example, height once per subject:
    %m_derive_param_computed_join(
      dataset=work.advs
    , by_vars=USUBJID AVISIT ATPT
    , parameters=WEIGHT
    , constant_by_vars=USUBJID
    , constant_parameters=HEIGHT
    , analysis_value=%str(WEIGHT / ((HEIGHT/100)**2))
    , set_values=%str(PARAMCD=BMI|PARAM=Body Mass Index (kg/m^2))
    , out=work.advs_bmi
    );
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_derive_param_computed_join(
  dataset=
, by_vars=USUBJID AVISIT
, parameters=
, analysis_value=
, set_values=
, filter=%str(1)
, constant_by_vars=
, constant_parameters=
, out=
);

  %local i p nparm nconst by_csv const_csv set_assign nv val _ndup _bad;

  %if %length(&dataset)=0 or %length(&parameters)=0 or %length(&analysis_value)=0
      or %length(&by_vars)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_derive_param_computed_join requires dataset=, by_vars=, parameters=, analysis_value=, and out=.;
    %return;
  %end;

  %let by_csv = %sysfunc(tranwrd(&by_vars, %str( ), %str(,)));
  %let const_csv = %sysfunc(tranwrd(&constant_by_vars, %str( ), %str(,)));
  %let nparm = 0;
  %let nconst = 0;
  %let _bad = 0;

  /* Names of the parameters that must sit on the same visit row. */
  %let i = 1;
  %let p = %scan(&parameters, &i, %str( ));
  %do %while(%length(&p));
    %let nparm = %eval(&nparm + 1);
    %let parm&nparm = &p;
    %let i = %eval(&i + 1);
    %let p = %scan(&parameters, &i, %str( ));
  %end;

  %if &nparm = 0 %then %do;
    %put ERROR: m_derive_param_computed_join parameters= did not contain a PARAMCD.;
    %return;
  %end;

  /* Names of the parameters measured once per constant_by_vars. */
  %if %length(&constant_by_vars) and %length(&constant_parameters) %then %do;
    %let i = 1;
    %let p = %scan(&constant_parameters, &i, %str( ));
    %do %while(%length(&p));
      %let nconst = %eval(&nconst + 1);
      %let cparm&nconst = &p;
      %let i = %eval(&i + 1);
      %let p = %scan(&constant_parameters, &i, %str( ));
    %end;
  %end;

  data work._cmpj_in;
    set &dataset;
    where &filter;
  run;

  /* One table per visit-level parameter: AVAL renamed to the PARAMCD. */
  %do i = 1 %to &nparm;
    data work._cmpj_p&i;
      set work._cmpj_in;
      where PARAMCD = "&&parm&i";
      rename AVAL = &&parm&i;
      keep &by_vars &&parm&i;
    run;

    proc sql noprint;
      create table work._cmpj_dup as
      select &by_csv, count(*) as _n
      from work._cmpj_p&i
      group by &by_csv
      having count(*) > 1;

      select count(*) into :_ndup from work._cmpj_dup;
    quit;

    %if &_ndup > 0 %then %do;
      %let _bad = 1;
      %put ERROR: &&parm&i occurs more than once in a &by_vars group.;
      proc print data=work._cmpj_dup;
        title "Repeated &&parm&i for one by_vars group";
      run;
      title;
    %end;

    proc sort data=work._cmpj_p&i;
      by &by_vars;
    run;
  %end;

  %if &_bad %then %return;

  /* Inner merge: keep a group only when every parameter is present. */
  data work._cmpj_wide;
    merge
      %do i = 1 %to &nparm;
        work._cmpj_p&i (in=_ok&i)
      %end;
    ;
    by &by_vars;
    if
      %do i = 1 %to &nparm;
        %if &i > 1 %then and;
        _ok&i
      %end;
    ;
  run;

  /* One height (or other constant) per subject, repeated onto each visit. */
  %if &nconst > 0 %then %do;
    %do i = 1 %to &nconst;
      data work._cmpj_c&i;
        set work._cmpj_in;
        where PARAMCD = "&&cparm&i";
        rename AVAL = &&cparm&i;
        keep &constant_by_vars &&cparm&i;
      run;

      proc sql noprint;
        create table work._cmpj_dup as
        select &const_csv, count(*) as _n
        from work._cmpj_c&i
        group by &const_csv
        having count(*) > 1;

        select count(*) into :_ndup from work._cmpj_dup;
      quit;

      %if &_ndup > 0 %then %do;
        %let _bad = 1;
        %put ERROR: &&cparm&i occurs more than once in a &constant_by_vars group.;
        proc print data=work._cmpj_dup;
          title "Repeated &&cparm&i for one constant_by_vars group";
        run;
        title;
      %end;

      proc sort data=work._cmpj_c&i;
        by &constant_by_vars;
      run;
    %end;

    %if &_bad %then %return;

    data work._cmpj_const;
      merge
        %do i = 1 %to &nconst;
          work._cmpj_c&i (in=_cok&i)
        %end;
      ;
      by &constant_by_vars;
      if
        %do i = 1 %to &nconst;
          %if &i > 1 %then and;
          _cok&i
        %end;
      ;
    run;

    proc sort data=work._cmpj_wide;
      by &constant_by_vars;
    run;

    data work._cmpj_wide;
      merge work._cmpj_wide (in=_visit)
            work._cmpj_const (in=_const);
      by &constant_by_vars;
      if _visit and _const;
    run;
  %end;

  /* PARAMCD=BMI|PARAM=Body Mass Index becomes two assignment statements. */
  %let set_assign =;
  %let i = 1;
  %let p = %scan(&set_values, &i, |);
  %do %while(%length(&p));
    %let nv = %scan(&p, 1, =);
    %let val = %substr(&p, %eval(%length(&nv) + 2));
    %let set_assign = &set_assign &nv = "&val";
    %let i = %eval(&i + 1);
    %let p = %scan(&set_values, &i, |);
  %end;

  data work._cmpj_new;
    set work._cmpj_wide;
    AVAL = &analysis_value;
    if not missing(AVAL);
    length PARAMCD $8 PARAM $200;
    &set_assign;
    keep &by_vars PARAMCD PARAM AVAL;
  run;

  data &out;
    set &dataset work._cmpj_new;
  run;

  proc datasets lib=work nolist;
    delete _cmpj_in _cmpj_wide _cmpj_new _cmpj_dup
      %do i = 1 %to &nparm;
        _cmpj_p&i
      %end;
      %if &nconst > 0 %then %do;
        _cmpj_const
        %do i = 1 %to &nconst;
          _cmpj_c&i
        %end;
      %end;
    ;
  quit;

%mend m_derive_param_computed_join;
