// mbt-linebreak 命令行入口。
//
// 算法全部在库包 `Mr-Houjie/mbt-linebreak`，这里只负责参数解析、
// 文件读取、输出格式与退出码。

///|
const VERSION : String = "0.1.0"

///|
fn usage() -> String {
  let s = StringBuilder()
  s.write_string(
    "mbt-linebreak \{VERSION} — Unicode 文本边界与行断裂\n\n",
  )
  s.write_string("用法:\n")
  s.write_string("  mbt-linebreak [选项] <文件...>\n\n")
  s.write_string("选项:\n")
  s.write_string("  --grapheme            按字素簇切分\n")
  s.write_string("  --word                按词边界切分\n")
  s.write_string("  --sentence            按句边界切分\n")
  s.write_string("  --line                列出断行位置（默认）\n")
  s.write_string("  --wrap <宽度>         按显示宽度折行\n")
  s.write_string("  --width               输出显示宽度（列数）\n")
  s.write_string("  --json                以 JSON 输出\n")
  s.write_string("  -v, --version         显示版本\n")
  s.write_string("  -h, --help            显示本帮助\n\n")
  s.write_string("退出码:\n")
  s.write_string("  0  成功\n")
  s.write_string("  1  读取失败\n")
  s.write_string("  2  用法错误\n")
  s.to_string()
}

///|
struct Options {
  paths : Array[String]
  mut kind : @Mr-Houjie/mbt-linebreak.BreakKind
  mut wrap_width : Int32
  mut width_only : Bool
  mut json : Bool
  mut help : Bool
  mut version : Bool
}

///|
fn Options::new() -> Options {
  {
    paths: [],
    kind: @Mr-Houjie/mbt-linebreak.BreakKind::Line,
    wrap_width: -1,
    width_only: false,
    json: false,
    help: false,
    version: false,
  }
}

///|
fn usage_error(message : String) -> Unit {
  println("错误: \{message}")
  println("")
  println(usage())
  @sys.exit(2)
}

///|
fn parse_positive(s : String) -> Int32 {
  let mut value = 0
  let mut any = false
  for c in s {
    let d = c.to_int()
    if d < 48 || d > 57 {
      return -1
    }
    value = value * 10 + (d - 48)
    any = true
  }
  if any {
    value
  } else {
    -1
  }
}

///|
fn starts_with_dash(s : String) -> Bool {
  for c in s {
    return c == '-'
  }
  false
}

///|
fn json_escape(s : String) -> String {
  let b = StringBuilder()
  for c in s {
    if c == '"' {
      b.write_string("\\\"")
    } else if c == '\\' {
      b.write_string("\\\\")
    } else if c == '\n' {
      b.write_string("\\n")
    } else if c == '\r' {
      b.write_string("\\r")
    } else if c == '\t' {
      b.write_string("\\t")
    } else {
      b.write_char(c)
    }
  }
  b.to_string()
}

///|
fn parse_args(args : Array[String]) -> Options {
  let options = Options::new()
  let mut i = 1
  while i < args.length() {
    let arg = args[i]
    if arg == "-h" || arg == "--help" {
      options.help = true
    } else if arg == "-v" || arg == "--version" {
      options.version = true
    } else if arg == "--json" {
      options.json = true
    } else if arg == "--width" {
      options.width_only = true
    } else if arg == "--grapheme" {
      options.kind = @Mr-Houjie/mbt-linebreak.BreakKind::Grapheme
    } else if arg == "--word" {
      options.kind = @Mr-Houjie/mbt-linebreak.BreakKind::Word
    } else if arg == "--sentence" {
      options.kind = @Mr-Houjie/mbt-linebreak.BreakKind::Sentence
    } else if arg == "--line" {
      options.kind = @Mr-Houjie/mbt-linebreak.BreakKind::Line
    } else if arg == "--wrap" {
      if i + 1 >= args.length() {
        usage_error("--wrap 需要一个宽度参数")
      }
      let raw = args[i + 1]
      let value = parse_positive(raw)
      if value <= 0 {
        usage_error("宽度必须是正整数: \{raw}")
      }
      options.wrap_width = value
      i = i + 1
    } else if starts_with_dash(arg) {
      usage_error("未知选项: \{arg}")
    } else {
      options.paths.push(arg)
    }
    i = i + 1
  }
  if !options.help && !options.version && options.paths.length() == 0 {
    usage_error("缺少输入文件")
  }
  options
}

