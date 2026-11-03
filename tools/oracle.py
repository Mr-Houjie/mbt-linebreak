"""Prototype of UAX #29 / #14 rules, used as the conformance oracle.

This file is not shipped as the library. It exists so that the rule logic can
be validated against the official Unicode test files before it is ported to
MoonBit, which keeps the port mechanical instead of exploratory.
"""

from __future__ import annotations

import os
import sys

UCD = os.path.join(os.path.dirname(__file__), "..", "corpus", "ucd")


def _ranges(path, wanted=None, field=1):
    """Parse a UCD range file into dict[property] -> [(lo, hi), ...]."""
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
    for ranges in out.values():
        ranges.sort()
    return out


class DB:
    def __init__(self):
        self.gcb = _ranges(os.path.join(UCD, "auxiliary", "GraphemeBreakProperty.txt"))
        self.wb = _ranges(os.path.join(UCD, "auxiliary", "WordBreakProperty.txt"))
        self.sb = _ranges(os.path.join(UCD, "auxiliary", "SentenceBreakProperty.txt"))
        self.lb = _ranges(os.path.join(UCD, "LineBreak.txt"))
        self.eaw = _ranges(os.path.join(UCD, "EastAsianWidth.txt"))
        emoji = _ranges(
            os.path.join(UCD, "emoji", "emoji-data.txt"),
            wanted={"Extended_Pictographic"},
        )
        self.extpict = emoji.get("Extended_Pictographic", [])
        incb: dict[str, list[tuple[int, int]]] = {}
        with open(os.path.join(UCD, "DerivedCoreProperties.txt"), encoding="utf-8") as fh:
            for line in fh:
                line = line.split("#", 1)[0].strip()
                if not line:
                    continue
                parts = [p.strip() for p in line.split(";")]
                if len(parts) < 3 or parts[1] != "InCB":
                    continue
                cps = parts[0]
                if ".." in cps:
                    lo, hi = (int(x, 16) for x in cps.split(".."))
                else:
                    lo = hi = int(cps, 16)
                incb.setdefault(parts[2], []).append((lo, hi))
        self.incb = incb
        self.gc = self._general_category(os.path.join(UCD, "UnicodeData.txt"))

    @staticmethod
    def _general_category(path):
        """General category ranges, needed for LB1/LB15/LB19a/LB30b."""
        ranges = []
        with open(path, encoding="utf-8") as fh:
            pending = None
            for line in fh:
                f = line.split(";")
                if len(f) < 3:
                    continue
                cp = int(f[0], 16)
                name, gc = f[1], f[2]
                if name.endswith(", First>"):
                    pending = (cp, gc)
                elif name.endswith(", Last>") and pending:
                    ranges.append((pending[0], cp, pending[1]))
                    pending = None
                else:
                    ranges.append((cp, cp, gc))
        ranges.sort()
        return ranges

    @staticmethod
    def _lookup(ranges, cp):
        lo, hi = 0, len(ranges) - 1
        while lo <= hi:
            mid = (lo + hi) // 2
            a, b = ranges[mid]
            if cp < a:
                hi = mid - 1
            elif cp > b:
                lo = mid + 1
            else:
                return True
        return False

    @staticmethod
    def _class(ranges, cp, default):
        for lo, hi in ranges.items():
            pass
        for name, rs in ranges.items():
            if DB._lookup(rs, cp):
                return name
        return default


def build_lookup(table: dict[str, list[tuple[int, int]]], default: str):
    # Flatten once into a sorted list for speed.
    flat = sorted((lo, hi, name) for name, rs in table.items() for lo, hi in rs)

    def lookup(cp: int) -> str:
        lo, hi = 0, len(flat) - 1
        while lo <= hi:
            mid = (lo + hi) // 2
            a, b, name = flat[mid]
            if cp < a:
                hi = mid - 1
            elif cp > b:
                lo = mid + 1
            else:
                return name
        return default

    return lookup


DB_ = DB()
gcb_of = build_lookup(DB_.gcb, "Other")
wb_of = build_lookup(DB_.wb, "Other")
sb_of = build_lookup(DB_.sb, "Other")
lb_of = build_lookup(DB_.lb, "XX")
eaw_of = build_lookup(DB_.eaw, "N")
incb_linker = set()
for lo, hi in DB_.incb.get("Linker", []):
    incb_linker.update(range(lo, hi + 1))
