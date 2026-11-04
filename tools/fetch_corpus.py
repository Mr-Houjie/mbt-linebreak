"""Download the Unicode Character Database files used by this project.

Usage:
    python tools/fetch_corpus.py [--force]

Files land in corpus/ucd/ and are committed to the repository so that
`moon run cmd/verify` works offline and in CI.
"""

from __future__ import annotations

import os
import sys
import urllib.request

VERSION = "18.0.0"
BASE = f"https://www.unicode.org/Public/{VERSION}/ucd"
ROOT = os.path.join(os.path.dirname(__file__), "..", "corpus", "ucd")

FILES = [
    "LineBreak.txt",
    "DerivedCoreProperties.txt",
    "EastAsianWidth.txt",
    "UnicodeData.txt",
    "extracted/DerivedBidiClass.txt",
    "BidiBrackets.txt",
    "BidiMirroring.txt",
    "BidiTest.txt",
    "BidiCharacterTest.txt",
    "PropList.txt",
    "auxiliary/GraphemeBreakProperty.txt",
    "auxiliary/WordBreakProperty.txt",
    "auxiliary/SentenceBreakProperty.txt",
    "auxiliary/GraphemeBreakTest.txt",
    "auxiliary/WordBreakTest.txt",
    "auxiliary/SentenceBreakTest.txt",
    "auxiliary/LineBreakTest.txt",
    "emoji/emoji-data.txt",
]


def main() -> int:
    force = "--force" in sys.argv
    for name in FILES:
        dest = os.path.join(ROOT, name.replace("/", os.sep))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        if os.path.exists(dest) and not force:
            print(f"skip  {name} ({os.path.getsize(dest)} bytes)")
            continue
        url = f"{BASE}/{name}"
        print(f"fetch {url}")
        with urllib.request.urlopen(url, timeout=120) as resp:
            data = resp.read()
        with open(dest, "wb") as fh:
            fh.write(data)
        print(f"  -> {len(data)} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
