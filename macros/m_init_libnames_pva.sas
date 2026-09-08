/*--------------------------------------------------------------
  Program Name                : m_init_libnames_pva.sas
  Purpose                     : Libnames for Track B (Pharmaverseadam gold QC)
  Note                        : Default ADAM_PATH = Part B adam/ under this tree.
                                Build via programs/create_ADaM_pva_oda.sas.
                                ref_pva = validation/ - gold members from user
                                proc copy of ref*.xpt: REFADSL REFADAE REFADCM
                                REFADVS REFADEG REFADLB (Unix: often lowercase
                                refadsl etc). Keep the XPT files - they are the
                                transport source - do not require a convert program.
  Paths                       : /home/&sysuserid/... only (no HOME / no ~)
  Modification Log            : 22AUG2026 - Own metadata.supp_qnam_ct (Part B copy).
                                22AUG2026 - Default ADAM_PATH to Part B adam/.
                                22AUG2026 - Simplified to m_get_oda_path only.
                                22AUG2026 - Document REF* gold members / proc copy.
--------------------------------------------------------------*/

%macro m_init_libnames_pva;

  %global ROOT ODA_BASE OUTDIR LOGDIR ADAM_PATH PVA_REFDIR PVA_SAS_ROOT;
  %local _rc;

  /* Require m_get_oda_path (include macro/m_get_oda_path.sas first) */
  %if %sysmacexist(m_get_oda_path) = 0 %then %do;
    %include "/home/&sysuserid/SAS_mirrored_Admiral_safety_ADaM/SAS/macro/m_get_oda_path.sas";
  %end;

  %let ODA_BASE = /home/&sysuserid;

  %if %length(%superq(PVA_SAS_ROOT)) = 0 %then %do;
    %let PVA_SAS_ROOT = %m_get_oda_path(SAS_mirrored_Admiral_safety_ADaM/SAS);
  %end;

  %let ROOT       = &PVA_SAS_ROOT;
  %let LOGDIR     = &ROOT/logs;
  %let OUTDIR     = &ROOT/output;
  %let PVA_REFDIR = &ROOT/validation;

  /* Default: Part B adam/ (sibling under Part B SAS root) - not Track A */
  %if %length(&ADAM_PATH) = 0 %then %do;
    %let ADAM_PATH = &ROOT/adam;
  %end;

  %let _rc = %sysfunc(dcreate(logs, &ROOT));
  %let _rc = %sysfunc(dcreate(output, &ROOT));
  %let _rc = %sysfunc(dcreate(validation, &ROOT));
  %let _rc = %sysfunc(dcreate(adam, &ROOT));
  %let _rc = %sysfunc(dcreate(metadata, &ROOT));

  libname adam     "&ADAM_PATH";
  libname ref_pva  "&PVA_REFDIR";
  libname metadata "&ROOT/metadata";

  /* SUPP QNAM CT - Part B owns a copy under SAS/metadata/ (not Track A) */
  %if %sysfunc(fileexist(&ROOT/metadata/supp_qnam_ct.sas)) %then %do;
    %include "&ROOT/metadata/supp_qnam_ct.sas";
  %end;
  %if %sysfunc(fileexist(&ROOT/metadata/supp_qnam_ct.sas)) = 0 %then %do;
    %put ERROR: Missing &ROOT/metadata/supp_qnam_ct.sas;
    %put ERROR: Upload SAS/metadata/supp_qnam_ct.sas to ODA then re-run init and create.;
  %end;
  %if %sysfunc(exist(metadata.supp_qnam_ct)) = 0 %then %do;
    %put ERROR: metadata.supp_qnam_ct was not created - SUPP flag merges will soft-fail.;
  %end;

  %put NOTE: ===== PVA Track B library paths =====;
  %put NOTE: SYSUSERID=&sysuserid;
  %put NOTE: ODA_BASE=&ODA_BASE;
  %put NOTE: PVA_SAS_ROOT=&PVA_SAS_ROOT;
  %put NOTE: ROOT=&ROOT;
  %put NOTE: adam path=%sysfunc(pathname(adam));
  %put NOTE: ref_pva path=%sysfunc(pathname(ref_pva));
  %put NOTE: metadata path=%sysfunc(pathname(metadata));
  %put NOTE: metadata.supp_qnam_ct exists? %sysfunc(exist(metadata.supp_qnam_ct));
  %put NOTE: gold members REFADSL REFADAE REFADCM REFADVS REFADEG REFADLB (or lowercase);
  %put NOTE: OUTDIR=&OUTDIR LOGDIR=&LOGDIR;

  %if %sysfunc(exist(adam.adsl)) = 0 %then %do;
    %put WARNING: adam.adsl not found - run programs/create_ADaM_pva_oda.sas first;
    %put WARNING: or set ADAM_PATH= to your Part B adam folder.;
  %end;
  %if %sysfunc(exist(ref_pva.refadsl)) = 0 %then %do;
    %put WARNING: ref_pva.refadsl not found - proc copy ref*.xpt into validation/ first.;
  %end;

%mend m_init_libnames_pva;
