# 更新日志

本项目采用 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 风格记录主要变更，并遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

**English**: [CHANGELOG.md](CHANGELOG.md) · **简体中文**（本文件）

## [未发布]

- 首次以开源形式发布 Fun 核心与标准库源码。
- 新增 `README.md`、`CONTRIBUTING.md`、`.gitignore`、`.gitattributes`。
- 语言版本：9.0。

## [9.0] - 2026

- 以数据为中心的脚本能力：内置 JSON 与 FD 数据格式、原生 list / set / tree 集合、内嵌 PCRE 正则。
- 解释器核心（值模型 / 对象系统 / 流程控制）、内建运行时库与 58 个标准库模块。
- 双形态构建：命令行 `funcmd` 与嵌入运行时 `fun.dll`。
- Delphi 2006/2009 与 Free Pascal 跨平台构建（Windows / Linux / ARM / WinCE）。
- 附带 IDE（`funide`）及示例应用（`notepad--`、`odbc-search`、基准测试）。
- 通过标准库支持运行时 C 编译（TCC）、JIT 与内联汇编。

> 注：本仓库在开源发布前已有长期的历史版本（可追溯到 2010 年）。由于历史提交未随源码迁移，此处的更新日志从开源首版开始记录。
