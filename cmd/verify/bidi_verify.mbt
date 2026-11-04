// UAX #9 官方语料自检。
//
// BidiCharacterTest.txt 给出码点与期望的层级/重排；
// BidiTest.txt 给出类别序列与期望的层级/重排。
// 两者都用 'x' 标记“该字符不参与层级比较与重排”。

///|
fn before_comment(line : String) -> String {
  match line.split("#").next() {
    Some(v) => v.to_owned()
    None => ""
  }
}

///|
fn parse_hex(s : String) -> Int32 {
  let mut value = 0
  for c in s {
    let code = c.to_int()
    let digit = if code >= 48 && code <= 57 {
      code - 48
    } else if code >= 65 && code <= 70 {
      code - 55
    } else if code >= 97 && code <= 102 {
      code - 87
    } else {
      -1
    }
    if digit < 0 {
      continue
    }
    value = value * 16 + digit
  }
  value
}

///|
fn is_x(field : String) -> Bool {
  field == "x"
}

///|
/// 解析十进制整数。
fn parse_dec(s : String) -> Int32 {
  let mut value = 0
  for c in s {
    let digit = c.to_int() - 48
    if digit < 0 || digit > 9 {
      continue
    }
    value = value * 10 + digit
  }
  value
}

///|
/// 解析 "1 1 x 2" 形式的字段（十进制）；`x` 记为 -1。
fn parse_number_list(s : String) -> Array[Int32] {
  let out : Array[Int32] = []
  for token in s.split(" ") {
    let t = token.to_owned()
    if t.length() == 0 {
      continue
    }
    if is_x(t) {
      out.push(-1)
    } else {
      out.push(parse_dec(t))
    }
  }
  out
}

///|
fn join_ints(values : Array[Int32]) -> String {
  let b = StringBuilder()
  for v in values {
    if b.to_string().length() > 0 {
      b.write_string(",")
    }
    b.write_string("\{v}")
  }
  b.to_string()
}

///|
fn run_character_test(path : String) -> (Int32, Int32, String) {
  let text = @fs.read_file_to_string(path) catch {
    _ => {
      println("  [read-error] \{path}")
      return (0, 0, "read-error")
    }
  }
  let mut total = 0
  let mut passed = 0
  let mut first = ""
  for raw in text.split("\n") {
    let line = raw.to_owned()
    let body = before_comment(line)
    let trimmed = body.trim().to_owned()
    if trimmed.length() == 0 {
      continue
    }
    let fields : Array[String] = []
    for part in trimmed.split(";") {
      fields.push(part.to_owned().trim().to_owned())
    }
    if fields.length() < 5 {
      continue
    }
    let cps : Array[Int32] = []
    for token in fields[0].split(" ") {
      let t = token.to_owned()
      if t.length() > 0 {
        cps.push(parse_hex(t))
      }
    }
    let direction = parse_hex(fields[1])
    let exp_levels = parse_number_list(fields[3])
    let exp_order = parse_number_list(fields[4])
    total = total + 1
    let dir = if direction == 0 {
      @bidi.Direction::Ltr
    } else if direction == 1 {
      @bidi.Direction::Rtl
    } else {
      @bidi.Direction::Auto
    }
    let result = @bidi.resolve_codepoints(cps, dir)
    // 跳过 'x' 位置的比较
    let got_levels : Array[Int32] = []
    let exp_masked : Array[Int32] = []
    for i = 0; i < exp_levels.length() && i < result.levels.length(); i = i + 1 {
      if exp_levels[i] >= 0 {
        exp_masked.push(exp_levels[i])
        got_levels.push(result.levels[i])
      }
    }
    let got_order : Array[Int32] = []
    for idx in result.order {
      if idx < exp_levels.length() && exp_levels[idx] >= 0 {
        got_order.push(idx)
      }
    }
    if got_levels == exp_masked && got_order == exp_order {
      passed = passed + 1
    } else if first == "" {
      first = "cps=[\{join_ints(cps)}] exp=[\{join_ints(exp_masked)}] got=[\{join_ints(got_levels)}] exp_order=[\{join_ints(exp_order)}] got_order=[\{join_ints(got_order)}]"
    }
  }
  (passed, total, first)
}

