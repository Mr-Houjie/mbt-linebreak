// UAX #9 双向算法（Unicode 18.0，UAX #9 revision 51）。
//
// 实现按规则编号组织：P1–P3 段落级、X1–X8 显式层级、X9/X10 隔离序列、
// W1–W7 弱类型、N0–N2 中性类型、I1–I2 隐式层级、L1–L2 重排。

///|
const MAX_DEPTH : Int32 = 125

///|
priv struct Status {
  level : Int32
  /// 0 = neutral, 1 = L, 2 = R
  ovr : Int32
  isolate : Bool
}

///|
fn top(stack : Array[Status]) -> Status {
  stack[stack.length() - 1]
}

///|
fn apply_override(
  stack : Array[Status],
  resolved : Array[Int32],
  i : Int32,
) -> Unit {
  let ov = top(stack).ovr
  if ov == 1 {
    resolved[i] = BC_L
  } else if ov == 2 {
    resolved[i] = BC_R
  }
}

///|
/// 找到与 `start` 处隔离起始符配对的 PDI；没有则返回字符数。
fn matching_pdi(types : Array[Int32], start : Int32) -> Int32 {
  let n = types.length()
  let mut depth = 1
  let mut i = start + 1
  while i < n {
    let t = types[i]
    if is_isolate_init(t) {
      depth = depth + 1
    } else if t == BC_PDI {
      depth = depth - 1
      if depth == 0 {
        return i
      }
    }
    i = i + 1
  }
  n
}

///|
/// P2：区间内第一个强方向字符，跳过隔离区间。
fn first_strong(types : Array[Int32], start : Int32, end : Int32) -> Int32 {
  let mut i = start
  while i < end {
    let t = types[i]
    if is_isolate_init(t) {
      i = matching_pdi(types, i) + 1
      continue
    }
    if t == BC_PDI {
      i = i + 1
      continue
    }
    if is_strong(t) {
      return t
    }
    i = i + 1
  }
  -1
}

///|
/// FSI 的方向判定：对其内容套用 P2/P3。
fn fsi_direction(types : Array[Int32], i : Int32) -> Int32 {
  let end = matching_pdi(types, i)
  let t = first_strong(types, i + 1, end)
  if t == BC_R || t == BC_AL {
    BC_R
  } else {
    BC_L
  }
}

///|
/// P2/P3：解析段落层级。
fn paragraph_level(types : Array[Int32], direction : Direction) -> Int32 {
  match direction {
    Ltr => 0
    Rtl => 1
    Auto => {
      let t = first_strong(types, 0, types.length())
      if t == BC_R || t == BC_AL {
        1
      } else {
        0
      }
    }
  }
}

