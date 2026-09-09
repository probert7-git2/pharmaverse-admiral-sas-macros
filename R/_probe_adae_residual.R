# Probe remaining ADAE value_diffs after *DTM scale promote + midnight collapse.
# Gold: validation/refadae.xpt (pharmaverseadam). Optional SAS: env ADAE_SAS_XPT.
suppressPackageStartupMessages({
  library(haven)
  library(dplyr)
})

epoch <- as.POSIXct("1960-01-01", tz = "UTC")
sas_days <- function(x) {
  if (inherits(x, "Date")) return(as.numeric(x) - as.numeric(as.Date("1960-01-01")))
  as.numeric(difftime(as.POSIXct(x), epoch, units = "days"))
}
sas_secs <- function(x) {
  if (inherits(x, "Date")) return((as.numeric(x) - as.numeric(as.Date("1960-01-01"))) * 86400)
  as.numeric(difftime(as.POSIXct(x), epoch, units = "secs"))
}

gold_path <- "C:/Users/probe/SAS_mirrored_Admiral_safety_ADaM/SAS/validation/refadae.xpt"
g <- read_xpt(gold_path)
cat("==== GOLD refadae ====\n")
cat("n rows=", nrow(g), "\n")

dtm_cols <- grep("DTM$", names(g), value = TRUE)
cat("DTM cols:", paste(dtm_cols, collapse = ", "), "\n")

for (c in c(dtm_cols, "ASTDT", "AENDT", "LDOSEDT", "ASTTMF", "AENTMF", "ASTDTF", "AENDTF",
            "TRTEMFL", "DOSEON", "ASTDY", "AENDY", "ADURN", "ASEV", "AESEV")) {
  if (!c %in% names(g)) next
  x <- g[[c]]
  nmiss <- sum(is.na(x) | (is.character(x) & trimws(as.character(x)) == ""))
  nnon <- nrow(g) - nmiss
  cat(sprintf("  %-10s n_nonmiss=%4d class=%s\n", c, nnon,
              paste(class(x), collapse = ",")))
  if (c %in% dtm_cols && nnon > 0) {
    days <- floor(sas_days(x[!is.na(x)]))
    cat(sprintf("    date-scale med=%s all<1e5=%s\n",
                median(days), all(days > 0 & days < 1e5)))
    times <- format(as.POSIXct(x[!is.na(x)]), "%H:%M:%S")
    print(sort(table(times), decreasing = TRUE)[1:min(5, length(unique(times)))])
  }
  if (c %in% c("ASTTMF", "AENTMF", "ASTDTF", "AENDTF", "TRTEMFL") && nnon > 0) {
    print(table(as.character(x), useNA = "ifany"))
  }
}

# Simulate QC norm: promote date-scale *DTM to midnight datetime
promote_mid <- function(x) {
  out <- rep(NA_real_, length(x))
  ok <- !is.na(x)
  d <- floor(sas_days(x[ok]))
  # gold is Date -> always midnight after promote
  out[ok] <- d * 86400
  out
}

# Simulate SAS builder DTM from gold *DT (date) + first/last time
sim_sas_astdtm <- function(astdt) {
  ok <- !is.na(astdt)
  out <- rep(NA_real_, length(astdt))
  d <- floor(sas_days(astdt[ok]))
  out[ok] <- d * 86400  # first = midnight
  out
}
sim_sas_aendtm <- function(aendt) {
  ok <- !is.na(aendt)
  out <- rep(NA_real_, length(aendt))
  d <- floor(sas_days(aendt[ok]))
  out[ok] <- d * 86400 + 86399  # last = 23:59:59
  out
}

cat("\n==== Simulate post-promote residuals (gold Date vs SAS datetime) ====\n")
g_ast <- promote_mid(g$ASTDTM)
g_aen <- promote_mid(g$AENDTM)
s_ast <- sim_sas_astdtm(g$ASTDT)  # use ASTDT as date of ASTDTM
# Prefer gold ASTDT when present
if ("ASTDT" %in% names(g)) s_ast <- sim_sas_astdtm(g$ASTDT)
s_aen <- if ("AENDT" %in% names(g)) sim_sas_aendtm(g$AENDT) else sim_sas_aendtm(g$AENDTM)