incb_consonant = set()
for lo, hi in DB_.incb.get("Consonant", []):
    incb_consonant.update(range(lo, hi + 1))
incb_extend = set()
for lo, hi in DB_.incb.get("Extend", []):
    incb_extend.update(range(lo, hi + 1))
extpict = set()
for lo, hi in DB_.extpict:
    extpict.update(range(lo, hi + 1))
marks = set()
for _lo, _hi, _gc in DB_.gc:
    if _gc in ("Mn", "Mc"):
        marks.update(range(_lo, _hi + 1))


def gc_of(cp: int) -> str:
    lo, hi = 0, len(DB_.gc) - 1
    while lo <= hi:
        mid = (lo + hi) // 2
        a, b, gc = DB_.gc[mid]
        if cp < a:
            hi = mid - 1
        elif cp > b:
            lo = mid + 1
        else:
            return gc
    return "Cn"


pi_qu = {cp for cp in range(0x110000) if gc_of(cp) == "Pi"} if False else set()
# Pi/Pf are small; collect them from the category ranges instead of scanning.
pi_set = set()
pf_set = set()
for _lo, _hi, _gc in DB_.gc:
    if _gc == "Pi":
        pi_set.update(range(_lo, _hi + 1))
    elif _gc == "Pf":
        pf_set.update(range(_lo, _hi + 1))
extpict_cn = {cp for cp in extpict if gc_of(cp) == "Cn"}


def incb(cp: int) -> str:
    if cp in incb_linker:
        return "Linker"
    if cp in incb_consonant:
        return "Consonant"
    if cp in incb_extend:
        return "Extend"
    return "None"


# ---------------------------------------------------------------------------
# UAX #29 grapheme clusters
# ---------------------------------------------------------------------------
def grapheme_bounds(cps):
    n = len(cps)
    b = [True] * (n + 1)
    for i in range(1, n):
        p, c = cps[i - 1], cps[i]
        pc, cc = gcb_of(p), gcb_of(c)
        if pc == "CR" and cc == "LF":
            b[i] = False
            continue
        if pc in ("Control", "CR", "LF") or cc in ("Control", "CR", "LF"):
            b[i] = True
            continue
        if pc == "L" and cc in ("L", "V", "LV", "LVT"):
            b[i] = False
            continue
        if pc in ("LV", "V") and cc in ("V", "T"):
            b[i] = False
            continue
        if pc in ("LVT", "T") and cc == "T":
            b[i] = False
            continue
        if cc in ("Extend", "ZWJ") or cc == "SpacingMark":
            b[i] = False
            continue
        if pc == "Prepend":
            b[i] = False
            continue
        if c in incb_consonant:
            j = i - 1
            while j >= 0 and cps[j] in incb_extend:
                j -= 1
            if j >= 0 and cps[j] in incb_linker:
                b[i] = False
                continue
        if c in extpict:
            j = i - 1
            if gcb_of(cps[j]) == "ZWJ":
                j -= 1
                while j >= 0 and gcb_of(cps[j]) == "Extend":
                    j -= 1
                if j >= 0 and cps[j] in extpict:
                    b[i] = False
                    continue
        if pc == "Regional_Indicator" and cc == "Regional_Indicator":
            cnt, j = 0, i - 1
            while j >= 0 and gcb_of(cps[j]) == "Regional_Indicator":
                cnt += 1
                j -= 1
            b[i] = cnt % 2 == 0
            continue
        b[i] = True
    return b


# ---------------------------------------------------------------------------
# UAX #29 word boundaries
# ---------------------------------------------------------------------------
WB_IGN = {"Extend", "Format", "ZWJ"}
AH = {"ALetter", "Hebrew_Letter"}
MIDL = {"MidLetter", "MidNumLet", "Single_Quote"}
MIDN = {"MidNum", "MidNumLet", "Single_Quote"}


