// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html

name = "Mr-Houjie/mbt-linebreak"

version = "0.1.0"

readme = "README.mbt.md"

repository = "https://github.com/Mr-Houjie/mbt-linebreak"

license = "MIT"

keywords = [
  "unicode",
  "line-breaking",
  "text-segmentation",
  "uax14",
  "uax29",
  "word-wrap",
  "i18n",
]

preferred_target = "native"

description = "Unicode 18.0.0 文本边界与行断裂：字素簇、词、句、断行机会与按宽度折行，纯 MoonBit 零依赖。"

import {
  "moonbitlang/x@0.5.7",
}
