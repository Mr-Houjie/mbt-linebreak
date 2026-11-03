// 黑盒测试：只通过公开 API 验证行为。
//
// 完整的 UAX #14 / #29 一致性语料由 `cmd/verify` 跑官方 Unicode 测试文件，
// 这里覆盖公开 API 的典型行为与边界，保证 `moon test` 快速可用。

///|
fn join(parts : Array[String]) -> String {
  let builder = StringBuilder()
  for part in parts {
    builder.write_string(part)
  }
  builder.to_string()
}

///|
test "unicode version" {
  assert_eq(@Mr-Houjie/mbt-linebreak.unicode_version(), "18.0.0")
}

///|
test "graphemes: 中英文混排" {
  let g = @Mr-Houjie/mbt-linebreak.graphemes("中文a")
  assert_eq(g.length(), 3)
  assert_eq(g[0], "中")
  assert_eq(g[2], "a")
  assert_eq(join(g), "中文a")
}

///|
test "graphemes: emoji 组合序列保持完整" {
  let family = "👨‍👩‍👧‍👦"
  let g = @Mr-Houjie/mbt-linebreak.graphemes(family + "a")
  assert_eq(g.length(), 2)
  assert_eq(g[0], family)
}

///|
test "words: ASCII 词与标点" {
  let w = @Mr-Houjie/mbt-linebreak.words("Hello, world!")
  assert_eq(w, ["Hello", ",", " ", "world", "!"])
  assert_eq(join(w), "Hello, world!")
}

///|
test "sentences: 中文句号与感叹号" {
  let s = @Mr-Houjie/mbt-linebreak.sentences("你好。世界！")
  assert_eq(s.length(), 2)
  assert_eq(s[0], "你好。")
  assert_eq(s[1], "世界！")
}

///|
test "line_breaks: 汉字之间可断行，末尾为强制断点" {
  let breaks = @Mr-Houjie/mbt-linebreak.line_breaks("你好世界")
  assert_eq(breaks.length(), 4)
  assert_eq(breaks[0].index, 1)
  assert_eq(breaks[3].index, 4)
  assert_true(breaks[3].mandatory)
  assert_false(breaks[0].mandatory)
}

///|
test "line_breaks: LF 产生强制断点" {
  let breaks = @Mr-Houjie/mbt-linebreak.line_breaks("ab\ncd")
  assert_eq(breaks.length(), 2)
  assert_eq(breaks[0].index, 3)
  assert_true(breaks[0].mandatory)
}

///|
test "display_width: 东亚宽字符按 2 列计算" {
  assert_eq(@Mr-Houjie/mbt-linebreak.display_width("中文"), 4)
  assert_eq(@Mr-Houjie/mbt-linebreak.display_width("abc"), 3)
  assert_eq(@Mr-Houjie/mbt-linebreak.display_width("😀"), 2)
}

///|
test "wrap: 不丢字符且每行不超宽" {
  let text = "hello world hello"
  let lines = @Mr-Houjie/mbt-linebreak.wrap(text, 7)
  assert_eq(join(lines), text)
  for line in lines {
    assert_true(@Mr-Houjie/mbt-linebreak.display_width(line) <= 7)
  }
}

///|
test "break_flags: 四种边界都返回 n+1 个标记" {
  let text = "a中。"
  for
    kind in [
      @Mr-Houjie/mbt-linebreak.BreakKind::Grapheme,
      @Mr-Houjie/mbt-linebreak.BreakKind::Word,
      @Mr-Houjie/mbt-linebreak.BreakKind::Sentence,
      @Mr-Houjie/mbt-linebreak.BreakKind::Line,
    ] {
    let flags = @Mr-Houjie/mbt-linebreak.break_flags(text, kind)
    assert_eq(flags.length(), 4)
  }
}