///|
fn kind_name(kind : @Mr-Houjie/mbt-linebreak.BreakKind) -> String {
  match kind {
    @Mr-Houjie/mbt-linebreak.BreakKind::Grapheme => "grapheme"
    @Mr-Houjie/mbt-linebreak.BreakKind::Word => "word"
    @Mr-Houjie/mbt-linebreak.BreakKind::Sentence => "sentence"
    @Mr-Houjie/mbt-linebreak.BreakKind::Line => "line"
  }
}

///|
fn segments(path : String, text : String, options : Options) -> Unit {
  let parts = match options.kind {
    @Mr-Houjie/mbt-linebreak.BreakKind::Grapheme =>
      @Mr-Houjie/mbt-linebreak.graphemes(text)
    @Mr-Houjie/mbt-linebreak.BreakKind::Word =>
      @Mr-Houjie/mbt-linebreak.words(text)
    @Mr-Houjie/mbt-linebreak.BreakKind::Sentence =>
      @Mr-Houjie/mbt-linebreak.sentences(text)
    @Mr-Houjie/mbt-linebreak.BreakKind::Line => []
  }
  if options.json {
    let b = StringBuilder()
    b.write_string("{\"kind\":\"\{kind_name(options.kind)}\",\"segments\":[")
    for i = 0; i < parts.length(); i = i + 1 {
      if i > 0 {
        b.write_string(",")
      }
      b.write_string("\"\{json_escape(parts[i])}\"")
    }
    b.write_string("]}")
    println(b.to_string())
  } else {
    println("# \{path} (\{kind_name(options.kind)}, \{parts.length()} 段)")
    for part in parts {
      println(part)
    }
  }
}

///|
fn print_breaks(
  path : String,
  breaks : Array[@Mr-Houjie/mbt-linebreak.LineBreak],
  options : Options,
) -> Unit {
  if options.json {
    let b = StringBuilder()
    b.write_string("{\"breaks\":[")
    for i = 0; i < breaks.length(); i = i + 1 {
      if i > 0 {
        b.write_string(",")
      }
      let item = breaks[i]
      b.write_string("{\"index\":\{item.index},\"mandatory\":")
      b.write_string(if item.mandatory { "true" } else { "false" })
      b.write_string("}")
    }
    b.write_string("]}")
    println(b.to_string())
  } else {
    println("# \{path} (\{breaks.length()} 个断行位置)")
    for item in breaks {
      let tag = if item.mandatory { "强制" } else { "可选" }
      println("\{item.index}: \{tag}")
    }
  }
}

///|
fn print_wrap(path : String, text : String, options : Options) -> Unit {
  let lines = @Mr-Houjie/mbt-linebreak.wrap(text, options.wrap_width)
  if options.json {
    let b = StringBuilder()
    b.write_string("{\"lines\":[")
    for i = 0; i < lines.length(); i = i + 1 {
      if i > 0 {
        b.write_string(",")
      }
      b.write_string("\"\{json_escape(lines[i])}\"")
    }
    b.write_string("]}")
    println(b.to_string())
  } else {
    println("# \{path} (宽度 \{options.wrap_width}, \{lines.length()} 行)")
    for line in lines {
      println(line)
    }
  }
}

///|
fn process(path : String, options : Options) -> Bool {
  let text = @fs.read_file_to_string(path) catch {
    _ => {
      eprintln("读取失败: \{path}")
      return false
    }
  }
  if options.width_only {
    let w = @Mr-Houjie/mbt-linebreak.display_width(text)
    if options.json {
      println("{\"width\":\{w}}")
    } else {
      println("\{path}: \{w} 列")
    }
  } else if options.wrap_width > 0 {
    print_wrap(path, text, options)
  } else {
    let is_line = match options.kind {
      @Mr-Houjie/mbt-linebreak.BreakKind::Line => true
      _ => false
    }
    if is_line {
      print_breaks(path, @Mr-Houjie/mbt-linebreak.line_breaks(text), options)
    } else {
      segments(path, text, options)
    }
  }
  true
}

///|
fn main {
  let args = @env.args()
  let options = parse_args(args)
  if options.help {
    println(usage())
    @sys.exit(0)
  }
  if options.version {
    println(
      "mbt-linebreak \{VERSION} (Unicode \{@Mr-Houjie/mbt-linebreak.unicode_version()})",
    )
    @sys.exit(0)
  }
  let mut ok = true
  for path in options.paths {
    if !process(path, options) {
      ok = false
    }
  }
  @sys.exit(if ok { 0 } else { 1 })
}
