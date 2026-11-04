// 黑盒测试：UAX #9 的公开行为。
//
// 完整的 BidiCharacterTest / BidiTest 语料由 `cmd/verify` 覆盖，
// 这里验证公开 API 的典型用法与边界。

///|
test "纯拉丁文本层级为 0 且顺序不变" {
  let r = @bidi.resolve("Hello", @bidi.Direction::Auto)
  assert_eq(r.paragraph_level, 0)
  assert_eq(r.levels, [0, 0, 0, 0, 0])
  assert_eq(r.order, [0, 1, 2, 3, 4])
}

///|
test "纯希伯来文本按 RTL 重排" {
  let r = @bidi.resolve("אבג", @bidi.Direction::Rtl)
  assert_eq(r.paragraph_level, 1)
  assert_eq(r.levels, [1, 1, 1])
  assert_eq(r.order, [2, 1, 0])
}

///|
test "Auto 方向由首个强字符决定" {
  assert_eq(@bidi.paragraph_level_of("abcאבג", @bidi.Direction::Auto), 0)
  assert_eq(@bidi.paragraph_level_of("אבגabc", @bidi.Direction::Auto), 1)
}

///|
test "reorder 输出视觉顺序" {
  assert_eq(@bidi.reorder("abc", @bidi.Direction::Ltr), "abc")
  assert_eq(@bidi.reorder("אבג", @bidi.Direction::Rtl), "גבא")
}

///|
test "数字在 RTL 段落中保持从左到右" {
  let r = @bidi.resolve("א1ב", @bidi.Direction::Rtl)
  assert_eq(r.levels.length(), 3)
  // 数字提到 level 2，显示时仍为 "1"
  assert_eq(r.levels[1], 2)
}

///|
test "Bidi_Class 名称解析可用于类别序列" {
  let classes = [
    @bidi.class_from_name("L"),
    @bidi.class_from_name("R"),
    @bidi.class_from_name("EN"),
  ]
  let r = @bidi.resolve_by_classes(classes, @bidi.Direction::Ltr)
  assert_eq(r.levels.length(), 3)
}
