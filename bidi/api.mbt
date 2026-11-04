// 公共 API。

///|
fn to_cps(s : String) -> Array[Int32] {
  let out : Array[Int32] = []
  for c in s {
    out.push(c.to_int())
  }
  out
}

///|
/// 以码点数组执行 UAX #9（供工具与一致性测试使用）。
pub fn resolve_codepoints(
  cps : Array[Int32],
  direction : Direction,
) -> BidiResult {
  resolve_bidi(cps, direction)
}

///|
/// 执行完整 UAX #9，返回每个字符的层级与视觉顺序。
pub fn resolve(text : String, direction : Direction) -> BidiResult {
  resolve_bidi(to_cps(text), direction)
}

///|
/// 按视觉顺序重排字符串（显式格式字符不可见，直接从结果中剔除）。
pub fn reorder(text : String, direction : Direction) -> String {
  let chars = text.iter().to_array()
  let result = resolve(text, direction)
  let builder = StringBuilder()
  for idx in result.order {
    if idx < chars.length() {
      builder.write_char(chars[idx])
    }
  }
  builder.to_string()
}

///|
/// 解析出的段落层级：0 为从左到右，1 为从右到左。
pub fn paragraph_level_of(text : String, direction : Direction) -> Int32 {
  resolve(text, direction).paragraph_level
}

///|
/// 属性表对应的 Unicode 版本。
pub fn unicode_version() -> String {
  "18.0.0"
}

///|
/// 按 Bidi_Class 名称取类别编号，供一致性测试与工具使用。
pub fn class_from_name(name : String) -> Int32 {
  if name == "L" {
    BC_L
  } else if name == "R" {
    BC_R
  } else if name == "AL" {
    BC_AL
  } else if name == "EN" {
    BC_EN
  } else if name == "ES" {
    BC_ES
  } else if name == "ET" {
    BC_ET
  } else if name == "AN" {
    BC_AN
  } else if name == "CS" {
    BC_CS
  } else if name == "NSM" {
    BC_NSM
  } else if name == "BN" {
    BC_BN
  } else if name == "B" {
    BC_B
  } else if name == "S" {
    BC_S
  } else if name == "WS" {
    BC_WS
  } else if name == "ON" {
    BC_ON
  } else if name == "LRE" {
    BC_LRE
  } else if name == "RLE" {
    BC_RLE
  } else if name == "LRO" {
    BC_LRO
  } else if name == "RLO" {
    BC_RLO
  } else if name == "PDF" {
    BC_PDF
  } else if name == "LRI" {
    BC_LRI
  } else if name == "RLI" {
    BC_RLI
  } else if name == "FSI" {
    BC_FSI
  } else if name == "PDI" {
    BC_PDI
  } else {
    -1
  }
}

///|
/// 直接以 Bidi_Class 序列执行算法（BidiTest.txt 的用法，无括号配对）。
pub fn resolve_by_classes(
  classes : Array[Int32],
  direction : Direction,
) -> BidiResult {
  resolve_types(classes, [], direction, false)
}
