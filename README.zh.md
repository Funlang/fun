# Fun 语言

> 一门轻量、可嵌入、**以数据为中心**的脚本语言，能力覆盖从 JSON/FD 数据处理一直到运行时编译 C 与直接编写机器码。

**English**: [README.md](README.md) · **简体中文**（本文件）

- 版本：**9.0**
- 官网：<https://funlang.org>
- 作者：Zhang Weidong &lt;zwd@funlang.org>
- 授权：MIT（另有商业授权条款，见下文「许可证」）

---

## 目录

- [为什么是 Fun](#为什么是-fun)
- [核心特性](#核心特性)
- [快速开始](#快速开始)
- [能力阶梯](#能力阶梯)
- [FD 数据格式](#fd-数据格式)
- [外部函数接口（FFI）](#外部函数接口ffi)
- [关键字别名](#关键字别名)
- [嵌入运行时 fun.dll](#嵌入运行时-fundll)
- [目录结构](#目录结构)
- [构建](#构建)
- [标准库](#标准库)
- [示例](#示例)
- [许可证](#许可证)

---

## 为什么是 Fun

Fun 的设计出发点很简单：**数据与代码都应该是头等公民，而且一段脚本应该能在不离开语言的情况下一路触达机器底层。**

多数脚本语言要么停留在高层（好用，但在 FFI 处撞墙），要么要求你在性能关键处去写 C。Fun 把这条能力阶梯收敛进同一个运行时：

- 用原生的 list / set / tree 集合处理 **JSON 与 FD** 数据；
- 通过 **紧凑的 FFI 签名**调用任意原生代码；
- 用内置的 Tiny C 编译器 **在运行时编译 C**；
- 需要最紧的循环时，直接 **内联汇编 / JIT**；

这一切都可以从纯脚本出发，并打包进单个可嵌入的二进制。

Fun 使用 Pascal（Delphi / Free Pascal）编写。核心是一个小巧的树遍历解释器，带有动态值模型、对象系统、闭包与模块——刻意保持精简，以便既可嵌入为 `fun.dll`，也可作为独立的 `fun.exe` 运行。

---

## 核心特性

- **动态、以数据为中心的值模型** —— 数字、字符串、时间、正则，以及头等集合：list（数组）、set 与 tree，构建于基于变体（variant）的运行时之上。
- **函数一等公民** —— 匿名函数、函数引用、柯里化、默认参数与可变参数，以及 `->` 管道。
- **对象系统** —— `class`、`this` / `base`、方法，以及属性的 get/set 分发（方法、getter、setter 统一通过 `.` 运算符分发）。
- **模块** —— `use 'file.fun'`（可 `as alias`）引入其它脚本；运行时跟踪模块状态与依赖。
- **正则作为值类型** —— 内嵌 PCRE 引擎，支持行内正则字面量（`/.../`）与匹配运算符（`=~`、`!~`）。
- **内置数据格式** —— JSON 与 **FD**，一种兼容 JSON、对人类与 AI 都友好的类 Markdown 格式（见[下文](#fd-数据格式)）。
- **运行时 C 与机器码** —— 内置 Tiny C 编译器、JIT 与内联汇编（见[能力阶梯](#能力阶梯)）。
- **紧凑的 FFI** —— 用简短的签名串调用 DLL/共享库函数（见 [FFI](#外部函数接口ffi)）。
- **关键字别名** —— 规范英文关键字 + 可插拔的别名包（中文、法文、自定义），运行时选择（见[下文](#关键字别名)）。
- **跨平台** —— Windows（32/64 位）、Linux、ARM 与 Windows CE。
- **双形态分发** —— 命令行 `fun.exe` 与嵌入运行时 `fun.dll`（导出简单的 `Run` 接口）。
- **自托管的标准库** —— 58 个用 Fun 自身编写的模块，覆盖 JSON/YAML/XML 到 ORM、异步、UI 与原生绑定。

---

## 快速开始

运行脚本：

```text
fun.exe <file.fun>            # 运行脚本（.fun / .foo / .fxx）
fun.exe -v <file.fun>         # 显示编译与运行耗时
fun.exe -log[:log.txt] -gui   # 输出到日志 / 以 GUI 模式运行
fun.exe -key:key_cn.ini       # 加载关键字别名包
```

Hello world（规范英文关键字）：

```fun
fun foo()
  ?. 'Hello, fun!';
end fun;

foo();

fun max(a, b)
  if a > b then
    result = a;
  else
    result = b;
  end if;
end fun;

?. max(1, 9);
?. max(9, 1);
```

运行：

```text
> fun.exe fun/demo/fun.fun
Hello, fun!
9
9
```

---

## 能力阶梯

Fun 的特殊之处在于，一段脚本在无需独立工具链的情况下能走多远：

| 层次       | 能力                              | 支撑                                             |
| ---------- | --------------------------------- | ------------------------------------------------ |
| 高层       | JSON / FD 数据，list / set / tree | 原生集合与解析器                                 |
| 原生调用   | `dll.getapi(name, 'signature')`   | 紧凑签名约定的 FFI                               |
| 运行时 C   | `ccompile(code, ...)`             | 内置 Tiny C 编译器（`libtcc.dll`）               |
| JIT        | `NewJit(...)`                     | 在 C（TCC）与汇编之间分发                        |
| 机器码     | `Assembly(code, ...).Load()`      | 内联汇编、可执行内存分配                         |

例如，`lib-tcc` 加载 `libtcc.dll` 并暴露 `tcc_new`、`tcc_compile_string`、`tcc_get_symbol` 等，从而你可以从字符串编译 C 源码并立即调用所得到的符号。`lib-asm` 分配可执行内存、写入机器码并调用之；`lib-jit` 则根据源码形态自动选择路径（`#!c` → TCC，否则走汇编）。

---

## FD 数据格式

FD 是一种 **对人类与 AI 都友好**、且与 JSON 互通的数据格式：

- 兼容 JSON 的结构（嵌套键、数组）；
- 基于缩进、类 Markdown 的语法；
- 可选的 SSE 压缩；
- 与 JSON 双向转换（`@toJson`、`getJson`）。

它的定义性特点是**自描述**：`lib-fd.fun` 中的解析器是由一份用 FD 本身写成的 BNF 文法（`fd.bnf.fd`）生成的。文法文件 `src/parse/bnf/fun.ebnf` 以同样的精神记录了语言文法。

---

## 外部函数接口（FFI）

Fun 通过**紧凑的签名串**约定暴露原生函数。标准库中的例子：

```fun
'kernel32'.getapi('VirtualAlloc', 'iiii:i');  // 4 个 int 参数 -> int
'tcc'.getapi('tcc_new', 'v:i');               // void 参数 -> int
```

签名依次编码每个参数类型，然后是 `:`，最后是返回类型（`i`=int、`s`=string、`v`=void、`d`=double 等）。同一机制驱动 COM（`lib-winole`）、Windows API（`lib-winapi`）与 C 运行时。

---

## 关键字别名

解释器的规范关键字是英文（`fun`、`if`、`then`、`loop`、`class`……）。由于关键字通过别名层（`ParseAlias`）解析，你可以在启动时提供**可插拔的别名包**：

```text
fun.exe -key:key_cn.ini   # 中文关键字（函数=fun、如果=if……）
fun.exe -key:key_fr.ini   # 法文关键字
```

已附带别名包：`key_cn.ini`（简体中文）、`key_fr.ini`（français）、`key_pua.ini`（自定义/私有区）。语言本身与关键字无关——别名是本地化/无障碍特性，而非另一种语言。

---

## 嵌入运行时 fun.dll

`fun.dll` 是嵌入运行时，用于把 Fun 脚本集成进第三方应用：

```pascal
Run(PChar('script.fun'));  // 编译脚本
Run(scriptContent);        // 执行
Run(-1);                   // 释放
```

- **免费使用（MIT）**：个人学习、内部工具，以及以开源许可证发布的产品。
- **商业使用**：将 `fun.dll` 嵌入闭源商业产品（exe/dmg/apk 或 SaaS 后端）需要商业授权，见 [`LICENSE.dll`](LICENSE.dll)。

---

## 目录结构

```text
fun/
├── src/
│   ├── core/          # 解释器核心（值模型、对象系统、流程控制、IO）
│   ├── parse/         # 词法/语法解析器
│   │   └── bnf/       #   文法定义：fun.ebnf、yacc.y、lex.l（生成 .inc/.cod）
│   ├── lib/           # 内建运行时库（winapi、winole、UI、host 等）
│   ├── regex/pcre/    # 内嵌 PCRE 正则引擎
│   ├── 3rd/           # 第三方组件（KOL）
│   ├── utils/         # 工具函数
│   └── prj/fun/       # 工程与构建脚本（funcmd.dpr，Delphi/FPC）
├── fun/
│   ├── lib/           # 标准库（纯 Fun 编写，58 个模块）
│   ├── demo/          # 语言语法演示
│   ├── demos/         # 完整应用与基准测试
│   └── key_*.ini      # 关键字别名包（CN / FR / PUA）
└── LICENSE*           # 授权文件
```

---

## 构建

Fun 核心为 Pascal，源码入口为 `src/prj/fun/funcmd.dpr`。

支持的工具链：

| 目标                | 脚本                                   | 工具链        |
| ------------------- | -------------------------------------- | ------------- |
| Windows 32 位       | `src/prj/fun/make-2006.bat` / `-2009.bat` | Delphi 2006 / 2009 |
| Linux（i386）       | `make-linux.bat`                       | FPC 2.4.0     |
| Linux / ARM         | `make-arm-linux.bat`                   | FPC 交叉      |
| Windows 64 位       | `make-win64.bat`                       | FPC 交叉      |
| Windows CE / ARM    | `make-wince.bat`                       | FPC 交叉      |

以 `-DFunDll` 编译可生成嵌入运行时 `fun.dll`，导出 `Run` 接口。构建产物已由 `.gitignore` 覆盖，不纳入版本控制。

完整文法定义见 [`src/parse/bnf/fun.ebnf`](src/parse/bnf/fun.ebnf)。

---

## 标准库

标准库位于 [`fun/lib`](fun/lib)，以纯 Fun 编写（58 个模块）：

- **数据**：`lib-json`、`lib-yaml`、`lib-xml`、`lib-base64`、`lib-cstruct`、`lib-md5`、`lib-crypt`
- **集合 / 算法**：`lib-set`、`lib-tree`、`lib-stack`、`lib-dyns`、`lib-math`
- **文本**：`lib-string`、`lib-regex`、`lib-match`、`lib-unicode`
- **系统 / IO**：`lib-file`、`lib-os`、`lib-time`、`lib-cmdline`、`lib-proc`
- **网络**：`lib-winsock`、`lib-ajax`、`lib-jsonrpc`
- **数据库**：`lib-orm`、`lib-orm-pro`、`lib-orm-gen`、`lib-orm-rpc`、`lib-orm-cte`、`lib-ado`、`lib-ado-schema`
- **原生 / 底层**：`lib-winapi`、`lib-winole`、`lib-tcc`（C 编译）、`lib-jit`、`lib-asm`、`lib-asm-pro`
- **UI**：`lib-ui`、`lib-ui-base`、`lib-dialog`、`lib-trayicon`
- **并发 / 异步**：`lib-async`、`lib-jsasync`、`lib-bind`、`lib-message`

---

## 示例

- [`fun/demo`](fun/demo) —— 语法演示：函数、闭包、柯里化、类、对象、集合、正则与异常处理。
- [`fun/demos`](fun/demos) —— 完整应用与基准测试：记事本 `notepad--`、`odbc-search`，以及性能 / 汇编 / JIT 基准。

---

## 许可证

Fun 采用 **双授权** 模式：

1. **开源许可证（MIT）** —— 见 [`LICENSE`](LICENSE)。允许自由使用、修改、分发源码，只要保留版权声明。
2. **商业授权**（额外条款，仅适用于下列闭源分发场景）：
   - 对内核做实质性修改并以闭源形式商业化分发 —— 见 [`LICENSE.custom`](LICENSE.custom)；
   - 将 `fun.dll` 嵌入闭源商业产品或 SaaS 后端 —— 见 [`LICENSE.dll`](LICENSE.dll)。

**简单说明**：内部使用、学习研究，以及以开源方式（MIT/GPL 等）发布修改版均免费。只有把修改过的内核或 `fun.dll` 当作闭源商业产品对外售卖时才需要付费授权。商业授权为一次性授权，按项目/公司计费，请联系 &lt;zwd@funlang.org&gt;。

---

© 2010-2026 Zhang Weidong &lt;zwd@funlang.org>
