/*--------------------------------------------------------------
  Program Name                : m_order_vars_like_ref.sas
  Purpose                     : Reorder ADaM columns to match REF/PVA var order.
                                Common vars follow &refds (or &fallback).
                                SAS-only vars insert after related anchors via
                                extra_after=EXTRA:ANCHOR pairs.
  Paths                       : Part B only (do not copy to Track A)
  Modification Log            : 24AUG2026 - KEEP/RETAIN use SQL-intersected
                                &_order only (REF names absent from &data are
                                never listed - avoids never-referenced WARNINGs).
                                set(keep=) reinforces the same list.
                                24AUG2026 - Rebuild order via SQL only (no
                                POINT=/nested SET). Nested POINT= on an empty
                                _movr_xok could raise a single engine ERROR on
                                ODA Viya during create.
                                24AUG2026 - Initial (ADSL/ADAE/BDS presentation).
--------------------------------------------------------------*/

%macro m_order_vars_like_ref(
  data=
, out=
, refds=
, fallback=
, extra_after=
);

  %local _out _have_ref _i _nm _tok _order;

  %if %length(&data) = 0 %then %do;
    %put ERROR: m_order_vars_like_ref requires data=.;
    %return;
  %end;
  %if %sysfunc(exist(&data)) = 0 %then %do;
    %put ERROR: m_order_vars_like_ref - &data not found.;
    %return;
  %end;

  %let _out = &out;
  %if %length(&_out) = 0 %then %let _out = &data;

  /* Prefer REF dictionary when the member exists */
  %let _have_ref = 0;
  %if %length(&refds) = 0 %then %do;
    %let _have_ref = 0;
  %end;
  %else %if %sysfunc(exist(&refds)) %then %do;
    %let _have_ref = 1;
  %end;

  /* Preferred order: REF dictionary, else caller fallback= list */
  %if &_have_ref %then %do;
    proc contents data=&refds out=work._movr_pref(keep=name varnum) noprint;
    run;
    data work._movr_pref;
      set work._movr_pref(rename=(varnum=seq));
      name = upcase(strip(name));
      keep name seq;
    run;
    %put NOTE: m_order_vars_like_ref using REF order from &refds.;
  %end;
  %else %do;
    data work._movr_pref;
      length name $32 seq 8;
      %let _i = 1;
      %let _nm = %upcase(%scan(&fallback, &_i, %str( )));
      %do %while(%length(&_nm));
        name = "&_nm"; seq = &_i; output;
        %let _i = %eval(&_i + 1);
        %let _nm = %upcase(%scan(&fallback, &_i, %str( )));
      %end;
      stop;
    run;
    %if %length(&refds) %then %do;
      %put NOTE: m_order_vars_like_ref - &refds missing - using fallback= list.;
    %end;
    %if %length(&fallback) = 0 %then %do;
      %put WARNING: m_order_vars_like_ref - no refds and empty fallback - order unchanged.;
    %end;
  %end;

  proc contents data=&data out=work._movr_have(keep=name varnum) noprint;
  run;
  data work._movr_have;
    set work._movr_have;
    name = upcase(strip(name));
    keep name varnum;
  run;

  data work._movr_extra;
    length extra $32 anchor $32;
    call missing(extra, anchor);
    %let _i = 1;
    %let _tok = %scan(&extra_after, &_i, %str( ));
    %do %while(%length(&_tok));
      extra  = upcase(strip(scan("&_tok", 1, ':')));
      anchor = upcase(strip(scan("&_tok", 2, ':')));
      if missing(extra) = 0 and missing(anchor) = 0 then output;
      %let _i = %eval(&_i + 1);
      %let _tok = %scan(&extra_after, &_i, %str( ));
    %end;
    stop;
  run;

  proc sql noprint;
    /* Preferred vars that exist on data, in REF/fallback order */
    create table work._movr_core as
    select p.name, p.seq as core_seq
    from work._movr_pref as p
    inner join work._movr_have as h
      on p.name = h.name
    order by p.seq;

    /* Extras that exist on data, keyed by anchor (anchor need not be on REF) */
    create table work._movr_xok0 as
    select e.extra, e.anchor
    from work._movr_extra as e
    inner join work._movr_have as h
      on e.extra = h.name;
  quit;

  /* Preserve extra_after token order for same-anchor ties (no POINT=) */
  data work._movr_xok;
    set work._movr_xok0;
    extra_seq = _N_;
  run;

  proc sql noprint;
    /* Slot each extra immediately after its anchor's core_seq */
    create table work._movr_xslot as
    select x.extra as name
         , c.core_seq + (x.extra_seq * 0.0001) as ord_seq
         , 1 as is_extra
    from work._movr_xok as x
    inner join work._movr_core as c
      on x.anchor = c.name;

    /* Core rows as ordered slots */
    create table work._movr_cslot as
    select name, core_seq as ord_seq, 0 as is_extra
    from work._movr_core;

    /* Union core + slotted extras, then leftovers by original varnum */
    create table work._movr_union as
    select name, ord_seq, is_extra from work._movr_cslot
    union all
    select name, ord_seq, is_extra from work._movr_xslot;

    create table work._movr_final as
    select u.name, u.ord_seq
    from work._movr_union as u
    union all
    select h.name, 1000000 + h.varnum as ord_seq
    from work._movr_have as h
    where h.name not in (select name from work._movr_union)
    order by ord_seq;

    /* Deduplicate preserving first ord_seq (core/extra beat leftovers) */
    create table work._movr_dedup as
    select name, min(ord_seq) as ord_seq
    from work._movr_final
    group by name
    order by ord_seq;

    select name into :_order separated by ' '
    from work._movr_dedup
    order by ord_seq;
  quit;

  %if %length(&_order) = 0 %then %do;
    %put WARNING: m_order_vars_like_ref - empty order - copying &data -> &_out unchanged.;
    data &_out;
      set &data;
    run;
  %end;
  %else %do;
    /* &_order is REF intersect data (+ slotted extras + leftovers) - never REF-only names */
    data &_out;
      retain &_order;
      set &data(keep=&_order);
    run;
  %end;

  proc datasets lib=work nolist;
    delete _movr_pref _movr_have _movr_extra _movr_core _movr_xok
           _movr_xslot _movr_cslot _movr_union _movr_final _movr_dedup;
  quit;

  %put NOTE: m_order_vars_like_ref done -> &_out.;

%mend m_order_vars_like_ref;
