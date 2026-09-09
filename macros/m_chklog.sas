/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_chklog.sas
  SAS Version                 : 9.4
  Purpose (short description) : Scan SAS log for ERROR/WARNING patterns
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Saved SAS log file
  Modification Log            : 18AUG2026 - Prefix must sit in COLUMN 1 (no strip before the
                                test) so indented listing text is never re-flagged; keep bare
                                ERROR/WARNING so numbered forms (ERROR 22-322:) still match;
                                new source column splits SAS-engine messages from QC-authored
                                findings and the closing WARNING keys on engine issues only.
                                17AUG2026 - Require NOTE:/WARNING:/ERROR: prefix before
                                pattern match (avoids SOURCE false positives).
                                16AUG2026 - ERROR if annotated= path fails to write.
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  %m_chklog - scan a saved SAS log for common issues
  On ODA: write the log with PROC PRINTTO first, then call this.
  Prefer %include of this macro BEFORE opening PRINTTO so SOURCE is not scanned.

  linenum is the line number IN THE SAVED logfile (not Studio log).
  Use annotated= to write a numbered copy for cross-reference.

  Output column source:
    SAS - message written by the SAS engine (a real log defect to fix)
    QC  - message written by a QC macro as %put WARNING: [LABEL] ...
          (a compare finding - triage it in the digest, not in the log)
  The closing WARNING: Log issues found fires when a source=SAS row exists or
  any ERROR was flagged. QC-only WARNING findings report at NOTE level - triage
  them in adam.qc_adam2_procompare, not as log defects.

  Example:
  %m_chklog(logfile=&ROOT/logs/run_adam2_workflow_oda.log);
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_chklog(
  logfile=
, out=work.log_issues
, print=Y
, annotated=
);

  %local _rc n_root n_cascade n_engine n_qc n_warn_eng n_warn_qc n_lines;
  %let n_lines = 0;

  %if %length(&logfile)=0 %then %do;
    %put ERROR: m_chklog requires logfile=;
    %return;
  %end;

  %let _rc = %sysfunc(fileexist(&logfile));
  %if &_rc = 0 %then %do;
    %put ERROR: m_chklog file not found;
    %put ERROR: &logfile;
    %return;
  %end;

  %if %length(&annotated) %then %do;
    data _null_;
      infile "&logfile" length=_ll truncover end=_eof;
      input _line $varying400. _ll;
      file "&annotated";
      put _n_ z6. ': ' _line;
    run;
    %if %sysfunc(fileexist(&annotated)) %then
      %put NOTE: m_chklog annotated log (linenum matches this file): &annotated;
    %else %put ERROR: m_chklog failed to write annotated log: &annotated;
  %end;

  data &out;
    length line $400 issue $40 source $8 logfile $256 cascade $1 _msg $400 _body $400;
    logfile = "&logfile";
    infile "&logfile" length=linelen truncover end=eof;
    input line $varying400. linelen;
    linenum = _N_;
    line_lc = lowcase(line);
    /* Sanity anchor for the column-1 rule: a big log with 0 issues means the
       keywords were not in column 1, not that the run was clean. */
    if eof then call symputx('n_lines', _N_, 'L');

    /* Classify only real SAS log messages. A message keyword is written in
       COLUMN 1, so line_lc must NOT be stripped before this test - indented
       text is listing output (PROC PRINT of a prior log_issues LINE column,
       titles, wrapped continuation lines) and re-flagging it inflates counts.
       Keyword stays bare (not 'error:') so numbered forms such as
       ERROR 22-322: and WARNING 32-169: are still caught. */
    issue = '';
    if line_lc =: 'error' then issue = 'ERROR';
    else if line_lc =: 'warning' then issue = 'WARNING';
    else if line_lc =: 'note:' then do;
      if index(line_lc, 'uninitialized') then issue = 'NOTE-UNINIT';
      else if index(line_lc, 'merge statement has more than one') then issue = 'NOTE-MERGE';
      else if index(line_lc, 'values have been converted') then issue = 'NOTE-CONVERT';
      else if index(line_lc, 'division by zero') then issue = 'NOTE-DIV0';
      else if index(line_lc, 'mathematical operations could not') then issue = 'NOTE-MATH';
      else if index(line_lc, 'invalid argument') then issue = 'NOTE-INVALID';
      else if index(line_lc, 'w.d format was too small')
           or index(line_lc, 'format was too small') then issue = 'NOTE-FORMAT';
      else if index(line_lc, 'apparent symbolic reference') then issue = 'NOTE-MACROVAR';
    end;
    if issue = '' then delete;

    /* Content tests below run on the accepted message only */
    _msg = strip(line_lc);

    /* QC macros write their findings as %put WARNING: [ADEG] ... - a compare
       result, not a log defect. Anything else is a SAS-engine message. */
    source = 'SAS';
    _colon = index(_msg, ':');
    if _colon > 0 and _colon < lengthn(_msg) then do;
      _body = strip(substr(_msg, _colon + 1));
      if _body =: '[' then source = 'QC';
    end;

    cascade = 'N';
    if issue = 'ERROR' then do;
      if index(_msg, 'does not exist')
      or index(_msg, 'requires work.')
      or index(_msg, 'defined as both character and numeric')
      or index(_msg, 'will stop executing')
      then cascade = 'Y';
    end;

    keep linenum issue source line logfile cascade;
  run;

  proc sql noprint;
    select count(*) into :n_iss trimmed from &out;
    select count(*) into :n_err trimmed from &out where issue = 'ERROR';
    select count(*) into :n_warn trimmed from &out where issue = 'WARNING';
    select count(*) into :n_cascade trimmed from &out
      where issue = 'ERROR' and cascade = 'Y';
    select count(*) into :n_root trimmed from &out
      where issue = 'ERROR' and cascade = 'N';
    select count(*) into :n_engine trimmed from &out where source = 'SAS';
    select count(*) into :n_qc trimmed from &out where source = 'QC';
    select count(*) into :n_warn_eng trimmed from &out
      where issue = 'WARNING' and source = 'SAS';
    select count(*) into :n_warn_qc trimmed from &out
      where issue = 'WARNING' and source = 'QC';
  quit;

  %put NOTE: ===== m_chklog done =====;
  %put NOTE: Log scanned: &logfile;
  %put NOTE: linenum values refer to THIS saved file (Studio log line numbers differ).;
  %if %length(&annotated) %then %put NOTE: Numbered copy: &annotated;
  %put NOTE: lines scanned=&n_lines;
  %put NOTE: issues=&n_iss  ERROR=&n_err  WARNING=&n_warn;
  %put NOTE: source split - sas-engine=&n_engine  qc-finding=&n_qc;
  %put NOTE: WARNING split - sas-engine=&n_warn_eng  qc-finding=&n_warn_qc;
  %put NOTE: ERROR root-cause lines=&n_root  likely cascade=&n_cascade;

  %if &n_iss = 0 %then %put NOTE: CLEAN LOG - no flagged issues.;
  %else %do;
    /* ERROR always escalates - assertion macros write ERROR: [GOLDEN FAIL] etc. */
    %if &n_engine > 0 or &n_err > 0 %then %do;
      %put WARNING: Log issues found - see dataset &out;
    %end;
    %else %do;
      %put NOTE: No SAS-engine issues. All &n_iss flagged line(s) are QC findings - see dataset &out;
    %end;
    %if %upcase(&print)=Y %then %do;
      title Log issues from chklog (linenum = saved log file);
      proc print data=&out;
        id linenum;
        var issue source cascade line;
      run;
      title;
      %if &n_root > 0 %then %do;
        title Root-cause ERROR lines (exclude cascade=Y);
        proc print data=&out;
          id linenum;
          var issue line;
          where issue = 'ERROR' and cascade = 'N';
        run;
        title;
      %end;
    %end;
  %end;

%mend m_chklog;
