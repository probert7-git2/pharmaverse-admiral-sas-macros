/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_derive_var_base.sas
  SAS Version                 : 9.4
  Purpose (short description) : BASE CHG PCHG SHIFT BSHIFT lookup ports for BDS
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Caller BDS dataset with AVAL ABLFL
  Modification Log            : 19AUG2026 - SHIFT rebuild v2f: trimn + missing-side
                                literals - cat() of $40 temps left internal pad blanks
                                vs gold "HIGH to NORMAL" (Layer-1 strip cannot fix).
                                19AUG2026 - SHIFT rebuild v2e: cat(_f,_t) without re-strip
                                of byte(32) - restores gold "  to NORMAL" (v2c re-strip
                                had collapsed the missing-side space).
                                19AUG2026 - SHIFT rebuild v2d: DROP=&new_var only when
                                the var exists on input (OPEN/VARNUM) - ODA ERRORs on
                                unconditional drop of never-referenced vars.
                                19AUG2026 - SHIFT rebuild v2c: cat(strip()) into $200 so
                                padded temps do not trip CAT buffer truncate.
                                19AUG2026 - SHIFT rebuild v2: LENGTH before SET, DROP= old
                                SHIFT, cat() not ||, byte(32) missing placeholder (ODA-safe).
                                19AUG2026 - SHIFT harden: strip(var) not vvalue, hard-code
                                sep and missing_value space (avoid %str defaults that ODA
                                can trim so SHIFT stayed blank while BNRIND/ANRIND matched).
                                18AUG2026 - SHIFT: do not strip(_f/_t) before || - strip(" ")
                                collapses admiral missing_value space and yields " to NORMAL"
                                instead of gold/admiral "  to NORMAL". Values already stripped
                                when non-missing.
                                18AUG2026 - Optional order= for first-after-sort baseline
                                (character BASEC/BNRIND - admiral derive_var_base). Default
                                remains SQL max (numeric AVAL BASE, matches Track A gold).
                                18AUG2026 - SHIFT use || not catt: catt strips trailing blanks
                                from " to " and produced "NORMAL toNORMAL" vs gold spacing.
                                17AUG2026 - SHIFT use catt not catx (admiral " to NORMAL").
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Phase 2 BDS — baseline / change / shift / lookup
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/
/*******************************************************************************
  %m_derive_var_base — substantial port of admiral::derive_var_base()

  For each by_vars group, take source_var from the row matching filter
  (default ABLFL='Y') and broadcast as new_var.

  Multiple baseline rows:
    - order= blank (default): SQL max (numeric AVAL / Track A gold)
    - order= supplied: first row after sort by by_vars + order (character
      BASEC/BNRIND, or any first-baseline-by-visit pattern)
*******************************************************************************/
%macro m_derive_var_base(
                           dataset=
                         , by_vars=USUBJID PARAMCD
                         , source_var=AVAL
                         , new_var=BASE
                         , filter=%str(ABLFL = 'Y')
                         , order=
                         , out=
                         );
  %local by_csv by_last;

  %if %length(&dataset)=0 or %length(&out)=0 %then %do;
      %put ERROR: m_derive_var_base requires dataset= and out=.;
      %return;
  %end;

  %let by_csv = %sysfunc(tranwrd(&by_vars, %str( ), %str(, )));
  %let by_last = %scan(&by_vars, -1, %str( ));

  %if %length(&order) %then %do;
    /* First matching baseline after by_vars + order (not SQL max) */
    proc sort data=&dataset out=work._base_cand;
      by &by_vars &order;
    run;
    data work._base_src(keep=&by_vars &new_var);
      set work._base_cand;
      where &filter;
      by &by_vars;
      if first.&by_last;
      &new_var = &source_var;
    run;
  %end;
  %else %do;
    proc sql noprint;
         create table work._base_src as
         select &by_csv
              , max(&source_var) as &new_var
         from &dataset
         where &filter
         group by &by_csv
         ;
    quit;
  %end;

  proc sort data=&dataset 
             out=work._base_all;
       by &by_vars;
  run;
  proc sort data=work._base_src;
       by &by_vars;
  run;

  data &out;
       merge work._base_all(in=a) 
             work._base_src;
       by &by_vars;
       if a;
  run;

  proc datasets lib=work nolist;
       delete _base_src 
              _base_all;
       %if %length(&order) %then %do;
         delete _base_cand;
       %end;
  quit;

  %m_nobs(ds=&out);
