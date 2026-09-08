*======================================================================
  SUPP QNAM controlled terminology

  Source of truth for the CDISC pilot / pharmaverse path:
    metacore::metacore_example("pilot_SDTM.rda")
      - CL.SUPPDM.QNAM / CL.SUPPAE.QNAM  (allowed QNAM values)
      - CL.Y_BLANK  (SUPPDM population-flag QVAL: Y / blank)
      - CL.YN       (SUPPAE TE-flag QVAL: Y/N with decode Yes/No)

  pharmaversesdtm ships SUPP *data* only (suppdm/suppae/suppds) — not CT.
  Refresh extracts:  source("R/check_pharmaverse_supp_ct.R")
                     source("R/dump_metacore_codelists.R")

  Columns:
    QNAM     $32  - supplemental qualifier name
    CODE     $40  - preferred / stored code (what ADaM should use)
    DECODE   $200 - display text / synonym that may appear in QVAL
    CLNAME   $40  - metacore/CDISC codelist id (YN, Y_BLANK, …)
    ALLOWED  $1   - Y if valid for production mapping
    NOTE     $200 - documentation

  Matching is case-insensitive on DECODE. Unknown QVAL → work.supp_ct_violations.
*======================================================================;
data metadata.supp_qnam_ct;
  length QNAM $32 CODE $40 DECODE $200 CLNAME $40 ALLOWED $1 NOTE $200;

  /* ---- SUPPDM population flags: metacore CL.Y_BLANK (Y / blank) ---- */
  /* Official code/decode from metacore CL.Y_BLANK */
  QNAM='ITT';      CODE='Y'; DECODE='Y';           CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='metacore CL.Y_BLANK'; output;
  QNAM='ITT';      CODE='Y'; DECODE='Yes';         CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='metacore CL.Y_BLANK decode'; output;
  QNAM='SAFETY';   CODE='Y'; DECODE='Y';           CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='metacore CL.Y_BLANK'; output;
  QNAM='SAFETY';   CODE='Y'; DECODE='Yes';         CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='metacore CL.Y_BLANK decode'; output;
  QNAM='EFFICACY'; CODE='Y'; DECODE='Y';           CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='metacore CL.Y_BLANK'; output;
  QNAM='EFFICACY'; CODE='Y'; DECODE='Yes';         CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='metacore CL.Y_BLANK decode'; output;
  QNAM='COMPLT8';  CODE='Y'; DECODE='Y';           CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='metacore CL.Y_BLANK'; output;
  QNAM='COMPLT8';  CODE='Y'; DECODE='Yes';         CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='metacore CL.Y_BLANK decode'; output;
  QNAM='COMPLT16'; CODE='Y'; DECODE='Y';           CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='metacore CL.Y_BLANK'; output;
  QNAM='COMPLT16'; CODE='Y'; DECODE='Yes';         CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='metacore CL.Y_BLANK decode'; output;
  QNAM='COMPLT24'; CODE='Y'; DECODE='Y';           CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='metacore CL.Y_BLANK'; output;
  QNAM='COMPLT24'; CODE='Y'; DECODE='Yes';         CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='metacore CL.Y_BLANK decode'; output;

  /* Drift synonyms (not in pilot Y_BLANK; keep for accumulating dirty text) */
  QNAM='ITT';      CODE='Y'; DECODE='YES';         CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='synonym'; output;
  QNAM='SAFETY';   CODE='Y'; DECODE='YES';         CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='synonym'; output;
  QNAM='EFFICACY'; CODE='Y'; DECODE='YES';         CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='synonym'; output;
  QNAM='COMPLT8';  CODE='Y'; DECODE='YES';         CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='synonym'; output;
  QNAM='COMPLT16'; CODE='Y'; DECODE='YES';         CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='synonym'; output;
  QNAM='COMPLT24'; CODE='Y'; DECODE='YES';         CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='synonym'; output;
  QNAM='ITT';      CODE='N'; DECODE='N';           CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='drift beyond Y_BLANK'; output;
  QNAM='ITT';      CODE='N'; DECODE='No';          CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='drift beyond Y_BLANK'; output;
  QNAM='ITT';      CODE='N'; DECODE='NO';          CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='synonym'; output;
  QNAM='SAFETY';   CODE='N'; DECODE='N';           CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='drift beyond Y_BLANK'; output;
  QNAM='SAFETY';   CODE='N'; DECODE='No';          CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='drift beyond Y_BLANK'; output;
  QNAM='SAFETY';   CODE='N'; DECODE='NO';          CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='synonym'; output;
  QNAM='EFFICACY'; CODE='N'; DECODE='N';           CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='drift beyond Y_BLANK'; output;
  QNAM='EFFICACY'; CODE='N'; DECODE='No';          CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='drift beyond Y_BLANK'; output;
  QNAM='EFFICACY'; CODE='N'; DECODE='NO';          CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='synonym'; output;
  QNAM='COMPLT8';  CODE='N'; DECODE='N';           CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='drift beyond Y_BLANK'; output;
  QNAM='COMPLT8';  CODE='N'; DECODE='No';          CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='drift beyond Y_BLANK'; output;
  QNAM='COMPLT8';  CODE='N'; DECODE='NO';          CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='synonym'; output;
  QNAM='COMPLT16'; CODE='N'; DECODE='N';           CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='drift beyond Y_BLANK'; output;
  QNAM='COMPLT16'; CODE='N'; DECODE='No';          CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='drift beyond Y_BLANK'; output;
  QNAM='COMPLT16'; CODE='N'; DECODE='NO';          CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='synonym'; output;
  QNAM='COMPLT24'; CODE='N'; DECODE='N';           CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='drift beyond Y_BLANK'; output;
  QNAM='COMPLT24'; CODE='N'; DECODE='No';          CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='drift beyond Y_BLANK'; output;
  QNAM='COMPLT24'; CODE='N'; DECODE='NO';          CLNAME='Y_BLANK'; ALLOWED='Y'; NOTE='synonym'; output;

  /* ---- SUPPAE AETRTEM: metacore CL.YN (Y/N = Yes/No) ---- */
  /* Pilot value_spec where-clause says QNAM='TRTEMFL' but data/QNAM list use AETRTEM */
  QNAM='AETRTEM';  CODE='Y'; DECODE='Y';           CLNAME='YN'; ALLOWED='Y'; NOTE='metacore CL.YN'; output;
  QNAM='AETRTEM';  CODE='N'; DECODE='N';           CLNAME='YN'; ALLOWED='Y'; NOTE='metacore CL.YN'; output;
  QNAM='AETRTEM';  CODE='Y'; DECODE='Yes';         CLNAME='YN'; ALLOWED='Y'; NOTE='metacore CL.YN decode'; output;
  QNAM='AETRTEM';  CODE='N'; DECODE='No';          CLNAME='YN'; ALLOWED='Y'; NOTE='metacore CL.YN decode'; output;
  QNAM='AETRTEM';  CODE='Y'; DECODE='YES';         CLNAME='YN'; ALLOWED='Y'; NOTE='synonym'; output;
  QNAM='AETRTEM';  CODE='N'; DECODE='NO';          CLNAME='YN'; ALLOWED='Y'; NOTE='synonym'; output;

  /* ---- SUPPDS ENTCRIT: no codelist in metacore pilot; observed pharmaversesdtm values ---- */
  QNAM='ENTCRIT';  CODE='16'; DECODE='16';         CLNAME='ENTCRIT'; ALLOWED='Y'; NOTE='pharmaversesdtm::suppds observed'; output;
  QNAM='ENTCRIT';  CODE='25'; DECODE='25';         CLNAME='ENTCRIT'; ALLOWED='Y'; NOTE='pharmaversesdtm::suppds observed'; output;
run;

proc sort data=metadata.supp_qnam_ct;
  by QNAM CODE DECODE;
run;

%put NOTE: metadata.supp_qnam_ct loaded from metacore pilot CT + drift synonyms.;
