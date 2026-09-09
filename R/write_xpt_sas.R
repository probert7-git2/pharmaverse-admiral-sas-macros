# Write SAS Version-5 XPT that SAS XPORT engine can actually read.
#
# Known pitfall: haven::write_xpt(..., version = 8) [the default] can produce
# files where SAS sees all variables but 0 observations (missing OBSV8 count;
# tidyverse/haven#756). Always use version = 5 for ODA / classic XPORT.

prep_xpt_v5 <- function(df, member) {
  stopifnot(is.data.frame(df))
  member <- toupper(substr(as.character(member), 1L, 8L))

  out <- as.data.frame(df, stringsAsFactors = FALSE)

  keep <- vapply(out, function(x) {
    !(is.list(x) && !inherits(x, c("Date", "POSIXt", "difftime")))
  }, logical(1))
  out <- out[keep]

  names(out) <- toupper(substr(names(out), 1L, 8L))
  if (anyDuplicated(names(out))) {
    stop("Duplicate names after truncating to 8 chars for member ", member)
  }

  for (nm in names(out)) {
    x <- out[[nm]]
    lab <- attr(x, "label")
    if (!is.null(lab)) {
      attr(x, "label") <- substr(as.character(lab), 1L, 40L)
    }

    if (inherits(x, "POSIXt")) {
      # Keep POSIXt so *DTM vars write as SAS datetime.
      # Do NOT as.Date() here - that collapsed TRTSDTM/ASTDTM to date-scale
      # (~16000) in ref*.xpt while Part B adam stores true datetime (~1.4e9),
      # which made PROC COMPARE FAIL every treated ADSL row (254) and every
      # ADAE row (1191) even when *TMF and *DT already matched.
      # haven::write_xpt(version=5) accepts POSIXct as SAS datetime.
    } else if (inherits(x, "Date")) {
      # leave Date as Date (SAS date)
    }

    if (is.factor(x)) {
      x <- as.character(x)
    }

    if (is.character(x)) {
      enc <- enc2utf8(x)
      enc[is.na(enc)] <- ""
      long <- nchar(enc, type = "chars", allowNA = TRUE) > 200L
      long[is.na(long)] <- FALSE
      if (any(long)) {
        enc[long] <- substr(enc[long], 1L, 200L)
        warning(member, ".", nm, ": truncated ", sum(long), " values to 200 chars")
      }
      x <- enc
      if (!is.null(lab)) attr(x, "label") <- substr(as.character(lab), 1L, 40L)
    }

    out[[nm]] <- x
  }

  attr(out, "label") <- member
  out
}

write_xpt_sas <- function(df, path, member) {
  member <- toupper(substr(as.character(member), 1L, 8L))
  df2 <- prep_xpt_v5(df, member)
  n_in <- nrow(df2)
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)

  wrote_with <- NA_character_

  if (requireNamespace("haven", quietly = TRUE)) {
    haven::write_xpt(df2, path, version = 5, name = member)
    wrote_with <- "haven::write_xpt(version=5)"
  } else if (requireNamespace("foreign", quietly = TRUE) &&
             exists("write.xport", envir = asNamespace("foreign"), inherits = FALSE)) {
    args <- list(df2, file = path)
    names(args) <- c(member, "file")
    do.call(get("write.xport", envir = asNamespace("foreign")), args)
    wrote_with <- "foreign::write.xport"
  } else {
    stop("Need package 'haven' (preferred) or 'foreign' with write.xport")
  }

  n_out <- NA_integer_
  if (requireNamespace("haven", quietly = TRUE)) {
    chk <- tryCatch(haven::read_xpt(path), error = function(e) e)
    if (inherits(chk, "error")) {
      stop("Wrote ", path, " with ", wrote_with, " but haven cannot read it: ",
           conditionMessage(chk))
    }
    n_out <- nrow(chk)
  } else if (requireNamespace("foreign", quietly = TRUE)) {
    chk <- foreign::read.xport(path)
    if (is.list(chk) && !is.data.frame(chk)) chk <- chk[[1]]
    n_out <- nrow(chk)
  }

  if (!is.na(n_out) && n_out != n_in) {
    stop(
      "XPT round-trip row mismatch for ", path, ": wrote ", n_in,
      " rows, read back ", n_out, " (writer=", wrote_with, "). ",
      "Do not upload this file."
    )
  }

  sz <- file.info(path)$size
  message(
    "  ", basename(path), ": ", n_in, " rows, ", sz, " bytes, member=", member,
    " via ", wrote_with
  )
  if (is.na(sz) || sz < 100) warning("XPT looks too small: ", path)

  invisible(path)
}
