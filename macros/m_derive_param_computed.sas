/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_derive_param_computed.sas
  SAS Version                 : 9.4
  Purpose (short description) : Computed parameter ports (BMI BSA MAP WBC summary)
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Caller BDS dataset
  Modification Log            : 09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Phase 2 BDS — computed parameters and summary records
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
/*******************************************************************************
  %m_derive_param_computed — substantial port of derive_param_computed()

  analysis_value: SAS expression using &prefix.AVAL for each parameter code
  after pivoting. parameters= space-separated PARAMCDs to transpose.
  set_values: pipe-separated assignments, e.g.
    PARAMCD=BMI|PARAM=Body Mass Index (kg/m^2)

  Example BMI via computed:
    parameters=WEIGHT HEIGHT
    analysis_value=%str(WEIGHT / ((HEIGHT/100)**2))
    set_values=%str(PARAMCD=BMI|PARAM=Body Mass Index (kg/m^2))
*******************************************************************************/
%macro m_derive_param_computed(
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
  %local i p by_csv set_assign nv val;

  %if %length(&dataset)=0 or %length(&parameters)=0 or %length(&analysis_value)=0
      or %length(&out)=0 %then %do;
    %put ERROR: m_derive_param_computed requires dataset=, parameters=, analysis_value=, out=.;
    %return;
  %end;

  %let by_csv = %sysfunc(tranwrd(&by_vars, %str( ), %str(, )));

  data work._cmp_in;
    set &dataset;
    where &filter;
  run;

  /* Optional constant parameters (e.g. HEIGHT once per subject) */
  %if %length(&constant_by_vars) and %length(&constant_parameters) %then %do;
    proc sort data=work._cmp_in out=work._cmp_c0;
      by &constant_by_vars;
    run;
    data work._cmp_c1;
      set work._cmp_in;
      where PARAMCD in (
        %let i=1; %let p=%scan(&constant_parameters,&i,%str( ));
        %do %while(%length(&p));
          %if &i>1 %then ,;
          "&p"
          %let i=%eval(&i+1);
          %let p=%scan(&constant_parameters,&i,%str( ));
        %end;
      );
      keep &constant_by_vars PARAMCD AVAL;
    run;
    proc transpose data=work._cmp_c1 out=work._cmp_ct prefix=C_;
      by &constant_by_vars;
      id PARAMCD;
      var AVAL;
    run;
  %end;

  data work._cmp_v;
    set work._cmp_in;
    where PARAMCD in (
      %let i=1; %let p=%scan(&parameters,&i,%str( ));
      %do %while(%length(&p));
        %if &i>1 %then ,;
        "&p"
        %let i=%eval(&i+1);
        %let p=%scan(&parameters,&i,%str( ));
      %end;
    );
    keep &by_vars PARAMCD AVAL;
  run;

  proc sort data=work._cmp_v;
    by &by_vars;
  run;

  proc transpose data=work._cmp_v out=work._cmp_t;
    by &by_vars;
    id PARAMCD;
    var AVAL;
  run;

  %if %length(&constant_by_vars) and %length(&constant_parameters) %then %do;
    /* Merge constants onto visit-level transpose via constant_by_vars */
    proc sort data=work._cmp_t;
      by &constant_by_vars;
    run;
    data work._cmp_t;
      merge work._cmp_t(in=a) work._cmp_ct;
      by &constant_by_vars;
      if a;
      /* Promote C_HEIGHT -> HEIGHT if HEIGHT not already present */
      %let i=1; %let p=%scan(&constant_parameters,&i,%str( ));
      %do %while(%length(&p));
        if missing(&p) and not missing(C_&p) then &p = C_&p;
        %let i=%eval(&i+1);
        %let p=%scan(&constant_parameters,&i,%str( ));
      %end;
      drop C_:;
    run;
  %end;

  /* Build SET assignments (pipe-separated NAME=VALUE) */
  %let set_assign =;
  %let i = 1;
  %let p = %scan(&set_values, &i, |);
  %do %while(%length(&p));
    %let nv  = %scan(&p, 1, =);
    %let val = %substr(&p, %eval(%length(&nv) + 2));
    %let set_assign = &set_assign &nv = "&val";
    %let i = %eval(&i + 1);
    %let p = %scan(&set_values, &i, |);
  %end;

  data work._cmp_new;
    set work._cmp_t;
    AVAL = &analysis_value;
    if not missing(AVAL);
    length PARAMCD $8 PARAM $200;
    &set_assign;
    keep &by_vars PARAMCD PARAM AVAL;
  run;

  data &out;
    set &dataset work._cmp_new;
  run;

  proc datasets lib=work nolist;
    delete _cmp_in _cmp_v _cmp_t _cmp_new _cmp_c0 _cmp_c1 _cmp_ct;
  quit;

  %m_nobs(ds=&out);
%mend m_derive_param_computed;


/*******************************************************************************
  %m_derive_param_bmi — BMI = WEIGHT / (HEIGHT_m)^2
  HEIGHT in cm, WEIGHT in kg. constant_by_vars e.g. USUBJID when height once.
*******************************************************************************/
%macro m_derive_param_bmi(
  dataset=
, by_vars=USUBJID AVISIT
, weight_code=WEIGHT
, height_code=HEIGHT
, paramcd=BMI
, param=%str(Body Mass Index (kg/m^2))
, constant_by_vars=
, filter=%str(1)
, out=
);
  %local parms cparms;
  %if %length(&constant_by_vars) %then %do;
    %let parms = &weight_code;
    %let cparms = &height_code;
  %end;
  %else %do;
    %let parms = &weight_code &height_code;
    %let cparms =;
  %end;

  %m_derive_param_computed(
    dataset=&dataset
  , by_vars=&by_vars
  , parameters=&parms
  , constant_by_vars=&constant_by_vars
  , constant_parameters=&cparms
  , analysis_value=%str(&weight_code / ((&height_code/100)**2))
  , set_values=%str(PARAMCD=&paramcd|PARAM=&param)
  , filter=&filter
  , out=&out
  );
%mend m_derive_param_bmi;


/*******************************************************************************
  %m_derive_param_bsa — Mosteller: sqrt(HEIGHT_cm * WEIGHT_kg / 3600)
*******************************************************************************/
%macro m_derive_param_bsa(
  dataset=
, by_vars=USUBJID AVISIT
, weight_code=WEIGHT
, height_code=HEIGHT
, paramcd=BSA
, param=%str(Body Surface Area (m^2))
, constant_by_vars=
, filter=%str(1)
, out=
);
  %local parms cparms;
  %if %length(&constant_by_vars) %then %do;
    %let parms = &weight_code;
    %let cparms = &height_code;
  %end;
  %else %do;
    %let parms = &weight_code &height_code;
    %let cparms =;
  %end;

  %m_derive_param_computed(
    dataset=&dataset
  , by_vars=&by_vars
  , parameters=&parms
  , constant_by_vars=&constant_by_vars
  , constant_parameters=&cparms
  , analysis_value=%str(sqrt(&height_code * &weight_code / 3600))
  , set_values=%str(PARAMCD=&paramcd|PARAM=&param)
  , filter=&filter
  , out=&out
  );
%mend m_derive_param_bsa;


/*******************************************************************************
  %m_derive_param_map — (2*DIABP + SYSBP)/3   (HR formula not in v1)
*******************************************************************************/
%macro m_derive_param_map(
  dataset=
, by_vars=USUBJID AVISIT
, sysbp_code=SYSBP
, diabp_code=DIABP
, hr_code=
, paramcd=MAP
, param=%str(Mean Arterial Pressure (mmHg))
, filter=%str(1)
, out=
);
  %if %length(&hr_code) %then %do;
    %put NOTE: m_derive_param_map v1 ignores hr_code - using (2*DIABP+SYSBP)/3.;
  %end;
  %m_derive_param_computed(
    dataset=&dataset
  , by_vars=&by_vars
  , parameters=&sysbp_code &diabp_code
  , analysis_value=%str((2*&diabp_code + &sysbp_code)/3)
  , set_values=%str(PARAMCD=&paramcd|PARAM=&param)
  , filter=&filter
  , out=&out
  );
%mend m_derive_param_map;


/*******************************************************************************
  %m_derive_param_wbc_abs — absolute = (differential % * WBC) / 100
*******************************************************************************/
%macro m_derive_param_wbc_abs(
  dataset=
, by_vars=USUBJID AVISIT
, wbc_code=WBC
, diff_code=
, paramcd=
, param=
, filter=%str(1)
, out=
);
  %if %length(&diff_code)=0 or %length(&paramcd)=0 %then %do;
    %put ERROR: m_derive_param_wbc_abs requires diff_code= and paramcd=.;
    %return;
  %end;

  %m_derive_param_computed(
    dataset=&dataset
  , by_vars=&by_vars
  , parameters=&wbc_code &diff_code
  , analysis_value=%str(&diff_code * &wbc_code / 100)
  , set_values=%str(PARAMCD=&paramcd|PARAM=&param)
  , filter=&filter
  , out=&out
  );
%mend m_derive_param_wbc_abs;


/*******************************************************************************
  %m_derive_summary_records — substantial port of derive_summary_records()

  Appends one summary row per by_vars with analysis_var = mean|sum|min|max|n
  of analysis_var from filtered input. set_values assign PARAMCD/PARAM etc.
*******************************************************************************/
%macro m_derive_summary_records(
  dataset=
, by_vars=USUBJID PARAMCD
, filter=%str(1)
, analysis_var=AVAL
, summary_fun=mean
, set_values=
, out=
);
  %local by_csv i p set_assign fun nv val;

  %if %length(&dataset)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_derive_summary_records requires dataset= and out=.;
    %return;
  %end;

  %let fun = %lowcase(&summary_fun);
  %let by_csv = %sysfunc(tranwrd(&by_vars, %str( ), %str(, )));

  proc sql;
    create table work._sum as
    select &by_csv
         , &fun(&analysis_var) as &analysis_var
    from &dataset
    where &filter
    group by &by_csv
    ;
  quit;

  %let set_assign =;
  %let i = 1;
  %let p = %scan(&set_values, &i, |);
  %do %while(%length(&p));
    %let nv  = %scan(&p, 1, =);
    %let val = %substr(&p, %eval(%length(&nv) + 2));
    %let set_assign = &set_assign &nv = "&val";
    %let i = %eval(&i + 1);
    %let p = %scan(&set_values, &i, |);
  %end;

  data work._sum2;
    set work._sum;
    length PARAMCD $8 PARAM $200;
    &set_assign;
  run;

  data &out;
    set &dataset work._sum2;
  run;

  proc datasets lib=work nolist;
    delete _sum _sum2;
  quit;

  %m_nobs(ds=&out);
%mend m_derive_summary_records;