///|
fn run_class_test(path : String) -> (Int32, Int32, String) {
  let text = @fs.read_file_to_string(path) catch {
    _ => {
      println("  [read-error] \{path}")
      return (0, 0, "read-error")
    }
  }
  let mut total = 0
  let mut passed = 0
  let mut first = ""
  let mut exp_levels : Array[Int32] = []
  let mut has_levels = false
  let mut exp_order : Array[Int32] = []
  for raw in text.split("\n") {
    let line = raw.to_owned()
    if line.has_prefix("@Levels:") {
      let rest = line[8:].to_owned().trim().to_owned()
      if rest == "x" {
        has_levels = false
        exp_levels = []
      } else {
        has_levels = true
        exp_levels = parse_number_list(rest)
      }
      continue
    }
    if line.has_prefix("@Reorder:") {
      let rest = line[9:].to_owned().trim().to_owned()
      exp_order = parse_number_list(rest)
      continue
    }
    if line.length() == 0 || line.has_prefix("#") {
      continue
    }
    let body = before_comment(line)
    let trimmed = body.trim().to_owned()
    if !trimmed.contains(";") {
      continue
    }
    let parts : Array[String] = []
    for part in trimmed.split(";") {
      parts.push(part.to_owned().trim().to_owned())
    }
    if parts.length() < 2 {
      continue
    }
    let classes : Array[Int32] = []
    for token in parts[0].split(" ") {
      let t = token.to_owned()
      if t.length() > 0 {
        classes.push(@bidi.class_from_name(t))
      }
    }
    let bitset = parse_hex(parts[1])
    let tries = [
      (1, @bidi.Direction::Auto),
      (2, @bidi.Direction::Ltr),
      (4, @bidi.Direction::Rtl),
    ]
    for item in tries {
      let (bit, dir) = item
      if bitset / bit % 2 == 0 {
        continue
      }
      total = total + 1
      let result = @bidi.resolve_by_classes(classes, dir)
      let got_levels : Array[Int32] = []
      let exp_masked : Array[Int32] = []
      if has_levels {
        for i = 0
            i < exp_levels.length() && i < result.levels.length()
            i = i + 1 {
          if exp_levels[i] >= 0 {
            exp_masked.push(exp_levels[i])
            got_levels.push(result.levels[i])
          }
        }
      }
      let got_order : Array[Int32] = []
      for idx in result.order {
        if !has_levels || (idx < exp_levels.length() && exp_levels[idx] >= 0) {
          got_order.push(idx)
        }
      }
      let level_ok = if has_levels { got_levels == exp_masked } else { true }
      if level_ok && got_order == exp_order {
        passed = passed + 1
      } else if first == "" {
        first = "classes=[\{join_ints(classes)}] exp=[\{join_ints(exp_masked)}] got=[\{join_ints(got_levels)}] exp_order=[\{join_ints(exp_order)}] got_order=[\{join_ints(got_order)}]"
      }
    }
  }
  (passed, total, first)
}

///|
fn run_bidi_conformance(base : String) -> Array[String] {
  let failures : Array[String] = []
  let (cp_pass, cp_total, cp_detail) = run_character_test(
    base + "/BidiCharacterTest.txt",
  )
  if cp_total == 0 {
    failures.push("bidi-character: 0 cases（文件缺失或为空）")
  } else {
    println(
      "bidi-character: \{cp_pass}/\{cp_total} (\{cp_pass * 100 / cp_total}%)",
    )
    if cp_pass != cp_total {
      failures.push("bidi-character: \{cp_pass}/\{cp_total} — \{cp_detail}")
    }
  }
  let (cls_pass, cls_total, cls_detail) = run_class_test(base + "/BidiTest.txt")
  if cls_total == 0 {
    failures.push("bidi-class: 0 cases（文件缺失或为空）")
  } else {
    println(
      "bidi-class: \{cls_pass}/\{cls_total} (\{cls_pass * 100 / cls_total}%)",
    )
    if cls_pass != cls_total {
      failures.push("bidi-class: \{cls_pass}/\{cls_total} — \{cls_detail}")
    }
  }
  failures
}
