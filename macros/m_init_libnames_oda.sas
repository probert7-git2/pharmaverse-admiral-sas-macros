/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_init_libnames_oda.sas
  SAS Version                 : 9.4
  Purpose (short description) : Assign ODA libnames ROOT raw adam ref metadata goldout
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : ODA HOME path, setup/study_params.sas, metadata/supp_qnam_ct.sas
  Modification Log            : 18AUG2026 - %include m_oda_ref_diag.sas (no longer inline).
                                18AUG2026 - Always re-assign libnames (incl. ref) when ROOT
                                already set from Autoexec. Create validation/. REF diagnostics
                                and wrong-case / XPT-only repair hints for exist(ref.ref_adsl).
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  ODA libnames for safety_monitoring_system/SAS

  %include once per session (ODA Autoexec or first driver program).
  SDTM sas7bdat live in sdtm/ (libname raw).
  Run archive: libname goldout -> &ROOT/output
  Primary build: adam/, logs/ under &ROOT

  ODA Files: safety_monitoring_system / SAS / output
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_init_libnames_oda;

  %global ROOT PATHSEP REFDIR SDTMDIR HOME_DIR OUTDIR LOGDIR GOLDOUT_PATH;
  %local _root_tail _rc _root_was_set;

  %let _root_was_set = 0;
  %if %symexist(ROOT) %then %do;
    %if %length(&ROOT) > 0 %then %let _root_was_set = 1;
  %end;

  %if &_root_was_set = 0 %then %do;
    %let PATHSEP  = /;
    %let HOME_DIR = %sysfunc(strip(%sysget(HOME)));
    %let ROOT     = &HOME_DIR/safety_monitoring_system/SAS;
  %end;
  %else %do;
    %put NOTE: init_libnames_oda ROOT already set - refreshing libnames. ROOT=&ROOT;
    %if not %symexist(HOME_DIR) %then %let HOME_DIR = %sysfunc(strip(%sysget(HOME)));
    %if %length(&HOME_DIR) = 0 %then %let HOME_DIR = %sysfunc(strip(%sysget(HOME)));
  %end;

  /* Always derive paths from ROOT so Autoexec re-include still points REF at validation/ */
  %let PATHSEP  = /;
  %let LOGDIR   = &ROOT/logs;
  %let OUTDIR   = &ROOT/output;
  %let SDTMDIR  = &ROOT/sdtm;
  %let REFDIR   = &ROOT/validation;

  /* Guard: ROOT must be .../SAS, never .../adam (would make adam/adam via dcreate) */
  %let _root_tail = %upcase(%scan(&ROOT, -1, /));
  %if &_root_tail = ADAM %then %do;
    %put ERROR: ROOT ends in adam - refusing libnames. Expected .../safety_monitoring_system/SAS;
    %put ERROR: ROOT=&ROOT;
    %return;
  %end;
  %if &_root_tail ne SAS %then %do;
    %put WARNING: ROOT last segment is &_root_tail - expected SAS. ROOT=&ROOT;
  %end;

  /* Always ensure dirs + libnames (Autoexec leaves ROOT set - must still assign ref) */
  %let _rc = %sysfunc(dcreate(sdtm, &ROOT));
  %let _rc = %sysfunc(dcreate(adam, &ROOT));
  %let _rc = %sysfunc(dcreate(logs, &ROOT));
  %let _rc = %sysfunc(dcreate(output, &ROOT));
  %let _rc = %sysfunc(dcreate(metadata, &ROOT));
  %let _rc = %sysfunc(dcreate(validation, &ROOT));

  libname raw      "&SDTMDIR";
  libname adam     "&ROOT/adam";
  libname ref      "&REFDIR";
  libname metadata "&ROOT/metadata";
  libname goldout  "&OUTDIR";

  options mprint notes source source2;

  /* study_params / CT: once per session is enough, but safe to re-include */
  %if %sysfunc(fileexist(&ROOT/setup/study_params.sas)) %then %do;
    %include "&ROOT/setup/study_params.sas";
  %end;

  %if %sysfunc(fileexist(&ROOT/metadata/supp_qnam_ct.sas)) %then %do;
    %include "&ROOT/metadata/supp_qnam_ct.sas";
  %end;
  %if %sysfunc(fileexist(&ROOT/metadata/supp_qnam_ct.sas)) = 0 %then %do;
    %put ERROR: Missing &ROOT/metadata/supp_qnam_ct.sas;
    %put ERROR: Upload the SAS/metadata folder to ODA (needed for SUPPDM/SUPPAE CT).;
  %end;

  %put NOTE: ===== ODA library paths =====;
  %put NOTE: HOME_DIR=&HOME_DIR;
  %put NOTE: ROOT=&ROOT;
  %put NOTE: LOGDIR=&LOGDIR;
  %put NOTE: OUTDIR=&OUTDIR;
  %put NOTE: REFDIR=&REFDIR;
  %put NOTE: raw  path=%sysfunc(pathname(raw));
  %put NOTE: adam path=%sysfunc(pathname(adam));
  %put NOTE: ref  path=%sysfunc(pathname(ref));
  %put NOTE: metadata path=%sysfunc(pathname(metadata));
  %put NOTE: Verify: ROOT should be HOME/safety_monitoring_system/SAS;
  %put NOTE: Verify: ref should be ROOT/validation (gold ref_*.sas7bdat live here);
  %put NOTE: Verify: adam should be ROOT/adam (one level only - no adam/SAS/adam nesting);

  %if %sysfunc(fileexist(%sysfunc(pathname(adam))/adam)) %then %do;
    %put WARNING: Nested adam/adam folder exists under adam lib - check ROOT was never set to .../adam.;
  %end;

  %if %sysfunc(exist(metadata.supp_qnam_ct)) = 0 %then %do;
    %put ERROR: metadata.supp_qnam_ct was not created - SUPP flag merges will fail.;
  %end;
  %if %sysfunc(libref(raw)) ne 0 %then %do;
    %put ERROR: libname raw failed - create &SDTMDIR;
  %end;
  %if %sysfunc(libref(adam)) ne 0 %then %do;
    %put ERROR: libname adam failed - create &ROOT/adam;
  %end;
  %if %sysfunc(libref(ref)) ne 0 %then %do;
    %put ERROR: libname ref failed - create &REFDIR;
  %end;
  %if %sysfunc(exist(raw.dm)) = 0 %then %do;
    %put WARNING: raw.dm not found - convert SDTM XPT to sas7bdat under &SDTMDIR;
  %end;

  /* Nest check every call (including Autoexec re-include when ROOT already set) */
  %if %sysfunc(fileexist(&ROOT/adam/SAS)) %then %do;
    %put ERROR: Nested project tree under adam: &ROOT/adam/SAS;
    %put ERROR: Delete that SAS folder (keep only datasets in adam/) - do not upload zips into adam.;
  %end;

  %if %sysfunc(fileexist(&ROOT/macros/m_oda_publish.sas)) %then %do;
    %include "&ROOT/macros/m_oda_publish.sas";
  %end;
  %else %do;
    %put ERROR: Missing &ROOT/macros/m_oda_publish.sas - upload SAS/macros to ODA.;
  %end;

  /* Load REF diag macro definition once - this file must ONLY define %m_oda_ref_diag.
     If ODA uploaded convert/compare source as m_oda_ref_diag.sas, include recurses. */
  %global _ODA_REF_DIAG_SRC;
  %if %symexist(_ODA_REF_DIAG_SRC) = 0 %then %let _ODA_REF_DIAG_SRC =;
  %if %length(&_ODA_REF_DIAG_SRC) = 0 %then %do;
    %if %sysfunc(fileexist(&ROOT/macros/m_oda_ref_diag.sas)) %then %do;
      %include "&ROOT/macros/m_oda_ref_diag.sas";
      %let _ODA_REF_DIAG_SRC = &ROOT/macros/m_oda_ref_diag.sas;
    %end;
    %else %do;
      %put ERROR: Missing &ROOT/macros/m_oda_ref_diag.sas - upload that standalone macro file.;
      %put ERROR: Do not copy driver programs into m_oda_ref_diag.sas (causes recursion).;
    %end;
  %end;

  %m_ensure_goldout;

  /* Drivers may call %m_oda_ref_diag again - safe. Init calls once after libname ref.
     A %include issued inside a macro is only processed once that macro returns, so on the
     first session the definition may not be compiled yet at this point - that is not an error. */
  %if %sysmacexist(m_oda_ref_diag) %then %do;
    %m_oda_ref_diag;
  %end;
  %else %if %length(&_ODA_REF_DIAG_SRC) > 0 %then %do;
    %put NOTE: M_ODA_REF_DIAG compiles when init returns - drivers run REF diagnostics themselves.;
  %end;
  %else %do;
    %put ERROR: Macro M_ODA_REF_DIAG not defined - check m_oda_ref_diag.sas contents on ODA.;
  %end;

  %put NOTE: Run archives (logs and QC copies) go to &GOLDOUT_PATH;

%mend m_init_libnames_oda;
