"""Reference implementation of UAX #9 (Unicode Bidirectional Algorithm).

Like tools/oracle.py this is a development-time oracle: the rule logic is
validated against the official test files first, and only then ported to
MoonBit. It is not shipped as part of the library.
"""

from __future__ import annotations

import os
import sys

UCD = os.path.join(os.path.dirname(__file__), "..", "corpus", "ucd")
MAX_DEPTH = 125

ISOLATE_INIT = {"LRI", "RLI", "FSI"}
REMOVED = {"RLE", "LRE", "RLO", "LRO", "PDF", "BN"}
NI = {"B", "S", "WS", "ON", "FSI", "LRI", "RLI", "PDI"}


def parse_ranges(path, field=1, value_field=None):
    out = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            if len(parts) < 2:
                continue
            cps = parts[field - 1] if field - 1 < len(parts) else parts[0]
            val = parts[field]
            if ".." in cps:
                lo, hi = (int(x, 16) for x in cps.split(".."))
            else:
                lo = hi = int(cps, 16)
            out.setdefault(val, []).append((lo, hi))
    return out


def build_lookup(table, default):
    flat = sorted((lo, hi, name) for name, rs in table.items() for lo, hi in rs)

    def lookup(cp):
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


bidi_class_of = build_lookup(
    parse_ranges(os.path.join(UCD, "extracted", "DerivedBidiClass.txt")), "L"
)

BRACKETS = {}
with open(os.path.join(UCD, "BidiBrackets.txt"), encoding="utf-8") as fh:
    for line in fh:
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        parts = [p.strip() for p in line.split(";")]
        if len(parts) < 3:
            continue
        cp, bpb, kind = int(parts[0], 16), int(parts[1], 16), parts[2]
        BRACKETS[cp] = (bpb, kind)


def matching_pdi(types, start):
    """Index of the PDI matching the isolate initiator at `start`, or len."""
    depth = 1
    i = start + 1
    while i < len(types):
        t = types[i]
        if t in ISOLATE_INIT:
            depth += 1
        elif t == "PDI":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return len(types)


def first_strong(types, start, end):
    """P2: first L/R/AL outside any nested isolate."""
    i = start
    while i < end:
        t = types[i]
        if t in ISOLATE_INIT:
            i = matching_pdi(types, i) + 1
            continue
        if t == "PDI":
            i += 1
            continue
        if t in ("L", "R", "AL"):
            return t
        i += 1
    return None


def fsi_direction(types, i):
    end = matching_pdi(types, i)
    t = first_strong(types, i + 1, end)
    return "R" if t in ("R", "AL") else "L"


def paragraph_level(types, direction):
    """direction: 0 = LTR, 1 = RTL, 2 = auto."""
    if direction == 0:
        return 0
    if direction == 1:
        return 1
    t = first_strong(types, 0, len(types))
    return 1 if t in ("R", "AL") else 0


def isolate_matches(types):
    """Map each isolate initiator / PDI to its counterpart, if any."""
    stack = []
    init_to_pdi = {}
    pdi_to_init = {}
    for i, t in enumerate(types):
        if t in ISOLATE_INIT:
            stack.append(i)
        elif t == "PDI" and stack:
            start = stack.pop()
            init_to_pdi[start] = i
            pdi_to_init[i] = start
    return init_to_pdi, pdi_to_init


def explicit_levels(types, para_level):
    """Rules X1-X8. Returns (levels, resolved_types)."""
    n = len(types)
    levels = [para_level] * n
    resolved = list(types)
    stack = [(para_level, "n", False)]
    overflow_isolate = 0
    overflow_embedding = 0
    valid_isolate = 0

    def apply_override(i):
        """X5a/X5b/X5c/X6a: an active override also rewrites the char type."""
        if stack[-1][1] != "n":
            resolved[i] = stack[-1][1]

    for i, t in enumerate(types):
        if t in ("RLE", "LRE", "RLO", "LRO"):
            levels[i] = stack[-1][0]
            if t in ("RLE", "RLO"):
                new_level = (stack[-1][0] + 1) | 1
            else:
                new_level = (stack[-1][0] + 2) & ~1
            if new_level <= MAX_DEPTH and overflow_isolate == 0 and overflow_embedding == 0:
                override = {"RLO": "R", "LRO": "L"}.get(t, "n")
                stack.append((new_level, override, False))
            elif overflow_isolate == 0:
                overflow_embedding += 1
        elif t in ISOLATE_INIT:
            levels[i] = stack[-1][0]
            apply_override(i)
            direction = fsi_direction(types, i) if t == "FSI" else ("R" if t == "RLI" else "L")
            if direction == "R":
                new_level = (stack[-1][0] + 1) | 1
            else:
                new_level = (stack[-1][0] + 2) & ~1
            if new_level <= MAX_DEPTH and overflow_isolate == 0 and overflow_embedding == 0:
                valid_isolate += 1
                stack.append((new_level, "n", True))
            else:
                overflow_isolate += 1
        elif t == "PDI":
            if overflow_isolate > 0:
                overflow_isolate -= 1
            elif valid_isolate == 0:
                pass  # X6a: matches no isolate initiator, do nothing
            else:
                overflow_embedding = 0
                while not stack[-1][2]:
                    stack.pop()
                stack.pop()
                valid_isolate -= 1
            levels[i] = stack[-1][0]
            apply_override(i)
        elif t == "PDF":
            if overflow_isolate > 0:
                pass
            elif overflow_embedding > 0:
                overflow_embedding -= 1
            elif not stack[-1][2] and len(stack) >= 2:
                stack.pop()
            levels[i] = stack[-1][0]
        elif t == "B":
            levels[i] = para_level
        elif t == "BN":
            levels[i] = stack[-1][0]
        else:  # X6
            levels[i] = stack[-1][0]
            apply_override(i)
    return levels, resolved