def word_bounds(cps):
    n = len(cps)
    b = [True] * (n + 1)

    def prev_eff(i):
        j = i - 1
        while j >= 0 and wb_of(cps[j]) in WB_IGN:
            j -= 1
        return j

    def next_eff(i):
        j = i + 1
        while j < n and wb_of(cps[j]) in WB_IGN:
            j += 1
        return j

    for i in range(1, n):
        p, c = cps[i - 1], cps[i]
        pc, cc = wb_of(p), wb_of(c)
        if pc == "CR" and cc == "LF":
            b[i] = False
            continue
        if pc in ("Newline", "CR", "LF") or cc in ("Newline", "CR", "LF"):
            b[i] = True
            continue
        if pc == "ZWJ" and c in extpict:
            b[i] = False
            continue
        if pc == "WSegSpace" and cc == "WSegSpace":
            b[i] = False
            continue
        if cc in WB_IGN:
            b[i] = False
            continue
        pi = prev_eff(i)
        if pi < 0:
            b[i] = True
            continue
        pc = wb_of(cps[pi])
        cc = wb_of(c)
        ni = next_eff(i)
        nxt = wb_of(cps[ni]) if ni < n else None
        p2i = prev_eff(pi)
        p2 = wb_of(cps[p2i]) if p2i >= 0 else None

        if pc in AH and cc in AH:
            b[i] = False
            continue
        if pc in AH and cc in MIDL and nxt in AH:
            b[i] = False
            continue
        if p2 in AH and pc in MIDL and cc in AH:
            b[i] = False
            continue
        if pc == "Hebrew_Letter" and cc == "Single_Quote":
            b[i] = False
            continue
        if pc == "Hebrew_Letter" and cc == "Double_Quote" and nxt == "Hebrew_Letter":
            b[i] = False
            continue
        if p2 == "Hebrew_Letter" and pc == "Double_Quote" and cc == "Hebrew_Letter":
            b[i] = False
            continue
        if pc == "Numeric" and cc == "Numeric":
            b[i] = False
            continue
        if pc in AH and cc == "Numeric":
            b[i] = False
            continue
        if pc == "Numeric" and cc in AH:
            b[i] = False
            continue
        if p2 == "Numeric" and pc in MIDN and cc == "Numeric":
            b[i] = False
            continue
        if pc == "Numeric" and cc in MIDN and nxt == "Numeric":
            b[i] = False
            continue
        if pc == "Katakana" and cc == "Katakana":
            b[i] = False
            continue
        if pc in AH | {"Numeric", "Katakana", "ExtendNumLet"} and cc == "ExtendNumLet":
            b[i] = False
            continue
        if pc == "ExtendNumLet" and cc in AH | {"Numeric", "Katakana"}:
            b[i] = False
            continue
        if pc == "Regional_Indicator" and cc == "Regional_Indicator":
            cnt, j = 0, pi
            while j >= 0:
                if wb_of(cps[j]) == "Regional_Indicator":
                    cnt += 1
                elif wb_of(cps[j]) not in WB_IGN:
                    break
                j -= 1
            b[i] = cnt % 2 == 0
            continue
        b[i] = True
    return b


# ---------------------------------------------------------------------------
# UAX #29 sentence boundaries
# ---------------------------------------------------------------------------
SB_IGN = {"Extend", "Format"}


# UAX #29 sentence boundaries (rule order faithful to the spec)
# ---------------------------------------------------------------------------
SB_STOP = {"OLetter", "Upper", "Lower", "Sep", "CR", "LF", "STerm", "ATerm"}


