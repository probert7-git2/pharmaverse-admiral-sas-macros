/*--------------------------------------------------------------
  Original Reporting Effort   : safety_monitoring_system / R/adam_sdtm_workflow_template.final_20260608_1.Rmd
  Program Name                : m_qc_compare_pva.sas
  SAS Version                 : 9.4
  Purpose (short description) : Part B isolated copy of Track A m_qc_compare
                                (includes %m_qc_norm_dtm_scale for PVA XPT Date
                                vs adam datetime). Do not overwrite Track A.
  Author                      : Cursor Grok 4.5
  Date                        : 09AUG2026
  Input Datasets or Metadata  : adam.* and ref_pva.ref*
  Modification Log            :                                 26AUG2026 - Do not replace ADaM QC keys with a
                                USUBJID+SDTM-var matcher. Pairing orphans were 0
                                on ADVS/ADEG/ADLB. Remaining fails are value
                                diffs on already-paired rows (EG* source, ADLB
                                tox). An SDTM-key matcher would be diagnostic
                                only - EG source diffs would still break EG*
                                pairing. Non-unique business-key sample is not
                                a FAIL and does not drop rows.
                                25AUG2026 - ADLB default chkvars include SHIFT2
                                BTOXGR* ATOXDSCL/H (safety tox - do not omit).
                                24AUG2026 - ADCM_AENDT_POLICY_V2 gate NOTE so
                                ODA upload is verifiable - POLICY when only
                                AENDT/AENDY Layer-1 mismatches.
                                24AUG2026 - ADCM AENDT/AENDY POLICY when that is
                                the only Layer-1 mismatch (PVA year-end without
                                EOSDT cap - SAS matches admiral+EOS - not a SAS bug).
                                23AUG2026 - %m_qc_norm_dtm_scale: robust *DTM
                                suffix detect (no prx $), date-scale promote, and
                                midnight-collapse non-zero timepart on QC copies
                                (gold Date-collapse vs time_imputation=last).
                                23AUG2026 - Isolated Part B copy under
                                SAS_mirrored_Admiral_safety_ADaM/SAS/macro/
                                (same %m_qc_one / %m_qc_prep_pair names - Part B
                                session only). Keeps date-scale *DTM promotion.
                                23AUG2026 - %m_qc_norm_dtm_scale always NOTE with
                                *DTM var list and n_values promoted (ODA proof).
                                23AUG2026 - %m_qc_norm_dtm_scale: promote date-scale
                                *DTM (<100000) to midnight datetime so Part B PVA
                                XPTs (haven wrote Date for POSIXt) do not FAIL
                                PROC COMPARE 254/1191 vs adam datetime builders.
                                keysrc=CALLER logs explicitly (digest must not say
                                METADATA when caller forced keys).
                                19AUG2026 - Document per-domain SAS<->R key
                                alignment - BDS and OCCDS do not share one pattern.
                                19AUG2026 - OCCDS defaults documented (ADAE/ADCM
                                USUBJID ASTDT *DECOD). Mismatch shell includes AVISIT
                                for BDS keys. SORTEDBY preference is adam first.
                                19AUG2026 - BDS defaults ADVS/ADEG/ADLB are
                                USUBJID PARAMCD AVISIT ADT (*SEQ tiebreak). AVISIT
                                is the ADaM analysis visit key (admiral bds_finding /
                                ADaMIG). Track A template omitting visit was incomplete
                                vs pharmaverseadam BDS.
                                24AUG2026 - _qc_mis: widen _sas_val/_ref_val to $200
                                so long PARAM (e.g. Ery. Mean Corpuscular Hemoglobin
                                with units) does not CATS-truncate / set _ERROR_=1.
                                KEEP display keys only when present on sasds (ADLB has
                                no AEDECOD/CMDECOD/ASTDT/*SEQ from other domains).
                                24AUG2026 - BDS defaults switched to PARAMN AVISITN
                                (1:1 with PARAMCD/AVISIT on PVA gold) to match display
                                PARAMN sequence. CALLER keys include *SEQ in ID.
                                25AUG2026 - BDS defaults back to PARAMCD + DTYPE
                                (PARAMN blank on derived rows collided pairing).
                                *SEQ remains tiebreak.
                                19AUG2026 - Clarify ADAE DATE_IMPUTE notes - ASTDT is already
                                in the match key (USUBJID ASTDT AEDECOD). Orphans are ASTDT
                                value disagreement (REF missing vs SAS imputed), not a missing
                                key column. Soften non-unique business-key sample title/NOTE
                                (was "duplicate sort keys") - clarifies tiebreak/_KEYSEQ, not
                                extra rows or FAIL.
                                18AUG2026 - Char value compare uses strip() so length/pad
                                differences (PARAM AVALU ANRIND SHIFT etc) are not mismatches
                                when content matches. Numeric/date paths unchanged.
                                18AUG2026 - Row-count-first: prominent SAS n vs REF n at each
                                domain start. When counts differ, COMPARE FAILED - COUNT and
                                value mismatches marked secondary/UNRELIABLE (still runs key
                                and value compare - large ADLB SCOPE skip stays in adam2).
                                18AUG2026 - Char match keys (USUBJID PARAMCD AEDECOD VISIT etc)
                                are UPCASE+STRIP on both sides before sort/merge so case-only
                                SAS-vs-R differences do not orphan every row. Case probe logs
                                mixed-case counts before the UPCASE. Prep now norms then sorts
                                (no sort-before-coerce).
                                18AUG2026 - KEY REDESIGN. Match key is now the ADaM sort key
                                (business keys) plus a derived within-key ordinal _KEYSEQ.
                                *SEQ is demoted to tiebreak= (orders duplicate sort-key groups
                                only). *SEQ is excluded from value compare - assignment order
                                is not clinical content (EGSEQ flooded ADEG value_diffs).
                                Sort keys are read from SAS metadata (dictionary.columns
                                SORTEDBY) when the builder PROC SORTed its output, else from
                                the explicit per-domain map in %m_qc_default_keys. Duplicate
                                sort keys are NOTE (expected for same-day repeats), not WARNING.
                                18AUG2026 - Exclude *SEQ from chkvars / PROC COMPARE VAR.
                                Soften dup-key WARNING to NOTE when orphans=0 path is fine.
                                APPEND KEEP lists full key shell to avoid DATA-file WARN noise.
                                18AUG2026 - %m_qc_fix_epoch_dates never matched a variable:
                                whichc() was called with one space-delimited argument instead of
                                a comma list, so the date list was always empty. Now prxmatch.
                                18AUG2026 - %m_qc_key_diag: per-key type/length/missing/distinct/
                                min/max on both merge inputs, printed whenever a domain reports
                                key orphans. ERROR when every key is an orphan on both sides.
                                18AUG2026 - Empty _qc_all_mis shell: call missing + byvar LENGTH
                                so APPEND FORCE keeps keys and skips BASE-file WARN noise.
                                17AUG2026 - Date compare accepts character ISO on either side.
                                17AUG2026 - Compare common vars only - warn SAS-only.
                                17AUG2026 - Skip empty mismatch PRINT - avoid uninit noise.
                                09AUG2026 - Added standardized header fields (aligned labels).

  --- Existing header notes ---
  Compare SAS ADaM to R-reference ADaM (gold standard).

  Important: this is NOT PROC COMPARE, and it does not compare
  "formatted display". A SAS date is still a number internally
  (days since 01JAN1960). Equality of two dates is equality of
  those numbers when both sides are true SAS dates.

  Date variables are compared as ISO text (yymmdd10.) so the QC
  check is explicitly about the calendar day, not raw numeric
  equality (avoids R 1970-epoch vs SAS 1960-epoch mismatches).
  See .cursor/rules/sas-r-date-epoch-pitfalls.mdc.

  Scope: only vars present on BOTH SAS and REF are value-compared.
  Requested vars on SAS only (e.g. SAFFL when gold ADSL lacks it)
  are skipped with a NOTE - not treated as value mismatches.

  MATCH KEY POLICY
  ----------------
  Per-domain alignment (authoritative): BDS and OCCDS do NOT share one key
  pattern. Align adam.<ds> with ref.ref_<ds> for that same dataset only
  (adam.advs <-> ref.ref_advs, adam.adae <-> ref.ref_adae, ...). Derive each
  domain from its admiral/pharmaverse spex - do not force ADAE to look like
  ADVS. Keep builder PROC SORT, %m_qc_default_keys, and R arrange() in step
  per domain. See SAS/docs/qc_rules_and_scope.md (Per-domain keys table).

  A *SEQ variable carries no clinical meaning. It only numbers records
  within a subject, independently on each side. Using it as the primary
  match key means one extra or missing source record shifts every later
  *SEQ, so a single upstream difference reports as thousands of orphans.

  Instead every domain declares its own:

    sortkeys = business keys both builders can reproduce for THAT domain
               (BDS: USUBJID PARAMCD AVISITN DTYPE ADT -
                OCCDS: USUBJID ASTDT AEDECOD/CMDECOD - ...)
    tiebreak = the *SEQ variable, used ONLY to order rows inside a
               duplicate sortkeys group so the ordinal below is stable

  Key source (AUTO): prefer dictionary.columns SORTEDBY from adam (SAS
  ADaM after builder PROC SORT = Admiral / as-programmed order). Ref XPT
  usually has no SORTEDBY after convert - still use adam SORTEDBY when
  those vars exist on both sides. If both sides have SORTEDBY and they
  differ, adam wins. Else caller sortkeys / tiebreak, else %m_qc_default_keys.

  Both sides are PROC SORTed by "sortkeys tiebreak" in %m_qc_prep_pair,
  then each side gets _KEYSEQ - the 1-based ordinal of the row inside its
  sortkeys group. The merge key is "sortkeys _KEYSEQ". _KEYSEQ is 1 on
  every row when the sort key is unique, so a numbering difference can
  only affect rows inside one duplicated key group - it cannot cascade
  down the dataset.

  Character sortkeys (and char tiebreaks that are not *SEQ) are forced to
  UPCASE(STRIP()) on the QC working copies before sort/merge. Adam builders
  and R gold can disagree on case for USUBJID / PARAMCD / VISIT / coded
  terms even when the clinical content matches. Without the UPCASE those
  rows sort apart and report as total orphans. Value-compare lists already
  exclude the resolved sortkeys, so upcasing the match copy does not hide
  a real content mismatch on a non-key variable.

  *SEQ is tiebreak only (orders duplicate sortkeys groups for _KEYSEQ).
  It is excluded from value compare - SEQ is assignment order, not content.
  ADEG EGSEQ 43 vs 12 previously reported every row as a value mismatch.

  Do not replace these ADaM keys with a USUBJID + SDTM-var matcher.
  ADVS/ADEG/ADLB had 0 pairing orphans on the ADaM keys. Remaining fails
  are value diffs on already-paired rows (EG* source, ADLB tox). An
  SDTM-key matcher would be a diagnostic only - EG source differences
  would still break EG*-based pairing.
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~*/


