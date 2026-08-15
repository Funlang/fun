# Fun Language

> **Fun** is an embeddable scripting language whose keywords are Chinese, with built-in JSON and FD data formats and PCRE regex.
> The core interpreter is written in Pascal (Delphi / Free Pascal) and ships as a command-line program or an embeddable runtime (`fun.dll`).

**English**: README.en.md | **中文**: [README.md](README.md)

- Language version: **9.0**
- Website: <https://funlang.org>
- Author: Zhang Weidong &lt;zwd@funlang.org&gt;
- License: MIT (plus commercial terms, see [License](#license))

---

## Table of contents

- [Features](#features)
- [Quick start](#quick-start)
- [Repository layout](#repository-layout)
- [Building](#building)
- [Standard library](#standard-library)
- [Embedding with fun.dll](#embedding-with-fundll)
- [License](#license)

---

## Features

- **Chinese keywords**: `fun` / `end fun`, `if` / `then` / `else`, `loop`, `case`, `try` / `except`, `class`, etc. The syntax reads like natural language.
- **Dynamic typing with built-in collections**: numbers, strings, time, regex, arrays (list), sets and trees.
- **Functional features**: anonymous functions (lambdas), closures, currying, `->` pipelines, default and variadic parameters.
- **Built-in data formats**: JSON and **FD** (a Markdown-like format compatible with JSON, friendly to both humans and AI), with bidirectional conversion and SSE compression.
- **Bundled PCRE regex engine**: no external dependency.
- **Embeddable runtime**: `fun.dll` can be embedded into third-party applications as an extension scripting language (see [License](#license)).
- **Cross-platform**: Windows (32/64-bit), Linux, ARM, and Windows CE cross-compilation.
- **Companion IDE** (`funide`) plus full examples: the `notepad--` editor, `odbc-search`, and performance benchmarks.

---

## Quick start

### Run a script

```text
fun.exe <file.fun>            # run a script (.fun / .foo / .fxx)
fun.exe -v <file.fun>         # show compile & run timing
fun.exe -log[:log.txt] -gui   # log output / run in GUI mode
fun.exe -key:key_cn.ini       # load a keyword/alias mapping file
```

### Hello world

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

Run:

```text
> fun.exe fun/demo/fun.fun
Hello, fun!
9
9
```

More examples live in [`fun/demo`](fun/demo) (syntax demos) and [`fun/demos`](fun/demos) (full applications and benchmarks).

---

## Repository layout

```text
fun/
├── src/
│   ├── core/          # Interpreter core (VM, type system, control flow, IO)
│   ├── parse/         # Lexer/parser
│   │   └── bnf/       #   Grammar: fun.ebnf, yacc.y, lex.l (generates .inc/.cod)
│   ├── lib/           # Built-in runtime library (winapi, winole, UI, host, etc.)
│   ├── regex/pcre/    # Bundled PCRE regex engine
│   ├── 3rd/           # Third-party components (KOL)
│   ├── utils/         # Utility functions
│   └── prj/fun/       # Projects & build scripts (funcmd.dpr, Delphi/FPC)
├── fun/
│   ├── lib/           # Standard library (pure Fun, 60+ modules)
│   ├── demo/          # Language syntax demos
│   ├── demos/         # Full applications & benchmarks
│   └── key_*.ini      # Keyword/alias mappings
└── LICENSE*           # License files
```

---

## Building

The Fun core is written in Pascal; the source entry point is `src/prj/fun/funcmd.dpr`.

Supported toolchains:

| Target                 | Script                                    | Toolchain      |
| ---------------------- | ----------------------------------------- | -------------- |
| Windows 32-bit         | `src/prj/fun/make-2006.bat` / `-2009.bat` | Delphi 2006 / 2009 |
| Linux (i386)           | `make-linux.bat`                          | FPC 2.4.0      |
| Linux / ARM            | `make-arm-linux.bat`                      | FPC cross      |
| Windows 64-bit         | `make-win64.bat`                          | FPC cross      |
| Windows CE / ARM       | `make-wince.bat`                          | FPC cross      |

> Building with `-DFunDll` produces the embeddable runtime `fun.dll`, which exports the `Run` interface.
> Build artifacts are covered by `.gitignore` and are not versioned.

The full grammar is defined in [`src/parse/bnf/fun.ebnf`](src/parse/bnf/fun.ebnf).

---

## Standard library

The standard library in [`fun/lib`](fun/lib) is written in pure Fun (60+ modules):

- **Data**: `lib-json`, `lib-yaml`, `lib-xml`, `lib-base64`, `lib-cstruct`, `lib-md5`, `lib-crypt`
- **Collections / algorithms**: `lib-set`, `lib-tree`, `lib-stack`, `lib-dyns`, `lib-math`
- **Text**: `lib-string`, `lib-regex`, `lib-match`, `lib-unicode`
- **System / IO**: `lib-file`, `lib-os`, `lib-time`, `lib-cmdline`, `lib-proc`
- **Network**: `lib-winsock`, `lib-ajax`, `lib-jsonrpc`
- **Databases**: `lib-orm`, `lib-orm-pro`, `lib-orm-gen`, `lib-orm-rpc`, `lib-orm-cte`, `lib-ado`, `lib-ado-schema`
- **Native interfaces**: `lib-winapi`, `lib-winole`, `lib-tcc` (C compile), `lib-jit`, `lib-asm`, `lib-asm-pro`
- **UI**: `lib-ui`, `lib-ui-base`, `lib-dialog`, `lib-trayicon`
- **Concurrency / async**: `lib-async`, `lib-jsasync`, `lib-bind`, `lib-message`

---

## Embedding with fun.dll

`fun.dll` is an embeddable runtime that lets third-party applications integrate Fun scripts as an extension language:

```pascal
Run(PChar('script.fun'));  // compile the script
Run(scriptContent);        // execute it
Run(-1);                   // release
```

- **Free use (MIT)**: personal study, internal tools, products released under an open-source license.
- **Commercial use**: embedding `fun.dll` in a closed-source commercial product (exe/dmg/apk or a SaaS backend) requires a commercial license — see [`LICENSE.dll`](LICENSE.dll).

---

## License

Fun is distributed under a **dual-license** model:

1. **Open-source (MIT)** — see [`LICENSE`](LICENSE).
   You are free to use, modify, and redistribute the source, provided the copyright notice is retained.

2. **Commercial license** (additional terms that apply only to these closed-source redistribution cases):
   - Substantially modifying the kernel and commercially distributing the result closed-source — see [`LICENSE.custom`](LICENSE.custom);
   - Embedding `fun.dll` in a closed-source commercial product or SaaS backend — see [`LICENSE.dll`](LICENSE.dll).

**In short**: internal use, study/research, and releasing modified versions under an open-source license (MIT/GPL etc.) are all free. You only need to pay when you sell a modified kernel or `fun.dll` as a closed-source commercial product. Commercial licenses are one-time, priced per project/company — contact &lt;zwd@funlang.org&gt;.

---

© 2010-2026 Zhang Weidong &lt;zwd@funlang.org&gt;
