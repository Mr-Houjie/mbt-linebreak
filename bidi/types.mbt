// UAX #9 的数据类型。

///|
/// 段落方向。
pub(all) enum Direction {
  /// 按首个强字符自动判定。
  Auto
  Ltr
  Rtl
}

///|
/// 双向算法结果。
pub(all) struct BidiResult {
  /// 每个字符的嵌入层级；被 X9 移除的显式格式字符也保留层级，
  /// 但不出现在 `order` 中。
  levels : Array[Int32]
  /// 重排后的字符下标（逻辑顺序 → 视觉顺序）。
  order : Array[Int32]
  /// 解析出的段落层级。
  paragraph_level : Int32
}