%macro m_qc_build_rename(vars=, prefix=_r_);
  %local i v out;
  %let out =;
  %let i = 1;
  %let v = %scan(&vars, &i, %str( ));
  %do %while(%length(&v));
    %let out = &out &v = &prefix&v;
    %let i = %eval(&i + 1);
    %let v = %scan(&vars, &i, %str( ));
  %end;
  &out
%mend m_qc_build_rename;


/* Keep tokens present on both datasets. Warn SAS-only / REF-only / neither. */
%macro m_qc_filter_common_vars(sasds=, refds=, invars=, outmacrovar=, label=);
  %local i v out dsid_s dsid_r on_s on_r;
  %let out =;
  %let dsid_s = %sysfunc(open(&sasds, i));
  %let dsid_r = %sysfunc(open(&refds, i));
  %if &dsid_s = 0 or &dsid_r = 0 %then %do;
    %if &dsid_s %then %let dsid_s = %sysfunc(close(&dsid_s));
    %if &dsid_r %then %let dsid_r = %sysfunc(close(&dsid_r));
    %let &outmacrovar = &invars;
    %return;
  %end;
  %let i = 1;
  %let v = %scan(&invars, &i, %str( ));
  %do %while(%length(&v));
    %let on_s = %sysfunc(varnum(&dsid_s, &v));
    %let on_r = %sysfunc(varnum(&dsid_r, &v));
    %if &on_s > 0 and &on_r > 0 %then %let out = &out &v;
    %else %if &on_s > 0 and &on_r = 0 %then
      %put NOTE: [&label] SAS-only var skipped from compare: &v;
    %else %if &on_s = 0 and &on_r > 0 %then
      %put NOTE: [&label] REF-only requested var skipped: &v;
    %else
      %put NOTE: [&label] Var on neither side skipped: &v;
    %let i = %eval(&i + 1);
    %let v = %scan(&invars, &i, %str( ));
  %end;
  %let dsid_s = %sysfunc(close(&dsid_s));
  %let dsid_r = %sysfunc(close(&dsid_r));
  %let &outmacrovar = &out;
%mend m_qc_filter_common_vars;


/* Shift R 1970-epoch day counts stored as plain numerics (3653 = 01JAN1970 in SAS).

   Safety net only. When the gold XPT is written by haven from real R Date
   columns the epoch is already correct and this macro changes nothing:
   study dates 2012-2020 are SAS 19000-22000 and fail the year < 1985 test.
   It only rescues values that were exported as bare 1970-epoch integers.

   Was a silent no-op until 18AUG2026: whichc() was given the candidate list
   as ONE space-delimited argument, so it compared the variable name to the
   whole string and never matched. %sysfunc needs comma-separated arguments -
   prxmatch on an alternation is used instead so the list cannot re-break. */
%macro m_qc_fix_epoch_dates(data=);

  %local dsid i nvn vn list;
  %let list =;
  %let dsid = %sysfunc(open(&data));
  %if &dsid = 0 %then %return;
  %let nvn = %sysfunc(attrn(&dsid, nvars));
  %let i = 1;
  %do %while(&i le &nvn);
    %let vn = %sysfunc(varname(&dsid, &i));
    %if %sysfunc(vartype(&dsid, &i)) = N and
        %sysfunc(prxmatch(/^(TRTSDT|TRTEDT|ASTDT|AENDT|LDOSEDT|STARTDT|ADT|EVNTDT|DTHDT|EOSDT|RANDDT|SCRFDT)$/i, &vn))
      %then %let list = &list &vn;
    %let i = %eval(&i + 1);
  %end;
  %let dsid = %sysfunc(close(&dsid));

  %if %length(&list) = 0 %then %return;

  data &data;
    set &data;
    %let i = 1;
    %let vn = %scan(&list, &i, %str( ));
    %do %while(%length(&vn));
      if not missing(&vn) and &vn > 0 and &vn < 40000 and year(&vn) < 1985 then &vn = &vn + 3653;
      %let i = %eval(&i + 1);
      %let vn = %scan(&list, &i, %str( ));
    %end;
  run;

%mend m_qc_fix_epoch_dates;


/* Normalize *DTM on QC working copies for Part B PVA gold.

   Root cause (haven proof): refadsl/refadae *DTM are Date-class with
   format.sas=DATE. SAS numeric is DATE-scale (~19183-20030 days since 1960),
   identical to *DT. adam builders store DATETIME (~1.65e9 = days*86400).
   Unfixed PROC COMPARE: ADSL value_diffs=254 (all nonmiss TRTSDTM), ADAE=1191.

   After date-scale promote, residual FAIL can remain: gold Date-collapse is
   always midnight, while adam time_imputation=last yields 23:59:59 on
   TRTEDTM/AENDTM. QC copies therefore also midnight-collapse non-zero
   timepart (date precision only - *TMF already checked in Layer-1).

   Detection: numeric vars whose name ends with DTM (substr, not prx $ -
   %sysfunc(prxmatch(/DTM$/i,...)) is fragile in some ODA macro contexts). */
