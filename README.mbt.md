# mbt-linebreak

Unicode 18.0.0 文本边界与行断裂的纯 MoonBit 实现：字素簇、词、句、断行机会、
双向算法与按宽度折行。

- 核心零第三方依赖，判定只依据 UCD 属性表
- 官方语料 884,603 条用例 100% 通过
- 覆盖 UAX #29、UAX #14（revision 57）与 UAX #9（revision 51）新规则

## 安装

```bash
moon add Mr-Houjie/mbt-linebreak
```

## 示例

```moonbit nocheck
///|
test {
  let clusters = @Mr-Houjie/mbt-linebreak.graphemes(
    "👨‍👩‍👧‍👦a",
  )
  inspect(clusters.length(), content="2")

  let lines = @Mr-Houjie/mbt-linebreak.wrap("hello world", 7)
  inspect(lines, content="[\"hello \", \"world\"]")

  let width = @Mr-Houjie/mbt-linebreak.display_width("中文")
  inspect(width, content="4")
}
```

## 一致性

| 语料 | 通过 |
|---|---|
| GraphemeBreakTest | 853 / 853 |
| WordBreakTest | 1944 / 1944 |
| SentenceBreakTest | 512 / 512 |
| LineBreakTest | 19346 / 19346 |
| BidiCharacterTest | 91707 / 91707 |
| BidiTest | 770241 / 770241 |

完整文档、API 表与数据管线见仓库中的 `README.md`。
