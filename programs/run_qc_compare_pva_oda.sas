/*--------------------------------------------------------------
  Program Name                : run_qc_compare_pva_oda.sas
  Purpose                     : Track B QC - adam.* vs ref_pva.refadsl etc (pharmaverseadam)
  Paths                       : /home/&sysuserid/... only (no HOME / no ~)
  Prerequisite                : User proc copy of ref*.xpt into validation/
                                (members REFADSL / refadsl, REFADAE / refadae, ...)
  Modification Log            : 24AUG2026 - ADVS CALLER sortkeys add ATPTN
                                (orthostatic position) + chkvars ATPT.
                                24AUG2026 - ADCM floatvars include AENDY (follows
                                AENDT PVA year-end POLICY - not a calendar date).
                                Re-upload m_qc_print_dif_pva_sas +
                                m_qc_procompare_pva: sample never prints raw
                                OUTDIF (date E). Title must say PVA over SAS.
                                24AUG2026 - Include m_qc_print_dif_pva_sas so
                                BDS/ADCM Layer-2 sample shows PVA over SAS cells
                                (not lone E). Upload that macro with procompare.
                                24AUG2026 - BDS/ADCM CALLER keys include *SEQ
                                (VSSEQ/EGSEQ/LBSEQ/CMSEQ) as final ID key - PVA
                                can repeat business keys. Matches builder PROC SORT.
                                26AUG2026 - ADEG_EG_SDTM_POLICY_V1 + ADLB HGB
                                extract_unit scan2. Fingerprint 20260826U.
                                25AUG2026 - ADLB Layer-1 chkvars include ATOXGR*
                                BTOXGR* SHIFT2 (safety tox). Omitting them made
                                Layer-1 look clean while PROC COMPARE still failed.
                                25AUG2026 - BDS CALLER keys pair on PARAMCD + DTYPE
                                (not PARAMN). Blank PARAMN after derive_param was
                                colliding rows across parameters. *SEQ is tiebreak.
                                24AUG2026 - BDS QC sortkeys use PARAMN AVISITN
                                (1:1 with PARAMCD/AVISIT on PVA gold) so pairing
                                honors display PARAMN sequence. Builder SORT is
                                USUBJID PARAMN PARAM AVISITN AVISIT ADT [ADTM] *SEQ.
                                23AUG2026 - QC macros isolated in Part B macro/:
                                m_qc_compare_pva.sas + m_qc_procompare_pva.sas
                                (DTM scale + CALLER + unequal-var). Track A
                                util/chklog/publish stay read-only. Force
                                keysrc=CALLER so adam SORTEDBY cannot override
                                OCCDS ADAE key. ADAE Layer-1 chkvars include
                                ASTTMF/AENTMF. Gold XPT *DTM DATE-scale fixed via
                                %m_qc_norm_dtm_scale. ADSL/ADAE success = PASS
                                value_diffs=0. 22AUG2026 - ADSL TRT*TMF/SAFFL,
                                ADAE ASEV/AESEQ OCCDS, gold REF* via proc copy.
--------------------------------------------------------------*/

/* Bootstrap: &sysuserid in path - no HOME needed to find macros */
%include "/home/&sysuserid/SAS_mirrored_Admiral_safety_ADaM/SAS/macro/m_get_oda_path.sas";
%include "/home/&sysuserid/SAS_mirrored_Admiral_safety_ADaM/SAS/macro/m_init_libnames_pva.sas";

%m_init_libnames_pva;