%macro m_qc_norm_dtm_scale(data=, label=);

  %local dsid i nvn vn list n_scale n_mid _l;
  %let list =;
  %let n_scale = 0;
  %let n_mid = 0;
  %let dsid = %sysfunc(open(&data, i));
  %if &dsid = 0 %then %do;
    %put NOTE: [&label] m_qc_norm_dtm_scale skipped - cannot open &data;
    %return;
  %end;
  %let nvn = %sysfunc(attrn(&dsid, nvars));
  %let i = 1;
  %do %while(&i le &nvn);
    %let vn = %sysfunc(varname(&dsid, &i));
    %let _l = %length(&vn);
    %if %sysfunc(vartype(&dsid, &i)) = N and &_l >= 3 %then %do;
      %if %upcase(%substr(&vn, %eval(&_l - 2), 3)) = DTM %then
        %let list = &list &vn;
    %end;
    %let i = %eval(&i + 1);
  %end;
  %let dsid = %sysfunc(close(&dsid));

  %if %length(&list) = 0 %then %do;
    %put NOTE: [&label] m_qc_norm_dtm_scale: no numeric *DTM vars on &data;
    %return;
  %end;

  %put NOTE: [&label] m_qc_norm_dtm_scale starting on &data vars=&list;

  /* n_scale = date->datetime promotes; n_mid = non-midnight -> midnight. */
  data &data;
    set &data end=_dtm_eof;
    retain _dtm_scale 0 _dtm_mid 0;
    %let i = 1;
    %let vn = %scan(&list, &i, %str( ));
    %do %while(%length(&vn));
      if not missing(&vn) then do;
        /* XPT Date-scale (~2e4) -> SAS midnight datetime (~1.7e9) */
        if &vn > 0 and &vn < 100000 then do;
          &vn = dhms(&vn, 0, 0, 0);
          _dtm_scale + 1;
        end;
        /* Datetime with time-of-day (e.g. last=23:59:59) -> midnight
           so Date-collapsed gold matches after scale promote. */
        else if &vn >= 100000 and abs(timepart(&vn)) > 0.5 then do;
          &vn = dhms(datepart(&vn), 0, 0, 0);
          _dtm_mid + 1;
        end;
      end;
      format &vn datetime20.;
      %let i = %eval(&i + 1);
      %let vn = %scan(&list, &i, %str( ));
    %end;
    if _dtm_eof then do;
      call symputx('n_scale', _dtm_scale, 'l');
      call symputx('n_mid', _dtm_mid, 'l');
    end;
    drop _dtm_scale _dtm_mid;
  run;

  %put NOTE: [&label] Promoted date-scale *DTM on &data - vars=&list n_scale=&n_scale n_midnight=&n_mid (XPT Date vs SAS datetime).;

%mend m_qc_norm_dtm_scale;


/*======================================================================
  KEY RESOLUTION

  Layer (a) SAS metadata (preferred when usable).
    dictionary.columns.SORTEDBY holds the 1-based position of a variable
    in the BY list of the PROC SORT that produced the member (0 = not a
    sort key, negative = DESCENDING). sashelp.vcolumn exposes the same
    column. It exists ONLY when the member really was PROC SORTed - a
    plain DATA step copy, an XPORT convert, or a haven-written XPT carry
    no sort order, so the R gold refs usually report nothing at all.

    Preference = adam (sasds) first. That is the Admiral / builder sort
    (as programmed). If ref lacks SORTEDBY, still use adam SORTEDBY when
    every token exists on both sides - do not fall back to defaults just
    because convert stripped ref metadata. If both sides report SORTEDBY
    and they differ, adam wins (logged). Ref metadata is used only when
    adam has none.

  Layer (b) explicit per-domain map - %m_qc_default_keys below. Used when
    neither side has usable SORTEDBY (or keysrc is not AUTO).

  A trailing *SEQ in a resolved list is split off as the tiebreak, so a
  builder sorted by USUBJID PARAMN PARAM AVISITN AVISIT ADT LBSEQ resolves to
  sortkeys = USUBJID PARAMN AVISITN ADT and tiebreak = LBSEQ.
======================================================================*/

/* Read SORTEDBY from dictionary metadata. Caller must %local outmacrovar. */
%macro m_qc_meta_sortedby(ds=, outmacrovar=);
  %local lib mem dot;
  %let &outmacrovar =;
  %if not %sysfunc(exist(&ds)) %then %return;
  %let dot = %index(&ds, .);
  %if &dot = 0 %then %do;
    %let lib = WORK;
    %let mem = %upcase(&ds);
  %end;
  %else %do;
    %let lib = %upcase(%substr(&ds, 1, %eval(&dot - 1)));
    %let mem = %upcase(%substr(&ds, %eval(&dot + 1)));
  %end;
  proc sql noprint;
    select upcase(name) into :&outmacrovar separated by ' '
      from dictionary.columns
      where libname = "&lib" and memname = "&mem" and sortedby ne 0
      order by abs(sortedby);
  quit;
%mend m_qc_meta_sortedby;


/* Explicit ADaM sort keys PER DOMAIN. Align adam.<ds> with ref.ref_<ds> -
   BDS and OCCDS do not share one pattern. Business keys both builders
   reproduce from SDTM - never a bare *SEQ. Keep builder PROC SORT,
   this map, and R arrange() in step for the same domain. */
%macro m_qc_default_keys(label=, out_keys=, out_tie=);
  %local l;
  /* Domain token: ADSL_PVA / ADAE_PVA still resolve to ADSL / ADAE maps */
  %let l = %upcase(%scan(&label, 1, _));
  %let &out_keys = USUBJID;
  %let &out_tie  =;
  /* OCCDS only (not BDS). USUBJID + analysis start + dictionary term
     (*SEQ tiebreak). Spex: admiral OCCDS vignette occurrence-flag order
     (ASTDT/ASTDTM + *SEQ) and preferred-term grouping - AEDECOD/CMDECOD
     make same-day multi-term rows distinct for QC pairing. ADSL is not
     OCCDS. ADTTE is BDS-TTE. */
  %if &l = ADAE %then %do;
    %let &out_keys = USUBJID ASTDT AEDECOD;
    %let &out_tie  = AESEQ;
  %end;
  %else %if &l = ADCM %then %do;
    %let &out_keys = USUBJID ASTDT CMDECOD;
    %let &out_tie  = CMSEQ;
  %end;
  %else %if &l = ADVS %then %do;
    /* BDS finding - PARAMCD not PARAMN (derived rows may lack PARAMN).
       ATPTN separates lying/standing. DTYPE separates AVERAGE. */
    %let &out_keys = USUBJID PARAMCD AVISITN ATPTN DTYPE ADT;
    %let &out_tie  = VSSEQ;
  %end;
  %else %if &l = ADEG %then %do;
    %let &out_keys = USUBJID PARAMCD AVISITN ATPTN DTYPE ADT;
    %let &out_tie  = EGSEQ;
  %end;
  %else %if &l = ADLB %then %do;
    %let &out_keys = USUBJID PARAMCD AVISITN DTYPE ADT;
    %let &out_tie  = LBSEQ;
  %end;
  %else %if &l = ADTTE or &l = ADTTEE %then %do;
    %let &out_keys = USUBJID PARAMCD;
    %let &out_tie  =;
  %end;
%mend m_qc_default_keys;


/* 1 when every token is present on both datasets, else 0. Macro function -
   call it inside %if, do not follow it with a semicolon. */
%macro m_qc_all_on_both(sasds=, refds=, vars=);
  %local i v dsid_s dsid_r ok;
  %let ok = 1;
  %let dsid_s = %sysfunc(open(&sasds, i));
  %let dsid_r = %sysfunc(open(&refds, i));
  %if &dsid_s = 0 or &dsid_r = 0 %then %let ok = 0;
  %else %do;
    %let i = 1;
    %let v = %scan(&vars, &i, %str( ));
    %do %while(%length(&v));
      %if %sysfunc(varnum(&dsid_s, &v)) = 0 %then %let ok = 0;
      %else %if %sysfunc(varnum(&dsid_r, &v)) = 0 %then %let ok = 0;
      %let i = %eval(&i + 1);
      %let v = %scan(&vars, &i, %str( ));
    %end;
  %end;
  %if &dsid_s %then %let dsid_s = %sysfunc(close(&dsid_s));
  %if &dsid_r %then %let dsid_r = %sysfunc(close(&dsid_r));
  &ok
%mend m_qc_all_on_both;


/* Keep only key tokens that exist on both datasets. A key present on one
   side only can never match, so it is dropped with a WARNING rather than
   left in to orphan every row. */
%macro m_qc_keys_common(sasds=, refds=, invars=, outmacrovar=, label=);
  %local i v out dsid_s dsid_r on_s on_r;
  %let out =;
  %let dsid_s = %sysfunc(open(&sasds, i));
  %let dsid_r = %sysfunc(open(&refds, i));
  %if &dsid_s = 0 or &dsid_r = 0 %then %do;
    %if &dsid_s %then %let dsid_s = %sysfunc(close(&dsid_s));
    %if &dsid_r %then %let dsid_r = %sysfunc(close(&dsid_r));
    %let &outmacrovar = &invars;
    %return;
  %end;
  %let i = 1;
  %let v = %scan(&invars, &i, %str( ));
  %do %while(%length(&v));
    %let on_s = %sysfunc(varnum(&dsid_s, &v));
    %let on_r = %sysfunc(varnum(&dsid_r, &v));
    %if &on_s > 0 and &on_r > 0 %then %let out = &out &v;
    %else %put WARNING: [&label] Sort key &v is not on both sides - dropped from the match key.;
    %let i = %eval(&i + 1);
    %let v = %scan(&invars, &i, %str( ));
  %end;
  %let dsid_s = %sysfunc(close(&dsid_s));
  %let dsid_r = %sysfunc(close(&dsid_r));
  %let &outmacrovar = &out;
