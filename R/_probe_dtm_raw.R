# Raw XPT numerics (foreign) + haven Date-class proof for *DTM scale
suppressPackageStartupMessages({
  library(haven)
})

epoch <- as.POSIXct("1960-01-01", tz = "UTC")
sas_days <- function(x) as.numeric(difftime(as.POSIXct(x), epoch, units = "days"))

cat("==== foreign::read.xport raw numerics (what SAS stores) ====\n")
if (requireNamespace("foreign", quietly = TRUE)) {
  adsl_f <- foreign::read.xport(
    "C:/Users/probe/SAS_mirrored_Admiral_safety_ADaM/SAS/validation/refadsl.xpt"
  )
  if (is.list(adsl_f) && !is.data.frame(adsl_f)) adsl_f <- adsl_f[[1]]
  cat("TRTSDTM class=", paste(class(adsl_f$TRTSDTM), collapse = ","),
      " min/med/max=", paste(round(quantile(adsl_f$TRTSDTM, c(0, 0.5, 1), na.rm = TRUE), 2), collapse = "/"),
      "\n")
  cat("TRTSDT  class=", paste(class(adsl_f$TRTSDT), collapse = ","),
      " min/med/max=", paste(round(quantile(adsl_f$TRTSDT, c(0, 0.5, 1), na.rm = TRUE), 2), collapse = "/"),
      "\n")
  m <- !is.na(adsl_f$TRTSDTM)
  cat("TRTSDTM == TRTSDT (raw):", all(adsl_f$TRTSDTM[m] == adsl_f$TRTSDT[m]),
      " n=", sum(m), "\n")
  cat("All TRTSDTM in (0,1e5):", all(adsl_f$TRTSDTM[m] > 0 & adsl_f$TRTSDTM[m] < 1e5), "\n")
  cat("dhms midnight example:", adsl_f$TRTSDTM[m][1] * 86400, "\n")

  adae_f <- foreign::read.xport(
    "C:/Users/probe/SAS_mirrored_Admiral_safety_ADaM/SAS/validation/refadae.xpt"
  )
  if (is.list(adae_f) && !is.data.frame(adae_f)) adae_f <- adae_f[[1]]
  cat("ASTDTM min/med/max=", paste(round(quantile(adae_f$ASTDTM, c(0, 0.5, 1), na.rm = TRUE), 2), collapse = "/"),
      " n=", sum(!is.na(adae_f$ASTDTM)), "\n")
  cat("ASTDTM == ASTDT (raw):", all(adae_f$ASTDTM == adae_f$ASTDT, na.rm = TRUE), "\n")
  cat("After promote ASTDTM==dhms(ASTDT,0,0,0):",
      all(abs(adae_f$ASTDTM * 86400 - adae_f$ASTDT * 86400) < 0.5, na.rm = TRUE), "\n")
} else {
  cat("foreign not installed - haven Date proof only\n")
}

cat("\n==== haven Date-class (same files) ====\n")
adsl <- read_xpt("C:/Users/probe/SAS_mirrored_Admiral_safety_ADaM/SAS/validation/refadsl.xpt")
cat("TRTSDTM class=", paste(class(adsl$TRTSDTM), collapse = ","),
    " format.sas=", as.character(attr(adsl$TRTSDTM, "format.sas")),
    " n nonmiss=", sum(!is.na(adsl$TRTSDTM)), "\n")
cat("Implied SAS DATE days med=", median(floor(sas_days(adsl$TRTSDTM[!is.na(adsl$TRTSDTM)]))),
    " -> midnight datetime med=", median(floor(sas_days(adsl$TRTSDTM[!is.na(adsl$TRTSDTM)])) * 86400), "\n")