///|
/// X1–X8：计算显式层级，并处理方向覆盖。
fn explicit_levels(
  types : Array[Int32],
  para : Int32,
) -> (Array[Int32], Array[Int32]) {
  let n = types.length()
  let levels : Array[Int32] = []
  let resolved : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    levels.push(para)
    resolved.push(types[i])
  }
  let stack : Array[Status] = [{ level: para, ovr: 0, isolate: false, }]
  let mut overflow_isolate = 0
  let mut overflow_embedding = 0
  let mut valid_isolate = 0
  for i = 0; i < n; i = i + 1 {
    let t = types[i]
    let cur = top(stack).level
    if t == BC_RLE || t == BC_LRE || t == BC_RLO || t == BC_LRO {
      levels[i] = cur
      let new_level = if t == BC_RLE || t == BC_RLO {
        (cur + 1) | 1
      } else {
        (cur + 2) / 2 * 2
      }
      if new_level <= MAX_DEPTH &&
        overflow_isolate == 0 &&
        overflow_embedding == 0 {
        let ov = if t == BC_RLO { 2 } else if t == BC_LRO { 1 } else { 0 }
        stack.push({ level: new_level, ovr: ov, isolate: false, })
      } else if overflow_isolate == 0 {
        overflow_embedding = overflow_embedding + 1
      }
    } else if is_isolate_init(t) {
      levels[i] = cur
      apply_override(stack, resolved, i)
      let dir = if t == BC_RLI {
        BC_R
      } else if t == BC_LRI {
        BC_L
      } else {
        fsi_direction(types, i)
      }
      let new_level = if dir == BC_R {
        (cur + 1) | 1
      } else {
        (cur + 2) / 2 * 2
      }
      if new_level <= MAX_DEPTH &&
        overflow_isolate == 0 &&
        overflow_embedding == 0 {
        valid_isolate = valid_isolate + 1
        stack.push({ level: new_level, ovr: 0, isolate: true, })
      } else {
        overflow_isolate = overflow_isolate + 1
      }
    } else if t == BC_PDI {
      if overflow_isolate > 0 {
        overflow_isolate = overflow_isolate - 1
      } else if valid_isolate == 0 {
        () // X6a：没有匹配的隔离起始符，什么都不做
      } else {
        overflow_embedding = 0
        while stack.length() > 1 && !top(stack).isolate {
          let _ = stack.pop()
        }
        if stack.length() > 1 {
          let _ = stack.pop()
        }
        valid_isolate = valid_isolate - 1
      }
      levels[i] = top(stack).level
      apply_override(stack, resolved, i)
    } else if t == BC_PDF {
      if overflow_isolate > 0 {
        ()
      } else if overflow_embedding > 0 {
        overflow_embedding = overflow_embedding - 1
      } else if !top(stack).isolate && stack.length() >= 2 {
        let _ = stack.pop()
      }
      levels[i] = top(stack).level
    } else if t == BC_B {
      levels[i] = para
    } else if t == BC_BN {
      levels[i] = cur
    } else {
      levels[i] = cur
      apply_override(stack, resolved, i)
    }
  }
  (levels, resolved)
}

///|
/// X9：按层级把保留字符切成 level run。
fn level_runs(
  types : Array[Int32],
  levels : Array[Int32],
) -> Array[Array[Int32]] {
  let runs : Array[Array[Int32]] = []
  let mut current : Array[Int32] = []
  for i = 0; i < types.length(); i = i + 1 {
    if is_removed(types[i]) {
      continue
    }
    if current.length() > 0 &&
      levels[i] != levels[current[current.length() - 1]] {
      runs.push(current)
      current = []
    }
    current.push(i)
  }
  if current.length() > 0 {
    runs.push(current)
  }
  runs
}

///|
/// BD13：把 level run 串成隔离序列。
fn isolating_sequences(
  types : Array[Int32],
  levels : Array[Int32],
) -> Array[Array[Int32]] {
  let runs = level_runs(types, levels)
  let n_runs = runs.length()
  let pdi_run : Array[Int32] = []
  for _i = 0; _i < types.length(); _i = _i + 1 {
    pdi_run.push(-1)
  }
  for idx = 0; idx < n_runs; idx = idx + 1 {
    let first = runs[idx][0]
    if types[first] == BC_PDI {
      pdi_run[first] = idx
    }
  }
  let links : Array[Int32] = []
  for i = 0; i < n_runs; i = i + 1 {
    links.push(-1)
  }
  for idx = 0; idx < n_runs; idx = idx + 1 {
    let run = runs[idx]
    let last = run[run.length() - 1]
    if is_isolate_init(types[last]) {
      let end = matching_pdi(types, last)
      if end < types.length() && pdi_run[end] >= 0 {
        links[idx] = pdi_run[end]
      }
    }
  }
  let used : Array[Bool] = []
  for i = 0; i < n_runs; i = i + 1 {
    used.push(false)
  }
  let sequences : Array[Array[Int32]] = []
  for idx = 0; idx < n_runs; idx = idx + 1 {
    if used[idx] {
      continue
    }
    let seq : Array[Int32] = []
    for item in runs[idx] {
      seq.push(item)
    }
    used[idx] = true
    let mut cur = idx
    while links[cur] >= 0 && !used[links[cur]] {
      let nxt = links[cur]
      for item in runs[nxt] {
        seq.push(item)
      }
      used[nxt] = true
      cur = nxt
    }
    sequences.push(seq)
  }
  sequences
}

