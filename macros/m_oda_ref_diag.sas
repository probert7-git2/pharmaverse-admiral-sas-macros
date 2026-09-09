/*--------------------------------------------------------------
  Program Name                : m_oda_ref_diag.sas
  Purpose                     : DEFINE ONLY %m_oda_ref_diag - no driver %includes here.
  CRITICAL                    : This file must not %include init/convert/QC programs.
                                Wrong contents on ODA cause infinite %%include recursion.
--------------------------------------------------------------*/

%macro m_oda_ref_diag;
  /* Studio-visible: where REF points and whether ref.ref_adsl is findable.
     Call after libname ref. Avoid ; inside * comments / mid-%put text. */
  %local _pn _libok _fx_dir _fx_lo _fx_up _fx_xpt _fx_stem _ex;
  %let _pn = %sysfunc(pathname(ref));
  %let _libok = %sysfunc(libref(ref));
  %let _fx_dir = %sysfunc(fileexist(&REFDIR));
  %let _fx_lo  = %sysfunc(fileexist(&REFDIR/ref_adsl.sas7bdat));
  %let _fx_up  = %sysfunc(fileexist(&REFDIR/REF_ADSL.sas7bdat));
  %let _fx_xpt = %sysfunc(fileexist(&REFDIR/refadsl.xpt));
  %let _fx_stem = %sysfunc(fileexist(&REFDIR/refadsl.sas7bdat));
  %if &_fx_stem = 0 %then %let _fx_stem = %sysfunc(fileexist(&REFDIR/REFADSL.sas7bdat));
  %let _ex = %sysfunc(exist(ref.ref_adsl));

  %put NOTE: ===== REF diagnostics =====;
  %put NOTE: REFDIR=&REFDIR;
  %put NOTE: pathname(ref)=&_pn;
  %put NOTE: libref(ref) rc=&_libok (0=assigned);
  %put NOTE: fileexist(REFDIR)=&_fx_dir;
  %put NOTE: fileexist(ref_adsl.sas7bdat)=&_fx_lo;
  %put NOTE: fileexist(REF_ADSL.sas7bdat)=&_fx_up;
  %put NOTE: fileexist(refadsl.xpt)=&_fx_xpt;
  %put NOTE: fileexist(refadsl|REFADSL.sas7bdat)=&_fx_stem;
  %put NOTE: exist(ref.ref_adsl)=&_ex;
  %put NOTE: Expected: pathname(ref) ends in /SAS/validation and exist(ref.ref_adsl)=1;

  %if &_libok ne 0 %then %do;
    %put WARNING: libname ref not assigned - create &REFDIR and re-run init.;
  %end;
  %if &_ex = 0 %then %do;
    /* Linux ODA: physical names are case-sensitive. ODA Files may show REF_ADSL. */
    %if &_fx_up = 1 and &_fx_lo = 0 %then %do;
      %put WARNING: Found REF_ADSL.sas7bdat (wrong case for Linux) - renaming to ref_adsl.sas7bdat.;
      data _null_;
        rc = rename("&REFDIR/REF_ADSL.sas7bdat", "&REFDIR/ref_adsl.sas7bdat", "file");
        put "NOTE: rename REF_ADSL -> ref_adsl rc=" rc;
      run;
    %end;
    /* Convert writes mem=ref_adsl - XPT stem REFADSL as sas7bdat is the wrong member name */
    %if %sysfunc(exist(ref.ref_adsl)) = 0 %then %do;
      %if %sysfunc(fileexist(&REFDIR/REFADSL.sas7bdat)) %then %do;
        %put WARNING: Found REFADSL.sas7bdat (XPT stem) - renaming to ref_adsl.sas7bdat.;
        data _null_;
          rc = rename("&REFDIR/REFADSL.sas7bdat", "&REFDIR/ref_adsl.sas7bdat", "file");
          put "NOTE: rename REFADSL -> ref_adsl rc=" rc;
        run;
      %end;
      %else %if %sysfunc(fileexist(&REFDIR/refadsl.sas7bdat)) %then %do;
        %put WARNING: Found refadsl.sas7bdat (XPT stem) - renaming to ref_adsl.sas7bdat.;
        data _null_;
          rc = rename("&REFDIR/refadsl.sas7bdat", "&REFDIR/ref_adsl.sas7bdat", "file");
          put "NOTE: rename refadsl -> ref_adsl rc=" rc;
        run;
      %end;
    %end;
    %if &_fx_xpt = 1 and %sysfunc(exist(ref.ref_adsl)) = 0 %then %do;
      %put WARNING: refadsl.xpt present but ref.ref_adsl missing - load ref_adsl.sas7bdat into validation/;
    %end;
    %if &_fx_lo = 0 and &_fx_up = 0 and &_fx_xpt = 0 and &_fx_stem = 0 %then %do;
      %put WARNING: No ref ADSL under &REFDIR yet - upload refadsl.xpt then convert, or upload ref_adsl.sas7bdat.;
    %end;
  %end;

  /* List REF* / *ADSL* names in validation/ (Studio Log) */
  data _null_;
    length name $256;
    rc = filename("_refd", "&REFDIR");
    did = dopen("_refd");
    if did = 0 then put "WARNING: cannot dopen REFDIR=&REFDIR";
    else do;
      nmem = dnum(did);
      put "NOTE: ===== REFDIR listing (REF* / *ADSL*) n=" nmem " =====";
      do i = 1 to nmem;
        name = dread(did, i);
        if index(upcase(name), "REF") or index(upcase(name), "ADSL") then
          put "NOTE:   " name;
      end;
      rc = dclose(did);
    end;
    rc = filename("_refd");
  run;

  %put NOTE: ===== end REF diagnostics (exist(ref.ref_adsl)=%sysfunc(exist(ref.ref_adsl))) =====;
%mend m_oda_ref_diag;
