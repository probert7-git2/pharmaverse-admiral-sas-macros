/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_qc_missingness.sas
  SAS Version                 : 9.4
  Purpose (short description) : Required/Expected variable missingness profiles
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : adam.adsl adae adtte ... and metadata/adam2_ds_vars.csv
  Modification Log            : 16AUG2026 - Fix nested %mend _miss_one (was bare %end).
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Missingness profiles for Required / Expected ADaM2 variables.

  Spec: metadata/adam2_ds_vars.csv (core = Required or Expected).
  Flags: Required with any miss -> FAIL; Expected with high % -> WARN.

~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_qc_missingness_adam2(
                                spec_csv=&ROOT/metadata/adam2_ds_vars.csv
                              , out=adam.qc_missingness
                              , warn_pct_expected=50
                              );

  %local n_flag;

  %if not %sysfunc(fileexist(&spec_csv)) %then %do;
    %put ERROR: m_qc_missingness_adam2 — missing &spec_csv;
    %return;
  %end;

  proc import datafile="&spec_csv"
    out=work._miss_spec dbms=csv replace;
    getnames=yes;
  run;

  data work._miss_spec;
    set work._miss_spec;
    dataset = upcase(strip(dataset));
    variable = upcase(strip(variable));
  run;

  data &out;
    length dataset $8 variable $32 core $12 severity $8;
    n_total = .;
    n_miss = .;
    pct_miss = .;
    stop;
  run;

  %macro _miss_one(sasds);
    %local dsn dsid nobs i vname vcore vtype n_miss pct sev;

    %let dsn = %upcase(%scan(&sasds, 2, .));

    %if not %sysfunc(exist(&sasds)) %then %do;
      %put NOTE: [missingness] Skip &sasds — not found.;
      %return;
    %end;

    %let dsid = %sysfunc(open(&sasds, i));
    %let nobs = %sysfunc(attrn(&dsid, nlobs));
    %let dsid = %sysfunc(close(&dsid));

    %if &nobs = 0 %then %do;
      %put WARNING: [missingness] &sasds has zero rows.;
    %end;

    %put NOTE: [missingness] Profiling &sasds n=&nobs;

    proc sql noprint;
      select count(*) into :nv trimmed
      from work._miss_spec
      where dataset = "&dsn";
    quit;

    %do i = 1 %to &nv;
      proc sql noprint;
        select variable, core
          into :vname trimmed, :vcore trimmed
        from (
          select variable, core, monotonic() as _rn
          from work._miss_spec
          where dataset = "&dsn"
          order by order
        )
        where _rn = &i;
      quit;

      %let dsid = %sysfunc(open(&sasds, i));
      %let vtype = %sysfunc(vartype(&dsid, %sysfunc(varnum(&dsid, &vname))));
      %let dsid = %sysfunc(close(&dsid));

      %if &vtype = %then %do;
        %put WARNING: [missingness] &vname not in &sasds;
        data _row;
          length dataset $8 variable $32 core $12 severity $8;
          dataset  = "&dsn";
          variable = "&vname";
          core = "&vcore";
          n_total = &nobs;
          n_miss = .;
          pct_miss = .;
          severity = "MISSING_VAR";
          output;
        run;
      %end;
      %else %do;
        proc sql noprint;
          select count(*)
            into :n_miss trimmed
          from &sasds
          where missing(&vname);
        quit;

        %let pct = 0;
        %if &nobs > 0 %then %let pct = %sysevalf(&n_miss / &nobs * 100);

        %let sev = OK;
        %if %upcase(&vcore) = REQUIRED and &n_miss > 0 %then %let sev = FAIL;
        %else %if %upcase(&vcore) = EXPECTED and &pct >= &warn_pct_expected %then %let sev = WARN;

        data _row;
          length dataset $8 variable $32 core $12 severity $8;
          dataset  = "&dsn";
          variable = "&vname";
          core     = "&vcore";
          n_total  = &nobs;
          n_miss   = &n_miss;
          pct_miss = &pct;
          severity = "&sev";
          output;
        run;
      %end;

      proc append base = &out
                  data = _row force;
      run;
    %end;
  %mend _miss_one;

  %_miss_one(adam.adsl);
  %_miss_one(adam.adae);
  %_miss_one(adam.adtte);
  %_miss_one(adam.advs);
  %_miss_one(adam.adeg);
  %_miss_one(adam.adcm);
  %_miss_one(adam.adlb);

  proc sql noprint;
       select count(*) into :n_flag trimmed 
       from &out 
       where severity ne 'OK';
  quit;

  %put NOTE: ===== m_qc_missingness_adam2 done flagged=&n_flag =====;

  title "ADaM2 missingness — issues only";
  proc print data=&out;
       where severity ne 'OK';
  run;
  title;

%mend m_qc_missingness_adam2;
