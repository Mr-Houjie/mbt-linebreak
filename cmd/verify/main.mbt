// 官方语料自检入口。
//
// 读取 Unicode 18.0.0 的四个测试文件，逐条比对边界标记。
// 这些文件放在 corpus/ucd 下，由 tools/fetch_corpus.py 下载。

///|
fn hex_value(c : Char) -> Int32 {
  let code = c.to_int()
  if code >= 48 && code <= 57 {
    code - 48
  } else if code >= 97 && code <= 102 {
    code - 87
  } else if code >= 65 && code <= 70 {
    code - 55
  } else {
    -1
  }
}

///|
fn parse_case(line : String) -> (Array[Int32], Array[Bool])? {
  let chars = line.iter().to_array()
  let cps : Array[Int32] = []
  let flags : Array[Bool] = []
  let mut i = 0
  while i < chars.length() {
    let c = chars[i]
    if c == '#' {
      break
    }
    let code = c.to_int()
    if code == 0xD7 {
      flags.push(false)
      i = i + 1
      continue
    }
    if code == 0xF7 {
      flags.push(true)
      i = i + 1
      continue
    }
    if c == ' ' || c == '\t' || c == '\r' {
      i = i + 1
      continue
    }
    let mut value = 0
    let mut j = i
    while j < chars.length() && hex_value(chars[j]) >= 0 {
      value = value * 16 + hex_value(chars[j])
      j = j + 1
    }
    if j > i {
      cps.push(value)
      i = j
    } else {
      i = i + 1
    }
  }
  if cps.length() == 0 || flags.length() != cps.length() + 1 {
    None
  } else {
    Some((cps, flags))
  }
}

///|
fn string_of_codepoints(cps : Array[Int32]) -> String {
  let builder = StringBuilder()
  for cp in cps {
    match cp.to_char() {
      Some(c) => builder.write_char(c)
      None => ()
    }
  }
  builder.to_string()
}

///|
fn kind_name(kind : @Mr-Houjie/mbt-linebreak.BreakKind) -> String {
  match kind {
    @Mr-Houjie/mbt-linebreak.BreakKind::Grapheme => "grapheme"
    @Mr-Houjie/mbt-linebreak.BreakKind::Word => "word"
    @Mr-Houjie/mbt-linebreak.BreakKind::Sentence => "sentence"
    @Mr-Houjie/mbt-linebreak.BreakKind::Line => "line"
  }
}

///|
fn run_file(
  path : String,
  kind : @Mr-Houjie/mbt-linebreak.BreakKind,
) -> (Int32, Int32, String) {
  let text = @fs.read_file_to_string(path) catch {
    _ => {
      println("  [read-error] \{path}")
      return (0, 0, "read-error \{path}")
    }
  }
  if text.length() == 0 {
    println("  [empty] \{path}")
    return (0, 0, "empty \{path}")
  }
  let mut total = 0
  let mut passed = 0
  let mut first = ""
  for line in text.split("\n") {
    match parse_case(line.to_owned()) {
      None => ()
      Some(pair) => {
        let (cps, expected) = pair
        total = total + 1
        let actual = @Mr-Houjie/mbt-linebreak.break_flags(
          string_of_codepoints(cps),
          kind,
        )
        let mut bad_at = -1
        if actual.length() != expected.length() {
          bad_at = -2
        } else {
          for i = 0; i < expected.length(); i = i + 1 {
            if actual[i] != expected[i] {
              bad_at = i
              break
            }
          }
        }
        if bad_at == -1 {
          passed = passed + 1
        } else if first == "" {
          let mut codes = ""
          for cp in cps {
            codes = codes + "\{cp} "
          }
          first = "\{kind_name(kind)} mismatch at \{bad_at} cps=[\{codes}]"
        }
      }
    }
  }
  if first != "" {
    println("  [fail] \{first}")
  }
  (passed, total, first)
}

///|
fn main {
  let args = @env.args()
  let base = if args.length() > 1 { args[1] } else { "corpus/ucd" }
  println("verify: corpus=\{(base)}")
  let cases = [
    (
      "/auxiliary/GraphemeBreakTest.txt",
      @Mr-Houjie/mbt-linebreak.BreakKind::Grapheme,
    ),
    ("/auxiliary/WordBreakTest.txt", @Mr-Houjie/mbt-linebreak.BreakKind::Word),
    (
      "/auxiliary/SentenceBreakTest.txt",
      @Mr-Houjie/mbt-linebreak.BreakKind::Sentence,
    ),
    ("/auxiliary/LineBreakTest.txt", @Mr-Houjie/mbt-linebreak.BreakKind::Line),
  ]
  let failures : Array[String] = []
  for item in cases {
    let (file, kind) = item
    let (passed, total, detail) = run_file(base + file, kind)
    let label = kind_name(kind)
    if total == 0 {
      failures.push("\{label}: 0 cases (file unreadable or empty)")
    } else {
      let rate = passed * 100 / total
      println("\{label}: \{passed}/\{total} (\{rate}%)")
      if passed != total {
        failures.push("\{label}: \{passed}/\{total} — \{detail}")
      }
    }
  }
  if failures.length() == 0 {
    println("conformance: ok")
    @sys.exit(0)
  }
  for f in failures {
    eprintln("conformance-fail: \{f}")
  }
  println("conformance: FAILED")
  @sys.exit(1)
}
