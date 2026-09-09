/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_oda_publish.sas
  SAS Version                 : 9.4
  Purpose (short description) : Archive logs and datasets to goldout/output on ODA
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Caller-supplied datasets and log path
  Modification Log            : 18AUG2026 - Quote path strings in %IF (ODA %EVAL char error).
                                17AUG2026 - %m_oda_touch heartbeat; log archive without goldout
                                lib; fail marker on early abort; verify OUTDIR exists.
                                17AUG2026 - Added %m_oda_expect; strip CR/LF from datasets= tokens;
                                end-of-run sentinel NOTE.
                                16AUG2026 - Fail loudly when _wrote=0 (marker alone is not success).
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Ensure project output libname (SAS/output under ROOT).

  Called from init and from m_oda_publish before every archive.
  Uses DATA step FILE/SET only - no XCMD, no FCOPY.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_ensure_goldout;

  %global OUTDIR GOLDOUT_PATH ROOT HOME_DIR;
  %local _rc _path_u _expect_u _gold_lr;

  %if not %symexist(ROOT) %then %do;
    %put ERROR: m_ensure_goldout - ROOT is undefined. Include init_libnames_oda.sas first.;
    %return;
  %end;

  %if not %symexist(OUTDIR) %then %let OUTDIR = &ROOT/output;

  /* Always pin OUTDIR to ROOT/output (never inherit a stale or nested path) */
  %let OUTDIR = &ROOT/output;
  %let _rc = %sysfunc(dcreate(output, &ROOT));

  %if %sysfunc(fileexist(&OUTDIR)) = 0 %then %do;
    %put ERROR: m_ensure_goldout - OUTDIR missing after dcreate: &OUTDIR;
    %put ERROR: Create safety_monitoring_system/SAS/output on ODA (Files) and re-run.;
  %end;

  %let _gold_lr = %sysfunc(libref(goldout));
  %if &_gold_lr = 0 %then %do;
    libname goldout clear;
  %end;

  libname goldout "&OUTDIR";
  %let GOLDOUT_PATH = %sysfunc(pathname(goldout));

  %if %sysfunc(libref(goldout)) ne 0 or %length(&GOLDOUT_PATH) = 0 %then %do;
    %put ERROR: m_ensure_goldout could not assign libname goldout to &OUTDIR;
  %end;
  %else %do;
    %put NOTE: m_ensure_goldout OK - goldout -> &GOLDOUT_PATH;
    %let _path_u = %upcase(&GOLDOUT_PATH);
    %let _expect_u = %upcase(&ROOT/output);
    /* Refuse only clear nest/quarantine paths - not a soft path mismatch */
    %if %index(&_path_u, ADAM_BAD) %then %do;
      %put ERROR: goldout path is under adam_BAD - refusing.;
      %put ERROR: Expected &ROOT/output - got &GOLDOUT_PATH;
      libname goldout clear;
    %end;
    %else %if %index(&_path_u, /ADAM/SAS/) %then %do;
      %put ERROR: goldout path is nested under adam/SAS - refusing.;
      %put ERROR: Expected &ROOT/output - got &GOLDOUT_PATH;
      libname goldout clear;
    %end;
    /* Quote paths - bare &_path_u ne &_expect_u hits %EVAL and fails on ODA */
    %else %if "%superq(_path_u)" ne "%superq(_expect_u)" %then %do;
      %put WARNING: goldout pathname differs from ROOT/output (continuing).;
      %put WARNING: expected=&_expect_u got=&_path_u;
    %end;
  %end;

%mend m_ensure_goldout;


/* Write a tiny proof file under OUTDIR (does not need goldout datasets).
   Call stage=start before PRINTTO body risk, stage=finish after publish. */
%macro m_oda_touch(tag=, stage=);

  %local _f;

  %if %length(&tag) = 0 or %length(&stage) = 0 %then %do;
    %put ERROR: m_oda_touch requires tag= and stage=;
    %return;
  %end;

  %m_ensure_goldout;

  %let _f = &OUTDIR/_run_&tag._&stage..txt;
  data _null_;
    file "&_f";
    put "tag=&tag";
    put "stage=&stage";
    put "root=&ROOT";
    put "outdir=&OUTDIR";
    put "goldout_path=&GOLDOUT_PATH";
    put "datetime=%sysfunc(datetime(), datetime19.)";
  run;

  %if %sysfunc(fileexist(&_f)) %then %put NOTE: m_oda_touch OK &_f;
  %else %put ERROR: m_oda_touch FAILED &_f - OUTDIR not writable on ODA;

