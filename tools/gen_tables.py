"""Generate MoonBit property tables from the Unicode Character Database.

The output is deterministic: re-running against the same UCD revision produces
byte-identical files. Tables are stored as flat triples (lo, hi, class) and
searched with a binary search in `props.mbt`.
"""

from __future__ import annotations

import os

HERE = os.path.dirname(__file__)
UCD = os.path.join(HERE, "..", "corpus", "ucd")
OUT = os.path.join(HERE, "..")
VERSION = "18.0.0"


def parse_ranges(path, wanted=None, field=1):
    out: dict[str, list[tuple[int, int]]] = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            if len(parts) <= field:
                continue
            cps, prop = parts[0], parts[field]
            if wanted and prop not in wanted:
                continue
            if ".." in cps:
                lo, hi = (int(x, 16) for x in cps.split(".."))
            else:
                lo = hi = int(cps, 16)
            out.setdefault(prop, []).append((lo, hi))
    return out


def sanitize(name):
    return "".join(c if c.isalnum() else "_" for c in name).upper()


def emit_table(var, const_prefix, table, doc):
    names = sorted(table)
    ids = {n: i for i, n in enumerate(names)}
    flat = sorted((lo, hi, ids[n]) for n, rs in table.items() for lo, hi in rs)
    lines = [
        f"// Generated from UCD {VERSION}. Do not edit by hand.",
        f"// {doc}",
        "",
    ]
    for n in names:
        lines.append(f"const {const_prefix}_{sanitize(n)} : Int = {ids[n]}")
    lines += ["", f"let {var} : Array[Int] = ["]
    row = []
    for triple in flat:
        row.extend(str(x) for x in triple)
        if len(row) >= 18:
            lines.append("  " + ", ".join(row) + ",")
            row = []
    if row:
        lines.append("  " + ", ".join(row) + ",")
    lines += ["]", ""]
    return "\n".join(lines)


def emit_ranges(var, ranges, doc):
    lines = [
        f"// Generated from UCD {VERSION}. Do not edit by hand.",
        f"// {doc}",
        "",
        f"let {var} : Array[Int] = [",
    ]
    row = []
    for lo, hi in sorted(ranges):
        row.extend((str(lo), str(hi)))
        if len(row) >= 16:
            lines.append("  " + ", ".join(row) + ",")
            row = []
    if row:
        lines.append("  " + ", ".join(row) + ",")
    lines += ["]", ""]
    return "\n".join(lines)


def merge(ranges):
    out = []
    for lo, hi in sorted(ranges):
        if out and lo <= out[-1][1] + 1:
            out[-1] = (out[-1][0], max(out[-1][1], hi))
        else:
            out.append((lo, hi))
    return out


