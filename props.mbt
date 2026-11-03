// UCD 属性查询。
//
// 表由 `tools/gen_tables.py` 从 Unicode 18.0.0 生成，按区间存储，
// 查询用二分查找。未列出的码点返回 -1，表示该属性的默认值
// （Grapheme/Word/Sentence 为 Other，Line_Break 为 XX）。

///|
/// 在三元组数组 `(lo, hi, value)` 中查找码点所属区间。
fn lookup3(table : Array[Int32], cp : Int32) -> Int32 {
  let mut lo = 0
  let mut hi = table.length() / 3 - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let base = mid * 3
    if cp < table[base] {
      hi = mid - 1
    } else if cp > table[base + 1] {
      lo = mid + 1
    } else {
      return table[base + 2]
    }
  }
  -1
}

///|
/// 在二元组数组 `(lo, hi)` 中判断码点是否命中。
fn in_ranges(table : Array[Int32], cp : Int32) -> Bool {
  let mut lo = 0
  let mut hi = table.length() / 2 - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let base = mid * 2
    if cp < table[base] {
      hi = mid - 1
    } else if cp > table[base + 1] {
      lo = mid + 1
    } else {
      return true
    }
  }
  false
}

///|
fn gcb_of(cp : Int32) -> Int32 {
  lookup3(gcb_ranges, cp)
}

///|
fn wb_of(cp : Int32) -> Int32 {
  lookup3(wb_ranges, cp)
}

///|
fn sb_of(cp : Int32) -> Int32 {
  lookup3(sb_ranges, cp)
}

///|
fn lb_of(cp : Int32) -> Int32 {
  lookup3(lb_ranges, cp)
}

///|
fn eaw_of(cp : Int32) -> Int32 {
  lookup3(eaw_ranges, cp)
}

///|
fn is_incb_linker(cp : Int32) -> Bool {
  in_ranges(incb_linker_ranges, cp)
}

///|
fn is_incb_consonant(cp : Int32) -> Bool {
  in_ranges(incb_consonant_ranges, cp)
}

///|
fn is_incb_extend(cp : Int32) -> Bool {
  in_ranges(incb_extend_ranges, cp)
}

///|
fn is_extpict(cp : Int32) -> Bool {
  in_ranges(extpict_ranges, cp)
}

///|
fn is_emoji_presentation(cp : Int32) -> Bool {
  in_ranges(emoji_pres_ranges, cp)
}

///|
fn is_pi_qu(cp : Int32) -> Bool {
  in_ranges(pi_qu_ranges, cp)
}

///|
fn is_pf_qu(cp : Int32) -> Bool {
  in_ranges(pf_qu_ranges, cp)
}

///|
fn is_extpict_cn(cp : Int32) -> Bool {
  in_ranges(extpict_cn_ranges, cp)
}

///|
fn is_mark(cp : Int32) -> Bool {
  in_ranges(mark_ranges, cp)
}

///|
/// 东亚宽度类别名，主要用于诊断输出。
pub fn eaw_name(c : Int32) -> String {
  if c == EAW_F {
    "F"
  } else if c == EAW_W {
    "W"
  } else if c == EAW_H {
    "H"
  } else if c == EAW_A {
    "A"
  } else if c == EAW_NA {
    "Na"
  } else if c == EAW_N {
    "N"
  } else {
    "?"
  }
}