%mend m_oda_touch;


/* SAS member names max 32 chars - shorten runtag_mem when needed */
%macro m_oda_gold_dest(runtag=, mem=);
  %local _full _dest;
  %let _full = &runtag._&mem;
  %if %length(&_full) <= 32 %then %let _dest = &_full;
  %else %if %length(&mem) <= 32 %then %let _dest = &mem;
  %else %let _dest = %substr(&mem, 1, 32);
  %if %length(&_full) > 32 %then %put NOTE: m_oda_gold_dest &_dest shortened from &_full;
  &_dest
%mend m_oda_gold_dest;


/*--------------------------------------------------------------
  Assert that one expected artifact landed, and say so in the log.

  kind=file - OS path under &OUTDIR
  kind=ds   - libname.member (e.g. goldout.golden_subjects_summary)

  Call AFTER PROC PRINTTO closes so the verdict is visible in the
  SAS Studio Log, not only inside the archived logs/ file.
--------------------------------------------------------------*/
%macro m_oda_expect(path=, kind=file);

  %local _k;

  %if %length(&path) = 0 %then %do;
    %put ERROR: m_oda_expect requires path=;
    %return;
  %end;

  %let _k = %upcase(&kind);
  %if %length(&_k) = 0 %then %let _k = FILE;

  %if &_k = DS %then %do;
    %if %sysfunc(exist(&path)) %then %put NOTE: archive OK: &path;
    %else %put ERROR: archive MISSING: &path;
  %end;
  %else %do;
    %if %sysfunc(fileexist(&path)) %then %put NOTE: archive OK: &path;
    %else %put ERROR: archive MISSING: &path;
  %end;

%mend m_oda_expect;


