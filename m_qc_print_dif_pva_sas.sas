/*--------------------------------------------------------------
  Program Name                : m_qc_print_dif_pva_sas.sas
  Purpose                     : Readable DIF sample - NEVER print raw OUTDIF
                                (date DIF under DATE formats shows as "E").
                                Each mismatched cell:
                                  PVA: <BASE / gold value>
                                  SAS: <COMPARE / adam value>
                                Values come from baseds/compds (not DIF math).
  Caller                      : %m_qc_procompare_one via run_qc_compare_pva_oda
  Modification Log            : 24AUG2026 - Fix _pdf_avars excl list quoting
                                (ERROR 22-322 / missing _PDF_AVARS) via
                                %sysfunc(quote) - guard blank n_avars.
                                24AUG2026 - Rebuild from base/comp by ID - do
                                not print OUTDIF or rely on OUTBASE/OUTCOMP
                                rows (fixes persistent "E" in Results).
                                24AUG2026 - Initial Part B helper.
--------------------------------------------------------------*/

%macro m_qc_print_dif_pva_sas(
  cmpout=_pc_out
, baseds=_pc_base
, compds=_pc_comp
, idkeys=
, exclude=
, label=
, n_dif=0
, obs=50
, criterion=1e-8
);

  %local n_disp n_avars i vn avar_list ren_b ren_c
         excl_sql excl_tok excl_j n_dif_use ls_prev;

  %if %length(&idkeys) = 0 %then %do;
    %put WARNING: [DIF PVA/SAS &label] idkeys= empty - skip stacked sample.;
    %return;
  %end;
  %if %sysfunc(exist(&baseds)) = 0 or %sysfunc(exist(&compds)) = 0 %then %do;
    %put WARNING: [DIF PVA/SAS &label] baseds/compds missing - skip stacked sample.;
    %return;
  %end;

  /* Prefer DIF keys from cmpout when present; else all ID-matched rows */
  %let n_dif_use = &n_dif;
  %if %sysfunc(exist(&cmpout)) %then %do;
    data work._pdf_od;
      set &cmpout;
      if upcase(_TYPE_) = 'DIF';
      keep &idkeys;
    run;
    proc sort data=work._pdf_od nodupkey;
      by &idkeys;
    run;
    proc sql noprint;
      select count(*) into :n_dif_use trimmed from work._pdf_od;
    quit;
  %end;
  %else %do;
    %put WARNING: [DIF PVA/SAS &label] cmpout=&cmpout missing - comparing all ID matches.;
    data work._pdf_od;
      set &baseds(keep=&idkeys);
    run;
    proc sort data=work._pdf_od nodupkey;
      by &idkeys;
    run;
    proc sql noprint;
      select count(*) into :n_dif_use trimmed from work._pdf_od;
    quit;
  %end;

  %if &n_dif_use = 0 %then %do;
    %put NOTE: [DIF PVA/SAS &label] No DIF/ID rows - skip stacked sample.;
    %return;
  %end;

  %put NOTE: ===== STACKED_DIF_FINGERPRINT=20260824G helper loaded =====;

  proc contents data=&baseds out=work._pdf_bvars(keep=name type) noprint;
  run;
  proc contents data=&compds out=work._pdf_cvars(keep=name type) noprint;
  run;

  /* Build quoted excl list with %sysfunc(quote) - %str(%') forms break on ODA
     (ERROR 22-322 expecting quoted string - _PDF_AVARS never created). */
  %let excl_sql = %sysfunc(quote(_TYPE_))%str(,)%sysfunc(quote(_OBS_))%str(,)%sysfunc(quote(_KEYSEQ));
  %let excl_j = 1;
  %let excl_tok = %upcase(%scan(&idkeys &exclude, &excl_j, %str( )));
  %do %while(%length(&excl_tok));
    %let excl_sql = &excl_sql%str(,) %sysfunc(quote(&excl_tok));
    %let excl_j = %eval(&excl_j + 1);
    %let excl_tok = %upcase(%scan(&idkeys &exclude, &excl_j, %str( )));
  %end;

  %let n_avars = 0;
  %let avar_list =;
  %let ren_b =;
  %let ren_c =;
  proc sql noprint;
    create table work._pdf_avars as
    select b.name, b.type
      from work._pdf_bvars b
      inner join work._pdf_cvars c
        on upcase(b.name) = upcase(c.name)
     where upcase(strip(b.name)) not in (&excl_sql)
     order by b.name;

    select count(*) into :n_avars trimmed from work._pdf_avars;
    select strip(name) into :avar_list separated by ' '
      from work._pdf_avars;
    select catx('=', strip(name), cats('B_', strip(name)))
      into :ren_b separated by ' '
      from work._pdf_avars;
    select catx('=', strip(name), cats('C_', strip(name)))
      into :ren_c separated by ' '
      from work._pdf_avars;
  quit;

  %if %sysevalf(%superq(n_avars) =, boolean) %then %let n_avars = 0;

  %if &n_avars = 0 %then %do;
    %put WARNING: [DIF PVA/SAS &label] No common analysis variables.;
    proc datasets lib=work nolist;
      delete _pdf_od _pdf_bvars _pdf_cvars _pdf_avars;
    quit;
    %return;
  %end;

  proc sort data=&baseds out=work._pdf_b;
    by &idkeys;
  run;
  proc sort data=&compds out=work._pdf_c;
    by &idkeys;
  run;
  proc sort data=work._pdf_od;
    by &idkeys;
  run;

  data work._pdf_dif_disp;
    length _DIFFVARS $400 _pva $400 _sas $400;
    %do i = 1 %to &n_avars;
      %let vn = %scan(&avar_list, &i, %str( ));
      length &vn $900;
    %end;

    merge
      work._pdf_od(in=in_d)
      work._pdf_b(in=in_b rename=(&ren_b) keep=&idkeys &avar_list)
      work._pdf_c(in=in_c rename=(&ren_c) keep=&idkeys &avar_list);
    by &idkeys;
    if in_d and in_b and in_c;

    _DIFFVARS = '';
    %do i = 1 %to &n_avars;
      %let vn = %scan(&avar_list, &i, %str( ));
      call missing(&vn);
      /* Compare actual PVA vs SAS values - not OUTDIF difference */
      if vtype(B_&vn) = 'N' then do;
        if (missing(B_&vn) and not missing(C_&vn))
           or (not missing(B_&vn) and missing(C_&vn))
           or (not missing(B_&vn) and not missing(C_&vn)
               and abs(B_&vn - C_&vn) > &criterion) then do;
          if missing(B_&vn) then _pva = '(missing)';
          else _pva = strip(vvalue(B_&vn));
          if missing(C_&vn) then _sas = '(missing)';
          else _sas = strip(vvalue(C_&vn));
          &vn = catx('0A'x, cats('PVA: ', _pva), cats('SAS: ', _sas));
          _DIFFVARS = catx(' ', _DIFFVARS, "&vn");
        end;
      end;
      else do;
        if strip(coalescec(B_&vn, '')) ne strip(coalescec(C_&vn, '')) then do;
          if missing(B_&vn) or strip(B_&vn) = '' then _pva = '(missing)';
          else _pva = strip(B_&vn);
          if missing(C_&vn) or strip(C_&vn) = '' then _sas = '(missing)';
          else _sas = strip(C_&vn);
          &vn = catx('0A'x, cats('PVA: ', _pva), cats('SAS: ', _sas));
          _DIFFVARS = catx(' ', _DIFFVARS, "&vn");
        end;
      end;
    %end;

    if strip(_DIFFVARS) ne '';
    keep &idkeys _DIFFVARS &avar_list;
  run;

  %let n_disp = 0;
  proc sql noprint;
    select count(*) into :n_disp trimmed from work._pdf_dif_disp;
  quit;

  %let ls_prev = %sysfunc(getoption(ls));
  options ls=256;

  title1 "PROC COMPARE diffs (sample) - &label - PVA over SAS (not E)";
  title2 "Sample OBS=&obs of &n_dif_use ID keys with diffs. Cell = PVA: then SAS:.";
  footnote "N=&n_dif_use unequal IDs. Raw OUTDIF is never printed (avoids date-format E).";

  proc print data=work._pdf_dif_disp(obs=&obs) width=min;
    var &idkeys _DIFFVARS &avar_list;
  run;

  title;
  footnote;
  options ls=&ls_prev;

  %put NOTE: [DIF PVA/SAS &label] Stacked sample printed - DIF_IDs=&n_dif_use rows_with_value_diffs=&n_disp obs=&obs.;

  proc datasets lib=work nolist;
    delete _pdf_od _pdf_bvars _pdf_cvars _pdf_avars _pdf_b _pdf_c _pdf_dif_disp;
  quit;

%mend m_qc_print_dif_pva_sas;
