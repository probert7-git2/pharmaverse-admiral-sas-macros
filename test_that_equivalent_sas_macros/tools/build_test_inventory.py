#!/usr/bin/env python3
"""Regenerate mapping/test_inventory.csv from a local clone of pharmaverse/admiral.

Usage:
    python build_test_inventory.py /path/to/admiral [--out ../mapping/test_inventory.csv]
"""
import argparse
import csv
import re
from pathlib import Path

COLUMNS = [
    "r_file", "r_test_name", "r_line_start", "r_line_end", "r_category",
    "r_expectation_type", "r_function_under_test", "porting_tier",
    "sas_port_status", "sas_notes",
]

TEST_RE = re.compile(r"^\s*test_that\(")
HEADER_RE = re.compile(r"^#\s*([A-Za-z_.][\w.]*)\s*(?:----|####)\s*$")
EXPECT_RE = re.compile(r"\b(expect_[A-Za-z0-9_]+)\s*\(")
# priority order when a block has several expectation kinds
PRIORITY = ["expect_snapshot", "expect_error", "expect_warning", "expect_message",
            "expect_dfs_equal", "expect_equal", "expect_identical"]
R_SPECIFIC_FILES = {
    "call_derivation", "restrict_derivation", "slice_derivation", "event",
    "admiral_options", "admiral_df", "user_helpers", "user_utils",
    "consolidate_metadata", "duplicates", "period_dataset",
}
CORE = R_SPECIFIC_FILES
SCALAR_FILES = {"dt_level", "convert_xxtpt_to_hours", "transform_range"}
DATE_FILES = {"dt_level", "derive_var_trtdurd", "derive_var_nfrlt"}
RECORD = ("derive_basetype_records", "derive_expected_records", "derive_extreme_event",
          "derive_extreme_records", "derive_joined", "derive_locf_records",
          "derive_merged", "derive_summary_records", "filter_", "get_",
          "create_", "derive_vars_merged")


def category(stem):
    if stem in CORE:
        return "core_infrastructure"
    if stem.startswith("compute_") or stem in SCALAR_FILES - {"dt_level"}:
        return "compute"
    if (stem in DATE_FILES or re.match(r"derive_vars_(dt|dtm|dy|duration|aage)", stem)
            or stem.startswith("derive_vars_dtm_")):
        return "date_time"
    if stem.startswith("derive_param_"):
        return "derive_param"
    if stem.startswith(RECORD):
        return "record_filter_dataset_creation"
    if stem.startswith("derive_var_"):
        return "derive_var"
    if stem.startswith("derive_vars_"):
        return "derive_vars"
    return "other"


def find_end(lines, start):
    """Line index (0-based) where the test_that( call closes; string/comment aware."""
    depth, quote = 0, None
    for i in range(start, len(lines)):
        line, j = lines[i], 0
        while j < len(line):
            c = line[j]
            if quote:
                if c == "\\":
                    j += 1
                elif c == quote:
                    quote = None
            elif c in "\"'`":
                quote = c
            elif c == "#":
                break
            elif c == "(":
                depth += 1
            elif c == ")":
                depth -= 1
                if depth == 0:
                    return i
            j += 1
    return len(lines) - 1


def title(lines, start, end):
    text = " ".join(l.strip() for l in lines[start:end + 1])
    m = re.search(r"test_that\(\s*(?:desc\s*=\s*)?(\"((?:[^\"\\]|\\.)*)\"|'((?:[^'\\]|\\.)*)')", text)
    if not m:
        # e.g. test_that(paste("a", "b"), ...): join the leading string literals
        head = text.split("{", 1)[0]
        parts = re.findall(r"\"((?:[^\"\\]|\\.)*)\"", head)
        return " ".join(parts)
    return (m.group(2) if m.group(2) is not None else m.group(3)).replace("\\\"", '"')


def expectation(block):
    found = set(EXPECT_RE.findall(block))
    for p in PRIORITY:
        if p in found:
            return p
    return sorted(found)[0] if found else "other"


def function_under_test(stem, name, current_header):
    if current_header:
        return current_header
    m = re.match(r"^([A-Za-z_.][\w.]*?)\s+Test\s+\d+", name)
    if m:
        return m.group(1)
    return stem


def tier(stem, exp, cat):
    if cat == "core_infrastructure" or exp in ("expect_snapshot", "expect_error",
                                               "expect_warning", "expect_message"):
        return 3
    if stem in SCALAR_FILES or stem.startswith("compute_") or exp in ("expect_equal", "expect_identical") \
            and cat in ("compute",):
        return 1
    return 2


def build(admiral_dir):
    rows = []
    for f in sorted(Path(admiral_dir, "tests", "testthat").glob("test-*.R")):
        stem = f.stem[len("test-"):]
        lines = f.read_text(encoding="utf-8", errors="replace").splitlines()
        header = None
        i = 0
        while i < len(lines):
            h = HEADER_RE.match(lines[i])
            if h and not lines[i].startswith("##"):
                header = h.group(1)
            if TEST_RE.match(lines[i]):
                end = find_end(lines, i)
                name = title(lines, i, end)
                exp = expectation("\n".join(lines[i:end + 1]))
                cat = category(stem)
                t = tier(stem, exp, cat)
                notes = ""
                status = "todo"
                if cat == "core_infrastructure":
                    status, notes = "needs_review", "R-specific (S3/exprs/function arguments); may be n/a in SAS"
                elif exp in ("expect_snapshot", "expect_error", "expect_warning", "expect_message"):
                    notes = "Assert error/warning flag and message text; not an exact snapshot port"
                rows.append({
                    "r_file": f.name, "r_test_name": name,
                    "r_line_start": i + 1, "r_line_end": end + 1,
                    "r_category": cat, "r_expectation_type": exp,
                    "r_function_under_test": function_under_test(stem, name, header),
                    "porting_tier": t, "sas_port_status": status, "sas_notes": notes,
                })
                i = end
            i += 1
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("admiral_dir", help="local clone of pharmaverse/admiral")
    default = Path(__file__).resolve().parent.parent / "mapping" / "test_inventory.csv"
    ap.add_argument("--out", default=str(default))
    args = ap.parse_args()
    rows = build(args.admiral_dir)
    with open(args.out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=COLUMNS)
        w.writeheader()
        w.writerows(rows)
    print(f"Wrote {len(rows)} tests to {args.out}")


if __name__ == "__main__":
    main()
