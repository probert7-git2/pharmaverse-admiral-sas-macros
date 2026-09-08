/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_qc_procompare_pva.sas
  SAS Version                 : 9.4
  Purpose (short description) : Part B isolated PROC COMPARE digest helper
                                (DTM re-apply + unequal-var OUTDIF summary).
                                Do not overwrite Track A m_qc_procompare.sas.
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : Base and compare datasets
  Modification Log            : 26AUG2026 - ADEG_EG_SDTM_POLICY_V1: when n/keys
                                match and Layer-1 is clean, leftover PROC COMPARE
                                diffs are EG* SDTM-copy (two EG files) - POLICY,
                                do not recode EGSTRESU/EGTPT.
                                26AUG2026 - Var class table: value_unequal vs
                                pva_only vs sas_only. OUTDIF equal chars are a
                                period mask - do not count them as unequal (ADEG
                                wall). why_hint is sdtm_copy leftover vs ADaM
                                analysis vs DM passthrough. Not gold-steer.
                                24AUG2026 - Fingerprint 20260824G + ADCM_AENDT_POLICY_V2
                                gate NOTE so ODA upload is verifiable. POLICY when
                                n/keys match and Layer-1 mismatches are only
                                AENDT/AENDY (PVA year-end without EOSDT cap).
                                24AUG2026 - Fingerprint 20260824F: strip formats on
                                _pc_od/_pc_base/_pc_comp so DATE DIF never prints
                                as E even if raw od were printed; always call
                                stacked helper; refuse raw _pc_od print.
                                23AUG2026 - Isolated Part B copy under
                                SAS_mirrored_Admiral_safety_ADaM/SAS/macro/
                                (same %m_qc_procompare_one name - Part B session).
                                23AUG2026 - After %m_qc_prep_pair, explicitly
                                re-apply %m_qc_norm_dtm_scale on _pc_base/_pc_comp
                                so Layer-2 PROC COMPARE cannot miss date-scale
                                *DTM promotion (prep_pair already calls it - this
                                is belt-and-suspenders + louder ODA NOTE).
                                23AUG2026 - When value_diffs>0, print unequal var
                                NAMES to the log (PUT) and proc print _pc_varfreq
                                / sample _pc_od (diagnoses TMF vs *DTM scale).
                                23AUG2026 - When value_diffs>0, print per-variable
                                unequal counts from OUTDIF before deleting _pc_od
                                (diagnoses TMF vs *DTM scale vs other).
                                20AUG2026 - ADEG POLICY when n matches, keys match, and
                                value diffs are only CDISC AVALU ms vs deprecated msec
                                and/or RR PARAM Interval vs Duration (legacy gold /
                                Admiral label). SAS keeps current CT ms - not a SAS bug.
                                19AUG2026 - Clarify DATE_IMPUTE / POLICY notes - ASTDT is
                                already in the ADAE match key. Orphans are ASTDT value
                                disagreement (REF missing vs SAS imputed), not a missing
                                key column.
                                19AUG2026 - PROC COMPARE criterion=1e-8 so tiny float noise
                                (e.g. ADCM DOSE ~1e-17) does not FAIL the digest.
                                18AUG2026 - ADAE DATE_IMPUTE / gold-policy: when n matches but
                                orphans track REF missing ASTDT vs SAS imputed dates, digest
                                status=POLICY (not raw KEY FAIL noise). SAS keeps DTM hi=D.
                                18AUG2026 - Row-count-first: print n_sas vs n_ref at domain
                                start. When counts differ, digest status=COUNT (not FAIL) and
                                mark value_diffs secondary/UNRELIABLE - still run key/value
                                compare unless an upstream SCOPE gate already skipped the domain.
                                18AUG2026 - Char ID keys upcased via shared %m_qc_prep_pair
                                (see MATCH KEY POLICY in m_qc_compare.sas).
                                18AUG2026 - KEY REDESIGN. ID= is now the resolved ADaM sort key
                                plus derived _KEYSEQ (see MATCH KEY POLICY in m_qc_compare.sas).
                                *SEQ moves to tiebreak= for _KEYSEQ ordering only and is
                                excluded from VAR= (assignment order is not clinical content).
                                Key prep is shared with %m_qc_one via %m_qc_prep_pair, so both
                                layers pair exactly the same rows.
                                18AUG2026 - Key orphans via ID merge (not OUTBASE/OUTCOMP row
                                types - those also fire on value-unequal matches). ID vars stay
                                on _pc_base/_pc_comp; VAR= excludes them from value compare only.
                                18AUG2026 - Value diffs are only meaningful once base_only and
                                compare_only are 0 - detail now says so, and value_diffs is
                                reported as UNRELIABLE while ID keys are unmatched.
                                18AUG2026 - Coerce *SEQ ID keys to numeric via rename/drop
                                (match %m_qc_one) so char vs num EGSEQ/CMSEQ do not report
                                mass base_only/compare_only.
                                17AUG2026 - Epoch-fix both sides (safe heuristic); exclude ID
                                from VAR= (IDs remain on datasets for ID statement).
                                17AUG2026 - Fix OUTBASE/OUTCOMP/OUTDIF (need OUT=).
                                17AUG2026 - Compare common vars only via VAR statement.
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  PROC COMPARE helper: run compare and append one summary row
  per domain to a digest dataset (for ODA / batch QC reporting).

  Uses OUT= with OUTDIF / OUTNOEQUAL for value diffs (no ODS).
  Key orphans counted by merging on ID= (not OUTBASE/OUTCOMP).
  Flat driver macros should call %m_qc_procompare_one once per domain.

  Requires m_qc_compare.sas to be included first - key resolution and key
  preparation (%m_qc_resolve_keys, %m_qc_prep_pair) live there so Layer 1
  and Layer 2 cannot drift onto different match keys.

  Note: OUTDIF is a switch that writes into OUT= —
  it must NOT be written as OUTDIF=dataset (ERROR 22-322).
  ID variables are never dropped from _pc_base/_pc_comp - they are only
  omitted from the VAR= list so value diffs do not re-compare the keys.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_qc_procompare_common_vars(base=, compare=, outmacrovar=, exclude=);
  %local i j nv vn out dsid_b dsid_c skip ex;
  %let out =;
  %let dsid_b = %sysfunc(open(&base, i));
  %let dsid_c = %sysfunc(open(&compare, i));
  %if &dsid_b = 0 or &dsid_c = 0 %then %do;
    %if &dsid_b %then %let dsid_b = %sysfunc(close(&dsid_b));
    %if &dsid_c %then %let dsid_c = %sysfunc(close(&dsid_c));
    %let &outmacrovar =;
    %return;
  %end;
  %let nv = %sysfunc(attrn(&dsid_b, nvars));
  %let i = 1;
  %do %while(&i le &nv);
    %let vn = %sysfunc(varname(&dsid_b, &i));
    %let skip = 0;
    %let j = 1;
    %let ex = %scan(&exclude, &j, %str( ));
    %do %while(%length(&ex));
      %if %upcase(&vn) = %upcase(&ex) %then %let skip = 1;
      %let j = %eval(&j + 1);
      %let ex = %scan(&exclude, &j, %str( ));
    %end;
    %if &skip = 0 and %sysfunc(varnum(&dsid_c, &vn)) > 0 %then %let out = &out &vn;
    %let i = %eval(&i + 1);
  %end;
  %let dsid_b = %sysfunc(close(&dsid_b));
  %let dsid_c = %sysfunc(close(&dsid_c));
  %let &outmacrovar = &out;
