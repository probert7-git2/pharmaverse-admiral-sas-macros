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