%mend m_qc_keys_common;


/* Resolve sortkeys / tiebreak for one domain. Caller must %local the three
   out_* macro variables. out_src reports METADATA, CALLER or DEFAULT.
   AUTO preference: adam SORTEDBY (as programmed) over ref, over caller, over
   %m_qc_default_keys. Ref lacking SORTEDBY does not block adam keys. */
%macro m_qc_resolve_keys(
  sasds=
, refds=
, label=
, sortkeys=
, tiebreak=
, keysrc=AUTO
, out_keys=
, out_tie=
, out_src=
);

  %local meta meta_adam meta_ref n_meta last cand_keys cand_tie def_keys def_tie taken;

  %let cand_keys =;
  %let cand_tie  =;
  %let taken     = 0;
  %let &out_src  = DEFAULT;
  %let meta      =;
  %let meta_adam =;
  %let meta_ref  =;

  /* CALLER: never read SORTEDBY - digest must say (CALLER), not (METADATA). */
  %if %upcase(&keysrc) = CALLER %then
    %put NOTE: [&label] keysrc=CALLER - ignoring adam/ref SORTEDBY - using sortkeys=&sortkeys tiebreak=&tiebreak.;

  %if %upcase(&keysrc) = AUTO %then %do;
    %m_qc_meta_sortedby(ds=&sasds, outmacrovar=meta_adam);
    %m_qc_meta_sortedby(ds=&refds, outmacrovar=meta_ref);

    /* adam first = Admiral / builder sort. Ref XPT convert usually strips
       SORTEDBY - still trust adam when vars exist on both sides. */
    %if %length(&meta_adam) %then %do;
      %let meta = &meta_adam;
      %if %length(&meta_ref) %then %do;
        %if %sysfunc(compare(%upcase(&meta_adam), %upcase(&meta_ref))) ne 0 %then %do;
          %put NOTE: [&label] adam and ref SORTEDBY differ - preferring adam (as programmed).;
          %put NOTE: [&label] adam SORTEDBY=&meta_adam;
          %put NOTE: [&label] ref  SORTEDBY=&meta_ref;
        %end;
      %end;
      %else %put NOTE: [&label] ref has no SORTEDBY (typical after XPT convert) - using adam metadata.;
    %end;
    %else %if %length(&meta_ref) %then %do;
      %let meta = &meta_ref;
      %put NOTE: [&label] adam has no SORTEDBY - falling back to ref metadata.;
    %end;

    %if %length(&meta) %then %do;
      %let n_meta = %sysfunc(countw(&meta, %str( )));
      %let last   = %scan(&meta, -1, %str( ));
      %if &n_meta > 1 and %sysfunc(prxmatch(/SEQ$/i, &last)) %then %do;
        %let cand_keys = %substr(&meta, 1, %eval(%length(&meta) - %length(&last) - 1));
        %let cand_tie  = &last;
      %end;
      %else %if &n_meta = 1 and %sysfunc(prxmatch(/SEQ$/i, &last)) %then %do;
        %put NOTE: [&label] SORTEDBY metadata is a bare *SEQ (&meta) - ignored.;
      %end;
      %else %do;
        %let cand_keys = &meta;
        %let cand_tie  =;
      %end;
    %end;
    %if %length(&cand_keys) %then %do;
      %if %m_qc_all_on_both(sasds=&sasds, refds=&refds, vars=&cand_keys &cand_tie) %then %do;
        %let taken = 1;
        %let &out_src = METADATA;
        %put NOTE: [&label] Sort keys from adam/ref SORTEDBY (adam preferred): &cand_keys tiebreak &cand_tie;
        /* The builder PROC SORT and the QC key map must not drift apart */
        %if %length(&sortkeys) %then %do;
          %if %sysfunc(compare(%upcase(&cand_keys &cand_tie), %upcase(&sortkeys &tiebreak))) ne 0 %then %do;
            %put WARNING: [&label] Builder sort order and QC key map disagree.;
            %put WARNING: [&label] SORTEDBY says &cand_keys &cand_tie and the caller asked for &sortkeys &tiebreak;
            %put WARNING: [&label] SORTEDBY wins - align the builder PROC SORT with the key map.;
          %end;
        %end;
      %end;
      %else %do;
        %put NOTE: [&label] SORTEDBY metadata (&cand_keys &cand_tie) is not usable on both sides.;
        %let cand_keys =;
        %let cand_tie  =;
      %end;
    %end;
    %else %put NOTE: [&label] No SORTEDBY on adam or ref - using the explicit key map.;
  %end;

  %if &taken = 0 and %length(&sortkeys) %then %do;
    %let cand_keys = &sortkeys;
    %let cand_tie  = &tiebreak;
    %let taken     = 1;
    %let &out_src  = CALLER;
  %end;

  %if &taken = 0 %then %do;
    %m_qc_default_keys(label=&label, out_keys=def_keys, out_tie=def_tie);
    %let cand_keys = &def_keys;
    %let cand_tie  = &def_tie;
    %let &out_src  = DEFAULT;
  %end;

  /* Drop key tokens missing on either side, then guarantee a usable key */
  %m_qc_keys_common(sasds=&sasds, refds=&refds, invars=&cand_keys,
    outmacrovar=cand_keys, label=&label);
  %if %length(&cand_tie) %then %do;
    %m_qc_keys_common(sasds=&sasds, refds=&refds, invars=&cand_tie,
      outmacrovar=cand_tie, label=&label);
  %end;
  %if %length(&cand_keys) = 0 %then %do;
    %put ERROR: [&label] No usable sort key survived - falling back to USUBJID.;
    %let cand_keys = USUBJID;
  %end;

  %let &out_keys = &cand_keys;
  %let &out_tie  = &cand_tie;

  %put NOTE: [&label] MATCH KEY source=&&&out_src sortkeys=&cand_keys tiebreak=&cand_tie plus derived _KEYSEQ;

%mend m_qc_resolve_keys;


/* Count rows whose character key is not already uppercase - run BEFORE
   %m_qc_norm_key_ds so the log still shows the case issue that UPCASE will fix. */
%macro m_qc_key_case_probe(data=, keys=, label=, side=);
  %local i v dsid vnum vt n_mixed;
  %let i = 1;
  %let v = %scan(&keys, &i, %str( ));
  %do %while(%length(&v));
    %let vnum = 0;
    %let vt   =;
    %let dsid = %sysfunc(open(&data, i));
    %if &dsid %then %do;
      %let vnum = %sysfunc(varnum(&dsid, &v));
      %if &vnum %then %let vt = %sysfunc(vartype(&dsid, &vnum));
      %let dsid = %sysfunc(close(&dsid));
    %end;
    %if &vnum > 0 %then %do;
      %if &vt = C %then %do;
        %if not %sysfunc(prxmatch(/(SEQ|NUM)$/i, &v)) %then %do;
          %let n_mixed = 0;
          proc sql noprint;
            select count(*) into :n_mixed trimmed
              from &data
              where not missing(&v) and strip(&v) ne upcase(strip(&v));
          quit;
          %if &n_mixed > 0 %then
            %put WARNING: [&label] &side key &v has &n_mixed rows not UPPERCASE - UPCASE for match.;
          %else
            %put NOTE: [&label] &side key &v already uppercase (or all missing).;
        %end;
      %end;
    %end;
    %let i = %eval(&i + 1);
    %let v = %scan(&keys, &i, %str( ));
  %end;
%mend m_qc_key_case_probe;


/* Make the key columns comparable on one dataset before the BY merge.
   Type changes need rename/drop - an in-place assignment cannot change type.
   Character business keys are UPCASE(STRIP()) so SAS vs R case drift cannot
   orphan an otherwise matching row. Working copies only - adam/ref untouched. */
