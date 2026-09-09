/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_qc_metacore_align.sas
  SAS Version                 : 9.4
  Purpose (short description) : Spec vs as-built variable alignment checks
  Author                      : Cursor Grok 4.5, edited by P. Robertson
  Date                        : 09AUG2026
  Input Datasets or Metadata  : adam.adsl adae adtte ... metadata/adam2_ds_vars.csv metadata.adam2_var_trace
  Modification Log            : 16AUG2026 - Fix nested %mend _align_one (was bare %end).
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Metacore / define-style alignment for ADaM2 datasets.

  Checks per dataset:
  Variables in data but not in adam2_ds_vars spec (extra)
  Required/Expected spec vars missing from data
  Label/length vs metadata.adam2_var_trace when trace exists

  Prerequisite for trace compare: build_adam2_metadata_oda.sas (optional).
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/



%macro m_qc_metacore_align_adam2(
                                   spec_csv=&ROOT/metadata/adam2_ds_vars.csv
                                 , trace_ds=metadata.adam2_var_trace
                                 , out=adam.qc_metacore_align
                                 );

      %if not %sysfunc(fileexist(&spec_csv)) %then %do;
          %put ERROR: m_qc_metacore_align_adam2 — missing &spec_csv;
          %return;
      %end;

      proc import datafile = "&spec_csv"
                       out = work._align_spec dbms=csv replace;
                  getnames = yes;
      run;

      data work._align_spec;
           set work._align_spec;
           dataset = upcase(strip(dataset));
           variable = upcase(strip(variable));
      run;

      data &out;
           length dataset    $8 
                  variable   $32 
                  check_type $24 
                  severity   $8 
                  detail     $200;
           stop;
      run;

      %macro _align_one(sasds);
             %local dsn;
             %let dsn = %upcase(%scan(&sasds, 2, .));
             %if not %sysfunc(exist(&sasds)) %then %return;

             proc contents data = &sasds 
                            out = _co noprint;
             run;

            data _data_vars(keep = dataset variable sas_label sas_length);
                 set _co;
                 dataset    = "&dsn";
                 variable   = upcase(name);
                 sas_label  = label;
                 sas_length = length;
                 keep dataset variable sas_label sas_length;
           run;

           /* Spec vars not in dataset */
           proc sql;
                create table _spec_only as
                select s.dataset, 
                       s.variable, 
                       s.core, 
                       'SPEC_NOT_IN_DATA' as check_type length=24
                from work._align_spec s
                left join _data_vars  d
                on s.dataset  = d.dataset and 
                   s.variable = d.variable
                where d.variable is null
                and s.dataset = "&dsn";
           quit;

           data _rows_spec(keep = dataset variable check_type severity detail);
                length dataset    $8 
                       variable   $32 
                       check_type $24 
                       severity   $8 
                       detail     $200;
                set _spec_only;
                severity = ifc(upcase(core) = 'REQUIRED', 'FAIL', 'WARN');
                detail   = cat('Variable in spec (', strip(core), ') but absent from dataset');
           run;

           /* Data vars not in spec (Permissible extras OK — INFO) */
           proc sql;
                create table _data_only as
                select d.dataset, 
                       d.variable, 
                       'DATA_NOT_IN_SPEC' as check_type length=24
                from _data_vars d
                left join work._align_spec s
                where s.variable is null
                and d.dataset = "&dsn";
           quit;

           data _rows_data;
                length dataset    $8 
                       variable   $32 
                       check_type $24 
                       severity   $8 
                       detail     $200;
                set _data_only;
                severity = 'INFO';
                detail = 'Variable present in dataset but not listed in adam2_ds_vars.csv';
                keep dataset variable check_type severity detail;
          run;

          proc append base = &out 
                      data = _rows_spec force;
          run;
          proc append base = &out
                      data = _rows_data force;
          run;

          %if %sysfunc(exist(&trace_ds)) %then %do;
              proc sql;
                   create table _label_chk as
                   select d.dataset, 
                          d.variable, 
                          'LABEL_LENGTH' as check_type length=24,
                          coalesce(t.define_label, t.sas_label) as spec_label length=256,
                          t.sas_length, 
                          d.sas_label as data_label length=256,
                   d.sas_length as data_length
                   from _data_vars d
                   inner join &trace_ds t
                   on d.dataset  = t.dataset and 
                      d.variable = t.variable
                   where d.dataset = "&dsn"
                      and (d.sas_length ne t.sas_length
                      or coalescec(d.sas_label, '') ne coalescec(coalesce(t.define_label, t.sas_label), ''));
              quit;

              data _rows_lbl;
                  length dataset $8 variable $32 check_type $24 severity $8 detail $200;
                  set _label_chk;
                  severity = 'WARN';
                  detail = catx(' | ', cat('spec_len=', sas_length), 
                                       cat('data_len=', data_length),
                                       cat('spec_lbl=', spec_label), 
                                       cat('data_lbl=', data_label));
                  keep dataset variable check_type severity detail;
              run;

              proc append base = &out
                          data = _rows_lbl force;
              run;
          %end;

    proc datasets lib=work nolist;
         delete _co 
                _data_vars
                _spec_only 
                _data_only
                _rows_spec
                _rows_data
                _label_chk
                _rows_lbl;
          quit;
  %mend _align_one;

  %_align_one(adam.adsl);
  %_align_one(adam.adae);
  %_align_one(adam.adtte);
  %_align_one(adam.advs);
  %_align_one(adam.adeg);
  %_align_one(adam.adcm);
  %_align_one(adam.adlb);

  title "ADaM2 metacore/define alignment — FAIL/WARN";
  proc print data=&out;
       where severity in ('FAIL', 'WARN');
  run;
  title;

  %put NOTE: m_qc_metacore_align_adam2 complete -> &out;

%mend m_qc_metacore_align_adam2;