%mend m_derive_var_base;


/*******************************************************************************
  %m_derive_var_chg — port of admiral::derive_var_chg()
*******************************************************************************/
%macro m_derive_var_chg(
                          dataset=
                        , out=
                        );

  %if %length(&dataset)=0 or 
      %length(&out)=0 %then %do;
         %put ERROR: m_derive_var_chg requires dataset= and out=.;
         %return;
  %end;

  data &out;
       set &dataset;
       if not missing(AVAL) and not missing(BASE) then CHG = AVAL - BASE;
       else                                            CHG = .;
  run;

  %m_nobs(ds=&out);
%mend m_derive_var_chg;


/*******************************************************************************
  %m_derive_var_pchg — port of admiral::derive_var_pchg()
*******************************************************************************/
%macro m_derive_var_pchg(
                           dataset=
                         , out=
                        );

  %if %length(&dataset)=0 or 
      %length(&out)=0 %then %do;
         %put ERROR: m_derive_var_pchg requires dataset= and out=.;
         %return;
  %end;

  data &out;
       set &dataset;
        if not missing(AVAL) and 
           not missing(BASE) and 
           BASE ne 0 then PCHG = 100 * (AVAL - BASE) / BASE;
        else              PCHG = .;
  run;

  %m_nobs(ds=&out);
%mend m_derive_var_pchg;

                                                                 
/*******************************************************************************
  %m_derive_var_shift / %m_derive_var_bshift
  Substantial port of admiral::derive_var_shift() (user list: bshift)

  SHIFT = from || " to " || to  (both blank -> blank SHIFT).
  Track A gold: paste(coalesce(BNRIND," "),"to",coalesce(ANRIND," ")).
  Missing side uses char literals ("  to " / " to  ") so spacing matches gold.
  Non-missing sides use trimn so $40 pad does not become internal blanks.
  Do NOT use catx/catt/cats - they drop or strip blank args / sep spaces.
  Do NOT cat() fixed-length temps - trailing pad becomes internal blanks.
  missing_value= and sep= are accepted for call compatibility but ignored -
  hard-coded literals avoid percent-str space defaults that some hosts trim.
*******************************************************************************/
%macro m_derive_var_shift(
                            dataset=
                          , new_var=SHIFT
                          , from_var=BASEC
                          , to_var=AVALC
                          , missing_value=
                          , sep=
                          , out=
                          );

  %if %length(&dataset)=0 or 
      %length(&out)=0 %then %do;
         %put ERROR: m_derive_var_shift requires dataset= and out=.;
         %return;
  %end;

  /* LENGTH before SET. DROP=&new_var only when it exists on input -
     ODA ERRORs on drop of a never-referenced variable (not a WARNING). */
  %local _dsid _has_nv _rc;
  %let _has_nv = 0;
  %let _dsid = %sysfunc(open(&dataset, i));
  %if &_dsid %then %do;
       %let _has_nv = %eval(%sysfunc(varnum(&_dsid, &new_var)) > 0);
       %let _rc = %sysfunc(close(&_dsid));
  %end;
  %put NOTE: m_derive_var_shift rebuild v2 19AUG2026f - &new_var from &from_var/&to_var (has_prior=&_has_nv).;
  data &out;
       length &new_var $200 _f $40 _t $40;
       %if &_has_nv %then %do;
            set &dataset(drop=&new_var);
       %end;
       %else %do;
            set &dataset;
       %end;
       if missing(&from_var) and missing(&to_var) then &new_var = '';
       else do;
            /* trimn drops $40 trailing pad without collapsing a real value.
               Missing-side space is a char literal - strip/trimn of an
               all-blank $40 would collapse gold "  to NORMAL" spacing. */
            _f = strip(&from_var);
            _t = strip(&to_var);
            if missing(_f) then &new_var = '  to ' || trimn(_t);
            else if missing(_t) then &new_var = trimn(_f) || ' to  ';
            else &new_var = trimn(_f) || ' to ' || trimn(_t);
       end;
       drop _f _t;
  run;

  %m_nobs(ds=&out);
