// UAX #9 的 Bidi_Class 与括号对查询。

///|
fn bidi_lookup3(table : Array[Int32], cp : Int32) -> Int32 {
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
  BC_L
}

///|
fn bidi_class_of(cp : Int32) -> Int32 {
  bidi_lookup3(bc_ranges, cp)
}

///|
/// 括号信息：返回 (配对码点, 类型)，类型 0 = 开括号，1 = 闭括号。
fn bracket_of(cp : Int32) -> (Int32, Int32)? {
  let mut lo = 0
  let mut hi = bc_bracket_cps.length() - 1
  while lo <= hi {
    let mid = (lo + hi) / 2
    let probe = bc_bracket_cps[mid]
    if cp < probe {
      hi = mid - 1
    } else if cp > probe {
      lo = mid + 1
    } else {
      return Some((bc_bracket_pairs[mid], bc_bracket_kinds[mid]))
    }
  }
  None
}

///|
/// BD16 允许括号按规范等价配对；Unicode 中只有两组存在这种等价。
fn bracket_canonical(cp : Int32) -> Int32 {
  if cp == 0x2329 {
    0x3008
  } else if cp == 0x232A {
    0x3009
  } else {
    cp
  }
}

///|
fn is_isolate_init(c : Int32) -> Bool {
  c == BC_LRI || c == BC_RLI || c == BC_FSI
}

///|
fn is_removed(c : Int32) -> Bool {
  c == BC_RLE ||
  c == BC_LRE ||
  c == BC_RLO ||
  c == BC_LRO ||
  c == BC_PDF ||
  c == BC_BN
}

///|
fn is_hard_break(c : Int32) -> Bool {
  c == BC_B || c == BC_S
}

///|
fn is_neutral(c : Int32) -> Bool {
  if c == BC_B || c == BC_S || c == BC_WS || c == BC_ON {
    true
  } else if c == BC_LRI || c == BC_RLI || c == BC_FSI || c == BC_PDI {
    true
  } else {
    false
  }
}

///|
fn is_strong(c : Int32) -> Bool {
  c == BC_L || c == BC_R || c == BC_AL
}

///|
fn strong_like(c : Int32) -> Int32 {
  // N1/N2 中 EN 与 AN 视作 R
  if c == BC_EN || c == BC_AN || c == BC_R || c == BC_AL {
    BC_R
  } else if c == BC_L {
    BC_L
  } else {
    -1
  }
}
