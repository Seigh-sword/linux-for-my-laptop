# The `.var` variable-file format (spec v1)

`.var` is arunlinux's tiny data format: one variable per line, human-readable,
machine-reliable. It is the backend store for the launcher's version registry
(`launcher/versions-registry.var`) and user accounts (`launcher/accounts.var`).

## Quick example

```
# versions-registry.var - which arunlinux versions the launcher can install
registry.latest = "x86_64-v90130a1";
registry.updated = "2026-09-11";

ver.count = 2;
ver.0.id = "x86_64-v90130a1";
ver.0.kind = "netinstall";
ver.0.commit = "90130a1";
ver.0.date = "2026-09-11";
ver.0.desc = "Latest stable netinstall payload";
```

## Grammar

A file is UTF-8 text, parsed line by line:

```
statement  := assignment | include
assignment := KEY "=" VALUE ";" [comment]
include    := "include" STRING ";" [comment]
comment    := "#" ... | "//" ...
KEY        := [A-Za-z_][A-Za-z0-9_.]*        (dots = namespaces, case-sensitive)
VALUE      := STRING | INT | BOOL
STRING     := '"' (escape | char)* '"'       (no literal newlines)
INT        := "-"? [0-9]+
BOOL       := "true" | "false"
escape     := "\\" | "\"" | "\n" | "\t" | "\r"
```

Rules:

1. Every statement ends with `;`. No `;`, no variable.
2. Whitespace around tokens is free: `x=1;`, `x = 1 ;`, all fine.
3. Strings are double-quoted. Inside them, `;`, `#` and `//` are literal data.
4. Blank lines and full-line comments (`#` or `//`) are ignored.
5. Trailing comments after `;` are allowed: `x = 1; # the one`.
6. Duplicate keys: **last one wins**, earlier values are shadowed.
7. `include "other.var";` inlines another file at that position (depth-first).
   Paths are relative to the file containing the directive. Missing files and
   include cycles are hard errors.
8. One statement per line. Values never span lines.

## Types

| Type | Example | Notes |
|---|---|---|
| string | `name = "Arun";` | escapes: `\\` `\"` `\n` `\t` `\r` |
| int | `count = 2;` | optional leading `-`, no `+`, no decimals |
| bool | `admin = true;` | exactly `true` or `false`, lowercase |

There are no floats, arrays, or nulls in v1. Dotted keys (`ver.0.id`) cover
namespaces; `*.count` integers cover list lengths. Keep it boring on purpose.

## Tooling

- `lib/var.sh` — the parser library (source it from Bash).
- `tools/var` — CLI: `get`, `set`, `del`, `keys`, `has`, `validate`, `dump`.
- `tests/test-var.sh` — test suite. Run it: `bash tests/test-var.sh`.
- `scripts/lint-distro.sh` validates every `*.var` in the repo on each commit.

Conventions for writers (`var set` follows these automatically):

- `set`/`del` only ever touch the top file, never an included file.
- `set` replaces the first definition in place (comments elsewhere survive);
  new keys are appended as `key = value;`.
- Types: `var set f k v` auto-detects int/bool, else string. Force with
  `--int`, `--bool`, `--string`.

## Limits (by design)

- Max sane size: thousands of lines (launcher data, not databases).
- No multiline strings, no expressions, no variable interpolation.
- If you need nesting deeper than dots, you need a real format (JSON) —
  `.var` stays a flat variable list forever.
