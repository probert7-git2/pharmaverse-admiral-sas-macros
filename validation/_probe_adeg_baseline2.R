# Follow-up: confirm ADEG ABLFL = last AVERAGE ADT<=TRTSDT (not mean of 6 screenings)
library(haven)

adeg <- read_xpt("C:/Users/probe/SAS_mirrored_Admiral_safety_ADaM/SAS/validation/refadeg.xpt")

# ABLFL visit pattern
abl <- adeg[!is.na(adeg$ABLFL) & adeg$ABLFL == "Y", ]
cat("ABLFL n=", nrow(abl), "\n")
cat("AVISITN:\n"); print(table(abl$AVISITN, useNA = "ifany"))
cat("ADY:\n"); print(table(abl$ADY, useNA = "ifany"))
cat("VISIT blank?\n"); print(table(is.na(abl$VISIT) | abl$VISIT == "", useNA = "ifany"))
cat("DTYPE:\n"); print(table(abl$DTYPE, useNA = "ifany"))

# Compare ABLFL AVAL vs mean of blank-DTYPE screenings vs mean of Baseline blank-DTYPE
check_one <- function(subj, param) {
  ex <- adeg[adeg$USUBJID == subj & adeg$PARAMCD == param, ]
  scr <- ex$AVAL[!is.na(ex$VISIT) & grepl("SCREEN", toupper(ex$VISIT)) &
                   (is.na(ex$DTYPE) | ex$DTYPE == "") & !is.na(ex$AVAL)]
  bl <- ex$AVAL[!is.na(ex$VISIT) & toupper(ex$VISIT) == "BASELINE" &
                  (is.na(ex$DTYPE) | ex$DTYPE == "") & !is.na(ex$AVAL)]
  abl_aval <- ex$AVAL[!is.na(ex$ABLFL) & ex$ABLFL == "Y"][1]
  bl_avg_row <- ex$AVAL[!is.na(ex$DTYPE) & ex$DTYPE == "AVERAGE" &
                          !is.na(ex$AVISIT) & ex$AVISIT == "Baseline"][1]
  data.frame(
    USUBJID = subj, PARAMCD = param,
    n_scr = length(scr), mean_scr = mean(scr),
    n_bl = length(bl), mean_bl = mean(bl),
    abl_aval = abl_aval, bl_avg_row = bl_avg_row,
    match_scr = isTRUE(all.equal(abl_aval, mean(scr))),
    match_bl = isTRUE(all.equal(abl_aval, mean(bl))),
    match_bl_avg = isTRUE(all.equal(abl_aval, bl_avg_row))
  )
}

subs <- unique(as.character(abl$USUBJID))[1:20]
params <- c("HR", "QT", "RR")
rows <- list()
i <- 1
for (s in subs) {
  for (p in params) {
    if (any(adeg$USUBJID == s & adeg$PARAMCD == p & adeg$ABLFL == "Y", na.rm = TRUE)) {
      rows[[i]] <- check_one(s, p)
      i <- i + 1
    }
  }
}
res <- do.call(rbind, rows)
cat("\n=== Sample match rates ===\n")
print(res)
cat("\nmatch_scr TRUE count:", sum(res$match_scr), "/", nrow(res), "\n")
cat("match_bl TRUE count:", sum(res$match_bl), "/", nrow(res), "\n")
cat("match_bl_avg TRUE count:", sum(res$match_bl_avg, na.rm = TRUE), "/", nrow(res), "\n")

# Any ABLFL not on Baseline?
cat("\nNon-Baseline ABLFL AVISIT:\n")
print(table(abl$AVISIT, useNA = "ifany"))

# CHG blank when AVISITN<=0?
cat("\nCHG missing rate by AVISITN>0:\n")
adeg$post <- !is.na(adeg$AVISITN) & adeg$AVISITN > 0
cat("post CHG nonmiss:", mean(!is.na(adeg$CHG[adeg$post])), "\n")
cat("pre/bl CHG nonmiss:", mean(!is.na(adeg$CHG[!adeg$post])), "\n")

# Subjects where screening mean would wrongly be used
cat("\nExample BASE vs mean_scr for 01-701-1015:\n")
print(check_one("01-701-1015", "HR"))
print(check_one("01-701-1015", "QT"))
print(check_one("01-701-1015", "QTCFR"))
)
