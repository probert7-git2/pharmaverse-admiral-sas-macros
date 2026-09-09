# Probe PVA REF ADEG baseline: ABLFL / DTYPE / BASE vs screening means
library(haven)

adeg <- read_xpt("C:/Users/probe/SAS_mirrored_Admiral_safety_ADaM/SAS/validation/refadeg.xpt")

cat("n=", nrow(adeg), " ncol=", ncol(adeg), "\n")
cat("\n=== DTYPE ===\n")
print(table(adeg$DTYPE, useNA = "ifany"))
cat("\n=== ABLFL ===\n")
print(table(adeg$ABLFL, useNA = "ifany"))
cat("\n=== VISIT among ABLFL=Y ===\n")
print(table(adeg$VISIT[adeg$ABLFL == "Y"], useNA = "ifany"))
cat("\n=== AVISIT among ABLFL=Y ===\n")
print(table(adeg$AVISIT[adeg$ABLFL == "Y"], useNA = "ifany"))
cat("\n=== DTYPE among ABLFL=Y ===\n")
print(table(adeg$DTYPE[adeg$ABLFL == "Y"], useNA = "ifany"))
cat("\n=== PARAMCD among ABLFL=Y ===\n")
print(table(adeg$PARAMCD[adeg$ABLFL == "Y"], useNA = "ifany"))
cat("\n=== BASETYPE ===\n")
print(table(adeg$BASETYPE, useNA = "ifany"))

# Find subject with many screening EG rows for a numeric PARAMCD
scr <- adeg[!is.na(adeg$VISIT) & grepl("SCREEN", toupper(adeg$VISIT), fixed = FALSE) &
              !is.na(adeg$AVAL) & (is.na(adeg$DTYPE) | adeg$DTYPE == ""), ]
scr_n <- as.data.frame(table(USUBJID = scr$USUBJID, PARAMCD = scr$PARAMCD))
scr_n <- scr_n[scr_n$Freq >= 6, ]
scr_n <- scr_n[order(-scr_n$Freq), ]
cat("\n=== Subjects with >=6 blank-DTYPE screening rows (top 15) ===\n")
print(head(scr_n, 15))

# Pick example: prefer 01-701-1015 if present, else first with Freq==6 for HR
ex_subj <- "01-701-1015"
ex_param <- "HR"
if (!any(scr_n$USUBJID == ex_subj & scr_n$PARAMCD == ex_param)) {
  pick <- scr_n[scr_n$Freq == 6 & scr_n$PARAMCD == "HR", ][1, ]
  if (is.na(pick$USUBJID)) pick <- scr_n[1, ]
  ex_subj <- as.character(pick$USUBJID)
  ex_param <- as.character(pick$PARAMCD)
}
cat("\n=== Example subject/param:", ex_subj, ex_param, "===\n")

ex <- adeg[adeg$USUBJID == ex_subj & adeg$PARAMCD == ex_param, ]
ex <- ex[order(ex$ADT, ex$VISITNUM, ex$EGSEQ, ex$DTYPE), ]
cols <- c(
  "VISIT", "AVISIT", "AVISITN", "ADT", "ADY", "ATPT", "ATPTN",
  "AVAL", "BASE", "CHG", "PCHG", "ABLFL", "DTYPE", "BASETYPE",
  "EGSEQ", "ANL01FL", "ONTRTFL"
)
cols <- intersect(cols, names(ex))
print(as.data.frame(ex[, cols]), row.names = FALSE)

scr_vals <- ex$AVAL[!is.na(ex$VISIT) & grepl("SCREEN", toupper(ex$VISIT)) &
                      (is.na(ex$DTYPE) | ex$DTYPE == "") & !is.na(ex$AVAL)]
cat("\nScreening blank-DTYPE AVALs (n=", length(scr_vals), "):\n", sep = "")
print(scr_vals)
cat("mean =", mean(scr_vals), "\n")

abl <- ex[ex$ABLFL == "Y", cols, drop = FALSE]
cat("\nABLFL=Y row(s):\n")
print(as.data.frame(abl), row.names = FALSE)

avg_pre <- ex[!is.na(ex$DTYPE) & ex$DTYPE == "AVERAGE" &
                !is.na(ex$VISIT) & grepl("SCREEN", toupper(ex$VISIT)), ]
# Also AVERAGE with blank AVISIT (screening maps to blank AVISIT)
avg_blank <- ex[!is.na(ex$DTYPE) & ex$DTYPE == "AVERAGE" &
                  (is.na(ex$AVISIT) | ex$AVISIT == "") &
                  (!is.na(ex$ABLFL) & ex$ABLFL == "Y" | TRUE), ]
cat("\nAVERAGE rows (all):\n")
print(as.data.frame(ex[!is.na(ex$DTYPE) & ex$DTYPE == "AVERAGE", cols]), row.names = FALSE)

# Confirm BASE equals AVAL on ABLFL across sample
abl_all <- adeg[!is.na(adeg$ABLFL) & adeg$ABLFL == "Y" & !is.na(adeg$AVAL), ]
cat("\n=== ABLFL=Y: AVAL==BASE? ===\n")
print(table(abl_all$AVAL == abl_all$BASE, useNA = "ifany"))

# Post-baseline BASE should match ABLFL AVAL mean
# For one subject: BASE on week rows vs ABLFL AVAL
if (nrow(abl) > 0) {
  cat("\nABLFL AVAL =", abl$AVAL[1], "  mean(screenings) =", mean(scr_vals), "\n")
  cat("match mean?", isTRUE(all.equal(abl$AVAL[1], mean(scr_vals))), "\n")
}

# How many screening individual rows kept when AVERAGE exists?
cat("\n=== COUNT: blank DTYPE vs AVERAGE ===\n")
print(table(DTYPE = ifelse(is.na(adeg$DTYPE) | adeg$DTYPE == "", "(blank)", adeg$DTYPE)))

# ATPT usage
cat("\n=== ATPT among numeric params (sample) ===\n")
print(table(adeg$ATPT[adeg$PARAMCD == "HR"], useNA = "ifany")[1:20])
)
