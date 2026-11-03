# 项目申报书：mbt-linebreak

## 一、项目名称与仓库

- **项目名称**：mbt-linebreak（基于 MoonBit 的 Unicode 文本边界与行断裂库）
- **仓库**：https://github.com/Mr-Houjie/mbt-linebreak
- **许可证**：MIT ｜ **语言**：MoonBit ≥ 0.1.20261028（moonc ≥ 0.10.18）
- **Unicode 版本**：18.0.0（UAX #14 revision 57、UAX #29 revision 49）

## 二、项目简介

`mbt-linebreak` 用纯 MoonBit 实现 Unicode 文本分段与行断裂：

1. **UAX #29**：字素簇、词、句三类边界；
2. **UAX #14**：断行机会（可断 / 不可断 / 强制断行）；
3. **按显示宽度的折行**：保证不切断字素簇，面向终端与文档排版。

核心库不依赖第三方包，判定只依据 UCD 属性表，因此在 native / wasm / js
后端上结果一致。附命令行工具与官方语料自检入口。

## 三、项目方向与适用场景

对应大赛「语言与开发工具」及「应用开发与内容处理」方向：

- 终端 UI 的自动换行与列宽计算
- 编辑器/IDE 的双击选词、光标移动、按词搜索
- 文档生成与电子书的断行、中文禁则的前置判定
- WebAssembly 前端的文本排版

MoonBit 生态现状：已有字素簇断点（`moonbit-community/find_cluster_break`）
与等宽宽度（`moonbit-community/unicodewidth`），但**没有 UAX #14 行断裂实现**。
本项目补齐这一层，并把词/句边界一并做全。

## 四、核心功能

1. 字素簇切分：emoji ZWJ 序列、区域指示符、组合符、Hangul、Indic 连字
2. 词边界：字母/数字/片假名/希伯来字母/引号/中点等上下文规则
3. 句边界：终结符 + 收尾标点 + 空格的组合规则
4. 行断裂：完整 LB1–LB31，含 Unicode 18.0 新增的 LB15a/b/c/d、LB19a、LB20a、LB28a
5. 折行：按显示宽度、优先断行机会、超长词硬切
6. 宽度：东亚宽字符、emoji、组合符
7. 工程化：`moon test` + `cmd/verify` 官方语料对拍 + GitHub Actions CI

## 五、一致性验证

| 语料 | 通过率 |
|---|---|
| GraphemeBreakTest.txt | 853 / 853 |
| WordBreakTest.txt | 1944 / 1944 |
| SentenceBreakTest.txt | 512 / 512 |
| LineBreakTest.txt | 19346 / 19346 |

合计 22,655 条，100% 通过。CI 中同时运行 Python 参考实现对拍，防止两个实现同时漂移。

## 六、项目性质与移植声明

**规范实现（参考移植），非代码复制。**

- 参考项目：[rivo/uniseg](https://github.com/rivo/uniseg)（Go，MIT），
  参考其 API 划分与状态机设计；
  另参考 [unicode-linebreak](https://github.com/axelf4/unicode-linebreak)（Rust，Apache-2.0）、
  [unicode-segmentation](https://github.com/unicode-rs/unicode-segmentation)（Rust，MIT/Apache-2.0）、
  [textwrap](https://github.com/mgeisler/textwrap)（Rust，MIT）的实现思路。
- **移植范围**：UAX #29 三类边界 + UAX #14 行断裂 + 等宽宽度 + 折行 API。
- **不复用源代码**：实现依据 UAX #14 / UAX #29 规范与 Unicode 官方测试语料；
  开发期的 Python 参考实现 `tools/oracle.py` 亦为本项目原创。
- **不含**：BiDi、词典断词（泰/老挝/高棉）、连字（hyphenation）、字形 shaping。

## 七、相对参考实现的增量

1. 对齐 Unicode **18.0.0**；`rivo/uniseg` 当前为 15.0，`unicode-segmentation` 为 17.0
2. 覆盖 UAX #14 revision 57 新增规则（LB15a/b/c/d、LB19a、LB20a）
3. 零依赖核心 + 可裁剪的属性表 + CLI + 官方语料自检
4. 中文场景的断行基线：CJK 与拉丁混排、标点不可行首等行为可被上层排版器直接复用

## 八、工程质量

- `moon check --deny-warn`、`moon test`、`moon run cmd/verify` 全绿
- 属性表由 `tools/gen_tables.py` 从 UCD 生成，可复现、禁止手改
- 数据版本写入生成文件头与 `unicode_version()` 返回值
- README 中英双份；`THIRD_PARTY_NOTICES.md` 记录参考项目与数据许可