def sentence_bounds(cps):
    n = len(cps)
    b = [True] * (n + 1)
    if n == 0:
        return b
    b[0] = True  # SB1

    def prev_eff(i):
        j = i - 1
        while j >= 0 and sb_of(cps[j]) in SB_IGN:
            j -= 1
        return j

    def next_eff(i):
        j = i + 1
        while j < n and sb_of(cps[j]) in SB_IGN:
            j += 1
        return j

    for i in range(1, n):
        pc, cc = sb_of(cps[i - 1]), sb_of(cps[i])
        if pc == "CR" and cc == "LF":  # SB3
            b[i] = False
            continue
        if pc in ("Sep", "CR", "LF"):  # SB4
            b[i] = True
            continue
        if cc in SB_IGN:  # SB5
            b[i] = False
            continue
        q = i - 1
        while q >= 0 and sb_of(cps[q]) in SB_IGN:
            q -= 1
        if q < i - 1 and q >= 0 and b[q + 1]:
            b[i] = False
            continue
        pi = prev_eff(i)
        if pi < 0:
            b[i] = False
            continue
        pc = sb_of(cps[pi])
        # SB6
        if pc == "ATerm" and cc == "Numeric":
            b[i] = False
            continue
        # SB7
        if cc == "Upper" and pc == "ATerm":
            pj = prev_eff(pi)
            if pj >= 0 and sb_of(cps[pj]) in ("Upper", "Lower"):
                b[i] = False
                continue
        # SB8
        j = pi
        while j >= 0 and sb_of(cps[j]) == "Sp":
            j = prev_eff(j)
        while j >= 0 and sb_of(cps[j]) == "Close":
            j = prev_eff(j)
        if j >= 0 and sb_of(cps[j]) == "ATerm":
            k = i
            while k < n and sb_of(cps[k]) not in SB_STOP:
                k = next_eff(k)
            if k < n and sb_of(cps[k]) == "Lower":
                b[i] = False
                continue
        # SB8a
        if cc in ("SContinue", "STerm", "ATerm"):
            j = pi
            while j >= 0 and sb_of(cps[j]) == "Sp":
                j = prev_eff(j)
            while j >= 0 and sb_of(cps[j]) == "Close":
                j = prev_eff(j)
            if j >= 0 and sb_of(cps[j]) in ("STerm", "ATerm"):
                b[i] = False
                continue
        # SB9
        if cc in ("Close", "Sp", "Sep", "CR", "LF"):
            j = pi
            while j >= 0 and sb_of(cps[j]) == "Close":
                j = prev_eff(j)
            if j >= 0 and sb_of(cps[j]) in ("STerm", "ATerm"):
                b[i] = False
                continue
        # SB10
        if cc in ("Sp", "Sep", "CR", "LF"):
            j = pi
            while j >= 0 and sb_of(cps[j]) == "Sp":
                j = prev_eff(j)
            while j >= 0 and sb_of(cps[j]) == "Close":
                j = prev_eff(j)
            if j >= 0 and sb_of(cps[j]) in ("STerm", "ATerm"):
                b[i] = False
                continue
        # SB11
        j = pi
        if j >= 0 and sb_of(cps[j]) in ("Sep", "CR", "LF"):
            j = prev_eff(j)
        while j >= 0 and sb_of(cps[j]) == "Sp":
            j = prev_eff(j)
        while j >= 0 and sb_of(cps[j]) == "Close":
            j = prev_eff(j)
        if j >= 0 and sb_of(cps[j]) in ("STerm", "ATerm"):
            b[i] = True
            continue
        b[i] = False  # SB998
    return b


# ---------------------------------------------------------------------------
# UAX #14 line breaking, Unicode 18.0 (UAX #14 revision 57)
# ---------------------------------------------------------------------------
LB_HARD = {"BK", "CR", "LF", "NL"}
LB_AL = {"AL", "HL"}
LB_EA = {"F", "W", "H"}


def lb_resolve_v18(cps):
    r, orig, ignored = [], [], []
    for cp in cps:
        c = lb_of(cp)
        if c in ("AI", "SG", "XX"):
            c = "AL"
        elif c == "CJ":
            c = "NS"
        elif c == "SA":
            c = "CM" if cp in marks else "AL"
        orig.append(c)
        r.append(c)
        ignored.append(False)
    for i in range(len(r)):
        if r[i] in ("CM", "ZWJ"):
            if i == 0 or r[i - 1] in LB_HARD | {"SP", "ZW"}:
                r[i] = "AL"
            else:
                r[i] = r[i - 1]
                ignored[i] = True
    return r, orig, ignored


