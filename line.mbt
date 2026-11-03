// UAX #14 行断裂（Unicode 18.0，UAX #14 revision 57）。
//
// 与 UAX #29 的两类边界不同，行断裂的起点是 `sot ×`（不允许在开头断开），
// 并且需要先做 LB1 类别归并、LB9/LB10 组合符继承。

///|
fn lb_base_idx(ign : Array[Bool], j : Int32) -> Int32 {
  let mut k = j
  while k >= 0 && ign[k] {
    k = k - 1
  }
  k
}

///|
fn lb_prev_nb(ign : Array[Bool], j : Int32) -> Int32 {
  lb_base_idx(ign, j - 1)
}

///|
fn lb_spaces_before(r : Array[Int32], ign : Array[Bool], i : Int32) -> Int32 {
  let mut j = lb_base_idx(ign, i - 1)
  while j >= 0 && r[j] == LB_SP {
    j = lb_prev_nb(ign, j)
  }
  j
}

///|
fn lb_is_syl(
  r : Array[Int32],
  ign : Array[Bool],
  cps : Array[Int32],
  i : Int32,
) -> Bool {
  let j = lb_base_idx(ign, i)
  j >= 0 && (r[j] == LB_AK || r[j] == LB_AS || cps[j] == 0x25CC)
}

///|
fn lb_is_ea(cps : Array[Int32], i : Int32) -> Bool {
  if i < 0 || i >= cps.length() {
    return false
  }
  let e = eaw_of(cps[i])
  e == EAW_F || e == EAW_W || e == EAW_H
}

///|
/// 匹配 `NU (SY | IS)*` 结尾：返回开头 NU 的下标，匹配失败返回 -1。
fn lb_num_tail(r : Array[Int32], j : Int32) -> Int32 {
  let mut k = j
  while k >= 0 && (r[k] == LB_SY || r[k] == LB_IS) {
    k = k - 1
  }
  if k >= 0 && r[k] == LB_NU {
    k
  } else {
    -1
  }
}

///|
/// LB1 归并 + LB9/LB10 组合符处理。
/// 返回 (归并类别, 原始类别, 是否被忽略)。
fn lb_resolve(cps : Array[Int32]) -> (Array[Int32], Array[Int32], Array[Bool]) {
  let n = cps.length()
  let resolved : Array[Int32] = []
  let original : Array[Int32] = []
  let ignored : Array[Bool] = []
  for i = 0; i < n; i = i + 1 {
    let raw = lb_of(cps[i])
    let mut c = raw
    if raw == LB_AI || raw == LB_SG || raw == LB_XX || raw == -1 {
      c = LB_AL
    } else if raw == LB_CJ {
      c = LB_NS
    } else if raw == LB_SA {
      c = if is_mark(cps[i]) { LB_CM } else { LB_AL }
    }
    resolved.push(c)
    original.push(c)
    ignored.push(false)
  }
  for i = 0; i < n; i = i + 1 {
    let c = resolved[i]
    if c == LB_CM || c == LB_ZWJ {
      let hard = i == 0 ||
        resolved[i - 1] == LB_BK ||
        resolved[i - 1] == LB_CR ||
        resolved[i - 1] == LB_LF ||
        resolved[i - 1] == LB_NL ||
        resolved[i - 1] == LB_SP ||
        resolved[i - 1] == LB_ZW
      if hard {
        resolved[i] = LB_AL
      } else {
        resolved[i] = resolved[i - 1]
        ignored[i] = true
      }
    }
  }
  (resolved, original, ignored)
}