# Without midnight collapse
diff_ast_raw <- sum(!is.na(g_ast) & !is.na(s_ast) & abs(g_ast - s_ast) > 0.5, na.rm = TRUE)
# AENDTM: gold midnight vs SAS 23:59:59
both_aen <- !is.na(g_aen) & !is.na(s_aen)
diff_aen_raw <- sum(both_aen & abs(g_aen - s_aen) > 0.5)
cat("ASTDTM diffs WITHOUT midnight collapse (should be ~0 if both midnight):",
    sum(!is.na(g_ast) & !is.na(s_ast) & abs(g_ast - s_ast) > 0.5), "\n")
cat("AENDTM diffs WITHOUT midnight collapse (gold mid vs SAS 23:59:59):",
    diff_aen_raw, " of paired=", sum(both_aen), "\n")

# With midnight collapse on SAS side
s_aen_mid <- ifelse(is.na(s_aen), NA_real_, floor(s_aen / 86400) * 86400)
diff_aen_mid <- sum(both_aen & abs(g_aen - s_aen_mid) > 0.5)
cat("AENDTM diffs WITH midnight collapse:", diff_aen_mid, "\n")

# LDOSEDTM: gold Date vs SAS EX start datetime (first -> midnight usually)
if ("LDOSEDTM" %in% names(g)) {
  g_ld <- promote_mid(g$LDOSEDTM)
  cat("LDOSEDTM gold nonmiss=", sum(!is.na(g$LDOSEDTM)),
      " after promote all midnight by construction\n")
}

# If only AENDTM drives residual without collapse:
cat("\nHypothesis: value_diffs~1148 ≈ AENDTM nonmiss without midnight collapse\n")
cat("AENDTM nonmiss=", sum(!is.na(g$AENDTM)), "\n")
cat("ASTDTM nonmiss=", sum(!is.na(g$ASTDTM)), "\n")
cat("rows=", nrow(g), "\n")
cat("1191-1148=", 1191 - 1148, " (possible ASTDTM-only rows fixed by promote alone)\n")

# Rows with ASTDTM but missing AENDTM
cat("ASTDTM present AENDTM miss=",
    sum(!is.na(g$ASTDTM) & is.na(g$AENDTM)), "\n")
cat("Both DTM present=",
    sum(!is.na(g$ASTDTM) & !is.na(g$AENDTM)), "\n")

