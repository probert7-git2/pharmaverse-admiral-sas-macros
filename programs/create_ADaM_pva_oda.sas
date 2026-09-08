/*--------------------------------------------------------------
  Program Name                : create_ADaM_pva_oda.sas
  Purpose                     : Part B ADaM build into this repo adam/ (ODA)
  Paths                       : /home/&sysuserid/... only (no HOME / no ~)
  Output                      : Part B adam.adsl adam.adae adam.qc_sdtm_issues
                                adam.advs adam.adeg adam.adcm adam.adlb (when SDTM present)
  SDTM                        : READ-ONLY from Track A
                                /home/&sysuserid/safety_monitoring_system/SAS/sdtm
  Builders                    : Part B SAS/macro/*_pva.sas (m_adsl_pva m_ex_single_pva
                                m_adae_pva m_qc_sdtm_issues_pva m_adcm_pva).
                                Defaults: ADEG/ADVS/ADLB = %m_*_admiral_mirror (1:1 R).
                                Legacy *_pva if ADEG_BUILDER/ADVS_BUILDER/ADLB_BUILDER=pva.
  Derive ports                : READ-ONLY %include from Track A macros/ until copied
  Scope                       : ADSL ADAE + BDS wave (ADVS ADEG ADCM ADLB); no ADTTE
  Modification Log            : 24AUG2026 - Include m_order_vars_like_ref for
                                PVA REF column presentation order on all ADaMs.
                                24AUG2026 - BDS wave: ADVS ADEG ADCM ADLB builders
                                when raw.vs/eg/cm/lb exist. Derive ports m_derive_var_base
                                m_derive_param_computed (MAP/BMI/BSA) m_derive_var_atoxgr.
                                24AUG2026 - Pass refadae/refadcm to
                                %m_qc_sdtm_issues_pva (SDTM + ADAM SOURCE
                                including PVA *DTM collapse and ADCM AENDT
                                year-end-without-EOS catalog).
                                23AUG2026 - Skip %m_qc_sdtm_issues_pva when
                                macro file missing on ODA (WARNING, ADSL/ADAE still build).
                                23AUG2026 - Include %m_ex_single_pva (called
                                inside %m_adae_pva for daily EX / LDOSE).
                                22AUG2026 - Call %m_qc_sdtm_issues_pva after ADAE
                                (informational SDTM incoming-issue QC).
                                22AUG2026 - Wire %m_adae_pva after ADSL.
                                22AUG2026 - Initial Part B create driver + %m_adsl_pva.
                                25AUG2026 - ADEG: default %m_adeg_admiral_mirror
                                (pure ad_adeg.R 1:1). Set ADEG_BUILDER=pva for
                                legacy %m_adeg_pva. Legacy file left intact.
                                25AUG2026 - ADVS/ADLB: default admiral mirrors
                                (ad_advs.R / ad_adlb.R 1:1). Set ADVS_BUILDER
                                or ADLB_BUILDER=pva for legacy *_pva.
                                25AUG2026 - Force mirror defaults each submit
                                (clears leftover session *_BUILDER=pva).
                                Stamp CREATE_PVA_STAMP=20260826W in the log
                                (ADSL LSTALVDT from AE/LB/TRTEDT, ADCM drop
                                TRTEMFL, ADLB drop AVALU).
                                26AUG2026 - After builders, include
                                run_traceability_pva_oda (Layer 3
                                as-programmed vs admiral template steps).
--------------------------------------------------------------*/

/* 1:1 Admiral mirrors are the default every submit.
   Leftover *_BUILDER=pva from an earlier ODA session is cleared here.
   For legacy approximate builders, change these three %lets to pva. */
%global ADEG_BUILDER ADVS_BUILDER ADLB_BUILDER;
%let ADEG_BUILDER = mirror;
%let ADVS_BUILDER = mirror;
%let ADLB_BUILDER = mirror;

