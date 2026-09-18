/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_derive_vars_dy.sas
  SAS Version                 : 9.4
  Purpose (short description) : admiral-style relative day and duration ports
  Author                      : Cursor Grok 4.5 -- Mod by P. Robertson to avoid PRX VARNAME case-sensitivity
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Caller dataset with date vars
  Modification Log            : 09AUG2026 - Added standardized header fields (aligned labels).
                                18SEP2026 - %upcase source_vars before PRX (PRX is
                                case-sensitive). ERROR if a bare token cannot be
                                renamed, so the source date is not wiped.

  --- Existing header notes ---
  %m_derive_vars_dy — substantial port of admiral::derive_vars_dy()

    reference_date: SAS date/datetime variable
    source_vars: space-separated list. Tokens are %upcase'd before PRX function rename:
      ASTDT          -> creates ASTDY (DT or DTM suffix becomes DY)
      trtedt         -> creates TRTEDY (same - SAS variable names are not case-sensitive but PRX is!)
      DEATHDY=DTHDT  -> creates DEATHDY from DTHDT

    Relative day: date - ref (+1 if nonnegative). No Day 0.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_derive_vars_dy(
  dataset=
, reference_date=
, source_vars=
, out=
);
  %local i 
         tok 
         newvar 
         src 
         canon;

  %if %length(&dataset)=0        or 
      %length(&reference_date)=0 or
      %length(&source_vars)=0    or 
      %length(&out)=0            %then %do;
         %put ERROR: m_derive_vars_dy requires dataset=, reference_date=, source_vars=, out=.;
         %return;
  %end;

  /* Resolve SAS variable names before the DATA step. PRX is case-sensitive - 
     %upcase function so, for example, trtedt matches DT$ and becomes TRTEDY. 
     Error here if a bare token cannot be renamed, otherwise NEWVAR stays equal to SRC 
     and SRC = . wipes the date. 
  */

  %let canon =;
  %let i     = 1;
  %let tok   = %upcase(%scan(&source_vars, &i, %str( )));

  %do %while(%length(&tok));
    %if %index(&tok, =) %then %do;
        %let newvar = %scan(&tok, 1, =);
        %let src    = %scan(&tok, 2, =);
    %end;
    %else %do;
        %let src = &tok;
        %let newvar = %sysfunc(prxchange(s/DTM$/DY/, 1, &src));

        %if &newvar = &src %then
            %let newvar = %sysfunc(prxchange(s/DT$/DY/, 1, &src));

        %if &newvar = &src %then %do;
            %put ERROR: m_derive_vars_dy cannot rename &src - expected a DT or DTM suffix or NEWVAR=SRC.;
            %return;
        %end;
    %end;
    %if %length(&newvar)=0 or 
        %length(&src)=0 %then %do;
            %put ERROR: m_derive_vars_dy NEWVAR=SRC token is incomplete.;
            %return;
    %end;

    %let canon = &canon &newvar=&src;
    %let i     = %eval(&i + 1);
    %let tok   = %upcase(%scan(&source_vars, &i, %str( )));
  %end;

  data &out;
    set &dataset;

    /* A heuristic is used here to distinguish SAS date. from datetime. formatted variables. 
       If the unformatted value is >100000 it is treated as datetime. Otherwise, date. 
       The context of clinical trial use of this macro makes this a fully defensible heuristic. 
       A datetime value of 100000 is seconds after the start of 1/1/1960, The result is 1/2/1960 3:40 AM.
       A date value of 100000 is days after 1/1/1960, which is several hundred years in the future. 
    */

    _refd = .;
    if not missing(&reference_date) then do;
       if &reference_date > 100000 then _refd = datepart(&reference_date);
       else                             _refd = &reference_date;
    end;

    %let i = 1;
    %let tok = %scan(&canon, &i, %str( ));

    %do %while(%length(&tok));
        %let newvar = %scan(&tok, 1, =);
        %let src    = %scan(&tok, 2, =);

        &newvar = .;
        if not missing(_refd) and not missing(&src) then do;
           if &src > 100000 then _srcd = datepart(&src);
           else                  _srcd = &src;

           if _srcd >= _refd then &newvar = _srcd - _refd + 1;
           else                   &newvar = _srcd - _refd;
        end;
        %let   i = %eval(&i + 1);
        %let tok = %scan(&canon, &i, %str( ));
    %end;
    drop _refd _srcd;
  run;

  %m_nobs(ds=&out);
%mend m_derive_vars_dy;


/*******************************************************************************
  %m_derive_vars_duration — substantial port of admiral::derive_vars_duration()

  new_var: output duration
  start_date / end_date: date or datetime
  out_unit: days (v1 only)
  add_one: Y (ADaM duration +1) | N
  type: duration (default)
*******************************************************************************/
%macro m_derive_vars_duration(
  dataset=
, new_var=
, start_date=
, end_date=
, out_unit=days
, add_one=Y
, out=
);

  %if %length(&dataset)=0    or 
      %length(&new_var)=0    or 
      %length(&start_date)=0 or
      %length(&end_date)=0   or 
      %length(&out)=0 %then %do;
         %put ERROR: m_derive_vars_duration requires dataset=, new_var=, start_date=, end_date=, out=.;
         %return;
  %end;

  %if %lowcase(&out_unit) ne days %then %do;
      %put NOTE: m_derive_vars_duration v1 supports out_unit=days only.;
  %end;

  data &out;
    set &dataset;
    &new_var = .;
    if not missing(&start_date) and 
       not missing(&end_date) then do;

           if &start_date > 100000 then _s = datepart(&start_date); 
           else                         _s = &start_date;
           if &end_date   > 100000 then _e = datepart(&end_date);   
           else                         _e = &end_date;

           &new_var = _e - _s;

           %if %upcase(&add_one) = Y or %upcase(&add_one) = TRUE %then %do;
               &new_var = &new_var + 1;
           %end;
    end;
    drop _s _e;
  run;

  %m_nobs(ds=&out);
%mend m_derive_vars_duration;

%put NOTE: Loaded m_derive_vars_dy.sas FIX20260918.;
