// 显示宽度（等宽字体下的列数）。
//
// 宽度没有 Unicode 标准可循，这里采用与 rivo/uniseg 相同的策略：
// 基础宽度为 1，组合符与控制符为 0，东亚宽字符为 2，emoji 按
// Emoji_Presentation 取 1 或 2，并在字素簇级别做修正。

///|
fn codepoint_width(cp : Int32) -> Int32 {
  if cp == 0x2E3A {
    return 3
  }
  if cp == 0x2E3B {
    return 4
  }
  let g = gcb_of(cp)
  if g == GCB_CONTROL ||
    g == GCB_CR ||
    g == GCB_LF ||
    g == GCB_EXTEND ||
    g == GCB_ZWJ {
    return 0
  }
  let e = eaw_of(cp)
  if e == EAW_F || e == EAW_W {
    return 2
  }
  if g == GCB_REGIONAL_INDICATOR {
    return 2
  }
  if is_extpict(cp) {
    if is_emoji_presentation(cp) {
      return 2
    }
    return 1
  }
  1
}

///|
fn cluster_width(cps : Array[Int32], start : Int32, end : Int32) -> Int32 {
  let g0 = gcb_of(cps[start])
  if g0 == GCB_L || g0 == GCB_V || g0 == GCB_LV || g0 == GCB_LVT || g0 == GCB_T {
    return 2
  }
  if g0 == GCB_REGIONAL_INDICATOR && end - start >= 2 {
    return 2
  }
  if is_extpict(cps[start]) {
    let mut w = if is_emoji_presentation(cps[start]) { 2 } else { 1 }
    for k = start; k < end; k = k + 1 {
      if cps[k] == 0xFE0E {
        w = 1
      } else if cps[k] == 0xFE0F {
        w = 2
      }
    }
    return w
  }
  let mut w = 0
  for k = start; k < end; k = k + 1 {
    w = w + codepoint_width(cps[k])
  }
  w
}