///|
fn line_breaks_of(cps : Array[Int32]) -> Array[Bool] {
  let n = cps.length()
  let breaks : Array[Bool] = []
  for i = 0; i <= n; i = i + 1 {
    breaks.push(true)
  }
  if n == 0 {
    return breaks
  }
  breaks[0] = false // LB2
  let (r, orig, ign) = lb_resolve(cps)
  for i = 1; i < n; i = i + 1 {
    let p = r[i - 1]
    let c = r[i]
    let op = orig[i - 1]
    let oc = orig[i]
    // LB9
    if (oc == LB_CM || oc == LB_ZWJ) &&
      !(op == LB_BK ||
      op == LB_CR ||
      op == LB_LF ||
      op == LB_NL ||
      op == LB_SP ||
      op == LB_ZW) {
      breaks[i] = false
      continue
    }
    // LB4 / LB5
    if p == LB_BK {
      continue
    }
    if p == LB_CR && c == LB_LF {
      breaks[i] = false
      continue
    }
    if p == LB_CR || p == LB_LF || p == LB_NL {
      continue
    }
    // LB6
    if c == LB_BK || c == LB_CR || c == LB_LF || c == LB_NL {
      breaks[i] = false
      continue
    }
    // LB7
    if c == LB_SP || c == LB_ZW {
      breaks[i] = false
      continue
    }
    // LB8
    if p == LB_ZW {
      continue
    }
    if lb_spaces_before(r, ign, i) >= 0 &&
      r[lb_spaces_before(r, ign, i)] == LB_ZW {
      continue
    }
    // LB8a
    if op == LB_ZWJ {
      breaks[i] = false
      continue
    }
    // LB11 / LB12 / LB12a
    if p == LB_WJ || c == LB_WJ {
      breaks[i] = false
      continue
    }
    if p == LB_GL {
      breaks[i] = false
      continue
    }
    if c == LB_GL && p != LB_SP && p != LB_HY && p != LB_HH {
      breaks[i] = false
      continue
    }
    // LB13
    if c == LB_CL || c == LB_CP || c == LB_EX || c == LB_SY {
      breaks[i] = false
      continue
    }
    // LB14
    let j14 = lb_spaces_before(r, ign, i)
    if j14 >= 0 && r[j14] == LB_OP {
      breaks[i] = false
      continue
    }
    // LB15a
    let j15 = lb_spaces_before(r, ign, i)
    if j15 >= 0 && is_pi_qu(cps[j15]) && r[j15] == LB_QU {
      let k = lb_prev_nb(ign, j15)
      if k < 0 ||
        r[k] == LB_BK ||
        r[k] == LB_CR ||
        r[k] == LB_LF ||
        r[k] == LB_NL ||
        r[k] == LB_OP ||
        r[k] == LB_QU ||
        r[k] == LB_GL ||
        r[k] == LB_SP ||
        r[k] == LB_ZW {
        breaks[i] = false
        continue
      }
    }
    // LB15b
    if is_pf_qu(cps[i]) && c == LB_QU {
      let nx = if i + 1 < n { r[i + 1] } else { -1 }
      if nx == -1 ||
        nx == LB_SP ||
        nx == LB_GL ||
        nx == LB_WJ ||
        nx == LB_CL ||
        nx == LB_QU ||
        nx == LB_CP ||
        nx == LB_EX ||
        nx == LB_IS ||
        nx == LB_SY ||
        nx == LB_BK ||
        nx == LB_CR ||
        nx == LB_LF ||
        nx == LB_NL ||
        nx == LB_ZW {
        breaks[i] = false
        continue
      }
    }
    // LB15c
    if p == LB_SP && c == LB_IS && i + 1 < n && r[i + 1] == LB_NU {
      continue
    }
    // LB15d
    if c == LB_IS {
      breaks[i] = false
      continue
    }
    // LB16
    if c == LB_NS {
      let j = lb_spaces_before(r, ign, i)
      if j >= 0 && (r[j] == LB_CL || r[j] == LB_CP) {
        breaks[i] = false
        continue
      }
    }
    // LB17
    if c == LB_B2 {
      let j = lb_spaces_before(r, ign, i)
      if j >= 0 && r[j] == LB_B2 {
        breaks[i] = false
        continue
      }
    }
    // LB18
    if p == LB_SP {
      continue
    }
    // LB19
    if c == LB_QU && !is_pi_qu(cps[i]) {
      breaks[i] = false
      continue
    }
    if p == LB_QU && !is_pf_qu(cps[i - 1]) {
      breaks[i] = false
      continue
    }
    // LB19a
    if c == LB_QU {
      let left_ea = i - 1 >= 0 && lb_is_ea(cps, i - 1)
      let right_ea = i + 1 < n && lb_is_ea(cps, i + 1)
      if !left_ea || !right_ea {
        breaks[i] = false
        continue
      }
    }
    if p == LB_QU {
      let left_ea = i - 2 >= 0 && lb_is_ea(cps, i - 2)
      let right_ea = i + 1 < n && lb_is_ea(cps, i + 1)
      if !left_ea || !right_ea {
        breaks[i] = false
        continue
      }
    }
    // LB20
    if c == LB_CB || p == LB_CB {
      continue
    }
    // LB20a
    if (c == LB_AL || c == LB_HL) && (p == LB_HY || p == LB_HH) {
      let h = lb_base_idx(ign, i - 1)
      let k = lb_prev_nb(ign, h)
      if k < 0 ||
        r[k] == LB_BK ||
        r[k] == LB_CR ||
        r[k] == LB_LF ||
        r[k] == LB_NL ||
        r[k] == LB_SP ||
        r[k] == LB_ZW ||
        r[k] == LB_CB ||
        r[k] == LB_GL {
        breaks[i] = false
        continue
      }
    }
    // LB21
    if c == LB_BA || c == LB_HH || c == LB_HY || c == LB_NS || p == LB_BB {
      breaks[i] = false
      continue
    }
    // LB21a
    if (p == LB_HY || p == LB_HH) && c != LB_HL {
      let h = lb_base_idx(ign, i - 1)
      let k = lb_prev_nb(ign, h)
      if k >= 0 && r[k] == LB_HL {
        breaks[i] = false
        continue
      }
    }
    // LB21b
    if p == LB_SY && c == LB_HL {
      breaks[i] = false
      continue
    }
    // LB22
    if c == LB_IN {
      breaks[i] = false
      continue
    }
    // LB23
    if ((p == LB_AL || p == LB_HL) && c == LB_NU) ||
      (p == LB_NU && (c == LB_AL || c == LB_HL)) {
      breaks[i] = false
      continue
    }
    // LB23a
    if (p == LB_PR && (c == LB_ID || c == LB_EB || c == LB_EM)) ||
      ((p == LB_ID || p == LB_EB || p == LB_EM) && c == LB_PO) {
      breaks[i] = false
      continue
    }
    // LB24
    if ((p == LB_PR || p == LB_PO) && (c == LB_AL || c == LB_HL)) ||
      ((p == LB_AL || p == LB_HL) && (c == LB_PR || c == LB_PO)) {
      breaks[i] = false
      continue
    }
    // LB25
    if c == LB_PO || c == LB_PR {
      if (p == LB_CL || p == LB_CP) && lb_num_tail(r, i - 2) >= 0 {
        breaks[i] = false
        continue
      }
      if lb_num_tail(r, i - 1) >= 0 {
        breaks[i] = false
        continue
      }
    }
    if c == LB_OP && (p == LB_PO || p == LB_PR) {
      if i + 1 < n && r[i + 1] == LB_NU {
        breaks[i] = false
        continue
      }
      if i + 2 < n && r[i + 1] == LB_IS && r[i + 2] == LB_NU {
        breaks[i] = false
        continue
      }
    }
    if c == LB_NU && (p == LB_PO || p == LB_PR || p == LB_HY || p == LB_IS) {
      breaks[i] = false
      continue
    }
    if c == LB_NU && lb_num_tail(r, i - 1) >= 0 {
      breaks[i] = false
      continue
    }
    // LB26
    if p == LB_JL && (c == LB_JL || c == LB_JV || c == LB_H2 || c == LB_H3) {
      breaks[i] = false
      continue
    }
    if (p == LB_JV || p == LB_H2) && (c == LB_JV || c == LB_JT) {
      breaks[i] = false
      continue
    }
    if (p == LB_JT || p == LB_H3) && c == LB_JT {
      breaks[i] = false
      continue
    }
    // LB27
    if (p == LB_JL || p == LB_JV || p == LB_JT || p == LB_H2 || p == LB_H3) &&
      c == LB_PO {
      breaks[i] = false
      continue
    }
    if p == LB_PR &&
      (c == LB_JL || c == LB_JV || c == LB_JT || c == LB_H2 || c == LB_H3) {
      breaks[i] = false
      continue
    }
    // LB28
    if (p == LB_AL || p == LB_HL) && (c == LB_AL || c == LB_HL) {
      breaks[i] = false
      continue
    }
    // LB28a
    if p == LB_AP && lb_is_syl(r, ign, cps, i) {
      breaks[i] = false
      continue
    }
    if lb_is_syl(r, ign, cps, i - 1) && (c == LB_VF || c == LB_VI) {
      breaks[i] = false
      continue
    }
    if p == LB_VI &&
      lb_is_syl(r, ign, cps, i) &&
      lb_is_syl(r, ign, cps, lb_prev_nb(ign, lb_base_idx(ign, i - 1))) {
      breaks[i] = false
      continue
    }
    if lb_is_syl(r, ign, cps, i - 1) &&
      lb_is_syl(r, ign, cps, i) &&
      i + 1 < n &&
      r[i + 1] == LB_VF {
      breaks[i] = false
      continue
    }
    // LB29
    if p == LB_IS && (c == LB_AL || c == LB_HL) {
      breaks[i] = false
      continue
    }
    // LB30
    if (p == LB_AL || p == LB_HL || p == LB_NU) &&
      c == LB_OP &&
      !lb_is_ea(cps, i) {
      breaks[i] = false
      continue
    }
    if p == LB_CP &&
      !lb_is_ea(cps, i - 1) &&
      (c == LB_AL || c == LB_HL || c == LB_NU) {
      breaks[i] = false
      continue
    }
    // LB30a
    if p == LB_RI && c == LB_RI {
      let mut count = 0
      let mut k = i - 1
      while k >= 0 {
        if ign[k] {
          k = k - 1
          continue
        }
        if r[k] != LB_RI {
          break
        }
        count = count + 1
        k = k - 1
      }
      breaks[i] = count % 2 == 0
      continue
    }
    // LB30b
    if c == LB_EM && (p == LB_EB || is_extpict_cn(cps[lb_base_idx(ign, i - 1)])) {
      breaks[i] = false
      continue
    }
    // LB31 保持默认：允许断开
  }
  breaks
}
