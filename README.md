# mbt-linebreak

[![CI](https://github.com/Mr-Houjie/mbt-linebreak/actions/workflows/ci.yml/badge.svg)](https://github.com/Mr-Houjie/mbt-linebreak/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Unicode 18.0.0 文本边界与行断裂的纯 MoonBit 实现。

`mbt-linebreak` 回答两个很具体的问题：**这段文本的字符、词、句在哪里分界**，
以及 **一行排不下时应该在哪里断开**。核心库不依赖任何第三方包，
所有判定只依据 UCD 属性表，因此同一份输入在任何后端上结果一致。

## 为什么需要它

MoonBit 生态里已有字素簇断点（`moonbit-community/find_cluster_break`）和
等宽宽度（`moonbit-community/unicodewidth`）的实现，但**没有 UAX #14 行断裂**：
没有断行机会，就没有真正的自动换行、终端折行和排版断行。

`mbt-linebreak` 补的是这一环，并且把 UAX #29 的词/句边界一并做全，
让“文本能放在哪里断开”成为一个可验证的确定性答案。

## 实测一致性

对 Unicode 18.0.0 官方测试文件逐条对拍（`moon run cmd/verify`）：

| 语料 | 通过 |
|---|---|
| `GraphemeBreakTest.txt` | 853 / 853 |
| `WordBreakTest.txt` | 1944 / 1944 |
| `SentenceBreakTest.txt` | 512 / 512 |
| `LineBreakTest.txt` | 19346 / 19346 |

合计 **22,655 条用例，100% 通过**，并覆盖 Unicode 18.0 的新规则
（GB9c 修订、LB15a/b/c/d、LB19a、LB20a、LB28a）。

## 安装

```bash
moon add Mr-Houjie/mbt-linebreak
```

## 快速开始

```moonbit
///|
test {
  // 字素簇：emoji 组合序列不会被拆开
  let clusters = @Mr-Houjie/mbt-linebreak.graphemes("👨‍👩‍👧‍👦a")
  inspect(clusters.length(), content="2")

  // 词与句
  inspect(@Mr-Houjie/mbt-linebreak.words("Hello, world!"), content="[\"Hello\", \",\", \" \", \"world\", \"!\"]")
  inspect(@Mr-Houjie/mbt-linebreak.sentences("你好。世界！"), content="[\"你好。\", \"世界！\"]")

  // 断行机会（按字符计数，mandatory 表示硬换行）
  let breaks = @Mr-Houjie/mbt-linebreak.line_breaks("ab\ncd")
  inspect(breaks[0].index, content="3")
  inspect(breaks[0].mandatory, content="true")

  // 按显示宽度折行
  let lines = @Mr-Houjie/mbt-linebreak.wrap("hello world", 7)
  inspect(lines, content="[\"hello \", \"world\"]")
}
```

## API

| 函数 | 说明 |
|---|---|
| `graphemes(s)` | 按字素簇切分（UAX #29） |
| `words(s)` | 按词边界切分（UAX #29） |
| `sentences(s)` | 按句边界切分（UAX #29） |
| `line_breaks(s)` | 断行位置列表（UAX #14），含是否为强制断行 |
| `break_flags(s, kind)` | 返回长度 `n + 1` 的边界布尔数组，供编辑器/测试使用 |
| `wrap(s, width)` | 按显示宽度折行，不切断字素簇 |
| `display_width(s)` | 等宽字体下的显示宽度（列数） |
| `unicode_version()` | 属性表对应的 Unicode 版本 |

断点位置按**字符（码点）**计数，不是 UTF-8 字节偏移。

## 命令行

```console
$ mbt-linebreak --wrap 24 文档.txt
$ mbt-linebreak --line 文档.txt
$ mbt-linebreak --word --json 文档.txt
$ mbt-linebreak --width 文档.txt
```

## 工程结构

```
mbt-linebreak/
├── api.mbt / types.mbt        # 公共 API 与数据类型
├── props.mbt                  # UCD 属性查询（二分查找）
├── grapheme.mbt               # UAX #29 字素簇
├── word.mbt                   # UAX #29 词边界
├── sentence.mbt               # UAX #29 句边界
├── line.mbt                   # UAX #14 行断裂
├── width.mbt                  # 显示宽度
├── tables_*.mbt               # 由 UCD 生成的属性表（勿手改）
├── cmd/main/                  # CLI
├── cmd/verify/                # 官方语料自检
├── corpus/ucd/                # Unicode 18.0.0 数据与测试文件
└── tools/
    ├── fetch_corpus.py        # 下载 UCD
    ├── gen_tables.py          # UCD → MoonBit 表
    └── oracle.py              # Python 参考实现，用于交叉验证
```

## 数据管线（可复现）

```bash
python tools/fetch_corpus.py     # 下载 Unicode 18.0.0
python tools/gen_tables.py       # 生成 tables_*.mbt
python tools/oracle.py           # Python 侧对拍（开发期使用）
moon run cmd/verify              # MoonBit 侧对拍
```

`tools/oracle.py` 是同一套规则的 Python 实现，用来在移植前快速迭代规则；
两个实现的输出都与官方语料 100% 一致，可作为交叉验证。

## 已知边界

- **宽度是启发式**：Unicode 没有等宽宽度的标准，这里采用与 `rivo/uniseg`
  相同的策略（东亚宽字符 2 列、emoji 按 `Emoji_Presentation`、组合符 0 列）。
  不同渲染引擎的显示结果可能不同。
- **不做词典断词**：泰文、老挝文、高棉文的词典式断词不在范围内，
  按 UAX #29 的默认规则处理。
- **不做 BiDi、连字（hyphenation）与字形 shaping**：这些属于排版器的其他层次。

## 与既有实现的关系

本项目是 **Unicode 规范的 MoonBit 原生实现**，参考
[`rivo/uniseg`](https://github.com/rivo/uniseg)（Go，MIT）的 API 划分与
状态机设计，以及 `unicode-linebreak`、`unicode-segmentation`、`textwrap`
的实现思路，但**不复用它们的源代码**。详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

相对参考实现的主要增量：

- 对齐 Unicode **18.0.0**（`rivo/uniseg` 当前为 15.0）
- 覆盖 UAX #14 revision 57 的新规则
- 属性表按需拆分，便于按包裁剪
- 提供零依赖核心 + CLI + 官方语料自检

## 许可证

MIT。`corpus/ucd` 与生成的 `tables_*.mbt` 遵循 Unicode Terms of Use。
