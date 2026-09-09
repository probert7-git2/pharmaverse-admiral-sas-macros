/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_adttee2.sas
  SAS Version                 : 9.4
  Purpose (short description) : Build ADTTE time-to-first treatment-emergent AE
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : adam.adsl adam.adae
  Modification Log            : 17AUG2026 - Robust lib/mem + DATA LABEL + PROC DATASETS for AVAL/CNSR.
                                15AUG2026 - Default out=adam.adtte (drop member *2 suffix).
                                15AUG2026 - PROC DATASETS labels for AVAL/CNSR (FDA/CDISC).
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  %m_derive_param_tte — substantial SAS port of admiral::derive_param_tte()

    v1 supports one event source + one censor date on ADSL (common TTAE pattern):
      - Event: earliest event_date on event_ds where event_filter
      - Censor: if no event, ADT = censor_date (from ADSL), CNSR = 1
      - STARTDT = start_date; AVAL = ADT - STARTDT + 1

    Full event_source / censor_source object lists are not modeled; pass filters.

    Example (time to first TEAE):
      %m_derive_param_tte(
        dataset_adsl=adam.adsl
      , event_ds=adam.adae
      , event_filter=%str(TRTEMFL='Y' and not missing(ASTDT))
      , event_date=ASTDT
      , start_date=TRTSDT
      , censor_date=TRTEDT
      , paramcd=TTAE
      , param=%str(Time to First Treatment-Emergent AE)
      , out=adam.adtte
      );
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_derive_param_tte(
  dataset_adsl=
, event_ds=
, event_filter=%str(1)
, event_date=ASTDT
, start_date=TRTSDT
, censor_date=TRTEDT
, paramcd=TTAE
, param=
, subject_keys=STUDYID USUBJID
, out=
, dataset=
);

  %local by_csv;

  %if %length(&dataset_adsl)=0 or %length(&event_ds)=0 or %length(&out)=0 %then %do;
    %put ERROR: m_derive_param_tte requires dataset_adsl=, event_ds=, out=.;
    %return;
  %end;

  %let by_csv = %sysfunc(tranwrd(&subject_keys, %str( ), %str(, )));

  /* Earliest event date per subject */
  proc sql;
    create table work._tte_ev as
    select &by_csv
         , min(&event_date) as EVNTDT format=date9.
    from &event_ds
    where &event_filter
    group by &by_csv
    ;
  quit;

  proc sort data=&dataset_adsl out=work._tte_sl;
    by &subject_keys;
  run;
  proc sort data=work._tte_ev;
    by &subject_keys;
  run;

  data work._tte_new;
    length PARAMCD $8 PARAM $200;
    merge work._tte_sl(in=a) work._tte_ev;
    by &subject_keys;
    if a;

    PARAMCD = "&paramcd";
    PARAM   = "&param";
    STARTDT = &start_date;
    format STARTDT ADT EVNTDT date9.;

    if missing(EVNTDT) then do;
      CNSR = 1;
      ADT  = &censor_date;
    end;
    else do;
      CNSR = 0;
      ADT  = EVNTDT;
    end;
    label CNSR    = 'Censor'
          STARTDT = 'Time-to-Event Origin Date'
          ADT     = 'Analysis Date'
          PARAMCD = 'Parameter Code'
          PARAM   = 'Parameter'
          EVNTDT  = 'Event Date';
  run;

  %m_derive_vars_duration(
    dataset=work._tte_new
  , new_var=AVAL
  , start_date=STARTDT
  , end_date=ADT
  , add_one=Y
  , out=work._tte_new2
  );

  data work._tte_new2;
    set work._tte_new2;
    label AVAL = 'Analysis Value'
          CNSR = 'Censor';
    keep &subject_keys PARAMCD PARAM STARTDT ADT AVAL CNSR
         &start_date &censor_date;
  run;

  %if %length(&dataset) and %sysfunc(exist(&dataset)) %then %do;
    data &out;
      set &dataset work._tte_new2;
    run;
  %end;
  %else %do;
    data &out;
      set work._tte_new2;
    run;
  %end;

  proc datasets lib=work nolist;
    delete _tte_ev _tte_sl _tte_new _tte_new2;
  quit;

  %m_nobs(ds=&out);