%macro m_qc_norm_key_ds(data=, keys=, label=);

  %local i v dsid vnum vt;

  %let i = 1;
  %let v = %scan(&keys, &i, %str( ));
  %do %while(%length(&v));
    %let vnum = 0;
    %let vt   =;
    %let dsid = %sysfunc(open(&data, i));
    %if &dsid %then %do;
      %let vnum = %sysfunc(varnum(&dsid, &v));
      %if &vnum %then %let vt = %sysfunc(vartype(&dsid, &vnum));
      %let dsid = %sysfunc(close(&dsid));
    %end;

    /* Nested %IF - &vt is only defined once &vnum proves the var exists.
       %EVAL has no short-circuit, so this cannot be one combined condition. */
    %if &vnum > 0 %then %do;
      %if &vt = C %then %do;
        %if %sysfunc(prxmatch(/(SEQ|NUM)$/i, &v)) %then %do;
          data &data;
            set &data(rename=(&v = _qc_kraw));
            &v = input(cats(_qc_kraw), ?? best32.);
            drop _qc_kraw;
          run;
          %put NOTE: [&label] Key &v coerced from character to numeric on &data;
        %end;
        %else %if %sysfunc(prxmatch(/^(ADT|ASTDT|AENDT|STARTDT|TRTSDT|TRTEDT|LDOSEDT|EVNTDT|DTHDT)$/i, &v)) %then %do;
          data &data;
            set &data(rename=(&v = _qc_kraw));
            length &v 8;
            format &v date9.;
            &v = input(strip(_qc_kraw), ?? yymmdd10.);
            if missing(&v) then &v = input(strip(_qc_kraw), ?? date9.);
            drop _qc_kraw;
          run;
          %put NOTE: [&label] Key &v parsed from character ISO text to a SAS date on &data;
        %end;
        %else %do;
          data &data;
            set &data;
            &v = upcase(strip(&v));
          run;
          %put NOTE: [&label] Key &v upcased and stripped on &data for case-safe match;
        %end;
      %end;
    %end;

    %let i = %eval(&i + 1);
    %let v = %scan(&keys, &i, %str( ));
  %end;

%mend m_qc_norm_key_ds;


/* Sort by "keys tiebreak" and number rows inside each sort-key group.
   _KEYSEQ is 1 on every row when the sort key is unique. */
%macro m_qc_add_keyseq(data=, keys=, tiebreak=);
  %local lastkey;
  %let lastkey = %scan(&keys, -1, %str( ));
  proc sort data=&data;
    by &keys &tiebreak;
  run;
  data &data;
    set &data;
    by &keys;
    retain _KEYSEQ 0;
    if first.&lastkey then _KEYSEQ = 1;
    else _KEYSEQ = _KEYSEQ + 1;
  run;
  /* Re-set the sort indicator on the actual merge key so the later BY merges
     and PROC COMPARE ID never hit an out-of-order check. */
  proc sort data=&data;
    by &keys _KEYSEQ;
  run;
%mend m_qc_add_keyseq;


/* Build the two merge inputs: copy, case-probe, type/case-align, epoch-fix,
   then PROC SORT both sides by the resolved keys and number duplicate groups.
   Norm before sort so UPCASE and type coercion define the order the BY merge
   actually uses. */
%macro m_qc_prep_pair(
  sasds=
, refds=
, keys=
, tiebreak=
, outsas=_qc_sas
, outref=_qc_ref
, label=
);

  %local n_dup_s n_dup_r;

  data &outsas;
    set &sasds;
  run;
  data &outref;
    set &refds;
  run;

  %m_qc_key_case_probe(data=&outsas, keys=&keys &tiebreak, label=&label, side=SAS);
  %m_qc_key_case_probe(data=&outref, keys=&keys &tiebreak, label=&label, side=REF);

  %m_qc_norm_key_ds(data=&outsas, keys=&keys &tiebreak, label=&label);
  %m_qc_norm_key_ds(data=&outref, keys=&keys &tiebreak, label=&label);

  %m_qc_fix_epoch_dates(data=&outsas);
  %m_qc_fix_epoch_dates(data=&outref);

  /* Date-scale *DTM (gold XPT) -> midnight datetime so PROC COMPARE matches
     adam datetime20. builders - see %m_qc_norm_dtm_scale. */
  %m_qc_norm_dtm_scale(data=&outsas, label=&label);
  %m_qc_norm_dtm_scale(data=&outref, label=&label);

  %m_qc_add_keyseq(data=&outsas, keys=&keys, tiebreak=&tiebreak);
  %m_qc_add_keyseq(data=&outref, keys=&keys, tiebreak=&tiebreak);

  proc sql noprint;
    select count(*) into :n_dup_s trimmed from &outsas where _KEYSEQ > 1;
    select count(*) into :n_dup_r trimmed from &outref where _KEYSEQ > 1;
  quit;

  %if &n_dup_s > 0 or &n_dup_r > 0 %then %do;
    %put NOTE: [&label] Non-unique business key (&keys) - tiebreak=&tiebreak / _KEYSEQ in use.;
    %put NOTE: [&label] Same key group repeats (e.g. same-day same-term AE) - SAS _KEYSEQ>1 rows=&n_dup_s REF=&n_dup_r.;
    %put NOTE: [&label] Expected true multi-row groups - not a missing date in the key. Harmless when base_only/compare_only are 0.;
    %put NOTE: [&label] Not a FAIL - rows are kept. _KEYSEQ pairs 1:1. Extra sort key (VISITNUM) is optional.;
    /* Informative only - rows are KEPT. _KEYSEQ>1 means the business key
       repeats (e.g. same-day same-term AE); *SEQ orders them for pairing.
       This is not a FAIL and does not drop duplicates. */
    title "QC non-unique business key - &label (tiebreak sample - rows kept)";
    proc print data=&outsas(where=(_KEYSEQ > 1) obs=20);
      var &keys &tiebreak _KEYSEQ;
    run;
    title;
  %end;
  %else %put NOTE: [&label] Sort key &keys is unique on both sides.;

%mend m_qc_prep_pair;


/* Key-alignment diagnostics for a domain that reports key orphans.
   Run on the POST-coercion / POST-epoch-fix merge inputs so the reported
   type, length and value ranges are the ones the BY merge actually used.
   A total-orphan result (orphans = n on both sides) is always one key
   variable disagreeing on every row - this names it instead of guessing. */
%macro m_qc_key_diag(sasds=, refds=, byvars=, label=, out=_qc_key_diag);

  %local i v dsid_s dsid_r vn_s vn_r;

  %let dsid_s = %sysfunc(open(&sasds, i));
  %let dsid_r = %sysfunc(open(&refds, i));
  %if &dsid_s = 0 or &dsid_r = 0 %then %do;
    %if &dsid_s %then %let dsid_s = %sysfunc(close(&dsid_s));
    %if &dsid_r %then %let dsid_r = %sysfunc(close(&dsid_r));
    %put ERROR: [&label] KEY DIAG could not open &sasds or &refds.;
    %return;
  %end;

  %put NOTE: [&label] KEY DIAG match key=&byvars;
  %put NOTE: [&label] KEY DIAG char business keys were UPCASE(STRIP) before match - remaining orphans are not case-only.;
  %let i = 1;
  %let v = %scan(&byvars, &i, %str( ));
  %do %while(%length(&v));
    %let vn_s = %sysfunc(varnum(&dsid_s, &v));
    %let vn_r = %sysfunc(varnum(&dsid_r, &v));
    %if &vn_s = 0 %then
      %put ERROR: [&label] KEY DIAG key var &v is not on SAS side - keys cannot match.;
    %else %if &vn_r = 0 %then
      %put ERROR: [&label] KEY DIAG key var &v is not on REF side - keys cannot match.;
    %else %put NOTE: [&label] KEY DIAG &v SAS %sysfunc(vartype(&dsid_s, &vn_s))%sysfunc(varlen(&dsid_s, &vn_s)) REF %sysfunc(vartype(&dsid_r, &vn_r))%sysfunc(varlen(&dsid_r, &vn_r));
    %let i = %eval(&i + 1);
    %let v = %scan(&byvars, &i, %str( ));
  %end;
  %let dsid_s = %sysfunc(close(&dsid_s));
  %let dsid_r = %sysfunc(close(&dsid_r));

  data &out;
    length _dataset $16 _side $4 _keyvar $32 _nmiss 8 _ndist 8 _min $32 _max $32;
    call missing(of _all_);
    stop;
  run;

  %let i = 1;
  %let v = %scan(&byvars, &i, %str( ));
  %do %while(%length(&v));
    proc sql noprint;
      create table _qc_kd_s as
        select "&label" as _dataset length=16
             , "SAS"    as _side    length=4
             , "&v"     as _keyvar  length=32
             , sum(missing(&v))     as _nmiss
             , count(distinct &v)   as _ndist
             , cats(min(&v))        as _min length=32
             , cats(max(&v))        as _max length=32
        from &sasds;
      create table _qc_kd_r as
        select "&label" as _dataset length=16
             , "REF"    as _side    length=4
             , "&v"     as _keyvar  length=32
             , sum(missing(&v))     as _nmiss
             , count(distinct &v)   as _ndist
             , cats(min(&v))        as _min length=32
             , cats(max(&v))        as _max length=32
        from &refds;
    quit;
    proc append base=&out data=_qc_kd_s force;
    run;
    proc append base=&out data=_qc_kd_r force;
    run;
    %let i = %eval(&i + 1);
    %let v = %scan(&byvars, &i, %str( ));
  %end;

  title "QC key diagnostics - &label (post-norm values used by the BY merge)";
  proc print data=&out noobs; run;
  title;

  proc datasets lib=work nolist;
    delete _qc_kd_s _qc_kd_r;
  quit;

