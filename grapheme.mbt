// UAX #29 字素簇边界（Unicode 18.0，规则 GB1–GB999）。

///|
/// 计算字素簇边界，返回长度 `n + 1` 的布尔数组；
/// `breaks[i]` 表示第 i 个码点之前是否允许断开。
fn grapheme_breaks(cps : Array[Int32]) -> Array[Bool] {
  let n = cps.length()
  let breaks : Array[Bool] = []
  for i = 0; i <= n; i = i + 1 {
    breaks.push(true)
  }
  for i = 1; i < n; i = i + 1 {
    let pc = gcb_of(cps[i - 1])
    let cc = gcb_of(cps[i])
    // GB3
    if pc == GCB_CR && cc == GCB_LF {
      breaks[i] = false
      continue
    }
    // GB4 / GB5
    if pc == GCB_CONTROL || pc == GCB_CR || pc == GCB_LF {
      continue
    }
    if cc == GCB_CONTROL || cc == GCB_CR || cc == GCB_LF {
      continue
    }
    // GB6 / GB7 / GB8：Hangul
    if pc == GCB_L &&
      (cc == GCB_L || cc == GCB_V || cc == GCB_LV || cc == GCB_LVT) {
      breaks[i] = false
      continue
    }
    if (pc == GCB_LV || pc == GCB_V) && (cc == GCB_V || cc == GCB_T) {
      breaks[i] = false
      continue
    }
    if (pc == GCB_LVT || pc == GCB_T) && cc == GCB_T {
      breaks[i] = false
      continue
    }
    // GB9 / GB9a
    if cc == GCB_EXTEND || cc == GCB_ZWJ || cc == GCB_SPACINGMARK {
      breaks[i] = false
      continue
    }
    // GB9b
    if pc == GCB_PREPEND {
      breaks[i] = false
      continue
    }
    // GB9c（Unicode 18.0：Linker Extend* × Consonant）
    if is_incb_consonant(cps[i]) {
      let mut j = i - 1
      while j >= 0 && is_incb_extend(cps[j]) {
        j = j - 1
      }
      if j >= 0 && is_incb_linker(cps[j]) {
        breaks[i] = false
        continue
      }
    }
    // GB11：ExtPict Extend* ZWJ × ExtPict
    if is_extpict(cps[i]) {
      let mut j = i - 1
      if j >= 0 && gcb_of(cps[j]) == GCB_ZWJ {
        j = j - 1
        while j >= 0 && gcb_of(cps[j]) == GCB_EXTEND {
          j = j - 1
        }
        if j >= 0 && is_extpict(cps[j]) {
          breaks[i] = false
          continue
        }
      }
    }
    // GB12 / GB13：区域指示符成对
    if pc == GCB_REGIONAL_INDICATOR && cc == GCB_REGIONAL_INDICATOR {
      let mut count = 0
      let mut j = i - 1
      while j >= 0 && gcb_of(cps[j]) == GCB_REGIONAL_INDICATOR {
        count = count + 1
        j = j - 1
      }
      breaks[i] = count % 2 == 0
      continue
    }
    // GB999 保持默认：允许断开
  }
  breaks
}