///|
/// BD13/BD14：计算 sos 与 eos。
fn sequence_bounds(
  seq : Array[Int32],
  types : Array[Int32],
  levels : Array[Int32],
  para : Int32,
) -> (Int32, Int32) {
  let first = seq[0]
  let mut prev_level = para
  let mut j = first - 1
  while j >= 0 && is_removed(types[j]) {
    j = j - 1
  }
  if j >= 0 {
    prev_level = levels[j]
  }
  let sos = if levels[first] > prev_level { levels[first] } else { prev_level }
  let last = seq[seq.length() - 1]
  let mut next_level = para
  if is_isolate_init(types[last]) {
    // 隔离内容紧随其后，序列在段落边界结束
    next_level = para
  } else {
    let mut k = last + 1
    while k < types.length() && is_removed(types[k]) {
      k = k + 1
    }
    next_level = if k < types.length() { levels[k] } else { para }
  }
  let eos_level = if levels[last] > next_level {
    levels[last]
  } else {
    next_level
  }
  (
    if sos % 2 == 1 {
      BC_R
    } else {
      BC_L
    },
    if eos_level % 2 == 1 {
      BC_R
    } else {
      BC_L
    },
  )
}

///|
/// N0：括号配对（BD16），并处理括号后紧随的原始 NSM。
fn resolve_brackets(
  seq : Array[Int32],
  ts : Array[Int32],
  levels : Array[Int32],
  sos : Int32,
  cps : Array[Int32],
  orig : Array[Int32],
) -> Unit {
  let n = ts.length()
  let stack : Array[(Int32, Int32)] = []
  let pairs : Array[(Int32, Int32)] = []
  for k = 0; k < n; k = k + 1 {
    if ts[k] != BC_ON {
      continue
    }
    match bracket_of(cps[seq[k]]) {
      None => ()
      Some(info) => {
        let (bpb, kind) = info
        if kind == 0 {
          if stack.length() >= 63 {
            break // BD16：括号栈深度上限 63
          }
          stack.push((k, bracket_canonical(bpb)))
        } else {
          let mut si = stack.length() - 1
          while si >= 0 {
            if stack[si].1 == bracket_canonical(cps[seq[k]]) &&
              ts[stack[si].0] == BC_ON {
              pairs.push((stack[si].0, k))
              while stack.length() > si {
                let _ = stack.pop()
              }
              break
            }
            si = si - 1
          }
        }
      }
    }
  }
  // 按开括号的逻辑顺序处理
  let mut a = 0
  while a < pairs.length() {
    let mut b = a + 1
    while b < pairs.length() {
      if pairs[b].0 < pairs[a].0 {
        let tmp = pairs[a]
        pairs[a] = pairs[b]
        pairs[b] = tmp
      }
      b = b + 1
    }
    a = a + 1
  }
  for pair in pairs {
    let (open_k, close_k) = pair
    let embed = if levels[seq[open_k]] % 2 == 1 { BC_R } else { BC_L }
    let opposite = if embed == BC_R { BC_L } else { BC_R }
    let mut found_embed = false
    let mut found_opposite = false
    for k = open_k + 1; k < close_k; k = k + 1 {
      let s = strong_like(ts[k])
      if s == embed {
        found_embed = true
        break
      }
      if s == opposite {
        found_opposite = true
      }
    }
    let mut new_type = -1
    if found_embed {
      new_type = embed
    } else if found_opposite {
      let mut preceding = sos
      let mut k = open_k - 1
      while k >= 0 {
        let s = strong_like(ts[k])
        if s >= 0 {
          preceding = s
          break
        }
        k = k - 1
      }
      new_type = if preceding == opposite { opposite } else { embed }
    }
    if new_type < 0 {
      continue
    }
    ts[open_k] = new_type
    ts[close_k] = new_type
    // W1 之前就是 NSM 的字符跟随括号的新类型
    for base in [open_k, close_k] {
      let mut k = base + 1
      while k < n && orig[k] == BC_NSM {
        ts[k] = new_type
        k = k + 1
      }
    }
  }
}