/*--------------------------------------------------------------
  Archive ODA run artifacts to SAS/output (libname goldout).

  Copies logs and datasets into &ROOT/output (safety_monitoring_system/SAS/output).
  Primary build paths (adam/, logs/) are unchanged.

  Log file copies use DATA step FILE and do NOT require libname goldout.
  Dataset copies require goldout. A marker .txt alone is NOT success.
--------------------------------------------------------------*/
%macro m_oda_publish(
  runtag=
, logfile=
, datasets=
, log_issues=
, annotated=Y
);

  %local _i _raw _src _mem _dest _copy _wrote _marker _n_skip _gold_ok _fail;

  %if %length(&runtag)=0 %then %do;
    %put ERROR: m_oda_publish requires runtag=;
    %return;
  %end;

  %m_ensure_goldout;

  %let _gold_ok = 1;
  %if %sysfunc(libref(goldout)) ne 0 %then %do;
    %let _gold_ok = 0;
    %put ERROR: m_oda_publish - libname goldout not available (dataset archive skipped).;
    %put ERROR: Log copies will still be attempted under OUTDIR=&OUTDIR;
  %end;

  %put NOTE: m_oda_publish start runtag=&runtag;
  %put NOTE: m_oda_publish OUTDIR=&OUTDIR;
  %put NOTE: m_oda_publish GOLDOUT_PATH=&GOLDOUT_PATH;
  %put NOTE: m_oda_publish goldout pathname=%sysfunc(pathname(goldout));

  %let _wrote = 0;
  %let _n_skip = 0;
  %let _marker = &OUTDIR/_oda_publish_&runtag..txt;
  %let _fail = &OUTDIR/_oda_publish_&runtag._FAILED.txt;

  /* Log archive via FILE - works even when goldout libref failed */
  %if %length(&logfile) and %sysfunc(fileexist(&logfile)) %then %do;
    %let _copy = &OUTDIR/&runtag..log;
    data _null_;
      infile "&logfile" length=_ll truncover end=_eof;
      input _line $varying400. _ll;
      file "&_copy";
      put _line;
    run;
    %if %sysfunc(fileexist(&_copy)) %then %do;
      %put NOTE: m_oda_publish log archive: &_copy;
      %let _wrote = %eval(&_wrote + 1);
    %end;
    %else %put ERROR: m_oda_publish failed to write &_copy;

    %if %upcase(&annotated)=Y %then %do;
      %let _copy = &OUTDIR/&runtag._annotated.log;
      data _null_;
        infile "&logfile" length=_ll truncover end=_eof;
        input _line $varying400. _ll;
        file "&_copy";
        put _n_ z6. ': ' _line;
      run;
      %if %sysfunc(fileexist(&_copy)) %then %do;
        %put NOTE: m_oda_publish annotated log: &_copy;
        %let _wrote = %eval(&_wrote + 1);
      %end;
      %else %put ERROR: m_oda_publish failed to write &_copy;
    %end;
  %end;
  %else %if %length(&logfile) %then %put ERROR: m_oda_publish log not found: &logfile;

  /* Dataset archive requires goldout */
  %if &_gold_ok %then %do;
    /* A datasets= list written across several source lines can carry a CR/LF into
       a token, which made %sysfunc(exist()) fail on a perfectly good member.
       _raw drives the loop, _src is the cleaned name actually used. */
    %let _i = 1;
    %let _raw = %scan(&datasets, &_i, %str( ));
    %do %while(%length(&_raw));
      %let _src = %sysfunc(compress(&_raw, %str(._), kan));
      %if %length(&_src) %then %do;
        %let _mem = %scan(&_src, 2, .);
        %if %length(&_mem) = 0 %then %let _mem = &_src;
        %let _dest = %m_oda_gold_dest(runtag=&runtag, mem=&_mem);
        %if %length(&_dest) <= 32 %then %do;
          %if %sysfunc(exist(&_src)) %then %do;
            data goldout.&_dest;
              set &_src;
            run;
            %if %sysfunc(exist(goldout.&_dest)) %then %do;
              %let _wrote = %eval(&_wrote + 1);
              %put NOTE: m_oda_publish dataset goldout.&_dest from &_src;
            %end;
            %else %put ERROR: m_oda_publish failed to create goldout.&_dest from &_src;
          %end;
          %else %do;
            %put WARNING: m_oda_publish skip missing dataset &_src;
            %let _n_skip = %eval(&_n_skip + 1);
          %end;
        %end;
        %else %put ERROR: m_oda_publish dest name exceeds 32 chars for &_src;
      %end;
      %let _i = %eval(&_i + 1);
      %let _raw = %scan(&datasets, &_i, %str( ));
    %end;

    %if %length(&log_issues) and %sysfunc(exist(&log_issues)) %then %do;
      %let _dest = %m_oda_gold_dest(runtag=&runtag, mem=log_issues);
      data goldout.&_dest;
        set &log_issues;
      run;
      %if %sysfunc(exist(goldout.&_dest)) %then %do;
        %let _wrote = %eval(&_wrote + 1);
        %put NOTE: m_oda_publish dataset goldout.&_dest from &log_issues;
      %end;
      %else %put ERROR: m_oda_publish failed to create goldout.&_dest from &log_issues;
    %end;
  %end;

  /* Marker is diagnostic only - never counts as a successful archive item */
  data _null_;
    file "&_marker";
    put "runtag=&runtag";
    put "outdir=&OUTDIR";
    put "goldout_path=&GOLDOUT_PATH";
    put "gold_ok=&_gold_ok";
    put "items=&_wrote";
    put "skipped=&_n_skip";
  run;

  %if &_wrote > 0 %then %do;
    %put NOTE: m_oda_publish &runtag finished - &_wrote item(s) in &OUTDIR;
    %if %sysfunc(fileexist(&_marker)) %then
      %put NOTE: m_oda_publish marker: &_marker;
  %end;
  %else %do;
    %put ERROR: m_oda_publish &runtag wrote nothing to &OUTDIR;
    %put ERROR: Check logfile= exists, OUTDIR is writable, and datasets= members exist.;
    %put ERROR: skipped_missing=&_n_skip OUTDIR=&OUTDIR gold_ok=&_gold_ok;
    data _null_;
      file "&_fail";
      put "runtag=&runtag";
      put "outdir=&OUTDIR";
      put "gold_ok=&_gold_ok";
      put "logfile=&logfile";
      put "reason=wrote_nothing";
    run;
    %put ERROR: Diagnostic marker was still written: &_marker;
    %if %sysfunc(fileexist(&_fail)) %then %put ERROR: Fail marker: &_fail;
  %end;

  /* Sentinel - search the Studio Log for "m_oda_publish end" to prove publish ran */
  %put NOTE: m_oda_publish end runtag=&runtag items=&_wrote skipped=&_n_skip;

%mend m_oda_publish;