def line_bounds(cps):
    n = len(cps)
    b = [True] * (n + 1)
    if n == 0:
        return b
    b[0] = False  # LB2: sot x
    r, orig, ign = lb_resolve_v18(cps)

    def base_idx(j):
        while j >= 0 and ign[j]:
            j -= 1
        return j

    def prev_nb(j):
        return base_idx(j - 1)

    def spaces_before(i):
        j = base_idx(i - 1)
        while j >= 0 and r[j] == "SP":
            j = prev_nb(j)
        return j

    def is_ea(i):
        return 0 <= i < n and eaw_of(cps[i]) in LB_EA

    def is_syl(i):
        j = base_idx(i)
        return j >= 0 and (r[j] in ("AK", "AS") or cps[j] == 0x25CC)

    def num_tail(j):
        """Index of the NU that starts `NU (SY|IS)*` ending at j, else -1."""
        while j >= 0 and r[j] in ("SY", "IS"):
            j -= 1
        if j >= 0 and r[j] == "NU":
            return j
        return -1

    for i in range(1, n):
        p, c = r[i - 1], r[i]
        op, oc = orig[i - 1], orig[i]

        # LB9
        if oc in ("CM", "ZWJ") and op not in LB_HARD | {"SP", "ZW"}:
            b[i] = False
            continue
        # LB4 / LB5
        if p == "BK":
            b[i] = True
            continue
        if p == "CR" and c == "LF":
            b[i] = False
            continue
        if p in ("CR", "LF", "NL"):
            b[i] = True
            continue
        # LB6
        if c in LB_HARD:
            b[i] = False
            continue
        # LB7
        if c in ("SP", "ZW"):
            b[i] = False
            continue
        # LB8
        if p == "ZW":
            b[i] = True
            continue
        j = spaces_before(i)
        if j >= 0 and r[j] == "ZW":
            b[i] = True
            continue
        # LB8a
        if op == "ZWJ":
            b[i] = False
            continue
        # LB11 / LB12 / LB12a
        if p == "WJ" or c == "WJ":
            b[i] = False
            continue
        if p == "GL":
            b[i] = False
            continue
        if c == "GL" and p not in ("SP", "HY", "HH"):
            b[i] = False
            continue
        # LB13
        if c in ("CL", "CP", "EX", "SY"):
            b[i] = False
            continue
        # LB14
        j = spaces_before(i)
        if j >= 0 and r[j] == "OP":
            b[i] = False
            continue
        # LB15a
        j = spaces_before(i)
        if j >= 0 and cps[j] in pi_set and r[j] == "QU":
            k = prev_nb(j)
            if k < 0 or r[k] in ("BK", "CR", "LF", "NL", "OP", "QU", "GL", "SP", "ZW"):
                b[i] = False
                continue
        # LB15b
        if cps[i] in pf_set and c == "QU":
            nx = r[i + 1] if i + 1 < n else None
            if nx is None or nx in (
                "SP", "GL", "WJ", "CL", "QU", "CP", "EX", "IS", "SY",
                "BK", "CR", "LF", "NL", "ZW",
            ):
                b[i] = False
                continue
        # LB15c
        if p == "SP" and c == "IS" and i + 1 < n and r[i + 1] == "NU":
            b[i] = True
            continue
        # LB15d
        if c == "IS":
            b[i] = False
            continue
        # LB16
        if c == "NS":
            j = spaces_before(i)
            if j >= 0 and r[j] in ("CL", "CP"):
                b[i] = False
                continue
        # LB17
        if c == "B2":
            j = spaces_before(i)
            if j >= 0 and r[j] == "B2":
                b[i] = False
                continue
        # LB18
        if p == "SP":
            b[i] = True
            continue
        # LB19
        if c == "QU" and cps[i] not in pi_set:
            b[i] = False
            continue
        if p == "QU" and cps[i - 1] not in pf_set:
            b[i] = False
            continue
        # LB19a
        if c == "QU":
            left_ea = i - 1 >= 0 and is_ea(i - 1)
            right_ea = i + 1 < n and is_ea(i + 1)
            if not left_ea or not right_ea:
                b[i] = False
                continue
        if p == "QU":
            left_ea = i - 2 >= 0 and is_ea(i - 2)
            right_ea = i + 1 < n and is_ea(i + 1)
            if not left_ea or not right_ea:
                b[i] = False
                continue
        # LB20
        if c == "CB" or p == "CB":
            b[i] = True
            continue
        # LB20a
        if c in ("AL", "HL") and p in ("HY", "HH"):
            h = base_idx(i - 1)
            k = prev_nb(h)
            if k < 0 or r[k] in ("BK", "CR", "LF", "NL", "SP", "ZW", "CB", "GL"):
                b[i] = False
                continue
        # LB21
        if c in ("BA", "HH", "HY", "NS") or p == "BB":
            b[i] = False
            continue
        # LB21a
        if p in ("HY", "HH") and c != "HL":
            h = base_idx(i - 1)
            k = prev_nb(h)
            if k >= 0 and r[k] == "HL":
                b[i] = False
                continue
        # LB21b
        if p == "SY" and c == "HL":
            b[i] = False
            continue
        # LB22
        if c == "IN":
            b[i] = False
            continue
        # LB23
        if (p in LB_AL and c == "NU") or (p == "NU" and c in LB_AL):
            b[i] = False
            continue
        # LB23a
        if (p == "PR" and c in ("ID", "EB", "EM")) or (
            p in ("ID", "EB", "EM") and c == "PO"
        ):
            b[i] = False
            continue
        # LB24
        if (p in ("PR", "PO") and c in LB_AL) or (p in LB_AL and c in ("PR", "PO")):
            b[i] = False
            continue
        # LB25
        if c in ("PO", "PR"):
            if p in ("CL", "CP") and num_tail(i - 2) >= 0:
                b[i] = False
                continue
            if num_tail(i - 1) >= 0:
                b[i] = False
                continue
        if c == "OP" and p in ("PO", "PR"):
            if i + 1 < n and r[i + 1] == "NU":
                b[i] = False
                continue
            if i + 2 < n and r[i + 1] == "IS" and r[i + 2] == "NU":
                b[i] = False
                continue
        if c == "NU" and p in ("PO", "PR", "HY", "IS"):
            b[i] = False
            continue
        if c == "NU" and num_tail(i - 1) >= 0:
            b[i] = False
            continue
        # LB26
        if p == "JL" and c in ("JL", "JV", "H2", "H3"):
            b[i] = False
            continue
        if p in ("JV", "H2") and c in ("JV", "JT"):
            b[i] = False
            continue
        if p in ("JT", "H3") and c == "JT":
            b[i] = False
            continue
        # LB27
        if p in ("JL", "JV", "JT", "H2", "H3") and c == "PO":
            b[i] = False
            continue
        if p == "PR" and c in ("JL", "JV", "JT", "H2", "H3"):
            b[i] = False
            continue
        # LB28
        if p in LB_AL and c in LB_AL:
            b[i] = False
            continue
        # LB28a
        if p == "AP" and is_syl(i):
            b[i] = False
            continue
        if is_syl(i - 1) and c in ("VF", "VI"):
            b[i] = False
            continue
        if p == "VI" and is_syl(i) and is_syl(prev_nb(base_idx(i - 1))):
            b[i] = False
            continue
        if is_syl(i - 1) and is_syl(i) and i + 1 < n and r[i + 1] == "VF":
            b[i] = False
            continue
        # LB29
        if p == "IS" and c in LB_AL:
            b[i] = False
            continue
        # LB30
        if p in ("AL", "HL", "NU") and c == "OP" and not is_ea(i):
            b[i] = False
            continue
        if p == "CP" and not is_ea(i - 1) and c in ("AL", "HL", "NU"):
            b[i] = False
            continue
        # LB30a
        if p == "RI" and c == "RI":
            cnt, k = 0, i - 1
            while k >= 0:
                if ign[k]:
                    k -= 1
                    continue
                if r[k] != "RI":
                    break
                cnt += 1
                k -= 1
            b[i] = cnt % 2 == 0
            continue
        # LB30b
        if c == "EM" and (p == "EB" or cps[base_idx(i - 1)] in extpict_cn):
            b[i] = False
            continue
        # LB31
        b[i] = True
    return b


