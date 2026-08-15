# Fun 语言

> **Fun** —— 一门以中文为关键字、内置 JSON/FD 数据格式与 PCRE 正则的嵌入式脚本语言。
> 语言核心使用 Pascal（Delphi / Free Pascal）编写，自带解释器 VM 与标准库，可编译为命令行程序或嵌入第三方应用。

- 语言版本：**9.0**
- 官方站点：<https://funlang.org>
- 作者：Zhang Weidong &lt;zwd@funlang.org&gt;
- 授权：MIT（另有商业授权条款，见下文「许可证」）

---

## 目录

- [特性](#特性)
- [快速开始](#快速开始)
- [目录结构](#目录结构)
- [构建](#构建)
- [标准库](#标准库)
- [嵌入运行时 fun.dll](#嵌入运行时-fundll)
- [许可证](#许可证)

---

## 特性

- **中文关键字**：`fun` / `end fun`、`if` / `then` / `else`、`loop`、`case`、`try` / `except`、`class` 等，语法贴近自然语言。
- **动态类型 + 内建集合**：数字、字符串、时间、正则、数组（list）、集合（set）与树（tree）。
- **函数式特性**：匿名函数（lambda）、闭包、柯里化、`->` 管道、默认参数、可变参数。
- **内置数据格式**：JSON 与 **FD**（一种兼容 JSON、对人类与 AI 友好的类 Markdown 格式），支持双向转换与 SSE 压缩。
- **内嵌 PCRE 正则引擎**：无需外部依赖。
- **嵌入式运行时**：`fun.dll` 可嵌入第三方应用，作为扩展脚本语言（见授权说明）。
- **跨平台**：Windows（32/64 位）、Linux、ARM、Windows CE 交叉编译支持。
- **附带 IDE**：`funide`，以及记事本 `notepad--`、`odbc-search`、性能基准等完整示例。

---

## 快速开始

### 运行脚本

```text
fun.exe <file.fun>            # 运行脚本文件（支持 .fun / .foo / .fxx）
fun.exe -v <file.fun>         # 显示编译与执行耗时
fun.exe -log[:log.txt] -gui   # 输出到日志 / 以 GUI 模式运行
fun.exe -key:key_cn.ini       # 加载关键字/别名映射
```

### 第一个程序

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

更多示例见 [`fun/demo`](fun/demo)（语法演示）与 [`fun/demos`](fun/demos)（完整应用与基准测试）。

---

## 目录结构

```text
fun/
├── src/
│   ├── core/          # 解释器核心（VM、类型系统、流程控制、IO）
│   ├── parse/         # 词法/语法解析器
│   │   └── bnf/       #   文法定义：fun.ebnf、yacc.y、lex.l（生成 .inc/.cod）
│   ├── lib/           # 内建运行时库（winapi、winole、UI、host 等）
│   ├── regex/pcre/    # 内嵌 PCRE 正则引擎
│   ├── 3rd/           # 第三方组件（KOL）
│   ├── utils/         # 工具函数
│   └── prj/fun/       # 工程与构建脚本（funcmd.dpr，Delphi/FPC）
├── fun/
│   ├── lib/           # 标准库（纯 Fun 编写，60+ 模块）
│   ├── demo/          # 语言语法演示
│   ├── demos/         # 完整应用与基准测试
│   └── key_*.ini      # 关键字/别名映射
└── LICENSE*           # 授权文件
```

---

## 构建

`fun` 内核使用 Pascal 编写，源码入口为 `src/prj/fun/funcmd.dpr`。

支持编译器：

| 目标                | 脚本                                   | 编译器    |
| ------------------- | -------------------------------------- | --------- |
| Windows 32 位       | `src/prj/fun/make-2006.bat` / `-2009.bat` | Delphi 2006 / 2009 |
| Linux（i386）       | `make-linux.bat`                       | FPC 2.4.0 |
| Linux / ARM         | `make-arm-linux.bat`                   | FPC 交叉  |
| Windows 64 位       | `make-win64.bat`                       | FPC 交叉  |
| Windows CE / ARM    | `make-wince.bat`                       | FPC 交叉  |

> 以 `-DFunDll` 编译可生成嵌入式运行时库 `fun.dll`，导出 `Run` 接口。
> 构建产物已加入 `.gitignore`，不纳入版本控制。

完整文法定义见 [`src/parse/bnf/fun.ebnf`](src/parse/bnf/fun.ebnf)。

---

## 标准库

标准库位于 [`fun/lib`](fun/lib)，以纯 Fun 编写（60+ 模块），覆盖：

- **数据**：`lib-json`、`lib-yaml`、`lib-xml`、`lib-base64`、`lib-cstruct`、`lib-md5`、`lib-crypt`
- **集合/算法**：`lib-set`、`lib-tree`、`lib-stack`、`lib-dyns`、`lib-math`
- **文本**：`lib-string`、`lib-regex`、`lib-match`、`lib-unicode`
- **系统/IO**：`lib-file`、`lib-os`、`lib-time`、`lib-cmdline`、`lib-proc`
- **网络**：`lib-winsock`、`lib-ajax`、`lib-jsonrpc`
- **数据库**：`lib-orm`、`lib-orm-pro`、`lib-orm-gen`、`lib-orm-rpc`、`lib-orm-cte`、`lib-ado`、`lib-ado-schema`
- **内建接口**：`lib-winapi`、`lib-winole`、`lib-tcc`（C 编译）、`lib-jit`、`lib-asm`、`lib-asm-pro`
- **UI**：`lib-ui`、`lib-ui-base`、`lib-dialog`、`lib-trayicon`
- **并发/异步**：`lib-async`、`lib-jsasync`、`lib-bind`、`lib-message`

---

## 嵌入运行时 fun.dll

`fun.dll` 是可嵌入的运行时库，允许第三方应用将 Fun 脚本作为扩展语言集成到自身进程中：

```pascal
// 编译、运行、释放三段式接口
Run(PChar('script.fun'));  // 编译脚本
Run(scriptContent);        // 执行
Run(-1);                   // 释放
```

- 免费使用（MIT）：个人学习、内部工具、以开源协议发布的产品。
- **商业使用**：将 `fun.dll` 嵌入闭源商业产品（exe/dmg/apk 或 SaaS 后端）需购买商业授权，见 [`LICENSE.dll`](LICENSE.dll)。

---

## 许可证

`fun` 采用 **双授权** 模式：

1. **开源许可证（MIT）** —— 见 [`LICENSE`](LICENSE)。
   允许自由使用、修改、分发源码，只要保留版权声明。

2. **商业授权**（额外条款，仅适用于下列闭源分发场景）：
   - 对内核做实质性修改并以闭源形式商业化分发 —— 见 [`LICENSE.custom`](LICENSE.custom)；
   - 将 `fun.dll` 嵌入闭源商业产品或 SaaS 后端 —— 见 [`LICENSE.dll`](LICENSE.dll)。

**简单说明**：内部使用、学习研究、以及以开源方式（MIT/GPL 等）发布修改版均免费。只有把修改过的内核或 `fun.dll` 当作闭源商业产品对外售卖时才需要付费授权。商业授权为一次性授权，按项目/公司计费，请联系 &lt;zwd@funlang.org&gt;。

---

© 2010-2026 Zhang Weidong &lt;zwd@funlang.org&gt;