%mend m_derive_param_tte;


/*******************************************************************************
  %m_adttee2 — ADTTE via %m_derive_param_tte (admiral-style)

  Final member adam.adtte / domain ADTTE.
  Defaults expect ADSL / ADAE. Macro file remains m_adttee2.sas.
*******************************************************************************/
%macro m_adttee2(
  adsl=adam.adsl
, adae=adam.adae
, out=adam.adtte
, paramcd=TTAE
, param=%str(Time to First Treatment-Emergent AE)
, event_filter=%str(TRTEMFL = 'Y' and not missing(ASTDT))
, start_date=TRTSDT
, censor_date=TRTEDT
, event_date=ASTDT
);

  %local _lib _mem;

  %m_derive_param_tte(
    dataset_adsl=&adsl
  , event_ds=&adae
  , event_filter=&event_filter
  , event_date=&event_date
  , start_date=&start_date
  , censor_date=&censor_date
  , paramcd=&paramcd
  , param=&param
  , out=work._adttee2_0
  );

  /* Bring TRTA/TRTP from ADSL */
  %m_derive_vars_merged(
    dataset=work._adttee2_0
  , dataset_add=&adsl
  , by_vars=STUDYID USUBJID
  , order=USUBJID
  , new_vars=TRTA=TRT01A TRTP=TRT01P TRTSDT=TRTSDT TRTEDT=TRTEDT
  , mode=first
  , out=&out
  );

  /* Join restore may miss vars created after SQL - force labels on final write */
  data &out;
    set &out;
    format STARTDT ADT TRTSDT TRTEDT date9.;
    label AVAL    = 'Analysis Value'
          CNSR    = 'Censor'
          STARTDT = 'Time-to-Event Origin Date'
          ADT     = 'Analysis Date'
          PARAMCD = 'Parameter Code'
          PARAM   = 'Parameter'
          TRTSDT  = 'Date of First Exposure to Treatment'
          TRTEDT  = 'Date of Last Exposure to Treatment'
          TRTA    = 'Actual Treatment'
          TRTP    = 'Planned Treatment'
          STUDYID = 'Study Identifier'
          USUBJID = 'Unique Subject Identifier';
    keep STUDYID USUBJID PARAMCD PARAM STARTDT ADT AVAL CNSR
         TRTSDT TRTEDT TRTA TRTP;
  run;

  /* Robust lib/mem (legacy m_adttee pattern) - %scan with %str(.) */
  %let _lib = %upcase(%scan(&out, 1, %str(.)));
  %let _mem = %upcase(%scan(&out, 2, %str(.)));
  %if %length(&_mem) = 0 %then %do;
    %let _lib = WORK;
    %let _mem = %upcase(&out);
  %end;

  /* PROC DATASETS - authoritative labels on final adam.adtte (FDA/CDISC) */
  proc datasets lib=&_lib nolist;
    modify &_mem;
    label AVAL    = 'Analysis Value'
          CNSR    = 'Censor'
          STARTDT = 'Time-to-Event Origin Date'
          ADT     = 'Analysis Date'
          PARAMCD = 'Parameter Code'
          PARAM   = 'Parameter'
          TRTSDT  = 'Date of First Exposure to Treatment'
          TRTEDT  = 'Date of Last Exposure to Treatment'
          TRTA    = 'Actual Treatment'
          TRTP    = 'Planned Treatment'
          STUDYID = 'Study Identifier'
          USUBJID = 'Unique Subject Identifier';
  quit;

  /* ADTTE sort order - one row per subject per parameter. Matches the ADTTE
     entry in %m_qc_default_keys and publishes SORTEDBY metadata. */
  proc sort data=&out;
    by USUBJID PARAMCD;
  run;

  proc datasets lib=work nolist;
    delete _adttee2_0;
  quit;

  %m_nobs(ds=&out);
  %put NOTE: m_adttee2 complete -> &out (&_lib..&_mem);
  %put NOTE: m_adttee2 labels set on AVAL CNSR via DATA LABEL + PROC DATASETS.;

%mend m_adttee2;
