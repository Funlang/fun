# 更新日志

本项目采用 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 风格记录主要变更，并遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

**English**: [CHANGELOG.md](CHANGELOG.md) · **简体中文**（本文件）

## [未发布]

- 首次以开源形式发布 Fun 核心与标准库源码。
- 新增 `README.md`、`CONTRIBUTING.md`、`.gitignore`、`.gitattributes`。
- 加固字符串/列表下标与字节访问，杜绝越界内存访问：越界**写**改为抛异常，越界**读**返回安全
  默认值（`s[i]`、`.toByte`、`.fromByte`、`.toNum(ptr:)`、`.movs`、`.x`、`.toStr`、列表
  `@count`）。字符串赋值保持引用语义。
- 语言版本：9.0。
- 限制 JSON/FD 解析的嵌套深度。扫描本身是迭代的，但生成的树在释放、克隆与序列化时
  是递归的，因此攻击者提交数千层 `[`/`{` 的文档会使栈溢出导致进程崩溃（DoS）。现在
  嵌套超过 512 层会抛异常，而不再构建出无法使用的结构。
- 修复多行 `DObject.Get`：内嵌的 `Read` 会遮蔽 `args` 成员，取多于一行的结果时抛
  `@Fields not found`。取行循环改为读 `this.args`。
- 在 `libase.pas` 中新增控制台输入内建：`'line'.input([prompt])`、
  `'char'.input([prompt])`（终端上为原始模式的单键读取）与 `'all'.input([prompt])`。
  可选的第二个参数用于接收 `ok` 标志，表示本次是否读到内容；由于 Fun 中空串与 nil
  相等，存在空行时该标志是让读循环可靠结束的唯一方式。

## [9.0] - 2026

- 以数据为中心的脚本能力：内置 JSON 与 FD 数据格式、原生 list / set / tree 集合、内嵌 PCRE 正则。
- 解释器核心（值模型 / 对象系统 / 流程控制）、内建运行时库与 58 个标准库模块。
- 双形态构建：命令行 `funcmd` 与嵌入运行时 `fun.dll`。
- Delphi 2006/2009 与 Free Pascal 跨平台构建（Windows / Linux / ARM / WinCE）。
- 附带 IDE（`funide`）及示例应用（`notepad--`、`odbc-search`、基准测试）。
- 通过标准库支持运行时 C 编译（TCC）、JIT 与内联汇编。

> 注：本仓库在开源发布前已有长期的历史版本（可追溯到 2010 年）。由于历史提交未随源码迁移，此处的更新日志从开源首版开始记录。