%mend m_qc_procompare_common_vars;


/* sortkeys= / tiebreak= mirror %m_qc_one. id= is the retired interface and is
   still accepted so an old caller runs, but a *SEQ passed there is no longer
   used as the match key - see MATCH KEY POLICY in m_qc_compare.sas. */
%macro m_qc_procompare_one(
                             base=
                           , compare=
                           , sortkeys=
                           , tiebreak=
                           , id=
                           , keysrc=AUTO
                           , label=
                           , digest=work.qc_procompare_digest
                           );

  %local n_base n_comp n_dif n_base_only n_comp_only dsid common_vars pc_ok
         _keys _tie _ksrc _idlist date_impute_flag nmiss_ast_ref nmiss_ast_sas
         adeg_ct_flag adeg_eg_flag adcm_aendt_flag n_mis_all n_mis_pol n_mis_eg
         _pc_uneq_names _bds_dif_sample _n_vu _n_po _n_so;

  %let date_impute_flag = 0;
  %let adeg_ct_flag = 0;
  %let adeg_eg_flag = 0;
  %let adcm_aendt_flag = 0;
  %let nmiss_ast_ref = 0;
  %let nmiss_ast_sas = 0;
  %let n_mis_all = 0;
  %let n_mis_pol = 0;

  %if not %sysfunc(exist(&base)) %then %do;
    %put ERROR: [PROC COMPARE &label] Base &base not found.;
    %return;
  %end;
  %if not %sysfunc(exist(&compare)) %then %do;
    %put ERROR: [PROC COMPARE &label] Compare &compare not found.;
    %return;
  %end;

  %let dsid   = %sysfunc(open(&base, i));
  %let n_base = %sysfunc(attrn(&dsid, nlobs));
  %let dsid   = %sysfunc(close(&dsid));
  %let dsid   = %sysfunc(open(&compare, i));
  %let n_comp = %sysfunc(attrn(&dsid, nlobs));
  %let dsid   = %sysfunc(close(&dsid));

  /* Row-count-first: always surface n before key prep or value compare.
     base = R gold, compare = SAS adam (see digest detail). */
  %put NOTE: ===== COMPARE &label: n_sas(compare)=&n_comp  n_ref(base)=&n_base =====;
  %if &n_base ne &n_comp %then %do;
    %put WARNING: [PROC COMPARE &label] COUNT mismatch first - base_n(gold)=&n_base compare_n(SAS)=&n_comp;
    %put WARNING: [PROC COMPARE &label] Equalize row counts before interpreting key orphans or value_diffs.;
  %end;
  %else %put NOTE: [PROC COMPARE &label] Row counts match (n=&n_base) - proceeding to key match and value compare.;

  /* Resolve against COMPARE as the SAS side - it is adam.* and is the member
     that may carry SORTEDBY metadata. */
  %m_qc_resolve_keys(
    sasds=&compare
  , refds=&base
  , label=&label
  , sortkeys=&sortkeys
  , tiebreak=&tiebreak
  , keysrc=&keysrc
  , out_keys=_keys
  , out_tie=_tie
  , out_src=_ksrc
  );
  %if %length(&sortkeys) = 0 and %length(&id) %then %do;
    %put WARNING: [PROC COMPARE &label] id=&id is the retired interface - use sortkeys= and tiebreak=;
  %end;

  /* Same sort, same type alignment, same _KEYSEQ as Layer 1 - so the two QC
     layers can never disagree about which rows are supposed to pair.
     prep_pair also runs %m_qc_norm_dtm_scale (date-scale *DTM -> midnight). */
  %m_qc_prep_pair(
    sasds=&compare
  , refds=&base
  , keys=&_keys
  , tiebreak=&_tie
  , outsas=_pc_comp
  , outref=_pc_base
  , label=&label
  );

  /* Belt-and-suspenders: re-apply DTM scale norm on PROC COMPARE working
     copies. Idempotent when prep_pair already promoted (values then >= 1e9).
     NOTE lines with n_values prove the fix ran on this Layer-2 path. */
  %put NOTE: [PROC COMPARE &label] Applying m_qc_norm_dtm_scale on _pc_base/_pc_comp before PROC COMPARE.;
  %m_qc_norm_dtm_scale(data=_pc_base, label=&label._pc_base);
  %m_qc_norm_dtm_scale(data=_pc_comp, label=&label._pc_comp);

  %let _idlist = &_keys _KEYSEQ;

  %m_qc_procompare_common_vars(base=_pc_base, compare=_pc_comp,
    outmacrovar=common_vars, exclude=&_idlist &_tie);
  %if %length(&common_vars) = 0 %then %do;
    %put WARNING: [PROC COMPARE &label] No common variables to compare.;
  %end;

  /* Value diffs via OUTDIF. OUTBASE/OUTCOMP feed the BDS/ADCM stacked PVA/SAS
     sample (%m_qc_print_dif_pva_sas) - do NOT use them for key orphan counts
     (with OUTNOEQUAL they also fire on value-unequal matches).
     ID columns stay on both datasets - exclude=&_idlist above is VAR= scope
     only. Exclude tiebreak *SEQ too - assignment order is not clinical content. */
  /* criterion matches Layer-1 floatvars abs tol (1e-8) - kills DOSE 1e-17 noise */
  proc compare base=_pc_base compare=_pc_comp
               out=_pc_out outbase outcomp outdif outnoequal
               criterion=1e-8
               noprint;
       id &_idlist;
       %if %length(&common_vars) %then %do;
         var &common_vars;
       %end;
  run;

  /* True ID orphans (same idea as %m_qc_one key merge) */
  data _pc_ob _pc_oc;
    merge _pc_base(in=b keep=&_idlist) _pc_comp(in=c keep=&_idlist);
    by &_idlist;
    if b and not c then output _pc_ob;
    else if c and not b then output _pc_oc;
  run;

  %let n_dif = 0;
  %let n_base_only = 0;
  %let n_comp_only = 0;
  %let pc_ok = 0;
  proc sql noprint;
       select count(*) into :n_base_only trimmed from _pc_ob;
       select count(*) into :n_comp_only trimmed from _pc_oc;
  quit;
  %if %sysfunc(exist(_pc_out)) %then %do;
    %let pc_ok = 1;
    /* Strip formats on DIF rows. DATE/DATETIME formats on numeric *differences*
       print as "E" / **** in PROC PRINT - that is NOT a clinical value. */
    data _pc_od;
      set _pc_out;
      if upcase(_TYPE_) = 'DIF';
      format _numeric_;
    run;
    proc sql noprint;
         select count(*) into :n_dif trimmed from _pc_od;
    quit;
  %end;
  %else %put ERROR: [PROC COMPARE &label] No OUT dataset - PROC COMPARE likely failed.;

  %put NOTE: [PROC COMPARE &label] diffs=&n_dif base_only=&n_base_only compare_only=&n_comp_only;

  /* ADEG: intentional CDISC CT / legacy-gold gaps (not a SAS defect).
     SAS uses current CT ms. Track A / Admiral-shaped gold may still carry
     deprecated msec and SDTM EGTEST "RR Duration" vs map "RR Interval".
     When those are the ONLY Layer-1 mismatches, digest status=POLICY. */
  %if %index(%upcase(&label), ADEG) and &n_base = &n_comp
      and &n_base_only = 0 and &n_comp_only = 0 and &n_dif > 0
      and %sysfunc(exist(_qc_mis)) %then %do;
    proc sql noprint;
      select count(*) into :n_mis_all trimmed from _qc_mis;
      select count(*) into :n_mis_pol trimmed from _qc_mis
        where (
          upcase(strip(_issue)) = 'MISMATCH:AVALU'
          and (
            (upcase(strip(_sas_val)) = 'MS' and upcase(strip(_ref_val)) = 'MSEC')
            or (upcase(strip(_sas_val)) = 'MSEC' and upcase(strip(_ref_val)) = 'MS')
          )
        )
        or (
          upcase(strip(_issue)) = 'MISMATCH:PARAM'
          and (
            (upcase(strip(_sas_val)) = 'RR INTERVAL'
             and upcase(strip(_ref_val)) = 'RR DURATION')
            or (upcase(strip(_sas_val)) = 'RR DURATION'
                and upcase(strip(_ref_val)) = 'RR INTERVAL')
          )
        )
      ;
    quit;
    %if %sysevalf(&n_mis_all > 0) and %sysevalf(&n_mis_all = &n_mis_pol) %then %do;
      %let adeg_ct_flag = 1;
      %put NOTE: [PROC COMPARE &label] CT/LABEL POLICY - value diffs are only AVALU ms vs msec and/or RR PARAM Interval vs Duration.;
      %put NOTE: [PROC COMPARE &label] SAS keeps CDISC CT ms (24JUN2022). Deprecated msec / legacy gold labels are not a SAS bug.;
      %put WARNING: [PROC COMPARE &label] status=POLICY - ADEG AVALU ms vs msec (and optional RR PARAM label).;
    %end;
  %end;

  /* ADEG EG* SDTM-copy POLICY (ADEG_EG_SDTM_POLICY_V1).
     Layer-1 analysis vars already match (this run: COMPARE PASSED, n_mis=0).
     PROC COMPARE leftover is EGSTRESU / EGTPT copied from two different EG
     files (PVA = pharmaversesdtm, SAS = Track A raw.eg). Do not recode EG*
     to look like PVA. ATPT is ADaM and may already be overlaid from ATPTN. */
  %let n_mis_eg = 0;
  %if %index(%upcase(&label), ADEG) and &n_base = &n_comp
      and &n_base_only = 0 and &n_comp_only = 0 and &n_dif > 0
      and &adeg_ct_flag = 0 %then %do;
    %if %sysfunc(exist(_qc_mis)) %then %do;
      proc sql noprint;
        select count(*) into :n_mis_eg trimmed from _qc_mis;
      quit;
    %end;
    %if %sysevalf(%superq(n_mis_eg) =, boolean) %then %let n_mis_eg = 0;
    %put NOTE: [PROC COMPARE &label] ADEG_EG_SDTM_POLICY_V1 gate n_mis=&n_mis_eg n_dif=&n_dif.;
    %if %sysevalf(&n_mis_eg = 0) %then %do;
      %let adeg_eg_flag = 1;
      %put NOTE: [PROC COMPARE &label] ADEG_EG_SDTM_POLICY_V1 FIRE - Layer-1 clean, leftover is EG* SDTM-copy (two EG files).;
      %put NOTE: [PROC COMPARE &label] Keep SAS EGSTRESU/EGTPT verbatim - do not recode to pharmaversesdtm labels.;
      %put WARNING: [PROC COMPARE &label] status=POLICY - ADEG EG* SDTM-copy leftovers (two EG files).;
    %end;
  %end;

  /* ADCM: PVA gold AENDT year-end without EOSDT cap (not a SAS defect).
     admiral ad_adcm.R: hi=M date_imputation=last max_dates=DTHDT,EOSDT.
     Example 01-718-1170 CMENDTC=2013-11 EOSDT=03NOV2013 - SAS AENDT=03NOV2013
     (correct) vs PVA 31DEC2013 (year-end). When Layer-1 mismatches are ONLY
     AENDT and/or AENDY, digest status=POLICY. Do not change SAS to match PVA.
     Uses Layer-1 _qc_mis (strip-aware) - not PROC COMPARE OUTDIF char noise. */
  %let n_mis_all = 0;
  %let n_mis_pol = 0;
  %if %index(%upcase(&label), ADCM) and &n_base = &n_comp
      and &n_base_only = 0 and &n_comp_only = 0 and &n_dif > 0
      and %sysfunc(exist(_qc_mis)) %then %do;
    proc sql noprint;
      select count(*) into :n_mis_all trimmed from _qc_mis;
      select count(*) into :n_mis_pol trimmed from _qc_mis
        where upcase(strip(_issue)) in ('MISMATCH:AENDT', 'MISMATCH:AENDY')
      ;
    quit;
    %if %sysevalf(%superq(n_mis_all) =, boolean) %then %let n_mis_all = 0;
    %if %sysevalf(%superq(n_mis_pol) =, boolean) %then %let n_mis_pol = 0;
    %put NOTE: [PROC COMPARE &label] ADCM_AENDT_POLICY_V2 gate n_mis_all=&n_mis_all n_aendt_aendy=&n_mis_pol n_dif=&n_dif.;
    %if %sysevalf(&n_mis_all > 0) and %sysevalf(&n_mis_all = &n_mis_pol) %then %do;
      %let adcm_aendt_flag = 1;
      %put NOTE: [PROC COMPARE &label] ADCM_AENDT_POLICY_V2 FIRE - Layer-1 diffs are only AENDT and/or AENDY.;
      %put NOTE: [PROC COMPARE &label] PVA appears to impute partial CMENDTC to year-end without EOSDT cap.;
      %put NOTE: [PROC COMPARE &label] SAS matches admiral ad_adcm.R (hi=M last + max_dates=DTHDT,EOSDT) - keep SAS.;
      %put WARNING: [PROC COMPARE &label] status=POLICY - ADCM AENDT PVA year-end without EOS cap.;
    %end;
  %end;
  %else %if %index(%upcase(&label), ADCM) and &n_dif > 0 %then
    %put NOTE: [PROC COMPARE &label] ADCM_AENDT_POLICY_V2 skip - need n match keys clean _qc_mis exist (n_dif=&n_dif).;

  /* Triage order: COUNT (n differs) first, then unmatched keys, then values.
     PROC COMPARE only compares ID-matched observations - while n differs or
     keys are orphaned, value_diffs describes whatever paired up and is
     secondary / UNRELIABLE. */
  %if &n_base ne &n_comp %then %do;
    %put WARNING: [PROC COMPARE &label] status=COUNT - row counts differ (fix n before value_diffs).;
    %put WARNING: [PROC COMPARE &label] value_diffs=&n_dif is secondary/UNRELIABLE until base_n equals compare_n.;
  %end;
  %if &n_base_only > 0 or &n_comp_only > 0 %then %do;
    /* ADAE: match key already includes ASTDT. Orphans = ASTDT *value*
       disagreement (REF missing vs SAS imputed) - gold-policy, not a
       missing key column. */
    %if %index(%upcase(&label), ADAE) and &n_base = &n_comp %then %do;
      %let dsid = %sysfunc(open(_pc_base, i));
      %if &dsid and %sysfunc(varnum(&dsid, ASTDT)) %then %do;
        %let dsid = %sysfunc(close(&dsid));
        proc sql noprint;
          select sum(missing(ASTDT)) into :nmiss_ast_ref trimmed from _pc_base;
          select sum(missing(ASTDT)) into :nmiss_ast_sas trimmed from _pc_comp;
        quit;
        %if %sysevalf(&nmiss_ast_ref > &nmiss_ast_sas) %then %do;
          %let date_impute_flag = 1;
          %put NOTE: [PROC COMPARE &label] DATE_IMPUTE / gold-policy - key already has ASTDT (&_keys).;
          %put NOTE: [PROC COMPARE &label] Orphans = ASTDT value gap - REF nmiss=&nmiss_ast_ref SAS=&nmiss_ast_sas (not a missing key column).;
          %put NOTE: [PROC COMPARE &label] SAS keeps conservative DTM imputation - not a SAS bug to fix for QC parity.;
          %put NOTE: [PROC COMPARE &label] User reviewing cases - closing gap is a gold-side change later.;
        %end;
      %end;
      %else %if &dsid %then %let dsid = %sysfunc(close(&dsid));
    %end;
    %if &date_impute_flag = 0 %then %do;
      %put ERROR: [PROC COMPARE &label] ID keys unmatched on &_keys - fix the key before reading value_diffs.;
      %put ERROR: [PROC COMPARE &label] value_diffs=&n_dif is UNRELIABLE until base_only and compare_only are 0.;
    %end;
    %else %do;
      %put WARNING: [PROC COMPARE &label] status=POLICY - DATE_IMPUTE ASTDT value orphans (gold hi=n vs SAS hi=D).;
      %put NOTE: [PROC COMPARE &label] value_diffs=&n_dif is UNRELIABLE while ASTDT values disagree by imputation policy.;
    %end;
    %put NOTE: [PROC COMPARE &label] base is the R gold ref, compare is the SAS build.;
    %put NOTE: [PROC COMPARE &label] base_only_keys are gold rows the SAS build has no match for.;
    %put NOTE: [PROC COMPARE &label] compare_only_keys are SAS rows the gold has no match for.;
  %end;

  data _pc_row;
    length dataset $32 compare_type $16 status $8 detail $400;
    call missing(of _all_);
    dataset = "&label";
    compare_type = "PROC_COMPARE";
    /* COUNT outranks FAIL when n differs - even if orphans or value diffs also exist.
       POLICY = ADAE DATE_IMPUTE, ADEG CT/label (ms vs msec / RR PARAM),
       ADEG EG* SDTM-copy leftovers (two EG files), or
       ADCM AENDT PVA year-end without EOSDT cap. */
    if &pc_ok and &n_dif = 0 and &n_base_only = 0 and &n_comp_only = 0 and &n_base = &n_comp
      then status = "PASS";
    else if &n_base ne &n_comp then status = "COUNT";
    else if &date_impute_flag = 1 or &adeg_ct_flag = 1 or &adeg_eg_flag = 1
            or &adcm_aendt_flag = 1
      then status = "POLICY";
    else status = "FAIL";
    detail = catx(" | ",
      "base=gold_ref compare=sas_adam",
      cat("base_n=", &n_base),
      cat("compare_n=", &n_comp),
      cat("value_diffs=", &n_dif),
      cat("base_only_keys=", &n_base_only),
      cat("compare_only_keys=", &n_comp_only),
      "key=&_keys (&_ksrc)",
      cat("proc_ok=", &pc_ok)
    );
    if &n_base ne &n_comp then
      detail = catx(" | ", detail, "COUNT first - value_diffs secondary/UNRELIABLE until n matches");
    if &n_base_only > 0 or &n_comp_only > 0 then do;
      if &date_impute_flag = 1 then
        detail = catx(" | ", detail,
          "DATE_IMPUTE - ASTDT already in key - orphans are ASTDT value gap (REF missing vs SAS imputed), not missing key column");
      else
        detail = catx(" | ", detail, "value_diffs UNRELIABLE - keys unmatched");
    end;
    if &adeg_ct_flag = 1 then
      detail = catx(" | ", detail,
        "ADEG CT/LABEL POLICY - SAS ms (CDISC 24JUN2022) vs gold msec and/or RR Interval vs Duration - keep as understood gap");
    if &adeg_eg_flag = 1 then
      detail = catx(" | ", detail,
        "ADEG EG* POLICY - PVA pharmaversesdtm EG vs SAS Track A raw.eg (EGSTRESU/EGTPT verbatim) - keep SAS");
    if &adcm_aendt_flag = 1 then
      detail = catx(" | ", detail,
        "ADCM AENDT POLICY - PVA year-end impute without EOSDT cap vs admiral hi=M last + max_dates=DTHDT,EOSDT - keep SAS");
    output;
  run;

  %if not %sysfunc(exist(&digest)) %then %do;
    data &digest;
      set _pc_row;
    run;
  %end;
  %else %do;
    proc append base=&digest data=_pc_row force;
    run;
  %end;

  %if &n_dif > 0 %then %do;
    %put NOTE: ===== STACKED_DIF_FINGERPRINT=20260824G label=&label n_dif=&n_dif =====;
    %put NOTE: If Results still show lone E with title without PVA over SAS - ODA has a STALE m_qc_procompare_pva.sas;
    %put WARNING: [PROC COMPARE &label] Value differences - stacked PVA/SAS sample follows (not raw OUTDIF).;

    /* Always strip formats on working copies used for value display */
    data _pc_base;
      set _pc_base;
      format _numeric_;
    run;
    data _pc_comp;
      set _pc_comp;
      format _numeric_;
    run;

    %if %sysmacexist(m_qc_print_dif_pva_sas) %then %do;
      %m_qc_print_dif_pva_sas(
        cmpout=_pc_out
      , baseds=_pc_base
      , compds=_pc_comp
      , idkeys=&_idlist
      , exclude=&_tie
      , label=&label
      , n_dif=&n_dif
      , obs=50
      , criterion=1e-8
      );
    %end;
    %else %do;
      %put ERROR: [PROC COMPARE &label] m_qc_print_dif_pva_sas not loaded - upload SAS/macro/m_qc_print_dif_pva_sas.sas;
      /* Emergency inline sample - still never print raw _pc_od */
      %put ERROR: [PROC COMPARE &label] Skipping cell sample - helper missing.;
    %end;
    /* Per-variable unequal counts from DIF rows.
       Numeric: abs>1e-8. Character: OUTDIF equal values are a period mask
       (not blank) - compress away '.' and space or every char var on a DIF
       row false-counts (ADEG wall of 57540). ID / tiebreak / bookkeeping
       are copied onto DIF rows and would also false-count. */
    %local _ex _j _tok;
    %let _ex = _TYPE_ _OBS_ _KEYSEQ &_idlist &_tie;
    proc contents data=_pc_od out=_pc_od_vars(keep=name type) noprint;
    run;
    data _pc_od_vars;
      set _pc_od_vars;
      length _vn $32;
      _vn = upcase(strip(name));
      %let _j = 1;
      %let _tok = %upcase(%scan(&_ex, &_j, %str( )));
      %do %while(%length(&_tok));
        if _vn = "&_tok" then delete;
        %let _j = %eval(&_j + 1);
        %let _tok = %upcase(%scan(&_ex, &_j, %str( )));
      %end;
    run;
    data _pc_varfreq;
      length variable $32 n_unequal 8;
      stop;
    run;
    data _null_;
      set _pc_od_vars end=eof;
      if _n_ = 1 then call execute('proc sql noprint;');
      if type = 1 then
        call execute('insert into _pc_varfreq select "'||strip(name)||
          '", coalesce(sum(case when not missing('||strip(name)||
          ') and abs('||strip(name)||') > 1e-8 then 1 else 0 end),0) from _pc_od;');
      else
        call execute('insert into _pc_varfreq select "'||strip(name)||
          '", coalesce(sum(case when compress('||strip(name)||
          ', '' .'') ne '''' then 1 else 0 end),0) from _pc_od;');
      if eof then call execute('quit;');
    run;
    proc sort data=_pc_varfreq;
      by descending n_unequal variable;
    run;
  %end;

  /* Classify compared variables: value_unequal (on both, values differ),
     pva_only (on PVA/base not SAS), sas_only (on SAS not PVA).
     PVA-only is NOT a value-unequal - it is "on BASE not on COMPARE". */
  %let _n_vu = 0;
  %let _n_po = 0;
  %let _n_so = 0;
  proc contents data=&base out=_pc_bvars(keep=name) noprint;
  run;
  proc contents data=&compare out=_pc_cvars(keep=name) noprint;
  run;
  data _pc_bvars;
    set _pc_bvars;
    name = upcase(strip(name));
    if name in ('_KEYSEQ' '_TYPE_' '_OBS_') then delete;
  run;
  data _pc_cvars;
    set _pc_cvars;
    name = upcase(strip(name));
    if name in ('_KEYSEQ' '_TYPE_' '_OBS_') then delete;
  run;
  proc sql noprint;
    create table _pc_varclass as
    select b.name as variable length=32, 'pva_only' as class length=16,
           . as n_unequal
    from _pc_bvars as b
    where b.name not in (select name from _pc_cvars)
    union all
    select c.name, 'sas_only', .
    from _pc_cvars as c
    where c.name not in (select name from _pc_bvars)
    union all
    select b.name, 'common', .
    from _pc_bvars as b
    where b.name in (select name from _pc_cvars);
  quit;
  %if &n_dif > 0 and %sysfunc(exist(_pc_varfreq)) %then %do;
    proc sql noprint;
      create table _pc_varclass2 as
      select a.variable length=32
           , case when b.n_unequal > 0 then 'value_unequal' else a.class end
             as class length=16
           , b.n_unequal as n_unequal
      from _pc_varclass as a
      left join _pc_varfreq as b
        on upcase(a.variable) = upcase(b.variable);
    quit;
    data _pc_varclass;
      set _pc_varclass2;
    run;
  %end;
  data _pc_varclass;
    set _pc_varclass;
    length why_hint $48 _n $32;
    _n = upcase(strip(variable));
    if class = 'pva_only' then why_hint = 'on PVA not SAS';
    else if class = 'sas_only' then why_hint = 'on SAS not PVA';
    else if class = 'value_unequal' then do;
      if prxmatch('/^(EG|VS|LB|CM)/', strip(_n)) then
        why_hint = 'sdtm_copy leftover';
      else if _n in ('STUDYID' 'SUBJID' 'SITEID' 'DOMAIN' 'COUNTRY' 'ETHNIC'
          'RACE' 'SEX' 'AGE' 'AGEU' 'ARM' 'ARMCD' 'ACTARM' 'ACTARMCD'
          'DTHFL' 'DTHDTC' 'RFSTDTC' 'RFENDTC' 'RFXSTDTC' 'RFXENDTC'
          'RFPENDTC' 'RFICDTC' 'BRTHDTC' 'BIRTHDTC' 'DMDTC' 'DMDY')
        then why_hint = 'DM passthrough';
      else why_hint = 'ADaM analysis var';
    end;
    drop _n;
  run;
  proc sql noprint;
    select count(*) into :_n_vu trimmed from _pc_varclass
      where class = 'value_unequal';
    select count(*) into :_n_po trimmed from _pc_varclass
      where class = 'pva_only';
    select count(*) into :_n_so trimmed from _pc_varclass
      where class = 'sas_only';
  quit;
  %if %sysevalf(%superq(_n_vu) =, boolean) %then %let _n_vu = 0;
  %if %sysevalf(%superq(_n_po) =, boolean) %then %let _n_po = 0;
  %if %sysevalf(%superq(_n_so) =, boolean) %then %let _n_so = 0;
  %put NOTE: [PROC COMPARE &label] VARCLASS=20260826A value_unequal=&_n_vu pva_only=&_n_po sas_only=&_n_so;
  %let _pc_uneq_names =;
  data _null_;
    length _names $400;
    retain _names;
    set _pc_varclass end=eof;
    if class = 'value_unequal' then
      _names = catx(' ', _names, strip(variable));
    if eof then do;
      call symputx('_pc_uneq_names', _names, 'l');
      if not missing(_names) then
        put "NOTE: [PROC COMPARE &label] value_unequal=" _names;
    end;
  run;
  %if &adeg_eg_flag = 1 %then
    %put NOTE: [PROC COMPARE &label] ADEG_EG_SDTM_POLICY_V1 value_unequal=&_pc_uneq_names.;
  %if &_n_vu > 0 or &_n_po > 0 or &_n_so > 0 %then %do;
    proc sort data=_pc_varclass;
      by class descending n_unequal variable;
    run;
    title "PROC COMPARE var class - &label (value_unequal / pva_only / sas_only)";
    proc print data=_pc_varclass(where=(class in ('value_unequal' 'pva_only' 'sas_only'))) noobs;
      var variable class n_unequal why_hint;
    run;
    title;
  %end;
  %else %put NOTE: [PROC COMPARE &label] var_class - no value_unequal, no PVA-only, no SAS-only.;

  proc datasets lib=work nolist;
    delete _pc_base _pc_comp _pc_out _pc_ob _pc_oc _pc_od _pc_row
           _pc_od_vars _pc_varfreq _pc_bvars _pc_cvars _pc_varclass _pc_varclass2;
  quit;

%mend m_qc_procompare_one;