def level_runs(types, levels):
    """X9 + level runs over the retained characters."""
    keep = [i for i, t in enumerate(types) if t not in REMOVED]
    runs = []
    current = []
    for i in keep:
        if current and levels[i] != levels[current[-1]]:
            runs.append(current)
            current = []
        current.append(i)
    if current:
        runs.append(current)
    return runs


def isolating_run_sequences(types, levels):
    """X10: group level runs into isolating run sequences."""
    runs = level_runs(types, levels)
    by_first = {run[0]: idx for idx, run in enumerate(runs)}
    pdi_run = {}
    for idx, run in enumerate(runs):
        if types[run[0]] == "PDI":
            pdi_run[run[0]] = idx
    # Match isolate initiators with the following run that starts with PDI.
    links = {}
    for idx, run in enumerate(runs):
        last = run[-1]
        if types[last] in ISOLATE_INIT:
            end = matching_pdi(types, last)
            if end < len(types) and end in pdi_run:
                links[idx] = pdi_run[end]
    used = set()
    sequences = []
    for idx in range(len(runs)):
        if idx in used:
            continue
        seq = list(runs[idx])
        used.add(idx)
        cur = idx
        while cur in links:
            nxt = links[cur]
            if nxt in used:
                break
            used.add(nxt)
            seq.extend(runs[nxt])
            cur = nxt
        sequences.append(seq)
    return sequences


def seq_sos_eos(seq, types, levels, para_level):
    first = seq[0]
    if first == 0:
        prev_level = para_level
    else:
        prev_level = levels[first - 1] if types[first - 1] not in REMOVED else para_level
        # level of the character before the first one in the sequence
        j = first - 1
        while j >= 0 and types[j] in REMOVED:
            j -= 1
        prev_level = levels[j] if j >= 0 else para_level
    sos = "R" if max(levels[first], prev_level) % 2 else "L"

    last = seq[-1]
    if types[last] in ISOLATE_INIT:
        # The isolate's content follows, so the sequence ends at the paragraph
        # boundary unless a matching PDI exists (then it would be linked).
        next_level = para_level
    else:
        j = last + 1
        while j < len(types) and types[j] in REMOVED:
            j += 1
        next_level = levels[j] if j < len(types) else para_level
    eos = "R" if max(levels[last], next_level) % 2 else "L"
    return sos, eos


def strong_for_neutral(t):
    return "R" if t in ("R", "AL", "EN", "AN") else ("L" if t == "L" else None)


