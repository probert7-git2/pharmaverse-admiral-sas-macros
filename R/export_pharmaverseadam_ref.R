# Export upstream Pharmaverse ADaM (pharmaverseadam) as SAS XPT gold

# Track B gold - NOT the safety_monitoring_system template script.
# Source: CRAN/GitHub pharmaverseadam (admiral template outputs on pharmaversesdtm).

required_pkgs <- c("pharmaverseadam", "dplyr", "tibble")
missing <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) {
  stop(
    "Install missing packages: ", paste(missing, collapse = ", "),
    "\n  install.packages(c(",
    paste(sprintf("'%s'", missing), collapse = ", "),
    ", 'haven'))"
  )
}
if (!requireNamespace("haven", quietly = TRUE) &&
    !requireNamespace("foreign", quietly = TRUE)) {
  stop("Install haven and/or foreign for XPT write.")
}

library(dplyr)
library(tibble)

root <- if (basename(getwd()) == "R") dirname(getwd()) else getwd()
source(file.path(root, "R", "write_xpt_sas.R"))
out_dir <- file.path(root, "validation")
if (!dir.exists(out_dir)) dir.create(out_dir, recursive = TRUE)

# Official package ADaMs (names as shipped)
pva_sets <- c("adsl", "adae", "adcm", "advs", "adeg", "adlb")

restore_date_cols <- function(df) {
  date_like <- grep("DT$|DTM$", names(df), value = TRUE)
  for (nm in date_like) {
    x <- df[[nm]]
    if (inherits(x, "Date") || inherits(x, "POSIXt")) next
    if (is.numeric(x)) {
      # Prefer SAS-epoch if values look like SAS dates (year >= 1985 as SAS date)
      # else treat as R 1970-epoch days
      as_sas <- as.Date(x, origin = "1960-01-01")
      as_r <- as.Date(x, origin = "1970-01-01")
      use_r <- sum(!is.na(x) & as.integer(format(as_r, "%Y")) >= 1985, na.rm = TRUE) >
        sum(!is.na(x) & as.integer(format(as_sas, "%Y")) >= 1985, na.rm = TRUE)
      df[[nm]] <- if (use_r) as_r else as_sas
    }
  }
  df
}

message("Loading pharmaverseadam datasets: ", paste(pva_sets, collapse = ", "))

for (nm in pva_sets) {
  data(list = nm, package = "pharmaverseadam", envir = environment())
  df <- get(nm)
  stopifnot(is.data.frame(df), nrow(df) > 0)

  if (nm == "adsl") {
    if (!"TRTSDT" %in% names(df)) {
      stop("pharmaverseadam::adsl has no TRTSDT - unexpected package contents.")
    }
    n_trt <- sum(!is.na(df$TRTSDT))
    message(sprintf("  adsl TRTSDT non-missing: %d / %d", n_trt, nrow(df)))
    if (n_trt == 0L) {
      stop("pharmaverseadam::adsl has 0 non-missing TRTSDT - aborting export.")
    }
  }

  # XPT member names max 8 chars: refadsl, refadae, ...
  xpt_file <- paste0("ref", substr(nm, 1L, 5L))
  if (nchar(xpt_file) > 8L) xpt_file <- substr(xpt_file, 1L, 8L)
  # Stable map
  xpt_map <- c(
    adsl = "refadsl",
    adae = "refadae",
    adcm = "refadcm",
    advs = "refadvs",
    adeg = "refadeg",
    adlb = "refadlb"
  )
  xpt_file <- unname(xpt_map[[nm]])

  path <- file.path(out_dir, paste0(xpt_file, ".xpt"))
  write_xpt_sas(restore_date_cols(df), path, member = xpt_file)
  message("  → ", path, "  (after proc copy: member ", toupper(xpt_file), " / ", xpt_file, ")")
}

message("\nExported Pharmaverseadam refs to ", normalizePath(out_dir, winslash = "/"))
message("Next: proc copy ref*.xpt into validation/ then run_qc_compare_pva_oda.sas")