# ---------------------------------------------------------------------------
# Conformance harness
# ---------------------------------------------------------------------------
def parse_test(path):
    cases = []
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            cps, expected = [], []
            for tok in line.split():
                if tok == "\u00d7":
                    expected.append(False)
                elif tok == "\u00f7":
                    expected.append(True)
                else:
                    cps.append(int(tok, 16))
            if len(expected) == len(cps) + 1:
                cases.append((cps, expected))
    return cases


def check(name, path, fn):
    cases = parse_test(path)
    fails = 0
    first = []
    for cps, expected in cases:
        got = fn(cps)
        if got != expected:
            fails += 1
            if len(first) < 3:
                first.append((cps, expected, got))
    print(f"{name:10s} {len(cases) - fails}/{len(cases)}  fail={fails}")
    for cps, expected, got in first:
        bad = [i for i, (a, b) in enumerate(zip(expected, got)) if a != b]
        print("   cps:", " ".join(f"{c:04X}" for c in cps))
        print("   bad boundary indexes:", bad)
    return fails


if __name__ == "__main__":
    total = 0
    total += check(
        "grapheme", os.path.join(UCD, "auxiliary", "GraphemeBreakTest.txt"), grapheme_bounds
    )
    total += check(
        "word", os.path.join(UCD, "auxiliary", "WordBreakTest.txt"), word_bounds
    )
    total += check(
        "sentence",
        os.path.join(UCD, "auxiliary", "SentenceBreakTest.txt"),
        sentence_bounds,
    )
    total += check(
        "line", os.path.join(UCD, "auxiliary", "LineBreakTest.txt"), line_bounds
    )
    sys.exit(1 if total else 0)