# Optional: compare to a SAS-built XPT if provided
sas_path <- Sys.getenv("ADAE_SAS_XPT", unset = "")
cands <- c(
  sas_path,
  "C:/Users/probe/Downloads/adam_adae.xpt",
  "C:/Users/probe/Downloads/adae_pva.xpt",
  "C:/Users/probe/SAS_mirrored_Admiral_safety_ADaM/SAS/validation/adae.xpt",
  "C:/Users/probe/safety_monitoring_system/R/adam_xpt/adae.xpt"
)
cands <- unique(cands[nzchar(cands) & file.exists(cands)])
if (length(cands)) {
  cat("\n==== Pairwise vs SAS XPT:", cands[[1]], "====\n")
  s <- read_xpt(cands[[1]])
  keys <- c("USUBJID", "ASTDT", "AEDECOD", "ASEV", "AESEQ")
  keys <- keys[keys %in% names(g) & keys %in% names(s)]
  # normalize key dates
  for (k in keys) {
    if (inherits(g[[k]], "Date") || inherits(s[[k]], "Date")) {
      g[[k]] <- as.Date(g[[k]])
      s[[k]] <- as.Date(s[[k]])
    }
  }
  if (!"ASEV" %in% names(s) && "AESEV" %in% names(s)) s$ASEV <- s$AESEV
  common <- intersect(names(g), names(s))
  common <- setdiff(common, c(keys, "AESEQ"))  # AESEQ may be key
  # join
  g2 <- g %>% mutate(.rid = row_number())
  # coerce ASTDT
  if ("ASTDT" %in% names(g2)) g2$ASTDT <- as.Date(g2$ASTDT)
  if ("ASTDT" %in% names(s)) s$ASTDT <- as.Date(s$ASTDT)
  j <- inner_join(
    g2, s,
    by = intersect(c("USUBJID", "ASTDT", "AEDECOD", "ASEV", "AESEQ"), names(s)),
    suffix = c(".g", ".s")
  )
  cat("paired rows=", nrow(j), " gold=", nrow(g), " sas=", nrow(s), "\n")
  # After promote+midnight, count per-var diffs
  score <- list()
  for (v in common) {
    vg <- j[[paste0(v, ".g")]]
    vs <- j[[paste0(v, ".s")]]
    if (is.null(vg) || is.null(vs)) {
      # unsuffixed if only one side had it - skip
      next
    }
    if (inherits(vg, "Date") || inherits(vs, "Date") || grepl("DTM$|DT$", v)) {
      # numeric compare after promote midnight for *DTM
      ng <- sas_secs(vg)
      ns <- sas_secs(vs)
      if (grepl("DTM$", v)) {
        # promote date-scale
        ng <- ifelse(!is.na(ng) & ng > 0 & ng < 1e5, ng * 86400, ng)
        ns <- ifelse(!is.na(ns) & ns > 0 & ns < 1e5, ns * 86400, ns)
        # midnight collapse
        ng <- ifelse(!is.na(ng) & ng >= 1e5, floor(ng / 86400) * 86400, ng)
        ns <- ifelse(!is.na(ns) & ns >= 1e5, floor(ns / 86400) * 86400, ns)
      } else if (grepl("DT$", v)) {
        ng <- floor(sas_days(vg))
        ns <- floor(sas_days(vs))
      }
      nd <- sum(!is.na(ng) & !is.na(ns) & abs(ng - ns) > 0.5)
      # also miss vs nonmiss
      nd <- nd + sum(xor(is.na(ng), is.na(ns)))
    } else if (is.numeric(vg) || is.numeric(vs)) {
      nd <- sum(!is.na(vg) & !is.na(vs) & abs(as.numeric(vg) - as.numeric(vs)) > 1e-8)
      nd <- nd + sum(xor(is.na(vg), is.na(vs)))
    } else {
      cg <- trimws(as.character(vg)); cg[is.na(vg)] <- NA
      cs <- trimws(as.character(vs)); cs[is.na(vs)] <- NA
      cg[cg == ""] <- NA; cs[cs == ""] <- NA
      nd <- sum(!is.na(cg) & !is.na(cs) & toupper(cg) != toupper(cs))
      nd <- nd + sum(xor(is.na(cg), is.na(cs)))
    }
    if (nd > 0) score[[v]] <- nd
  }
  score <- sort(unlist(score), decreasing = TRUE)
  cat("Top unequal vars AFTER promote+midnight:\n")
  print(head(score, 25))
  # Also WITHOUT midnight collapse for DTM
  score2 <- list()
  for (v in grep("DTM$", common, value = TRUE)) {
    vg <- j[[paste0(v, ".g")]]; vs <- j[[paste0(v, ".s")]]
    if (is.null(vg) || is.null(vs)) next
    ng <- sas_secs(vg); ns <- sas_secs(vs)
    ng <- ifelse(!is.na(ng) & ng > 0 & ng < 1e5, ng * 86400, ng)
    ns <- ifelse(!is.na(ns) & ns > 0 & ns < 1e5, ns * 86400, ns)
    nd <- sum(!is.na(ng) & !is.na(ns) & abs(ng - ns) > 0.5)
    score2[[v]] <- nd
  }
  cat("DTM unequal WITHOUT midnight collapse:\n")
  print(unlist(score2))
} else {
  cat("\nNo SAS ADAE XPT found locally - gold-only hypothesis above.\n")
  cat("Searched:", paste(c(
    "Downloads/adam_adae.xpt", "Downloads/adae_pva.xpt",
    "validation/adae.xpt", "R/adam_xpt/adae.xpt"
  ), collapse = ", "), "\n")
}

# pharmaverseadam package direct if available
if (requireNamespace("pharmaverseadam", quietly = TRUE)) {
  cat("\n==== pharmaverseadam::adae package ====\n")
  data("adae", package = "pharmaverseadam")
  cat("n=", nrow(adae), " version=", as.character(packageVersion("pharmaverseadam")), "\n")
  for (c in c("ASTDTM", "AENDTM", "LDOSEDTM", "ASTTMF", "AENTMF")) {
    if (!c %in% names(adae)) next
    x <- adae[[c]]
    cat(c, " n_nonmiss=", sum(!is.na(x) & !(is.character(x) & x == "")),
        " class=", paste(class(x), collapse = ","), "\n")
  }
}
