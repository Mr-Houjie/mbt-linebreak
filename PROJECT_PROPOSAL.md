# 项目申报书：mbt-linebreak

> 一页版。完整版（含数据管线、工程细节与风险边界）见 [docs/PROPOSAL_FULL.md](docs/PROPOSAL_FULL.md)。

## 一、项目概览

- **项目名称**：mbt-linebreak —— 对标 [rivo/uniseg](https://github.com/rivo/uniseg) 的 MoonBit 迁移
- **仓库**：https://github.com/Mr-Houjie/mbt-linebreak ｜ **许可证**：MIT
- **语言**：MoonBit ≥ 0.1.20261028（moonc ≥ 0.10.18）｜ **Unicode**：18.0.0

用纯 MoonBit 实现 Unicode 文本分段与行断裂：UAX #29 的字素簇 / 词 / 句边界，
UAX #14 的断行机会，UAX #9 的双向算法与重排，以及按显示宽度的折行。
核心零第三方依赖，判定只依据 UCD 属性表，native / wasm / js 三端结果一致。

## 二、移植声明

**性质：规范实现（参考移植），非代码复制。**

| 参考项目 | 语言 | 许可证 | 参考内容 |
|---|---|---|---|
| [rivo/uniseg](https://github.com/rivo/uniseg) | Go | MIT | 主对象：API 划分与状态机设计 |
| [unicode-linebreak](https://github.com/axelf4/unicode-linebreak) | Rust | Apache-2.0 | 断行规则组织方式 |
| [unicode-segmentation](https://github.com/unicode-rs/unicode-segmentation) | Rust | MIT / Apache-2.0 | 词 / 句边界规则 |
| [textwrap](https://github.com/mgeisler/textwrap) | Rust | MIT | 折行策略 |

**移植范围**：UAX #29 三类边界 + UAX #14 行断裂 + UAX #9 双向算法 + 等宽宽度 + 折行 API。
**不含**：词典断词（泰 / 老挝 / 高棉）、连字（hyphenation）、字形 shaping。

实现依据 UAX #14 / UAX #29 规范与 Unicode 官方测试语料，**不复用上述项目源代码**；
`corpus/ucd` 与生成的 `tables_*.mbt` 来自 UCD 18.0.0，遵循 Unicode Terms of Use。

## 三、一致性与工程质量

| 官方语料 | 通过 |
|---|---|
| GraphemeBreakTest.txt | 853 / 853 |
| WordBreakTest.txt | 1944 / 1944 |
| SentenceBreakTest.txt | 512 / 512 |
| LineBreakTest.txt | 19346 / 19346 |
| BidiCharacterTest.txt | 91707 / 91707 |
| BidiTest.txt | 770241 / 770241 |

合计 **884,603 条，100% 通过**。属性表由 `tools/gen_tables.py` 与
`tools/gen_bidi_tables.py` 从 UCD 生成，可复现、禁止手改；CI 跑
`moon check --deny-warn`、`moon test`、`moon run cmd/verify`，
并用两份独立的 Python 参考实现交叉对拍，防止两个实现同时漂移。

## 四、相对参考实现的增量

1. **对齐 Unicode 18.0.0**：`rivo/uniseg` 停在 15.0，`unicode-segmentation` 为 17.0
2. **覆盖 UAX #14 revision 57 与 UAX #9 revision 51 的新规则**：LB15a/b/c/d、LB19a、LB20a、LB28a，以及隔离符与括号配对
3. **补齐生态空白**：MoonBit 已有字素簇断点与等宽宽度，但**没有 UAX #14 行断裂，也没有 UAX #9 双向算法**
4. **面向中文排版**：CJK 与拉丁混排、标点不可行首等行为可直接被上层排版器复用
5. **可交付形态**：零依赖核心 + 可裁剪属性表 + CLI + 官方语料自检
