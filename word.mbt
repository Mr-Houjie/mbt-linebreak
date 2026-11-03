// UAX #29 词边界（Unicode 18.0，规则 WB1–WB999）。

///|
fn wb_is_ignorable(cp : Int32) -> Bool {
  let c = wb_of(cp)
  c == WB_EXTEND || c == WB_FORMAT || c == WB_ZWJ
}

///|
fn wb_prev_effective(cps : Array[Int32], i : Int32) -> Int32 {
  let mut j = i - 1
  while j >= 0 && wb_is_ignorable(cps[j]) {
    j = j - 1
  }
  j
}

///|
fn wb_next_effective(cps : Array[Int32], i : Int32) -> Int32 {
  let mut j = i + 1
  while j < cps.length() && wb_is_ignorable(cps[j]) {
    j = j + 1
  }
  j
}

///|
fn wb_is_ah(c : Int32) -> Bool {
  c == WB_ALETTER || c == WB_HEBREW_LETTER
}

///|
fn wb_is_mid_letter(c : Int32) -> Bool {
  c == WB_MIDLETTER || c == WB_MIDNUMLET || c == WB_SINGLE_QUOTE
}

///|
fn wb_is_mid_num(c : Int32) -> Bool {
  c == WB_MIDNUM || c == WB_MIDNUMLET || c == WB_SINGLE_QUOTE
}

///|
fn word_breaks(cps : Array[Int32]) -> Array[Bool] {
  let n = cps.length()
  let breaks : Array[Bool] = []
  for i = 0; i <= n; i = i + 1 {
    breaks.push(true)
  }
  for i = 1; i < n; i = i + 1 {
    let pc = wb_of(cps[i - 1])
    let cc = wb_of(cps[i])
    // WB3 / WB3a / WB3b
    if pc == WB_CR && cc == WB_LF {
      breaks[i] = false
      continue
    }
    if pc == WB_NEWLINE || pc == WB_CR || pc == WB_LF {
      continue
    }
    if cc == WB_NEWLINE || cc == WB_CR || cc == WB_LF {
      continue
    }
    // WB3c
    if pc == WB_ZWJ && is_extpict(cps[i]) {
      breaks[i] = false
      continue
    }
    // WB3d
    if pc == WB_WSEGSPACE && cc == WB_WSEGSPACE {
      breaks[i] = false
      continue
    }
    // WB4
    if cc == WB_EXTEND || cc == WB_FORMAT || cc == WB_ZWJ {
      breaks[i] = false
      continue
    }
    let pi = wb_prev_effective(cps, i)
    if pi < 0 {
      continue
    }
    let prev = wb_of(cps[pi])
    let cur = wb_of(cps[i])
    let ni = wb_next_effective(cps, i)
    let next = if ni < n { wb_of(cps[ni]) } else { -1 }
    let p2i = wb_prev_effective(cps, pi)
    let prev2 = if p2i >= 0 { wb_of(cps[p2i]) } else { -1 }
    // WB5
    if wb_is_ah(prev) && wb_is_ah(cur) {
      breaks[i] = false
      continue
    }
    // WB6 / WB7
    if wb_is_ah(prev) && wb_is_mid_letter(cur) && wb_is_ah(next) {
      breaks[i] = false
      continue
    }
    if wb_is_ah(prev2) && wb_is_mid_letter(prev) && wb_is_ah(cur) {
      breaks[i] = false
      continue
    }
    // WB7a / WB7b / WB7c
    if prev == WB_HEBREW_LETTER && cur == WB_SINGLE_QUOTE {
      breaks[i] = false
      continue
    }
    if prev == WB_HEBREW_LETTER &&
      cur == WB_DOUBLE_QUOTE &&
      next == WB_HEBREW_LETTER {
      breaks[i] = false
      continue
    }
    if prev2 == WB_HEBREW_LETTER &&
      prev == WB_DOUBLE_QUOTE &&
      cur == WB_HEBREW_LETTER {
      breaks[i] = false
      continue
    }
    // WB8 / WB9 / WB10
    if prev == WB_NUMERIC && cur == WB_NUMERIC {
      breaks[i] = false
      continue
    }
    if wb_is_ah(prev) && cur == WB_NUMERIC {
      breaks[i] = false
      continue
    }
    if prev == WB_NUMERIC && wb_is_ah(cur) {
      breaks[i] = false
      continue
    }
    // WB11 / WB12
    if prev2 == WB_NUMERIC && wb_is_mid_num(prev) && cur == WB_NUMERIC {
      breaks[i] = false
      continue
    }
    if prev == WB_NUMERIC && wb_is_mid_num(cur) && next == WB_NUMERIC {
      breaks[i] = false
      continue
    }
    // WB13
    if prev == WB_KATAKANA && cur == WB_KATAKANA {
      breaks[i] = false
      continue
    }
    // WB13a / WB13b
    if (
        wb_is_ah(prev) ||
        prev == WB_NUMERIC ||
        prev == WB_KATAKANA ||
        prev == WB_EXTENDNUMLET
      ) &&
      cur == WB_EXTENDNUMLET {
      breaks[i] = false
      continue
    }
    if prev == WB_EXTENDNUMLET &&
      (wb_is_ah(cur) || cur == WB_NUMERIC || cur == WB_KATAKANA) {
      breaks[i] = false
      continue
    }
    // WB15 / WB16
    if prev == WB_REGIONAL_INDICATOR && cur == WB_REGIONAL_INDICATOR {
      let mut count = 0
      let mut j = pi
      while j >= 0 {
        if wb_of(cps[j]) == WB_REGIONAL_INDICATOR {
          count = count + 1
        } else if !wb_is_ignorable(cps[j]) {
          break
        }
        j = j - 1
      }
      breaks[i] = count % 2 == 0
      continue
    }
    // WB999 保持默认：允许断开
  }
  breaks
}
