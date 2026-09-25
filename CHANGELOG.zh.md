# 更新日志

本项目采用 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 风格记录主要变更，并遵循 [语义化版本](https://semver.org/lang/zh-CN/)。

**English**: [CHANGELOG.md](CHANGELOG.md) · **简体中文**（本文件）

## [未发布]

- 首次以开源形式发布 Fun 核心与标准库源码。
- 命令行 `funcmd` 现在把诊断信息写入 stderr，并在解析或运行时出错时返回非零退出码 (1)，
  使 `a.fun && b.fun`、CI 任务与 cron 告警不再把失败脚本当成成功。运行时错误前缀为
  `文件:行:`。函数调用栈（每帧一行 `  in 名称() (文件:行)`，由内向外，最多 10 帧）仅在
  定义了 `-dFunTraceback` 的构建中追加；默认构建只报出错命令，因此每次调用零开销。
  脚本正常输出（`?.`）仍走 stdout。内嵌 `fun.dll` 的 `Run` 返回码约定不变，`-gui`/非控制台
  运行与原先一样保持静默。诊断信息直接写操作系统标准错误句柄（不再用 RTL 的
  `StdErr`/`ErrOutput` 文本文件，Delphi 7 未声明这两个标识符），因此驱动在 Delphi 7
  与 Free Pascal 上都能原样编译。
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
  相等，存在空行时该标志是让读循环可靠结束的唯一方式。Linux 逐字节读取标准输入，
  三种模式都支持；Windows 上只按行读取（用 RTL 的 `ReadLn`），得到的文本直接是
  本构建的字符串编码（ANSI；Delphi 2009 为 Unicode），不会把多字节字符拆成字节。
- 为基本类型新增严格比较与类型号：`a.eq(b)` 仅在类型与值都相同时为真（`nil`/`0`/`''`/`false`
  互不相等，`'1' <> 1`，`1 <> 1.0`，字符串区分大小写），`a.type()` 返回可移植的逻辑类型号。
  编号对标 COM `VARENUM`（`VT_*`，即 Delphi `VType` 与 ADO `DataTypeEnum` 的底层表），并把运行时
  依赖平台的标签归一化：所有整型宽度 -> 3，所有浮点宽度 -> 5，所有字符串形态 -> 8。两者都位于
  `libase`，只作用于基本（非对象）值，宽松的 `=` 保持不变；`100+` 预留给 Fun 专有的对象类型。
- 修复 Free Pascal 下布尔与数字比较不对称的问题：variant 比较按操作数顺序做隐式转换，
  于是 `true = 1` 为假而 `1 = true` 为真（`<`/`>`、`<=`/`>=`、`<>` 同理）。`varComp` 现在
  把布尔与数字统一按数值类型比较，`true` 取 -1（`VARIANT_BOOL`，与 Delphi/COM `VarCmp` 一致），
  两种顺序结果一致。该分支仅在 FPC 下生效（`{$IfDef FPC}`）；Delphi 的 `VarCmp` 本就对称。
  由 fun/test/bool-num-cmp.fun 覆盖（本地套件：89/89）。

## [9.0] - 2026

- 以数据为中心的脚本能力：内置 JSON 与 FD 数据格式、原生 list / set / tree 集合、内嵌 PCRE 正则。
- 解释器核心（值模型 / 对象系统 / 流程控制）、内建运行时库与 58 个标准库模块。
- 双形态构建：命令行 `funcmd` 与嵌入运行时 `fun.dll`。
- Delphi 2006/2009 与 Free Pascal 跨平台构建（Windows / Linux / ARM / WinCE）。
- 附带 IDE（`funide`）及示例应用（`notepad--`、`odbc-search`、基准测试）。
- 通过标准库支持运行时 C 编译（TCC）、JIT 与内联汇编。

> 注：本仓库在开源发布前已有长期的历史版本（可追溯到 2010 年）。由于历史提交未随源码迁移，此处的更新日志从开源首版开始记录。
