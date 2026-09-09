# Probe gold XPT *DTM scale vs SAS midnight datetime
library(haven)

epoch <- as.POSIXct("1960-01-01", tz = "UTC")
sas_days <- function(x) as.numeric(difftime(as.POSIXct(x), epoch, units = "days"))
sas_secs <- function(x) as.numeric(difftime(as.POSIXct(x), epoch, units = "secs"))

cat("==== ADSL refadsl.xpt ====\n")
adsl <- read_xpt("C:/Users/probe/SAS_mirrored_Admiral_safety_ADaM/SAS/validation/refadsl.xpt")
cat("n=", nrow(adsl), "\n")
for (c in c("TRTSDTM", "TRTEDTM", "TRTSDT", "TRTEDT")) {
  x <- adsl[[c]]
  cat("---", c, "class=", paste(class(x), collapse = ","),
      "format.sas=", as.character(attr(x, "format.sas")),
      "nmiss=", sum(is.na(x)), "---\n")
  nn <- x[!is.na(x)]
  if (!length(nn)) next
  cat("  SAS DATE days min/med/max:",
      paste(round(quantile(sas_days(nn), c(0, 0.5, 1)), 4), collapse = " / "), "\n")
  # What SAS stores for Date-typed XPT vars: the DATE integer, not POSIXt secs
  raw_sas_date <- floor(sas_days(nn))
  cat("  Implied SAS numeric if DATE-typed (days): med=", median(raw_sas_date),
      " all <100000?", all(raw_sas_date > 0 & raw_sas_date < 100000), "\n")
  cat("  After dhms(date,0,0,0)=days*86400 med=", median(raw_sas_date * 86400), "\n")
  times <- format(as.POSIXct(nn), "%H:%M:%S")
  print(sort(table(times), decreasing = TRUE)[1:min(3, length(unique(times)))])
}

m <- !is.na(adsl$TRTSDTM) & !is.na(adsl$TRTSDT)
cat("ADSL both nonmiss:", sum(m), "\n")
cat("TRTSDTM days == TRTSDT days:",
    mean(floor(sas_days(adsl$TRTSDTM[m])) == floor(sas_days(adsl$TRTSDT[m]))), "\n")
cat("TRTSDTM is Date class (XPT Date-scale in SAS):", inherits(adsl$TRTSDTM, "Date"), "\n")
i <- which(m)[1]
d <- floor(sas_days(adsl$TRTSDT[i]))
cat("example: TRTSDT days=", d,
    " TRTSDTM days=", floor(sas_days(adsl$TRTSDTM[i])),
    " promoted midnight dtm=", d * 86400, "\n")
cat("n TRTSDTM nonmiss (expect 254 diffs if unfixed)=", sum(!is.na(adsl$TRTSDTM)), "\n")

cat("\n==== ADAE refadae.xpt ====\n")
adae <- read_xpt("C:/Users/probe/SAS_mirrored_Admiral_safety_ADaM/SAS/validation/refadae.xpt")
cat("n=", nrow(adae), "\n")
for (c in c("ASTDTM", "AENDTM", "LDOSEDTM", "ASTDT", "AENDT")) {
  x <- adae[[c]]
  cat("---", c, "class=", paste(class(x), collapse = ","),
      "format.sas=", as.character(attr(x, "format.sas")),
      "nmiss=", sum(is.na(x)), "---\n")
  nn <- x[!is.na(x)]
  if (!length(nn)) next
  raw_sas_date <- floor(sas_days(nn))
  cat("  SAS DATE days med=", median(raw_sas_date),
      " all in (0,1e5)?", all(raw_sas_date > 0 & raw_sas_date < 100000), "\n")
  cat("  promoted dhms med=", median(raw_sas_date * 86400), "\n")
  times <- format(as.POSIXct(nn), "%H:%M:%S")
  print(sort(table(times), decreasing = TRUE)[1:min(5, length(unique(times)))])
}

m <- !is.na(adae$ASTDTM) & !is.na(adae$ASTDT)
cat("ADAE both nonmiss:", sum(m), " ASTDTM n=", sum(!is.na(adae$ASTDTM)), "\n")
cat("ASTDTM days == ASTDT:",
    mean(floor(sas_days(adae$ASTDTM[m])) == floor(sas_days(adae$ASTDT[m]))), "\n")
cat("ASTDTM Date class:", inherits(adae$ASTDTM, "Date"), "\n")
# Simulate promotion equality to dhms(ASTDT,0,0,0)
prom <- floor(sas_days(adae$ASTDTM[m])) * 86400
expect <- floor(sas_days(adae$ASTDT[m])) * 86400
cat("After promote, ASTDTM == dhms(ASTDT,0,0,0)?", mean(abs(prom - expect) < 0.5), "\n")
cat("n ASTDTM nonmiss (expect ~1191 if all rows differ on DTM)=", sum(!is.na(adae$ASTDTM)), "\n")
cat("n rows=", nrow(adae), "\n")

# Threshold bug check: are any date-scale values >= 100000? (no for study dates)
raw <- floor(sas_days(adae$ASTDTM[!is.na(adae$ASTDTM)]))
cat("ASTDTM date-scale max=", max(raw), " threshold 100000 ok?", max(raw) < 100000, "\n")
