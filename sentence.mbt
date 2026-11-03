// UAX #29 句边界（Unicode 18.0，规则 SB1–SB998）。

///|
fn sb_is_ignorable(cp : Int32) -> Bool {
  let c = sb_of(cp)
  c == SB_EXTEND || c == SB_FORMAT
}

///|
fn sb_prev_effective(cps : Array[Int32], i : Int32) -> Int32 {
  let mut j = i - 1
  while j >= 0 && sb_is_ignorable(cps[j]) {
    j = j - 1
  }
  j
}

///|
fn sb_next_effective(cps : Array[Int32], i : Int32) -> Int32 {
  let mut j = i + 1
  while j < cps.length() && sb_is_ignorable(cps[j]) {
    j = j + 1
  }
  j
}

///|
fn sb_is_stop(c : Int32) -> Bool {
  c == SB_OLETTER ||
  c == SB_UPPER ||
  c == SB_LOWER ||
  c == SB_SEP ||
  c == SB_CR ||
  c == SB_LF ||
  c == SB_STERM ||
  c == SB_ATERM
}

///|
fn sb_is_term(c : Int32) -> Bool {
  c == SB_STERM || c == SB_ATERM
}

///|
/// 跳过 `Sp*` 再跳过 `Close*`，返回落点下标（用于 SB8–SB11 的后向匹配）。
fn sb_skip_sp_close(cps : Array[Int32], from : Int32) -> Int32 {
  let mut j = from
  while j >= 0 && sb_of(cps[j]) == SB_SP {
    j = sb_prev_effective(cps, j)
  }
  while j >= 0 && sb_of(cps[j]) == SB_CLOSE {
    j = sb_prev_effective(cps, j)
  }
  j
}

///|
fn sentence_breaks(cps : Array[Int32]) -> Array[Bool] {
  let n = cps.length()
  let breaks : Array[Bool] = []
  for i = 0; i <= n; i = i + 1 {
    breaks.push(true)
  }
  for i = 1; i < n; i = i + 1 {
    let pc = sb_of(cps[i - 1])
    let cc = sb_of(cps[i])
    // SB3
    if pc == SB_CR && cc == SB_LF {
      breaks[i] = false
      continue
    }
    // SB4
    if pc == SB_SEP || pc == SB_CR || pc == SB_LF {
      continue
    }
    // SB5
    if cc == SB_EXTEND || cc == SB_FORMAT {
      breaks[i] = false
      continue
    }
    // 由于忽略 Extend/Format，紧跟在已确定的断点之后的边界不再断开。
    let mut q = i - 1
    while q >= 0 && sb_is_ignorable(cps[q]) {
      q = q - 1
    }
    if q < i - 1 && q >= 0 && breaks[q + 1] {
      breaks[i] = false
      continue
    }
    let pi = sb_prev_effective(cps, i)
    if pi < 0 {
      breaks[i] = false
      continue
    }
    let prev = sb_of(cps[pi])
    // SB6
    if prev == SB_ATERM && cc == SB_NUMERIC {
      breaks[i] = false
      continue
    }
    // SB7
    if cc == SB_UPPER && prev == SB_ATERM {
      let pj = sb_prev_effective(cps, pi)
      if pj >= 0 {
        let c2 = sb_of(cps[pj])
        if c2 == SB_UPPER || c2 == SB_LOWER {
          breaks[i] = false
          continue
        }
      }
    }
    // SB8
    let j8 = sb_skip_sp_close(cps, pi)
    if j8 >= 0 && sb_of(cps[j8]) == SB_ATERM {
      let mut k = i
      while k < n && !sb_is_stop(sb_of(cps[k])) {
        k = sb_next_effective(cps, k)
      }
      if k < n && sb_of(cps[k]) == SB_LOWER {
        breaks[i] = false
        continue
      }
    }
    // SB8a
    if cc == SB_SCONTINUE || cc == SB_STERM || cc == SB_ATERM {
      let j = sb_skip_sp_close(cps, pi)
      if j >= 0 && sb_is_term(sb_of(cps[j])) {
        breaks[i] = false
        continue
      }
    }
    // SB9
    if cc == SB_CLOSE ||
      cc == SB_SP ||
      cc == SB_SEP ||
      cc == SB_CR ||
      cc == SB_LF {
      let mut j = pi
      while j >= 0 && sb_of(cps[j]) == SB_CLOSE {
        j = sb_prev_effective(cps, j)
      }
      if j >= 0 && sb_is_term(sb_of(cps[j])) {
        breaks[i] = false
        continue
      }
    }
    // SB10
    if cc == SB_SP || cc == SB_SEP || cc == SB_CR || cc == SB_LF {
      let j = sb_skip_sp_close(cps, pi)
      if j >= 0 && sb_is_term(sb_of(cps[j])) {
        breaks[i] = false
        continue
      }
    }
    // SB11
    let mut j = pi
    if j >= 0 {
      let cj = sb_of(cps[j])
      if cj == SB_SEP || cj == SB_CR || cj == SB_LF {
        j = sb_prev_effective(cps, j)
      }
    }
    j = sb_skip_sp_close(cps, j)
    if j >= 0 && sb_is_term(sb_of(cps[j])) {
      continue
    }
    // SB998
    breaks[i] = false
  }
  breaks
}