def resolve_sequence(seq, types, levels, sos, eos, cps):
    """Rules W1-W7, N0-N2, I1-I2 over one isolating run sequence."""
    ts = [types[i] for i in seq]
    n = len(ts)

    # W1: NSM takes the type of the previous character.
    for k in range(n):
        if ts[k] == "NSM":
            if k == 0:
                ts[k] = sos
            else:
                prev = ts[k - 1]
                if prev in ISOLATE_INIT or prev == "PDI":
                    ts[k] = "ON"
                else:
                    ts[k] = prev

    # W2: EN with a preceding strong AL becomes AN.
    last_strong = sos
    for k in range(n):
        t = ts[k]
        if t in ("L", "R", "AL"):
            last_strong = t
        elif t == "EN" and last_strong == "AL":
            ts[k] = "AN"

    # W3
    for k in range(n):
        if ts[k] == "AL":
            ts[k] = "R"

    # W4
    for k in range(1, n - 1):
        if ts[k] == "ES" and ts[k - 1] == "EN" and ts[k + 1] == "EN":
            ts[k] = "EN"
        elif ts[k] == "CS":
            if ts[k - 1] == "EN" and ts[k + 1] == "EN":
                ts[k] = "EN"
            elif ts[k - 1] == "AN" and ts[k + 1] == "AN":
                ts[k] = "AN"

    # W5
    k = 0
    while k < n:
        if ts[k] == "ET":
            j = k
            while j < n and ts[j] == "ET":
                j += 1
            before = ts[k - 1] if k > 0 else None
            after = ts[j] if j < n else None
            if before == "EN" or after == "EN":
                for m in range(k, j):
                    ts[m] = "EN"
            k = j
        else:
            k += 1

    # W6
    for k in range(n):
        if ts[k] in ("ES", "ET", "CS"):
            ts[k] = "ON"

    # W7
    last_strong = sos
    for k in range(n):
        t = ts[k]
        if t in ("L", "R"):
            last_strong = t
        elif t == "EN" and last_strong == "L":
            ts[k] = "L"

    # N0: paired brackets.
    if cps is not None:
        resolve_brackets(seq, ts, levels, sos, cps, types)

    # N1 / N2
    k = 0
    while k < n:
        if ts[k] in NI:
            j = k
            while j < n and ts[j] in NI:
                j += 1
            before = sos if k == 0 else strong_for_neutral(ts[k - 1])
            after = eos if j >= n else strong_for_neutral(ts[j])
            if before is None:
                before = "L"
            if after is None:
                after = "L"
            fill = before if before == after else ("R" if levels[seq[k]] % 2 else "L")
            for m in range(k, j):
                ts[m] = fill
            k = j
        else:
            k += 1

    # I1 / I2 (isolate initiators and matched PDIs keep their X-rule level)
    for k in range(n):
        idx = seq[k]
        if levels[idx] % 2 == 0:
            if ts[k] == "R":
                levels[idx] += 1
            elif ts[k] in ("AN", "EN"):
                levels[idx] += 2
        else:
            if ts[k] in ("L", "EN", "AN"):
                levels[idx] += 1


# BD16 compares brackets up to canonical equivalence; only two bracket
# characters have a canonical equivalent in Unicode.
CANONICAL_BRACKETS = {0x2329: 0x3008, 0x232A: 0x3009}


def bracket_canonical(cp):
    return CANONICAL_BRACKETS.get(cp, cp)


def resolve_brackets(seq, ts, levels, sos, cps, orig_types):
    """N0 with BD16 bracket pairing, operating on one isolating run sequence."""
    n = len(ts)
    stack = []
    pairs = []
    for k in range(n):
        if ts[k] != "ON":
            continue
        cp = cps[seq[k]]
        if cp not in BRACKETS:
            continue
        bpb, kind = BRACKETS[cp]
        if kind == "o":
            if len(stack) >= 63:
                break  # BD16: bracket pairing is capped at depth 63
            stack.append((k, bracket_canonical(bpb)))
        else:
            for si in range(len(stack) - 1, -1, -1):
                if stack[si][1] == bracket_canonical(cp) and ts[stack[si][0]] == "ON":
                    pairs.append((stack[si][0], k))
                    del stack[si:]
                    break
    pairs.sort()

    # Track strong types, treating EN/AN as R.
    def strong(k):
        t = ts[k]
        if t == "EN" or t == "AN":
            return "R"
        if t in ("L", "R"):
            return t
        return None

    for open_k, close_k in pairs:
        embed = "R" if levels[seq[open_k]] % 2 else "L"
        opposite = "L" if embed == "R" else "R"
        found_embed = False
        found_opposite = False
        for k in range(open_k + 1, close_k):
            s = strong(k)
            if s == embed:
                found_embed = True
                break
            if s == opposite:
                found_opposite = True
        if found_embed:
            new_type = embed
        elif found_opposite:
            preceding = None
            for k in range(open_k - 1, -1, -1):
                s = strong(k)
                if s is not None:
                    preceding = s
                    break
            if preceding is None:
                preceding = sos
            new_type = opposite if preceding == opposite else embed
        else:
            continue
        ts[open_k] = new_type
        ts[close_k] = new_type
        # NSMs that were originally NSM before W1 follow the bracket's new type.
        for base in (open_k, close_k):
            k = base + 1
            while k < n and orig_types[seq[k]] == "NSM":
                ts[k] = new_type
                k += 1