///|
/// W1–W7、N0–N2、I1–I2，作用于一条隔离序列。
fn resolve_sequence(
  seq : Array[Int32],
  types : Array[Int32],
  levels : Array[Int32],
  sos : Int32,
  eos : Int32,
  cps : Array[Int32],
  use_brackets : Bool,
) -> Unit {
  let n = seq.length()
  let orig : Array[Int32] = []
  let ts : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    orig.push(types[seq[i]])
    ts.push(types[seq[i]])
  }
  // W1
  for k = 0; k < n; k = k + 1 {
    if ts[k] == BC_NSM {
      if k == 0 {
        ts[k] = sos
      } else {
        let prev = ts[k - 1]
        if is_isolate_init(prev) || prev == BC_PDI {
          ts[k] = BC_ON
        } else {
          ts[k] = prev
        }
      }
    }
  }
  // W2
  let mut last_strong = sos
  for k = 0; k < n; k = k + 1 {
    let t = ts[k]
    if is_strong(t) {
      last_strong = t
    } else if t == BC_EN && last_strong == BC_AL {
      ts[k] = BC_AN
    }
  }
  // W3
  for k = 0; k < n; k = k + 1 {
    if ts[k] == BC_AL {
      ts[k] = BC_R
    }
  }
  // W4
  for k = 1; k + 1 < n; k = k + 1 {
    if ts[k] == BC_ES && ts[k - 1] == BC_EN && ts[k + 1] == BC_EN {
      ts[k] = BC_EN
    } else if ts[k] == BC_CS {
      if ts[k - 1] == BC_EN && ts[k + 1] == BC_EN {
        ts[k] = BC_EN
      } else if ts[k - 1] == BC_AN && ts[k + 1] == BC_AN {
        ts[k] = BC_AN
      }
    }
  }
  // W5
  let mut k5 = 0
  while k5 < n {
    if ts[k5] == BC_ET {
      let mut j = k5
      while j < n && ts[j] == BC_ET {
        j = j + 1
      }
      let before = if k5 > 0 { ts[k5 - 1] } else { -1 }
      let after = if j < n { ts[j] } else { -1 }
      if before == BC_EN || after == BC_EN {
        for m = k5; m < j; m = m + 1 {
          ts[m] = BC_EN
        }
      }
      k5 = j
    } else {
      k5 = k5 + 1
    }
  }
  // W6
  for k = 0; k < n; k = k + 1 {
    if ts[k] == BC_ES || ts[k] == BC_ET || ts[k] == BC_CS {
      ts[k] = BC_ON
    }
  }
  // W7
  let mut last_strong7 = sos
  for k = 0; k < n; k = k + 1 {
    let t = ts[k]
    if t == BC_L || t == BC_R {
      last_strong7 = t
    } else if t == BC_EN && last_strong7 == BC_L {
      ts[k] = BC_L
    }
  }
  // N0
  if use_brackets {
    resolve_brackets(seq, ts, levels, sos, cps, orig)
  }
  // N1 / N2
  let mut kn = 0
  while kn < n {
    if is_neutral(ts[kn]) {
      let mut j = kn
      while j < n && is_neutral(ts[j]) {
        j = j + 1
      }
      let mut before = if kn == 0 { sos } else { strong_like(ts[kn - 1]) }
      let mut after = if j >= n { eos } else { strong_like(ts[j]) }
      if before < 0 {
        before = BC_L
      }
      if after < 0 {
        after = BC_L
      }
      let fill = if before == after {
        before
      } else if levels[seq[kn]] % 2 == 1 {
        BC_R
      } else {
        BC_L
      }
      for m = kn; m < j; m = m + 1 {
        ts[m] = fill
      }
      kn = j
    } else {
      kn = kn + 1
    }
  }
  // I1 / I2
  for k = 0; k < n; k = k + 1 {
    let idx = seq[k]
    if levels[idx] % 2 == 0 {
      if ts[k] == BC_R {
        levels[idx] = levels[idx] + 1
      } else if ts[k] == BC_AN || ts[k] == BC_EN {
        levels[idx] = levels[idx] + 2
      }
    } else if ts[k] == BC_L || ts[k] == BC_EN || ts[k] == BC_AN {
      levels[idx] = levels[idx] + 1
    }
  }
}

