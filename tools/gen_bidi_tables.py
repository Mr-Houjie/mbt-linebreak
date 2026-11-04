"""Generate MoonBit tables for UAX #9 (Bidi_Class and paired brackets)."""

from __future__ import annotations

import os

HERE = os.path.dirname(__file__)
UCD = os.path.join(HERE, "..", "corpus", "ucd")
OUT = os.path.join(HERE, "..", "bidi")
VERSION = "18.0.0"


def parse_bidi_class():
    table = {}
    with open(os.path.join(UCD, "extracted", "DerivedBidiClass.txt"), encoding="utf-8") as fh:
        for line in fh:
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            if len(parts) < 2:
                continue
            cps, cls = parts[0], parts[1]
            if ".." in cps:
                lo, hi = (int(x, 16) for x in cps.split(".."))
            else:
                lo = hi = int(cps, 16)
            table.setdefault(cls, []).append((lo, hi))
    return table


def main():
    classes = parse_bidi_class()
    names = sorted(classes)
    ids = {n: i for i, n in enumerate(names)}
    flat = sorted((lo, hi, ids[n]) for n, rs in classes.items() for lo, hi in rs)

    lines = [
        f"// Generated from UCD {VERSION}. Do not edit by hand.",
        "// Bidi_Class (UAX #9) and Bidi_Paired_Bracket data.",
        "",
    ]
    for n in names:
        lines.append(f"const BC_{n} : Int = {ids[n]}")
    lines += ["", "let bc_ranges : Array[Int] = ["]
    row = []
    for triple in flat:
        row.extend(str(x) for x in triple)
        if len(row) >= 18:
            lines.append("  " + ", ".join(row) + ",")
            row = []
    if row:
        lines.append("  " + ", ".join(row) + ",")
    lines += ["]", ""]

    brackets = []
    with open(os.path.join(UCD, "BidiBrackets.txt"), encoding="utf-8") as fh:
        for line in fh:
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            if len(parts) < 3:
                continue
            cp, bpb, kind = int(parts[0], 16), int(parts[1], 16), parts[2]
            brackets.append((cp, bpb, 0 if kind == "o" else 1))
    brackets.sort()

    lines.append("let bc_bracket_cps : Array[Int] = [")
    lines.append("  " + ", ".join(str(b[0]) for b in brackets) + ",")
    lines += ["]", "", "let bc_bracket_pairs : Array[Int] = ["]
    lines.append("  " + ", ".join(str(b[1]) for b in brackets) + ",")
    lines += ["]", "", "let bc_bracket_kinds : Array[Int] = ["]
    lines.append("  " + ", ".join(str(b[2]) for b in brackets) + ",")
    lines += ["]", ""]

    text = "\n".join(lines)
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "tables_bidi.mbt"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    print(f"wrote bidi/tables_bidi.mbt: {len(text)} bytes, {len(brackets)} bracket chars")


if __name__ == "__main__":
    main()
