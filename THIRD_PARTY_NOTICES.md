# 第三方与数据来源说明

本项目的 MoonBit 代码为原创实现，依据 Unicode 标准文档与官方测试语料编写，
未复制下列项目的源代码。

## 参考实现（仅用于行为对照与设计参考）

| 项目 | 语言 | 许可证 | 用途 |
|---|---|---|---|
| [rivo/uniseg](https://github.com/rivo/uniseg) | Go | MIT | 主要参考：UAX #29 + UAX #14 + 等宽宽度的 API 划分与状态机设计 |
| [unicode-linebreak](https://github.com/axelf4/unicode-linebreak) | Rust | Apache-2.0 | 断行规则的组织方式参考 |
| [unicode-segmentation](https://github.com/unicode-rs/unicode-segmentation) | Rust | MIT / Apache-2.0 | 词/句边界规则参考 |
| [textwrap](https://github.com/mgeisler/textwrap) | Rust | MIT | 折行策略参考 |

## 数据与测试语料

`corpus/ucd/` 下的文件来自 [Unicode Character Database](https://www.unicode.org/Public/18.0.0/ucd/)，
版本 18.0.0，遵循 [Unicode Terms of Use](https://www.unicode.org/terms_of_use.html)。

由这些数据生成的 `tables_*.mbt` 属于数据衍生文件，同样受 Unicode License 约束。