%macro _run_qc_compare_pva_oda;
  %local _rc _sms _pva QC_LOG;

  /* Part B QC macros (isolated) + Track A util/chklog/publish (read-only) */
  %let _pva = %m_get_oda_path(SAS_mirrored_Admiral_safety_ADaM/SAS);
  %let _sms = %m_get_oda_path(safety_monitoring_system/SAS);
  %if %sysfunc(fileexist(&_pva/macro/m_qc_compare_pva.sas)) = 0
      or %sysfunc(fileexist(&_pva/macro/m_qc_procompare_pva.sas)) = 0
      or %sysfunc(fileexist(&_pva/macro/m_qc_print_dif_pva_sas.sas)) = 0 %then %do;
    %put ERROR: Part B QC macros not found at &_pva/macro - upload m_qc_compare_pva.sas m_qc_procompare_pva.sas m_qc_print_dif_pva_sas.sas.;
    %return;
  %end;
  %if %sysfunc(fileexist(&_sms/macros/m_util.sas)) = 0 %then %do;
    %put ERROR: Track A util macros not found at &_sms - upload safety_monitoring_system/SAS/macros (m_util m_chklog m_oda_publish).;
    %return;
  %end;
  %put NOTE: Part B QC macros from &_pva/macro;
  %put NOTE: Track A util/chklog/publish from &_sms/macros;
  %put NOTE: ===== STACKED_DIF_FINGERPRINT=20260826U run_qc_compare_pva_oda =====;
  %put NOTE: After this run Results title must say PVA over SAS (not E). If not - macros not uploaded.;

  %include "&_sms/macros/m_util.sas";
  %include "&_sms/macros/m_chklog.sas";
  %include "&_pva/macro/m_qc_compare_pva.sas";
  %include "&_pva/macro/m_qc_print_dif_pva_sas.sas";
  %include "&_pva/macro/m_qc_procompare_pva.sas";
  %include "&_sms/macros/m_oda_publish.sas";

  %let _rc = %sysfunc(dcreate(logs, &ROOT));
  %let _rc = %sysfunc(dcreate(output, &ROOT));
  %let QC_LOG = &LOGDIR/run_qc_compare_pva_oda.log;

  %put NOTE: ===== opening PRINTTO -> &QC_LOG =====;
  filename pvaqclog "&QC_LOG";
  proc printto log=pvaqclog new;
  run;

  %put NOTE: ===== run_qc_compare_pva_oda starting (Track B / PVA) =====;
  %put NOTE: PVA gold = ref_pva.refadsl refadae refadcm refadvs refadeg refadlb;
  %put NOTE: (from proc copy of ref*.xpt - Unix ODA member names are typically lowercase);
  %put NOTE: ADTTE out of scope for Part B core safety QC.;
  %put NOTE: SUCCESS ADSL/ADAE - digest status=PASS value_diffs=0 keysrc=CALLER;
  %put NOTE: SUCCESS proof - NOTE Promoted date-scale *DTM with n_scale>0 on ref working copies;

  %if %sysfunc(exist(adam.adsl)) = 0 %then %do;
    %put ERROR: adam.adsl missing - run create_ADaM_pva_oda.sas or set ADAM_PATH.;
  %end;
  %if %sysfunc(exist(ref_pva.refadsl)) = 0 %then %do;
    %put ERROR: ref_pva.refadsl missing - proc copy validation/refadsl.xpt into validation/ first.;
  %end;

  /* Shell digests */
  data _qc_all_mis;
    length _dataset $16 _issue $40 _sas_val $200 _ref_val $200
           USUBJID $40 PARAMCD $16 AVISIT $40 AEDECOD $200 CMDECOD $200
           AESEQ VSSEQ EGSEQ CMSEQ LBSEQ ADT ASTDT _KEYSEQ 8;
    call missing(of _all_);
    stop;
  run;

  data work.qc_procompare_digest;
    length dataset $32 compare_type $16 status $8 detail $400;
    call missing(of _all_);
    stop;
  run;

  /* ---- ADSL ----
     Layer-1 chkvars include TRT*TMF (Part B root cause of prior diffs=254).
     mask_vars = SAS-only pop flags not on pharmaverseadam::adsl.
     label=ADSL (not ADSL_PVA) so POLICY / default-key token logic matches.
     keysrc=CALLER - force USUBJID even if adam SORTEDBY is STUDYID USUBJID. */
  %m_qc_one(
    sasds=adam.adsl
  , refds=ref_pva.refadsl
  , sortkeys=USUBJID
  , keysrc=CALLER
  , chkvars=STUDYID SUBJID SITEID AGE AGEU SEX RACE ARM ARMCD TRT01P TRT01A DTHFL
            SAFFL TRTSTMF TRTETMF TRTDURD
  , datevars=TRTSDT TRTEDT EOSDT RANDDT SCRFDT
  , mask_vars=ITTFL EFFFL COMPL8FL COMPL16FL COMPL24FL
  , label=ADSL
  );
  %m_qc_procompare_one(
    base=ref_pva.refadsl
  , compare=adam.adsl
  , sortkeys=USUBJID
  , keysrc=CALLER
  , label=ADSL
  );

  /* ---- ADAE (full OCCDS natural key - every row; AESEQ in key) ----
     keysrc=CALLER required: AUTO preferred stale adam SORTEDBY
     USUBJID ASTDT AEDECOD (+ AESEQ tiebreak) and digest showed METADATA
     without ASEV/AESEQ. Builder now sorts the same OCCDS key. */
  %if %sysfunc(exist(adam.adae)) and %sysfunc(exist(ref_pva.refadae)) %then %do;
    %m_qc_one(
      sasds=adam.adae
    , refds=ref_pva.refadae
    , sortkeys=USUBJID ASTDT AEDECOD ASEV AESEQ
    , keysrc=CALLER
    , chkvars=STUDYID AETERM AESOC AESEV AEREL TRTEMFL ASTTMF AENTMF
    , datevars=AENDT TRTSDT TRTEDT
    , label=ADAE
    );
    %m_qc_procompare_one(
      base=ref_pva.refadae
    , compare=adam.adae
    , sortkeys=USUBJID ASTDT AEDECOD ASEV AESEQ
    , keysrc=CALLER
    , label=ADAE
    );
  %end;

  /* ---- ADVS ----
     keysrc=CALLER - PARAMCD + AVISITN + ATPTN + DTYPE + ADT.
     PARAMCD (not PARAMN) so derived rows with blank PARAMN do not collide.
     DTYPE separates AVERAGE from observed. VSSEQ is tiebreak only.
     ATPTN separates orthostatic positions (lying / stand 1 / stand 3).
     No ADTM on PVA ADVS gold. */
  %if %sysfunc(exist(adam.advs)) and %sysfunc(exist(ref_pva.refadvs)) %then %do;
    %m_qc_one(
      sasds=adam.advs
    , refds=ref_pva.refadvs
    , sortkeys=USUBJID PARAMCD AVISITN ATPTN DTYPE ADT
    , tiebreak=VSSEQ
    , keysrc=CALLER
    , chkvars=STUDYID PARAM PARAMN VISIT AVISIT ATPT ADY AVALU ABLFL TRTA TRTP
    , datevars=TRTSDT TRTEDT
    , floatvars=AVAL BASE CHG PCHG
    , label=ADVS
    );
    %m_qc_procompare_one(
      base=ref_pva.refadvs
      , compare=adam.advs
      , sortkeys=USUBJID PARAMCD AVISITN ATPTN DTYPE ADT
      , tiebreak=VSSEQ
      , keysrc=CALLER
      , label=ADVS
    );
  %end;

  /* ---- ADEG (expect AVALU ms vs msec POLICY via Part B QC gate) ----
     keysrc=CALLER - PARAMCD + AVISITN + ATPTN + DTYPE + ADT. EGSEQ tiebreak.
     ADTM on both sides (gold may be date-scale - DTM norm). Pair on PARAMCD
     not PARAM string (apostrophes). */
  %if %sysfunc(exist(adam.adeg)) and %sysfunc(exist(ref_pva.refadeg)) %then %do;
    %m_qc_one(
      sasds=adam.adeg
    , refds=ref_pva.refadeg
    , sortkeys=USUBJID PARAMCD AVISITN ATPTN DTYPE ADT
    , tiebreak=EGSEQ
    , keysrc=CALLER
    , chkvars=STUDYID PARAM PARAMN VISIT AVISIT ATPT ADY AVALU ABLFL TRTA TRTP
    , datevars=TRTSDT TRTEDT
    , floatvars=AVAL BASE CHG PCHG
    , label=ADEG
    );
    %m_qc_procompare_one(
      base=ref_pva.refadeg
      , compare=adam.adeg
      , sortkeys=USUBJID PARAMCD AVISITN ATPTN DTYPE ADT
      , tiebreak=EGSEQ
      , keysrc=CALLER
      , label=ADEG
    );
  %end;

  /* ---- ADCM ----
     keysrc=CALLER - OCCDS business + CMSEQ in ID (not tiebreak-only).
     Prior METADATA / tiebreak-only digests orphaned same-day CM rows.
     24AUG2026: equal-n ~5454 orphans also from ASTDT gap - m_adcm_pva now
     matches admiral ad_adcm.R (DTM hi=M + TRTSDT min_dates). Rebuild adam.adcm. */
  %if %sysfunc(exist(adam.adcm)) and %sysfunc(exist(ref_pva.refadcm)) %then %do;
    %m_qc_one(
      sasds=adam.adcm
    , refds=ref_pva.refadcm
    , sortkeys=USUBJID ASTDT CMDECOD CMSEQ
    , keysrc=CALLER
    , chkvars=STUDYID CMDECOD TRTEMFL TRTA TRTP
    , datevars=AENDT TRTSDT TRTEDT
    , floatvars=DOSE AENDY
    , label=ADCM
    );
    %m_qc_procompare_one(
      base=ref_pva.refadcm
      , compare=adam.adcm
      , sortkeys=USUBJID ASTDT CMDECOD CMSEQ
      , keysrc=CALLER
      , label=ADCM
    );
  %end;

  /* ---- ADLB ----
     keysrc=CALLER - PARAMCD + AVISITN + DTYPE + ADT. LBSEQ tiebreak.
     No ATPT on ADLB template. No ADTM on PVA ADLB gold.
     Layer-1 includes ATOXGR / BTOXGR / SHIFT2 - safety-summary vars, not optional. */
  %if %sysfunc(exist(adam.adlb)) and %sysfunc(exist(ref_pva.refadlb)) %then %do;
    %m_qc_one(
      sasds=adam.adlb
    , refds=ref_pva.refadlb
    , sortkeys=USUBJID PARAMCD AVISITN DTYPE ADT
    , tiebreak=LBSEQ
    , keysrc=CALLER
    , chkvars=STUDYID PARAM PARAMN VISIT AVISIT ADY AVALU ABLFL ONTRTFL ANRIND BASEC BNRIND
              SHIFT SHIFT1 SHIFT2 ATOXDSCL ATOXDSCH ATOXGRL ATOXGRH ATOXGR
              BTOXGRL BTOXGRH BTOXGR TRTA TRTP
    , datevars=TRTSDT TRTEDT
    , floatvars=AVAL BASE CHG PCHG ANRLO ANRHI
    , label=ADLB
    );
    %m_qc_procompare_one(
      base=ref_pva.refadlb
      , compare=adam.adlb
      , sortkeys=USUBJID PARAMCD AVISITN DTYPE ADT
      , tiebreak=LBSEQ
      , keysrc=CALLER
      , label=ADLB
    );
  %end;

  title "Track B PVA QC digest (adam vs pharmaverseadam)";
  proc print data=work.qc_procompare_digest noobs; run;
  title;

  %if %sysfunc(exist(_qc_all_mis)) %then %do;
    title "Track B PVA mismatches sample";
    proc print data=_qc_all_mis(obs=40); run;
    title;
  %end;

  proc printto;
  run;

  %m_chklog(logfile=&QC_LOG, out=work.pva_log_issues, print=Y);

  %if %sysfunc(fileexist(&_sms/macros/m_oda_publish.sas)) %then %do;
    %m_oda_publish(
      runtag=qc_pva
    , logfile=&QC_LOG
    );
  %end;

  %put NOTE: ===== run_qc_compare_pva_oda done =====;
%mend _run_qc_compare_pva_oda;

%_run_qc_compare_pva_oda;
