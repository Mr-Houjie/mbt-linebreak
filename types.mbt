// 公共数据类型。
//
// 本库不依赖任何第三方包，算法只依据 UCD 属性表，因此同一份输入
// 在 native / wasm / js 后端上都会得到相同结果。

///|
/// 一个断行位置。
pub(all) struct LineBreak {
  /// 断点位置，按字符（码点）计数；`0` 表示文本起点。
  index : Int32
  /// 是否为强制断行（BK / CR / LF / NL）。
  mandatory : Bool
}

///|
/// 边界类型。
pub(all) enum BreakKind {
  Grapheme
  Word
  Sentence
  Line
}