%mend m_derive_var_shift;

%macro m_derive_var_bshift(
                             dataset=
                           , new_var=SHIFT
                           , from_var=BASEC
                           , to_var=AVALC
                           , out=
                           );

  %m_derive_var_shift(
                        dataset=&dataset
                      , new_var=&new_var
                      , from_var=&from_var
                      , to_var=&to_var
                      , out=&out
                      );

%mend m_derive_var_bshift;


/*******************************************************************************
  %m_derive_vars_merged_lookup — substantial port of derive_vars_merged_lookup()

  Left-join lookup (dataset_add) onto dataset by by_vars; optionally list
  unmapped keys. new_vars: space-separated NEW=OLD or bare names.
*******************************************************************************/
%macro m_derive_vars_merged_lookup(
                                     dataset=
                                   , dataset_add=
                                   , by_vars=
                                   , new_vars=
                                   , filter_add=%str(1)
                                   , print_not_mapped=Y
                                   , out=
                                   );
  %local i v nv_new nv_old sel keep_add by_csv;

  %if %length(&dataset)=0 or 
     %length(&dataset_add)=0 or 
     %length(&by_vars)=0 or
     %length(&out)=0 %then %do;
        %put ERROR: m_derive_vars_merged_lookup requires dataset=, dataset_add=, by_vars=, out=.;
        %return;
  %end;

  %let by_csv = %sysfunc(tranwrd(&by_vars, %str( ), %str(, )));

  %let sel =;
  %let keep_add = &by_vars;
  %if %length(&new_vars) = 0 %then %do;
      %put ERROR: m_derive_vars_merged_lookup v1 requires new_vars= (NEW=OLD or NAME list).;
      %return;
  %end;

  %let i = 1;
  %let v = %scan(&new_vars, &i, %str( ));
  %do %while(%length(&v));
      %if %index(&v, =) %then %do;
          %let nv_new = %scan(&v, 1, =);
          %let nv_old = %scan(&v, 2, =);
      %end;
      %else %do;
          %let nv_new = &v;
          %let nv_old = &v;
      %end;
      %let sel = &sel , b.&nv_old as &nv_new;
      %let keep_add = &keep_add &nv_old;
      %let i = %eval(&i + 1);
      %let v = %scan(&new_vars, &i, %str( ));
  %end;

  proc sql;
       create table work._lkp as
       select *
       from &dataset_add
       where &filter_add
    ;
  quit;

  %if %upcase(&print_not_mapped) = Y or %upcase(&print_not_mapped) = TRUE %then %do;
    proc sort data=&dataset(keep=&by_vars)
               out=work._keys nodupkey;
         by &by_vars;
    run;
    proc sort data=work._lkp(keep=&by_vars) 
               out=work._lkp_keys nodupkey;
         by &by_vars;
    run;
    data work._unmap;
         merge work._keys(in=a) 
               work._lkp_keys(in=b);
         by &by_vars;
         if a and not b;
    run;
    proc sql noprint;
         select count(*) into :_nunmap trimmed 
         from work._unmap;
    quit;
    %if &_nunmap > 0 %then %do;
        %put WARNING: &_nunmap distinct by_vars key(s) not mapped from lookup.;
        proc print data=work._unmap(obs=20);
             title "Unmapped lookup keys (first 20)";
        run;
        title;
    %end;
    %else %put NOTE: All by_vars keys are mapped.;
  %end;

  proc sql;
       create table &out as
       select a.*
              &sel
       from &dataset       as a
       left join work._lkp as b
       on %let i=1; %let v=%scan(&by_vars,&i,%str( ));
       %do %while(%length(&v));
           %if &i>1 %then and;
           a.&v = b.&v
           %let i=%eval(&i+1);
           %let v=%scan(&by_vars,&i,%str( ));
       %end;
       ;
  quit;

  proc datasets lib=work nolist;
       delete _lkp 
              _unmap 
              _keys 
              _lkp_keys;
  quit;

  %m_nobs(ds=&out);
%mend m_derive_vars_merged_lookup;