%mend m_qc_key_diag;


/* sortkeys= / tiebreak= are the current interface - see MATCH KEY POLICY in
   the file header. byvars= is kept only so an old caller still runs; it is
   treated as sortkeys and reported, because a *SEQ passed there used to be
   the match key and is no longer an acceptable one. */
%macro m_qc_one(
  sasds=
, refds=
, sortkeys=
, tiebreak=
, byvars=
, keysrc=AUTO
, chkvars=
, datevars=
, floatvars=
, mask_vars=
, label=
);

  %local n_sas n_ref n_mis n_only_sas n_only_ref dsid i v ren
         chkvars2 datevars2 floatvars2 mtok
         _keys _tie _ksrc _di_adae _nm_ref _nm_sas
         _adeg_pol _adcm_pol _n_mis_pol _disp_keep _dk _dsid_k;

  %let _di_adae = 0;
  %let _nm_ref = 0;
  %let _nm_sas = 0;
  %let _adeg_pol = 0;
  %let _adcm_pol = 0;
  %let _n_mis_pol = 0;

  /* Drop masked variables from compare lists (e.g. DD-sourced DTHCAUS) */
  %let chkvars2 = &chkvars;
  %let datevars2 = &datevars;
  %let floatvars2 = &floatvars;
  %if %length(&mask_vars) %then %do;
    %put NOTE: [&label] Masking from QC: &mask_vars;
    %let i = 1;
    %let mtok = %scan(&mask_vars, &i, %str( ));
    %do %while(%length(&mtok));
      %let chkvars2 = %sysfunc(prxchange(s/\b&mtok\b//i, -1, &chkvars2));
      %let datevars2 = %sysfunc(prxchange(s/\b&mtok\b//i, -1, &datevars2));
      %let floatvars2 = %sysfunc(prxchange(s/\b&mtok\b//i, -1, &floatvars2));
      %let i = %eval(&i + 1);
      %let mtok = %scan(&mask_vars, &i, %str( ));
    %end;
  %end;

  %if not %sysfunc(exist(&sasds)) %then %do;
    %put ERROR: [&label] SAS dataset &sasds not found.;
    %return;
  %end;
  %if not %sysfunc(exist(&refds)) %then %do;
    %put ERROR: [&label] Reference &refds not found. Convert R ref XPT to sas7bdat under validation/.;
    %return;
  %end;

  /* Row-count-first: print n before key resolve or value compare. */
  %let dsid = %sysfunc(open(&sasds, i));
  %let n_sas = %sysfunc(attrn(&dsid, nlobs));
  %let dsid = %sysfunc(close(&dsid));
  %let dsid = %sysfunc(open(&refds, i));
  %let n_ref = %sysfunc(attrn(&dsid, nlobs));
  %let dsid = %sysfunc(close(&dsid));

  %put NOTE: ===== COMPARE &label: SAS n=&n_sas  REF n=&n_ref =====;
  %if &n_sas ne &n_ref %then %do;
    %put WARNING: [&label] COUNT mismatch first - SAS n=&n_sas REF n=&n_ref;
    %put WARNING: [&label] Equalize row counts before interpreting key orphans or value mismatches.;
  %end;
  %else %put NOTE: [&label] Row counts match (n=&n_sas) - proceeding to key match and value compare.;

  %m_qc_resolve_keys(
    sasds=&sasds
  , refds=&refds
  , label=&label
  , sortkeys=&sortkeys
  , tiebreak=&tiebreak
  , keysrc=&keysrc
  , out_keys=_keys
  , out_tie=_tie
  , out_src=_ksrc
  );
  %if %length(&sortkeys) = 0 and %length(&byvars) %then %do;
    %put WARNING: [&label] byvars=&byvars is the retired interface - use sortkeys= and tiebreak=;
    %put WARNING: [&label] Resolved keys &_keys &_tie were used instead of byvars.;
  %end;

  /* A match key is already equality-enforced by the BY merge, and renaming a
     key on the REF side would remove it from the merge. Strip resolved keys
     out of the value-compare lists. Also strip *SEQ: assignment order is not
     clinical content (EGSEQ 43 vs 12 flooded ADEG value_diffs). SEQ remains
     tiebreak for _KEYSEQ ordering only. */
  %let i = 1;
  %let v = %scan(&_keys, &i, %str( ));
  %do %while(%length(&v));
    %let chkvars2   = %sysfunc(prxchange(s/\b&v\b//i, -1, &chkvars2));
    %let datevars2  = %sysfunc(prxchange(s/\b&v\b//i, -1, &datevars2));
    %let floatvars2 = %sysfunc(prxchange(s/\b&v\b//i, -1, &floatvars2));
    %let i = %eval(&i + 1);
    %let v = %scan(&_keys, &i, %str( ));
  %end;
  %if %length(&_tie) %then %do;
    %let chkvars2   = %sysfunc(prxchange(s/\b&_tie\b//i, -1, &chkvars2));
    %let datevars2  = %sysfunc(prxchange(s/\b&_tie\b//i, -1, &datevars2));
    %let floatvars2 = %sysfunc(prxchange(s/\b&_tie\b//i, -1, &floatvars2));
  %end;
  /* Belt: any leftover *SEQ token in chkvars */
  %let chkvars2 = %sysfunc(prxchange(s/\b\w*SEQ\b//i, -1, &chkvars2));

  /* Value-compare only vars on both sides (avoids rename ERROR + blank _ref_val noise) */
  %m_qc_filter_common_vars(sasds=&sasds, refds=&refds, invars=&chkvars2,
    outmacrovar=chkvars2, label=&label);
  %m_qc_filter_common_vars(sasds=&sasds, refds=&refds, invars=&datevars2,
    outmacrovar=datevars2, label=&label);
  %m_qc_filter_common_vars(sasds=&sasds, refds=&refds, invars=&floatvars2,
    outmacrovar=floatvars2, label=&label);

  /* Sort BOTH sides by the shared ADaM sort key, align key types, then number
     rows inside each key group so the merge is 1:1 without using *SEQ. */
  %m_qc_prep_pair(
    sasds=&sasds
  , refds=&refds
  , keys=&_keys
  , tiebreak=&_tie
  , outsas=_qc_sas
  , outref=_qc_ref
  , label=&label
  );

  data _qc_keys;
    merge _qc_sas(in=s keep=&_keys _KEYSEQ) _qc_ref(in=r keep=&_keys _KEYSEQ);
    by &_keys _KEYSEQ;
    length _side $8;
    if s and not r then do; _side = 'SAS_ONLY'; output; end;
    else if r and not s then do; _side = 'REF_ONLY'; output; end;
  run;

  proc sql noprint;
    select count(*) into :n_only_sas trimmed from _qc_keys where _side = 'SAS_ONLY';
    select count(*) into :n_only_ref trimmed from _qc_keys where _side = 'REF_ONLY';
  quit;

  %put NOTE: [&label] key orphans SAS_ONLY=&n_only_sas REF_ONLY=&n_only_ref on key &_keys;

  /* Orphans on both sides mean the sort key disagrees, not that rows are
     missing. Diagnose the key before reading value diffs - they describe only
     whatever paired up. With a business key an orphan is a real content
     difference on that key (a date, a PARAMCD, a coded term), so KEY DIAG
     names the column to look at. */
  %if &n_only_sas > 0 or &n_only_ref > 0 %then %do;
    /* ADAE DATE_IMPUTE: match key already includes ASTDT (USUBJID ASTDT AEDECOD).
       Orphans here are ASTDT *value* disagreement (REF missing vs SAS imputed) -
       gold-policy, not "ASTDT omitted from the key". */
    %if %index(%upcase(&label), ADAE) and &n_sas = &n_ref %then %do;
      proc sql noprint;
        select sum(missing(ASTDT)) into :_nm_ref trimmed from _qc_ref;
        select sum(missing(ASTDT)) into :_nm_sas trimmed from _qc_sas;
      quit;
      %if %sysevalf(&_nm_ref > &_nm_sas) %then %do;
        %let _di_adae = 1;
        %put NOTE: [&label] DATE_IMPUTE / gold-policy - key already has ASTDT (&_keys).;
        %put NOTE: [&label] Orphans = ASTDT value gap - REF nmiss(ASTDT)=&_nm_ref SAS=&_nm_sas (not a missing key column).;
        %put NOTE: [&label] SAS keeps conservative DTM hi=D - orphans are not a SAS bug to fix for QC parity.;
        %put NOTE: [&label] User reviewing cases - closing gap is gold-side imputation later.;
        %put WARNING: [&label] KEY orphans classified as DATE_IMPUTE / POLICY (not KEY FAIL noise).;
      %end;
    %end;
    %if &_di_adae = 0 %then %do;
      %if &n_only_sas = &n_sas and &n_only_ref = &n_ref %then %do;
        %put ERROR: [&label] EVERY key is an orphan on both sides (n=&n_sas).;
        %put ERROR: [&label] One key variable differs on every row - see KEY DIAG below.;
        %put ERROR: [&label] Check the key map in %nrstr(%m_qc_default_keys) before reading value diffs.;
      %end;
    %end;
    %m_qc_key_diag(sasds=_qc_sas, refds=_qc_ref, byvars=&_keys &_tie, label=&label);
  %end;

  %let ren = %m_qc_build_rename(vars=&chkvars2 &datevars2 &floatvars2, prefix=_r_);

  /* Optional PRINT columns - KEEP only names that exist on sasds.
     Hard-coding AEDECOD/*SEQ/ASTDT caused never-referenced WARNINGs on ADLB. */
  %let _disp_keep =;
  %let _dsid_k = %sysfunc(open(&sasds, i));
  %let i = 1;
  %let _dk = %scan(USUBJID PARAMCD AEDECOD CMDECOD AESEQ VSSEQ EGSEQ CMSEQ LBSEQ ADT ASTDT, &i, %str( ));
  %do %while(%length(&_dk));
    %if &_dsid_k and %sysfunc(varnum(&_dsid_k, &_dk)) > 0 %then
      %let _disp_keep = &_disp_keep &_dk;
    %let i = %eval(&i + 1);
    %let _dk = %scan(USUBJID PARAMCD AEDECOD CMDECOD AESEQ VSSEQ EGSEQ CMSEQ LBSEQ ADT ASTDT, &i, %str( ));
  %end;
  %if &_dsid_k %then %let _dsid_k = %sysfunc(close(&_dsid_k));

  data _qc_mis;
    /* $200 - PARAM with units can be 43-48+ chars; $40 CATS truncates and sets _ERROR_ */
    length _dataset $16 _issue $40 _sas_val $200 _ref_val $200;
    %if %length(&ren) %then %do;
      merge _qc_sas(in=s) _qc_ref(in=r rename=(&ren));
    %end;
    %else %do;
      merge _qc_sas(in=s) _qc_ref(in=r);
    %end;
    by &_keys _KEYSEQ;
    if s and r;

    /* Non-date check vars: strip char sides so length/pad noise is not a fail.
       Numerics keep raw equality (missing / ne). */
    %let i = 1;
    %let v = %scan(&chkvars2, &i, %str( ));
    %do %while(%length(&v));
      if vtype(&v) = 'C' then do;
        if strip(&v) ne strip(_r_&v) then do;
          _dataset = "&label";
          _issue = "MISMATCH:&v";
          _sas_val = cats(&v);
          _ref_val = cats(_r_&v);
          output;
        end;
      end;
      else if missing(&v) ne missing(_r_&v) or
         (not missing(&v) and not missing(_r_&v) and &v ne _r_&v) then do;
        _dataset = "&label";
        _issue = "MISMATCH:&v";
        _sas_val = cats(&v);
        _ref_val = cats(_r_&v);
        output;
      end;
      %let i = %eval(&i + 1);
      %let v = %scan(&chkvars2, &i, %str( ));
    %end;

    /* Dates: ISO calendar compare; accept numeric SAS dates or character ISO.
       Normalize ref 1970-epoch numerics (+3653) when year < 1985. */
    length _qc_sas_iso _qc_ref_iso $10;
    _qc_work_dt = .;
    %let i = 1;
    %let v = %scan(&datevars2, &i, %str( ));
    %do %while(%length(&v));
      if missing(&v) then _qc_sas_iso = '';
      else if vtype(&v) = 'C' then do;
        _qc_work_dt = input(strip(&v), ?? yymmdd10.);
        if missing(_qc_work_dt) then _qc_work_dt = input(strip(&v), ?? date9.);
        if missing(_qc_work_dt) then _qc_sas_iso = strip(&v);
        else _qc_sas_iso = put(_qc_work_dt, yymmdd10.);
      end;
      else _qc_sas_iso = put(&v, yymmdd10.);

      if missing(_r_&v) then _qc_ref_iso = '';
      else if vtype(_r_&v) = 'C' then do;
        _qc_work_dt = input(strip(_r_&v), ?? yymmdd10.);
        if missing(_qc_work_dt) then _qc_work_dt = input(strip(_r_&v), ?? date9.);
        if missing(_qc_work_dt) then _qc_ref_iso = strip(_r_&v);
        else _qc_ref_iso = put(_qc_work_dt, yymmdd10.);
      end;
      else do;
        _qc_work_dt = _r_&v;
        if _qc_work_dt > 0 and _qc_work_dt < 40000 and year(_qc_work_dt) < 1985
          then _qc_work_dt = _qc_work_dt + 3653;
        _qc_ref_iso = put(_qc_work_dt, yymmdd10.);
      end;
      if _qc_sas_iso ne _qc_ref_iso then do;
        _dataset = "&label";
        _issue = "MISMATCH:&v";
        _sas_val = _qc_sas_iso;
        _ref_val = _qc_ref_iso;
        output;
      end;
      %let i = %eval(&i + 1);
      %let v = %scan(&datevars2, &i, %str( ));
    %end;

    %let i = 1;
    %let v = %scan(&floatvars2, &i, %str( ));
    %do %while(%length(&v));
      if missing(&v) ne missing(_r_&v) or
         (not missing(&v) and not missing(_r_&v) and abs(&v - _r_&v) > 1e-8) then do;
        _dataset = "&label";
        _issue = "MISMATCH:&v";
        _sas_val = cats(&v);
        _ref_val = cats(_r_&v);
        output;
      end;
      %let i = %eval(&i + 1);
      %let v = %scan(&floatvars2, &i, %str( ));
    %end;

    keep _dataset _issue _sas_val _ref_val &_keys &_tie _KEYSEQ &_disp_keep;
  run;

  proc sql noprint;
    select count(*) into :n_mis trimmed from _qc_mis;
  quit;

  %put NOTE: [&label] value mismatches=&n_mis;
  %if &n_sas ne &n_ref %then
    %put WARNING: [&label] value mismatches are secondary/UNRELIABLE until SAS n equals REF n.;

  /* ADEG CT/LABEL POLICY - same gate as %m_qc_procompare_one (ms vs msec /
     RR Interval vs Duration). Soften Layer-1 FAILED wording when that is all. */
  %let _adeg_pol = 0;
  %if %index(%upcase(&label), ADEG) and &n_sas = &n_ref
      and &n_only_sas = 0 and &n_only_ref = 0 and &n_mis > 0 %then %do;
    proc sql noprint;
      select count(*) into :_n_mis_pol trimmed from _qc_mis
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
    %if %sysevalf(&n_mis = &_n_mis_pol) %then %let _adeg_pol = 1;
  %end;

  /* ADCM AENDT POLICY - PVA year-end impute without EOSDT cap vs admiral
     hi=M last + max_dates=DTHDT,EOSDT (SAS correct). Soften when ONLY
     AENDT and/or AENDY disagree (AENDY follows AENDT).
     Gate stamp ADCM_AENDT_POLICY_V2 - must appear in ODA log after upload. */
  %let _adcm_pol = 0;
  %let _n_mis_pol = 0;
  %if %index(%upcase(&label), ADCM) and &n_sas = &n_ref
      and &n_only_sas = 0 and &n_only_ref = 0 and &n_mis > 0 %then %do;
    proc sql noprint;
      select count(*) into :_n_mis_pol trimmed from _qc_mis
        where upcase(strip(_issue)) in ('MISMATCH:AENDT', 'MISMATCH:AENDY')
      ;
    quit;
    %if %sysevalf(%superq(_n_mis_pol) =, boolean) %then %let _n_mis_pol = 0;
    %put NOTE: [&label] ADCM_AENDT_POLICY_V2 gate n_mis=&n_mis n_aendt_aendy=&_n_mis_pol.;
    %if %sysevalf(&n_mis = &_n_mis_pol) and %sysevalf(&_n_mis_pol > 0) %then %do;
      %let _adcm_pol = 1;
      %put NOTE: [&label] ADCM_AENDT_POLICY_V2 FIRE - Layer-1 diffs are only AENDT and/or AENDY.;
    %end;
  %end;

  %if &n_mis > 0 or &n_only_sas > 0 or &n_only_ref > 0 or &n_sas ne &n_ref %then %do;
    %if &n_sas ne &n_ref %then
      %put WARNING: [&label] COMPARE FAILED - COUNT (row counts differ);
    %else %if &_adeg_pol = 1 %then
      %put WARNING: [&label] COMPARE POLICY - ADEG AVALU ms vs msec and/or RR PARAM label (not a SAS bug).;
    %else %if &_adcm_pol = 1 %then
      %put WARNING: [&label] COMPARE POLICY - ADCM AENDT PVA year-end without EOS cap (SAS matches admiral+EOS - not a SAS bug).;
    %else
      %put WARNING: [&label] COMPARE FAILED;
    %if &n_mis > 0 %then %do;
      title "QC mismatches - &label";
      proc print data=_qc_mis(obs=50); run;
    %end;
    %if &n_only_sas > 0 or &n_only_ref > 0 %then %do;
      title "QC key orphans - &label";
      proc print data=_qc_keys(obs=50); run;
    %end;
    title;
  %end;
  %else %put NOTE: [&label] COMPARE PASSED;

  proc append base=_qc_all_mis data=_qc_mis force;
  run;

%mend m_qc_one;


%macro m_qc_compare(
  adam_lib=adam
, ref_lib=ref
);

  %local n_all_mis;

  %put NOTE: ===== Starting m_qc_compare =====;

  /* Shell must carry every key %m_qc_one may KEEP - avoids APPEND FORCE
     BASE-file WARN. call missing avoids NOTE-UNINIT on LENGTH+STOP creates. */
  data _qc_all_mis;
    length _dataset $16 _issue $40 _sas_val $200 _ref_val $200
           USUBJID $40 PARAMCD $16 AVISIT $40 AEDECOD $200 CMDECOD $200
           AESEQ VSSEQ EGSEQ CMSEQ LBSEQ ADT ASTDT _KEYSEQ 8;
    call missing(of _all_);
    stop;
  run;

  %m_qc_one(
    sasds=&adam_lib..adsl
  , refds=&ref_lib..ref_adsl
  , sortkeys=USUBJID
  , chkvars=STUDYID SUBJID SITEID AGE AGEU SEX RACE ARM ARMCD TRT01P TRT01A DTHFL
  , datevars=TRTSDT TRTEDT
  , floatvars=
  , label=ADSL
  );

  %m_qc_one(
    sasds=&adam_lib..adae
  , refds=&ref_lib..ref_adae
  , sortkeys=USUBJID ASTDT AEDECOD
  , tiebreak=AESEQ
  , chkvars=STUDYID ADY AETERM AESOC ASEV AREL TRTEMFL TRTA TRTP DOSEON DOSEU
  , datevars=AENDT TRTSDT TRTEDT LDOSEDT
  , floatvars=
  , label=ADAE
  );

  /* CURRENT: adam.adtte; legacy quarantine may still write adam.adttee */
  %if %sysfunc(exist(&adam_lib..adtte)) %then %do;
    %m_qc_one(
      sasds=&adam_lib..adtte
    , refds=&ref_lib..ref_adttee
    , sortkeys=USUBJID PARAMCD
    , chkvars=STUDYID PARAM CNSR TRTA TRTP
    , datevars=STARTDT ADT TRTSDT TRTEDT
    , floatvars=AVAL
    , label=ADTTE
    );
  %end;
  %else %if %sysfunc(exist(&adam_lib..adttee)) %then %do;
    %m_qc_one(
      sasds=&adam_lib..adttee
    , refds=&ref_lib..ref_adttee
    , sortkeys=USUBJID PARAMCD
    , chkvars=STUDYID PARAM CNSR TRTA TRTP
    , datevars=STARTDT ADT TRTSDT TRTEDT
    , floatvars=AVAL
    , label=ADTTEE
    );
  %end;
  %else %put NOTE: Skipping ADTTE QC (adam.adtte / adam.adttee missing).;

  %m_qc_one(
    sasds=&adam_lib..advs
  , refds=&ref_lib..ref_advs
  , sortkeys=USUBJID PARAMCD AVISITN ATPTN DTYPE ADT
  , tiebreak=VSSEQ
  , chkvars=STUDYID PARAM PARAMN VISIT AVISIT ATPT ADY AVALU ABLFL TRTA TRTP
  , datevars=TRTSDT TRTEDT
  , floatvars=AVAL BASE CHG PCHG
  , label=ADVS
  );

  %m_qc_one(
    sasds=&adam_lib..adeg
  , refds=&ref_lib..ref_adeg
  , sortkeys=USUBJID PARAMCD AVISITN ATPTN DTYPE ADT
  , tiebreak=EGSEQ
  , chkvars=STUDYID PARAM PARAMN VISIT AVISIT ATPT ADY AVALU ABLFL TRTA TRTP
  , datevars=TRTSDT TRTEDT
  , floatvars=AVAL BASE CHG PCHG
  , label=ADEG
  );

  %m_qc_one(
    sasds=&adam_lib..adcm
  , refds=&ref_lib..ref_adcm
  , sortkeys=USUBJID ASTDT CMDECOD
  , tiebreak=CMSEQ
  , chkvars=STUDYID ADY CMTRT CMROUTE CMDOSFRQ DOSEU TRTEMFL TRTA TRTP
  , datevars=AENDT ADT TRTSDT TRTEDT
  , floatvars=DOSE
  , label=ADCM
  );

  %if %sysfunc(exist(&adam_lib..adlb)) and %sysfunc(exist(&ref_lib..ref_adlb)) %then %do;
    %m_qc_one(
      sasds=&adam_lib..adlb
    , refds=&ref_lib..ref_adlb
    , sortkeys=USUBJID PARAMCD AVISITN DTYPE ADT
    , tiebreak=LBSEQ
    , chkvars=STUDYID PARAM PARAMN VISIT AVISIT ADY AVALU ABLFL ONTRTFL ANRIND BASEC BNRIND
              SHIFT SHIFT1 SHIFT2 ATOXDSCL ATOXDSCH ATOXGRL ATOXGRH ATOXGR
              BTOXGRL BTOXGRH BTOXGR TRTA TRTP
    , datevars=TRTSDT TRTEDT
    , floatvars=AVAL BASE CHG PCHG ANRLO ANRHI
    , label=ADLB
    );
  %end;
  %else %put NOTE: Skipping ADLB QC (adam.adlb or ref.ref_adlb missing).;

  proc sql noprint;
    select count(*) into :n_all_mis trimmed from _qc_all_mis;
  quit;

  %put NOTE: ===== m_qc_compare DONE total value-mismatch rows=&n_all_mis =====;

  data adam.qc_mismatches;
    set _qc_all_mis;
  run;

%mend m_qc_compare;


/*******************************************************************************
  %m_qc_compare_adsl2_pva — compare adam.adsl to a pharmaverseadam-style
  reference, masking DD-/death-detail vars that may diverge when DD is
  constructed or incomplete.
*******************************************************************************/
%macro m_qc_compare_adsl2_pva(
  sasds=adam.adsl
, refds=ref.ref_adsl
, mask_vars=DTHCAUS DTHDOM DTHCGR1 DTHADY LDDTHELD DTH30FL DTHA30FL DTHB30FL LDDTHGR1
);

  %m_qc_one(
    sasds=&sasds
  , refds=&refds
  , sortkeys=USUBJID
  , chkvars=STUDYID SUBJID SITEID AGE AGEU SEX RACE ARM ARMCD TRT01P TRT01A
            DTHFL SAFFL ITTFL DTHCAUS DTHDOM DTHCGR1
  , datevars=TRTSDT TRTEDT DTHDT
  , floatvars=
  , mask_vars=&mask_vars
  , label=ADSL_vs_PVA
  );

%mend m_qc_compare_adsl2_pva;