/* Bootstrap: &sysuserid in path - no HOME / no ~ */
%include "/home/&sysuserid/SAS_mirrored_Admiral_safety_ADaM/SAS/macro/m_get_oda_path.sas";
%include "/home/&sysuserid/SAS_mirrored_Admiral_safety_ADaM/SAS/macro/m_init_libnames_pva.sas";

%m_init_libnames_pva;

%macro _create_adam_pva_oda;
  %local _rc _sms _partb ADAM_LOG _have_qc;
  %local _ds _suppdm _dd _suppae _ae _lb;

  /* Builders already set at driver top (mirror unless those %lets were edited). */

  %let _partb = %m_get_oda_path(SAS_mirrored_Admiral_safety_ADaM/SAS);
  %let _sms   = %m_get_oda_path(safety_monitoring_system/SAS);

  /* Part B adam/ under this tree (never Track A adam) */
  %let ADAM_PATH = &_partb/adam;
  %let _rc = %sysfunc(dcreate(adam, &_partb));
  %let _rc = %sysfunc(dcreate(logs, &_partb));
  libname adam "&ADAM_PATH";

  /* SDTM: read-only from Track A sdtm/ (XPTs already converted there) */
  %if %sysfunc(fileexist(&_sms/sdtm)) = 0 %then %do;
    %put ERROR: Track A SDTM folder missing at &_sms/sdtm - upload safety_monitoring_system/SAS/sdtm.;
    %return;
  %end;
  libname raw "&_sms/sdtm" access=readonly;
  %put NOTE: Part B adam writes to %sysfunc(pathname(adam));
  %put NOTE: Part B SDTM reads (readonly) from %sysfunc(pathname(raw));

  /* Shared derive / util ports from Track A - READ ONLY shared until copied to Part B */
  %if %sysfunc(fileexist(&_sms/macros/m_util.sas)) = 0 %then %do;
    %put ERROR: Track A macros not found at &_sms/macros - upload safety_monitoring_system/SAS/macros.;
    %return;
  %end;
  %put NOTE: Derive ports included READ-ONLY from Track A &_sms/macros;
  %include "&_sms/macros/m_util.sas";
  %include "&_sms/macros/m_chklog.sas";
  %include "&_sms/macros/m_derive_vars_joined.sas";
  %include "&_sms/macros/m_derive_vars_dt.sas";
  %include "&_sms/macros/m_derive_vars_dtm.sas";
  %include "&_sms/macros/m_derive_vars_dy.sas";
  %include "&_sms/macros/m_derive_vars_merged.sas";
  %include "&_sms/macros/m_derive_var_extreme.sas";
  %include "&_sms/macros/m_derive_var_trtemfl.sas";
  %include "&_sms/macros/m_derive_var_base.sas";
  %include "&_sms/macros/m_derive_param_computed.sas";
  %include "&_sms/macros/m_derive_var_atoxgr.sas";
  %include "&_sms/macros/m_supp_util.sas";
  %include "&_sms/macros/m_derive_vars_query.sas";

  /* Part B builders (local *_pva - edit here, not Track A) */
  %include "&_partb/macro/m_order_vars_like_ref.sas";
  %include "&_partb/macro/m_adsl_pva.sas";
  %include "&_partb/macro/m_ex_single_pva.sas";
  %include "&_partb/macro/m_adae_pva.sas";
  %include "&_partb/macro/m_advs_pva.sas";
  %include "&_partb/macro/m_adeg_pva.sas";
  %if %sysfunc(fileexist(&_partb/macro/admiral/m_adm_advs_ports.sas)) = 0
      or %sysfunc(fileexist(&_partb/macro/m_advs_admiral_mirror.sas)) = 0
      or %sysfunc(fileexist(&_partb/macro/m_adlb_admiral_mirror.sas)) = 0 %then %do;
    %put ERROR: Admiral 1:1 files missing - upload SAS/macro/admiral/ and m_advs_admiral_mirror.sas m_adlb_admiral_mirror.sas.;
    %return;
  %end;
  %include "&_partb/macro/admiral/m_adm_adeg_ports.sas";
  %include "&_partb/macro/admiral/m_adm_common_ports.sas";
  %include "&_partb/macro/admiral/m_adm_advs_ports.sas";
  %include "&_partb/macro/admiral/m_adm_adlb_ports.sas";
  %include "&_partb/macro/m_adeg_admiral_mirror.sas";
  %include "&_partb/macro/m_advs_admiral_mirror.sas";
  %include "&_partb/macro/m_adlb_admiral_mirror.sas";
  %include "&_partb/macro/m_adcm_pva.sas";
  %include "&_partb/macro/m_adlb_pva.sas";

  /* QC macro optional on ODA - skip if not uploaded yet */
  %let _have_qc = 0;
  %if %sysfunc(fileexist(&_partb/macro/m_qc_sdtm_issues_pva.sas)) %then %do;
    %include "&_partb/macro/m_qc_sdtm_issues_pva.sas";
    %let _have_qc = 1;
  %end;
  %else %do;
    %put WARNING: m_qc_sdtm_issues_pva.sas not found - skipping adam.qc_sdtm_issues;
  %end;

  %let ADAM_LOG = &LOGDIR/create_ADaM_pva_oda.log;
  %put NOTE: ===== opening PRINTTO -> &ADAM_LOG =====;
  filename adampva "&ADAM_LOG";
  proc printto log=adampva new;
  run;

  %put NOTE: ===== create_ADaM_pva_oda starting (Part B) =====;
  %put NOTE: CREATE_PVA_STAMP=20260826W ADEG_BUILDER=&ADEG_BUILDER ADVS_BUILDER=&ADVS_BUILDER ADLB_BUILDER=&ADLB_BUILDER.;

  %if %sysfunc(exist(raw.dm)) = 0 %then %do;
    %put ERROR: raw.dm missing - convert SDTM under Track A sdtm/ before running.;
  %end;
  %if %sysfunc(exist(raw.ex)) = 0 %then %do;
    %put ERROR: raw.ex missing - convert SDTM under Track A sdtm/ before running.;
  %end;

  %let _ds     =;
  %let _suppdm =;
  %let _dd     =;
  %let _suppae =;
  %let _ae     =;
  %let _lb     =;
  %if %sysfunc(exist(raw.ds))     %then %do;  %let _ds = raw.ds;          %end;
  %if %sysfunc(exist(raw.suppdm)) %then %do;  %let _suppdm = raw.suppdm;  %end;
  %if %sysfunc(exist(raw.dd))     %then %do;  %let _dd = raw.dd;          %end;
  %if %sysfunc(exist(raw.suppae)) %then %do;  %let _suppae = raw.suppae;  %end;
  %if %sysfunc(exist(raw.ae))     %then %do;  %let _ae = raw.ae;          %end;
  %if %sysfunc(exist(raw.lb))     %then %do;  %let _lb = raw.lb;          %end;

  %if %sysfunc(exist(raw.ae)) = 0 %then %do;
    %put ERROR: raw.ae missing - convert SDTM under Track A sdtm/ before ADAE.;
  %end;

  /* ---- ADSL (Part B local %m_adsl_pva) ---- */
  %m_adsl_pva(
           dm     = raw.dm
         , ex     = raw.ex
         , ds     = &_ds
         , ae     = &_ae
         , lb     = &_lb
         , suppdm = &_suppdm
         , dd     = &_dd
         , out    = adam.adsl
        );

  /* ---- ADAE (Part B local %m_adae_pva) ---- */
  %m_adae_pva(
           ae     = raw.ae
         , ex     = raw.ex
         , adsl   = adam.adsl
         , suppae = &_suppae
         , out    = adam.adae
         , end_window=30
         , derive_aesi=N
        );

  /* ---- Data issues QC (SDTM AE + ADAM gold quirks - informational) ---- */
  %if &_have_qc %then %do;
    %m_qc_sdtm_issues_pva(
             ae      = raw.ae
           , refadae = ref_pva.refadae
           , refadcm = ref_pva.refadcm
           , out     = adam.qc_sdtm_issues
          );
  %end;

  /* ---- BDS wave (when SDTM domains present) ---- */
  %if %sysfunc(exist(raw.vs)) %then %do;
    /* Default: pure ad_advs.R 1:1 mirror. Legacy: %let ADVS_BUILDER=pva; */
    %if %upcase(&ADVS_BUILDER) = PVA %then %do;
      %put NOTE: ADVS builder = legacy m_advs_pva.;
      %m_advs_pva(vs=raw.vs, adsl=adam.adsl, out=adam.advs);
    %end;
    %else %do;
      %put NOTE: ADVS builder = m_advs_admiral_mirror (ad_advs.R 1:1).;
      %m_advs_admiral_mirror(vs=raw.vs, adsl=adam.adsl, out=adam.advs);
    %end;
  %end;
  %if %sysfunc(exist(raw.eg)) %then %do;
    /* Default: pure ad_adeg.R 1:1 mirror. Legacy: %let ADEG_BUILDER=pva; */
    %if %upcase(&ADEG_BUILDER) = PVA %then %do;
      %put NOTE: ADEG builder = legacy m_adeg_pva.;
      %m_adeg_pva(eg=raw.eg, adsl=adam.adsl, out=adam.adeg);
    %end;
    %else %do;
      %put NOTE: ADEG builder = m_adeg_admiral_mirror (ad_adeg.R 1:1).;
      %m_adeg_admiral_mirror(eg=raw.eg, adsl=adam.adsl, out=adam.adeg);
    %end;
  %end;
  %if %sysfunc(exist(raw.cm)) %then %do;
    %m_adcm_pva(cm=raw.cm, adsl=adam.adsl, out=adam.adcm);
  %end;
  %if %sysfunc(exist(raw.lb)) %then %do;
    /* Default: pure ad_adlb.R 1:1 mirror. Legacy: %let ADLB_BUILDER=pva; */
    %if %upcase(&ADLB_BUILDER) = PVA %then %do;
      %put NOTE: ADLB builder = legacy m_adlb_pva.;
      %m_adlb_pva(lb=raw.lb, adsl=adam.adsl, out=adam.adlb);
    %end;
    %else %do;
      %put NOTE: ADLB builder = m_adlb_admiral_mirror (ad_adlb.R 1:1).;
      %m_adlb_admiral_mirror(lb=raw.lb, adsl=adam.adsl, out=adam.adlb);
    %end;
  %end;

  %put NOTE: ADTTE out of scope for Part B core safety QC.;

  proc printto;
  run;

  %m_chklog(logfile=&ADAM_LOG, out=work.adam_log_issues, print=Y);

  /* Layer 3 - as-programmed traceability after Create ADaM */
  %if %sysfunc(fileexist(&_partb/programs/run_traceability_pva_oda.sas)) %then %do;
    %put NOTE: Layer 3 traceability - including run_traceability_pva_oda.sas.;
    %include "&_partb/programs/run_traceability_pva_oda.sas";
  %end;
  %else %do;
    %put WARNING: run_traceability_pva_oda.sas not found - skipping Layer 3.;
  %end;

  %if &_have_qc %then %do;
    %put NOTE: ===== create_ADaM_pva_oda done - adam.adsl adam.adae adam.qc_sdtm_issues + BDS when SDTM present =====;
  %end;
  %else %do;
    %put NOTE: ===== create_ADaM_pva_oda done - adam.adsl adam.adae + BDS when SDTM present (qc_sdtm_issues skipped) =====;
  %end;
%mend _create_adam_pva_oda;

%_create_adam_pva_oda;