def main():
    gcb = parse_ranges(os.path.join(UCD, "auxiliary", "GraphemeBreakProperty.txt"))
    wb = parse_ranges(os.path.join(UCD, "auxiliary", "WordBreakProperty.txt"))
    sb = parse_ranges(os.path.join(UCD, "auxiliary", "SentenceBreakProperty.txt"))
    lb = parse_ranges(os.path.join(UCD, "LineBreak.txt"))
    eaw = parse_ranges(os.path.join(UCD, "EastAsianWidth.txt"))

    emoji = parse_ranges(os.path.join(UCD, "emoji", "emoji-data.txt"))
    extpict = merge(emoji.get("Extended_Pictographic", []))
    emoji_pres = merge(emoji.get("Emoji_Presentation", []))

    incb_linker, incb_consonant, incb_extend = [], [], []
    with open(os.path.join(UCD, "DerivedCoreProperties.txt"), encoding="utf-8") as fh:
        for line in fh:
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            if len(parts) < 3 or parts[1] != "InCB":
                continue
            cps = parts[0]
            lo, hi = (
                (int(x, 16) for x in cps.split("..")) if ".." in cps else (int(cps, 16),) * 2
            )
            {"Linker": incb_linker, "Consonant": incb_consonant, "Extend": incb_extend}[
                parts[2]
            ].append((lo, hi))

    # General categories needed by UAX #14.
    gc_ranges = []
    with open(os.path.join(UCD, "UnicodeData.txt"), encoding="utf-8") as fh:
        pending = None
        for line in fh:
            f = line.split(";")
            if len(f) < 3:
                continue
            cp, name, gc = int(f[0], 16), f[1], f[2]
            if name.endswith(", First>"):
                pending = (cp, gc)
            elif name.endswith(", Last>") and pending:
                gc_ranges.append((pending[0], cp, pending[1]))
                pending = None
            else:
                gc_ranges.append((cp, cp, gc))
    gc_ranges.sort()

    def gc_of(cp):
        lo, hi = 0, len(gc_ranges) - 1
        while lo <= hi:
            mid = (lo + hi) // 2
            a, b, gc = gc_ranges[mid]
            if cp < a:
                hi = mid - 1
            elif cp > b:
                lo = mid + 1
            else:
                return gc
        return "Cn"

    marks = merge([(lo, hi) for lo, hi, gc in gc_ranges if gc in ("Mn", "Mc")])
    pi = merge([(lo, hi) for lo, hi, gc in gc_ranges if gc == "Pi"])
    pf = merge([(lo, hi) for lo, hi, gc in gc_ranges if gc == "Pf"])

    # QU class && Pi / Pf, and Extended_Pictographic && Cn.
    lb_qu = merge(lb.get("QU", []))

    def intersect(a, b):
        out, i, j = [], 0, 0
        while i < len(a) and j < len(b):
            lo = max(a[i][0], b[j][0])
            hi = min(a[i][1], b[j][1])
            if lo <= hi:
                out.append((lo, hi))
            if a[i][1] < b[j][1]:
                i += 1
            else:
                j += 1
        return out

    pi_qu = intersect(pi, lb_qu)
    pf_qu = intersect(pf, lb_qu)
    extpict_cn = merge([(lo, hi) for lo, hi in extpict if gc_of(lo) == "Cn"])

    files = {
        "tables_gcb.mbt": emit_table(
            "gcb_ranges", "GCB", gcb, "Grapheme_Cluster_Break (UAX #29)"
        ),
        "tables_wb.mbt": emit_table("wb_ranges", "WB", wb, "Word_Break (UAX #29)"),
        "tables_sb.mbt": emit_table("sb_ranges", "SB", sb, "Sentence_Break (UAX #29)"),
        "tables_lb.mbt": emit_table("lb_ranges", "LB", lb, "Line_Break (UAX #14)"),
        "tables_eaw.mbt": emit_table(
            "eaw_ranges", "EAW", eaw, "East_Asian_Width (UAX #11)"
        ),
        "tables_props.mbt": "\n".join(
            [
                f"// Generated from UCD {VERSION}. Do not edit by hand.",
                "// Supplementary properties used by UAX #14 and UAX #29.",
                "",
                emit_ranges("incb_linker_ranges", incb_linker, "Indic_Conjunct_Break=Linker"),
                emit_ranges("incb_consonant_ranges", incb_consonant, "Indic_Conjunct_Break=Consonant"),
                emit_ranges("incb_extend_ranges", incb_extend, "Indic_Conjunct_Break=Extend"),
                emit_ranges("extpict_ranges", extpict, "Extended_Pictographic"),
                emit_ranges("emoji_pres_ranges", emoji_pres, "Emoji_Presentation"),
                emit_ranges("pi_qu_ranges", pi_qu, "General_Category=Pi and Line_Break=QU"),
                emit_ranges("pf_qu_ranges", pf_qu, "General_Category=Pf and Line_Break=QU"),
                emit_ranges("extpict_cn_ranges", extpict_cn, "Extended_Pictographic and General_Category=Cn"),
                emit_ranges("mark_ranges", marks, "General_Category Mn or Mc"),
                "",
                f'const UNICODE_VERSION : String = "{VERSION}"',
                "",
            ]
        ),
    }
    for name, text in files.items():
        with open(os.path.join(OUT, name), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        print(f"wrote {name}: {len(text)} bytes")


if __name__ == "__main__":
    main()
