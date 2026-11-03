// 公共 API。

///|
/// 按字素簇切分字符串。
pub fn graphemes(s : String) -> Array[String] {
  let cps = to_codepoints(s)
  segments_of(s, grapheme_breaks(cps), cps.length())
}

///|
/// 按词边界切分字符串。
pub fn words(s : String) -> Array[String] {
  let cps = to_codepoints(s)
  segments_of(s, word_breaks(cps), cps.length())
}

///|
/// 按句边界切分字符串。
pub fn sentences(s : String) -> Array[String] {
  let cps = to_codepoints(s)
  segments_of(s, sentence_breaks(cps), cps.length())
}

///|
/// 列出所有断行位置（含文本末尾）。
///
/// `index` 按字符（码点）计数，与 `String` 的字节长度无关；
/// `mandatory` 表示该位置是 BK / CR / LF / NL 引起的强制换行。
pub fn line_breaks(s : String) -> Array[LineBreak] {
  let cps = to_codepoints(s)
  let n = cps.length()
  let flags = line_breaks_of(cps)
  let out : Array[LineBreak] = []
  for i = 1; i <= n; i = i + 1 {
    if flags[i] {
      let mut mandatory = i == n
      if !mandatory {
        let pc = lb_of(cps[i - 1])
        mandatory = pc == LB_BK || pc == LB_CR || pc == LB_LF || pc == LB_NL
      }
      out.push({ index: i, mandatory, })
    }
  }
  out
}

///|
/// 字符串在等宽字体下的显示宽度（列数）。
pub fn display_width(s : String) -> Int32 {
  let cps = to_codepoints(s)
  let gb = grapheme_breaks(cps)
  let n = cps.length()
  let mut total = 0
  let mut start = 0
  for i = 1; i <= n; i = i + 1 {
    if gb[i] {
      total = total + cluster_width(cps, start, i)
      start = i
    }
  }
  total
}

///|
/// 按显示宽度折行，保证不切断字素簇。
///
/// 优先在 UAX #14 给出的断行机会处断开；若整行没有任何机会
/// （例如超长英文单词），则在当前簇处硬切，避免无限延伸。
pub fn wrap(s : String, width : Int32) -> Array[String] {
  let out : Array[String] = []
  let chars = s.iter().to_array()
  let n = chars.length()
  if n == 0 {
    return out
  }
  if width <= 0 {
    out.push(s)
    return out
  }
  let cps = to_codepoints(s)
  let gb = grapheme_breaks(cps)
  let lb = line_breaks_of(cps)
  let bounds : Array[Int32] = [0]
  for i = 1; i < n; i = i + 1 {
    if gb[i] {
      bounds.push(i)
    }
  }
  bounds.push(n)
  let m = bounds.length() - 1
  let widths : Array[Int32] = []
  for k = 0; k < m; k = k + 1 {
    widths.push(cluster_width(cps, bounds[k], bounds[k + 1]))
  }
  let mut line_start = 0
  let mut current = 0
  let mut last_opportunity = -1
  let mut k = 0
  while k < m {
    if current + widths[k] > width && k > line_start {
      let cut = if last_opportunity > line_start { last_opportunity } else { k }
      out.push(slice_chars(chars, bounds[line_start], bounds[cut]))
      line_start = cut
      last_opportunity = -1
      current = 0
      k = cut
      continue
    }
    current = current + widths[k]
    k = k + 1
    if lb[bounds[k]] && k > line_start {
      last_opportunity = k
    }
  }
  if line_start < m {
    out.push(slice_chars(chars, bounds[line_start], n))
  }
  out
}

///|
/// 属性表对应的 Unicode 版本。
pub fn unicode_version() -> String {
  UNICODE_VERSION
}

///|
/// 返回边界布尔数组（长度 `n + 1`），便于编辑器、测试与交叉校验使用。
/// `flags[i]` 表示第 i 个码点之前是否允许断开。
pub fn break_flags(s : String, kind : BreakKind) -> Array[Bool] {
  let cps = to_codepoints(s)
  match kind {
    Grapheme => grapheme_breaks(cps)
    Word => word_breaks(cps)
    Sentence => sentence_breaks(cps)
    Line => line_breaks_of(cps)
  }
}
