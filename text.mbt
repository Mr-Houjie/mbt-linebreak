// 字符与字符串处理小工具。

///|
fn to_codepoints(s : String) -> Array[Int32] {
  let out : Array[Int32] = []
  for c in s {
    out.push(c.to_int())
  }
  out
}

///|
fn slice_chars(chars : Array[Char], start : Int32, end : Int32) -> String {
  let builder = StringBuilder()
  let mut i = start
  while i < end && i < chars.length() {
    builder.write_char(chars[i])
    i = i + 1
  }
  builder.to_string()
}

///|
/// 把断点布尔数组切成字符串片段；`n` 是码点数量。
fn segments_of(s : String, breaks : Array[Bool], n : Int32) -> Array[String] {
  let out : Array[String] = []
  if n == 0 {
    return out
  }
  let chars = s.iter().to_array()
  let mut start = 0
  for i = 1; i <= n; i = i + 1 {
    if breaks[i] {
      out.push(slice_chars(chars, start, i))
      start = i
    }
  }
  out
}