def resolve(types, cps, direction):
    """Full UBA. Returns (levels, reorder). direction: 0=LTR, 1=RTL, 2=auto."""
    para = paragraph_level(types, direction)
    levels, resolved = explicit_levels(types, para)
    # sos/eos depend on the X-rule levels only, so snapshot them first: the
    # implicit rules mutate `levels` while the sequences are processed.
    sequences = isolating_run_sequences(types, levels)
    boundaries = [seq_sos_eos(seq, types, levels, para) for seq in sequences]
    for seq, (sos, eos) in zip(sequences, boundaries):
        resolve_sequence(seq, resolved, levels, sos, eos, cps)
    # L1
    n = len(types)
    for i, t in enumerate(types):
        if t in ("S", "B"):
            levels[i] = para
    i = 0
    while i < n:
        if types[i] in ("S", "B"):
            j = i - 1
            while j >= 0 and (
                types[j] == "WS"
                or types[j] in ISOLATE_INIT
                or types[j] == "PDI"
                or types[j] in REMOVED
            ):
                if types[j] not in REMOVED:
                    levels[j] = para
                j -= 1
            i += 1
        else:
            i += 1
    j = n - 1
    while j >= 0 and (
        types[j] == "WS"
        or types[j] in ISOLATE_INIT
        or types[j] == "PDI"
        or types[j] in REMOVED
    ):
        if types[j] not in REMOVED:
            levels[j] = para
        j -= 1
    # L2 (characters removed by X9 take no part in reordering)
    keep = [i for i, t in enumerate(types) if t not in REMOVED]
    seq_levels = [levels[i] for i in keep]
    order = list(range(len(keep)))
    if seq_levels:
        highest = max(seq_levels)
        lowest_odd = min((lv for lv in seq_levels if lv % 2), default=highest + 1)
        for level in range(highest, lowest_odd - 1, -1):
            k = 0
            m = len(seq_levels)
            while k < m:
                if seq_levels[order[k]] >= level:
                    j = k
                    while j < m and seq_levels[order[j]] >= level:
                        j += 1
                    order[k:j] = reversed(order[k:j])
                    k = j
                else:
                    k += 1
    return levels, [keep[i] for i in order]


def run_character_test():
    path = os.path.join(UCD, "BidiCharacterTest.txt")
    total = passed = 0
    first = None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.split("#", 1)[0].strip()
            if not line:
                continue
            f = [p.strip() for p in line.split(";")]
            cps = [int(x, 16) for x in f[0].split()]
            direction = int(f[1])
            exp_level = int(f[2]) if f[2] != "x" else None
            exp_levels = [None if x == "x" else int(x) for x in f[3].split()]
            exp_order = [int(x) for x in f[4].split()]
            types = [bidi_class_of(cp) for cp in cps]
            levels, order = resolve(types, cps, direction)
            total += 1
            got_levels = [
                None if exp_levels[i] is None else levels[i] for i in range(len(cps))
            ]
            got_order = [i for i in order if exp_levels[i] is not None]
            if got_levels == exp_levels and got_order == exp_order:
                passed += 1
            elif first is None:
                first = (cps, direction, exp_level, exp_levels, got_levels, exp_order, got_order)
    print(f"BidiCharacterTest  {passed}/{total}")
    if first:
        cps, d, el, els, ls, eo, o = first
        print("  first failure: dir", d, "para", el)
        print("   cps  ", " ".join(f"{c:04X}" for c in cps))
        print("   types", [bidi_class_of(c) for c in cps])
        print("   levels exp", els)
        print("   levels got", ls)
        print("   order  exp", eo)
        print("   order  got", o)
    return total - passed


def run_test():
    path = os.path.join(UCD, "BidiTest.txt")
    total = passed = 0
    first = None
    exp_levels = None
    exp_order = None
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("@Levels:"):
                raw = line.split(":", 1)[1].strip()
                exp_levels = (
                    None if raw == "x" else [None if x == "x" else int(x) for x in raw.split()]
                )
                continue
            if line.startswith("@Reorder:"):
                raw = line.split(":", 1)[1].strip()
                exp_order = [int(x) for x in raw.split()] if raw else []
                continue
            body = line.split("#", 1)[0].strip()
            if ";" not in body:
                continue
            classes, bitset = body.split(";")
            types = classes.split()
            bitset = int(bitset.strip(), 16)
            for bit, direction in ((1, 2), (2, 0), (4, 1)):
                if not bitset & bit:
                    continue
                levels, order = resolve(list(types), None, direction)
                total += 1
                got_order = [i for i in order if types[i] not in REMOVED]
                got_levels = levels
                if exp_levels is not None:
                    got_levels = [
                        None if exp_levels[i] is None else levels[i]
                        for i in range(len(types))
                    ]
                ok = got_order == exp_order
                if ok and exp_levels is not None:
                    ok = got_levels == exp_levels
                if ok:
                    passed += 1
                elif first is None:
                    first = (types, direction, exp_levels, got_levels, exp_order, got_order)
    print(f"BidiTest           {passed}/{total}")
    if first:
        types, d, el, ls, eo, o = first
        print("  first failure: dir", d)
        print("   types ", types)
        print("   levels exp", el)
        print("   levels got", ls)
        print("   order  exp", eo)
        print("   order  got", o)
    return total - passed


if __name__ == "__main__":
    bad = 0
    bad += run_character_test()
    bad += run_test()
    sys.exit(1 if bad else 0)