///|
/// L1：段落分隔符、段尾与分隔符前的空白回到段落层级。
fn reset_by_l1(
  types : Array[Int32],
  levels : Array[Int32],
  para : Int32,
) -> Unit {
  let n = types.length()
  for i = 0; i < n; i = i + 1 {
    if is_hard_break(types[i]) {
      levels[i] = para
    }
  }
  for i = 0; i < n; i = i + 1 {
    if is_hard_break(types[i]) {
      let mut j = i - 1
      while j >= 0 {
        let t = types[j]
        if t == BC_WS || is_isolate_init(t) || t == BC_PDI {
          levels[j] = para
        } else if is_removed(t) {
          ()
        } else {
          break
        }
        j = j - 1
      }
    }
  }
  let mut j = n - 1
  while j >= 0 {
    let t = types[j]
    if t == BC_WS || is_isolate_init(t) || t == BC_PDI {
      levels[j] = para
    } else if is_removed(t) {
      ()
    } else {
      break
    }
    j = j - 1
  }
}

///|
/// 完整 UAX #9：返回层级与视觉顺序。
fn resolve_bidi(cps : Array[Int32], direction : Direction) -> BidiResult {
  let types : Array[Int32] = []
  for cp in cps {
    types.push(bidi_class_of(cp))
  }
  resolve_types(types, cps, direction, true)
}

///|
/// 以给定的 Bidi_Class 序列执行算法；`use_brackets` 为 false 时不做括号配对。
fn resolve_types(
  types : Array[Int32],
  cps : Array[Int32],
  direction : Direction,
  use_brackets : Bool,
) -> BidiResult {
  let n = types.length()
  let para = paragraph_level(types, direction)
  let (levels, resolved) = explicit_levels(types, para)
  let sequences = isolating_sequences(types, levels)
  let bounds : Array[(Int32, Int32)] = []
  for seq in sequences {
    bounds.push(sequence_bounds(seq, types, levels, para))
  }
  for i = 0; i < sequences.length(); i = i + 1 {
    let (sos, eos) = bounds[i]
    resolve_sequence(
      sequences[i],
      resolved,
      levels,
      sos,
      eos,
      cps,
      use_brackets,
    )
  }
  reset_by_l1(types, levels, para)
  // L2：重排在 X9 保留的字符上进行
  let keep : Array[Int32] = []
  for i = 0; i < n; i = i + 1 {
    if !is_removed(types[i]) {
      keep.push(i)
    }
  }
  let m = keep.length()
  let seq_levels : Array[Int32] = []
  for i in keep {
    seq_levels.push(levels[i])
  }
  let order : Array[Int32] = []
  for i = 0; i < m; i = i + 1 {
    order.push(i)
  }
  if m > 0 {
    let mut highest = 0
    for lv in seq_levels {
      if lv > highest {
        highest = lv
      }
    }
    let mut lowest_odd = highest + 1
    for lv in seq_levels {
      if lv % 2 == 1 && lv < lowest_odd {
        lowest_odd = lv
      }
    }
    let mut level = highest
    while level >= lowest_odd {
      let mut k = 0
      while k < m {
        if seq_levels[order[k]] >= level {
          let mut j = k
          while j < m && seq_levels[order[j]] >= level {
            j = j + 1
          }
          // 反转 [k, j)
          let mut lo = k
          let mut hi = j - 1
          while lo < hi {
            let tmp = order[lo]
            order[lo] = order[hi]
            order[hi] = tmp
            lo = lo + 1
            hi = hi - 1
          }
          k = j
        } else {
          k = k + 1
        }
      }
      level = level - 1
    }
  }
  let visual : Array[Int32] = []
  for i in order {
    visual.push(keep[i])
  }
  { levels, order: visual, paragraph_level: para, }
}
