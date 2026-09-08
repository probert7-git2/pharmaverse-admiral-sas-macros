/*--------------------------------------------------------------
  Program Name                : run_traceability_pva_oda.sas
  Purpose                     : Layer 3 as-programmed trace vs admiral
                                template step names (ODA)
  Paths                       : /home/&sysuserid/... only (no HOME / no ~)
  Prerequisite                : create_ADaM_pva_oda.sas has built adam.*
  Input                       : metadata/pva_as_programmed_registry.csv
                                plus PROC CONTENTS of adam.adsl adae advs
                                adeg adcm adlb
  Output                      : metadata.pva_as_programmed_registry
                                metadata.pva_var_inventory
                                metadata.pva_var_trace
                                CSV copies under metadata/ and output/
  Honesty                     : admiral has function docs and templates.
                                No CDISC-style ADaM spec spreadsheet was
                                found. prespec_analogue = template step.
  Modification Log            : 26AUG2026 - Initial Layer 3 port of Track A
                                build_adam2_metadata_oda (smallest join
                                plus as-programmed registry print).
--------------------------------------------------------------*/

%macro _run_traceability_pva_oda;
  %local _partb _sms _rc TRACE_LOG _have_pub _ds _n _regcsv;
  %local n_trace n_reg n_inv n_both n_code_only n_reg_only n_trace_ds;
  %local trace_ds;

  %if %sysmacexist(m_get_oda_path) = 0 %then %do;
    %include "/home/&sysuserid/SAS_mirrored_Admiral_safety_ADaM/SAS/macro/m_get_oda_path.sas";
  %end;
  %if %sysmacexist(m_init_libnames_pva) = 0 %then %do;
    %include "/home/&sysuserid/SAS_mirrored_Admiral_safety_ADaM/SAS/macro/m_init_libnames_pva.sas";
    %m_init_libnames_pva;
  %end;

  %let _partb = %m_get_oda_path(SAS_mirrored_Admiral_safety_ADaM/SAS);
  %let _sms   = %m_get_oda_path(safety_monitoring_system/SAS);

  %if %sysmacexist(m_chklog) = 0 %then %do;
    %if %sysfunc(fileexist(&_sms/macros/m_util.sas)) = 0 %then %do;
      %put ERROR: Track A macros not found at &_sms/macros - need m_util m_chklog.;
      %return;
    %end;
    %include "&_sms/macros/m_util.sas";
    %include "&_sms/macros/m_chklog.sas";
  %end;

  %let _have_pub = 0;
  %if %sysfunc(fileexist(&_sms/macros/m_oda_publish.sas)) %then %do;
    %include "&_sms/macros/m_oda_publish.sas";
    %let _have_pub = 1;
  %end;

  %let _rc = %sysfunc(dcreate(logs, &_partb));
  %let _rc = %sysfunc(dcreate(output, &_partb));
  %let _rc = %sysfunc(dcreate(metadata, &_partb));
  %let _rc = %sysfunc(dcreate(docs, &_partb));
  %let TRACE_LOG = &LOGDIR/run_traceability_pva_oda.log;
  filename tracel3 "&TRACE_LOG";
  proc printto log=tracel3 new;
  run;

  %put NOTE: ===== run_traceability_pva_oda starting (Layer 3) =====;
  %put NOTE: No CDISC-style admiral ADaM spec spreadsheet found.;
  %put NOTE: Prespec analogue is the admiral template function name.;

  %let _regcsv = &_partb/metadata/pva_as_programmed_registry.csv;
  %if %sysfunc(fileexist(&_regcsv)) = 0 %then %do;
    %put ERROR: Missing &_regcsv - upload SAS/metadata/pva_as_programmed_registry.csv.;
    proc printto;
    run;
    %return;
  %end;

  proc import datafile = "&_regcsv"
                   out = work._pva_reg_imp
                  dbms = csv replace;
              getnames = yes;
              guessingrows = max;
  run;

  data metadata.pva_as_programmed_registry;
    length dataset $8 variable $32 origin $16
           builder_macro $40 sas_port $48
           admiral_template $16 admiral_function $80
           key_params $200 by_vars $200
           derivation_summary $400 prespec_analogue $120;
    set work._pva_reg_imp;
    dataset  = upcase(strip(dataset));
    variable = upcase(strip(variable));
    if missing(dataset) then delete;
  run;

  /* Inventory from built ADaM (as programmed contents) */
  proc datasets lib=work nolist;
    delete _pva_inv;
  quit;

  %macro _pva_inv_one(ds=);
    %if %sysfunc(exist(adam.&ds)) %then %do;
      proc contents data=adam.&ds noprint out=work._pva_c(keep=memname name type length label);
      run;
      data work._pva_c2;
        length dataset $8 variable $32 type $8 sas_label $256;
        set work._pva_c;
        dataset  = upcase(strip("&ds"));
        variable = upcase(strip(name));
        if type = 1 then type = 'N';
        else type = 'C';
        sas_length = length;
        sas_label  = label;
        keep dataset variable type sas_length sas_label;
      run;
      proc append base=work._pva_inv data=work._pva_c2 force;
      run;
    %end;
    %else %do;
      %put NOTE: adam.&ds not found - skipped in Layer 3 inventory.;
    %end;
  %mend _pva_inv_one;

  %_pva_inv_one(ds=adsl);
  %_pva_inv_one(ds=adae);
  %_pva_inv_one(ds=advs);
  %_pva_inv_one(ds=adeg);
  %_pva_inv_one(ds=adcm);
  %_pva_inv_one(ds=adlb);

  %if %sysfunc(exist(work._pva_inv)) = 0 %then %do;
    %put ERROR: No adam.* datasets found - run create_ADaM_pva_oda.sas first.;
    proc printto;
    run;
    %return;
  %end;

  data metadata.pva_var_inventory;
    set work._pva_inv;
  run;

  proc sql;
    create table metadata.pva_var_trace as
    select
           coalescec(c.dataset, r.dataset) as dataset length=8
         , coalescec(c.variable, r.variable) as variable length=32
         , c.type
         , c.sas_length
         , c.sas_label
         , r.origin
         , r.builder_macro
         , r.sas_port
         , r.admiral_template
         , r.admiral_function
         , r.key_params
         , r.by_vars
         , r.derivation_summary
         , r.prespec_analogue
         , case
             when c.variable is null then 'REGISTRY_ONLY'
             when r.variable is null then 'CODE_ONLY'
             else 'BOTH'
           end as trace_status length=12
    from metadata.pva_var_inventory c
    full join metadata.pva_as_programmed_registry r
         on c.dataset  = r.dataset
        and c.variable = r.variable
    order by dataset, variable;
  quit;

  /* CODE_ONLY fill - pass-through SDTM vs other as-programmed vars.
     Do not invent predecessor detail. */
  data metadata.pva_var_trace;
    set metadata.pva_var_trace;
    length _v $32 _ds $8;
    _v  = upcase(strip(variable));
    _ds = upcase(strip(dataset));
    if upcase(strip(trace_status)) = 'CODE_ONLY' then do;
      if missing(builder_macro) then do;
        if      _ds = 'ADSL' then builder_macro = 'm_adsl_pva';
        else if _ds = 'ADAE' then builder_macro = 'm_adae_pva';
        else if _ds = 'ADVS' then builder_macro = 'm_advs_admiral_mirror';
        else if _ds = 'ADEG' then builder_macro = 'm_adeg_admiral_mirror';
        else if _ds = 'ADCM' then builder_macro = 'm_adcm_pva';
        else if _ds = 'ADLB' then builder_macro = 'm_adlb_admiral_mirror';
      end;
      if missing(derivation_summary) then do;
        if _v in ('STUDYID' 'USUBJID' 'DOMAIN' 'VISIT' 'VISITNUM' 'EPOCH'
                  'COUNTRY' 'SITEID' 'SUBJID' 'SEX' 'RACE' 'ETHNIC'
                  'ARM' 'ACTARM' 'AETERM' 'AEDECOD' 'AESOC' 'AESEV' 'AEREL'
                  'AESER' 'AESTDTC' 'AEENDTC' 'AESEQ'
                  'CMTRT' 'CMDECOD' 'CMSEQ' 'CMSTDTC' 'CMENDTC' 'CMDOSFRQ'
                  'CMROUTE' 'CMDOSE' 'CMDOSU'
                  'LBSEQ' 'LBCAT' 'VSSEQ' 'EGSEQ' 'EXTRT' 'EXROUTE')
        then do;
          if missing(origin) then origin = 'Predecessor';
          derivation_summary = 'Copied from SDTM';
        end;
        else do;
          if missing(origin) then origin = 'Derived';
          derivation_summary = 'As programmed (not yet in registry)';
        end;
      end;
      if missing(prespec_analogue) then
        prespec_analogue = 'as programmed - no registry row yet';
    end;
    drop _v _ds;
  run;

  proc sql noprint;
    select count(*) into :n_reg trimmed
           from metadata.pva_as_programmed_registry;
    select count(*) into :n_inv trimmed
           from metadata.pva_var_inventory;
    select count(*) into :n_trace trimmed
           from metadata.pva_var_trace;
    select count(*) into :n_both trimmed
           from metadata.pva_var_trace
           where upcase(trace_status) = 'BOTH';
    select count(*) into :n_code_only trimmed
           from metadata.pva_var_trace
           where upcase(trace_status) = 'CODE_ONLY';
    select count(*) into :n_reg_only trimmed
           from metadata.pva_var_trace
           where upcase(trace_status) = 'REGISTRY_ONLY';
    select count(distinct upcase(dataset)) into :n_trace_ds trimmed
           from metadata.pva_var_trace;
    select distinct upcase(dataset) into :trace_ds separated by ' '
           from metadata.pva_var_trace;
  quit;

  %put NOTE: Layer 3 registry rows=&n_reg inventory rows=&n_inv trace rows=&n_trace.;
  %put NOTE: datasets=&trace_ds (n=&n_trace_ds).;
  %put NOTE: trace_status BOTH=&n_both CODE_ONLY=&n_code_only REGISTRY_ONLY=&n_reg_only.;
  %put NOTE: CODE_ONLY = on adam.* but not yet in the as-programmed registry.;
  %put NOTE: REGISTRY_ONLY = documented in the registry but not on the built dataset.;

  title "Layer 3 - as-programmed registry vs admiral template steps";
  title2 "No CDISC-style admiral ADaM spec spreadsheet found. Prespec analogue = template function.";
  proc print data=metadata.pva_as_programmed_registry noobs;
    var dataset variable origin builder_macro sas_port
        admiral_function key_params by_vars prespec_analogue;
  run;
  title;

  title "Layer 3 - coverage by dataset and trace_status";
  proc freq data=metadata.pva_var_trace;
    tables dataset / nocum nopercent;
    tables trace_status / nocum nopercent;
    tables dataset*trace_status / norow nocol nopercent;
  run;
  title;

  title "Layer 3 - as-programmed provenance (FULL trace - all vars all datasets)";
  title2 "BOTH / CODE_ONLY / REGISTRY_ONLY. CSV: metadata/pva_var_trace.csv";
  proc print data=metadata.pva_var_trace noobs;
    var dataset variable type sas_length origin trace_status
        builder_macro sas_port admiral_function
        key_params derivation_summary prespec_analogue;
  run;
  title;

  proc export data = metadata.pva_var_inventory
           outfile = "&ROOT/metadata/pva_var_inventory.csv"
              dbms = csv replace;
  run;
  proc export data = metadata.pva_var_trace
           outfile = "&ROOT/metadata/pva_var_trace.csv"
              dbms = csv replace;
  run;
  proc export data = metadata.pva_as_programmed_registry
           outfile = "&OUTDIR/pva_as_programmed_registry.csv"
              dbms = csv replace;
  run;
  proc export data = metadata.pva_var_trace
           outfile = "&OUTDIR/pva_var_trace.csv"
              dbms = csv replace;
  run;
  proc export data = metadata.pva_as_programmed_registry
           outfile = "&ROOT/docs/pva_as_programmed_spex.csv"
              dbms = csv replace;
  run;

  proc printto;
  run;

  %m_chklog(logfile=&TRACE_LOG, out=work.trace_log_issues, print=Y);

  %if &_have_pub %then %do;
    %m_oda_publish(
                   runtag=pva_traceability
                 , logfile  = &TRACE_LOG
                 , datasets = metadata.pva_as_programmed_registry
                              metadata.pva_var_inventory
                              metadata.pva_var_trace
                 );
  %end;

  %put NOTE: Layer 3 complete. Open Results HTML or metadata/pva_var_trace.csv.;
  %put NOTE: First-cut as-programmed spex: SAS/docs/pva_as_programmed_spex.csv.;
%mend _run_traceability_pva_oda;

%_run_traceability_pva_oda;
