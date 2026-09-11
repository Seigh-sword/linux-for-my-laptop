#!/bin/bash
# ============================================================================
# tests/test-var.sh - test suite for the .var format (lib/var.sh + tools/var)
# Run: bash tests/test-var.sh   (exit 0 = all pass)
# ============================================================================
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VAR="$REPO_DIR/tools/var"
T="$(mktemp -d /tmp/vartest-XXXXXX)"
trap 'rm -rf "$T"' EXIT
PASS=0; FAIL=0

ok()   { PASS=$((PASS+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1 -- $2"; }

# assert_eq NAME EXPECTED ACTUAL
assert_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else fail "$1" "expected [$2] got [$3]"; fi
}
# assert_rc NAME EXPECTED_RC COMMAND...
assert_rc() {
  local name="$1" want="$2"; shift 2
  "$@" >/dev/null 2>&1
  local rc=$?
  if [ "$rc" = "$want" ]; then ok "$name"; else fail "$name" "exit $rc, want $want"; fi
}

chmod +x "$VAR"
# shellcheck source=../lib/var.sh
. "$REPO_DIR/lib/var.sh"

echo "== basic types =="
cat > "$T/basic.var" <<'EOF'
x = 1;
x2 = "hello, world!";
neg = -42;
yes = true;
no = false;
empty = "";
spaced   =   "pads"   ;
compact="tight";
EOF
assert_eq "int"            "1"             "$(var_get "$T/basic.var" x)"
assert_eq "string"         "hello, world!" "$(var_get "$T/basic.var" x2)"
assert_eq "negative int"   "-42"           "$(var_get "$T/basic.var" neg)"
assert_eq "bool true"      "true"          "$(var_get "$T/basic.var" yes)"
assert_eq "bool false"     "false"         "$(var_get "$T/basic.var" no)"
assert_eq "empty string"   ""              "$(var_get "$T/basic.var" empty)"
assert_eq "spaced"         "pads"          "$(var_get "$T/basic.var" spaced)"
assert_eq "compact"        "tight"         "$(var_get "$T/basic.var" compact)"

echo "== escapes =="
printf 'esc = "a\\"b\\\\c\\nd\\te\\rf";\n' > "$T/esc.var"
assert_eq "escapes" "$(printf 'a"b\\c\nd\te\rf')" "$(var_get "$T/esc.var" esc)"

echo "== comments, semicolons and hashes inside strings =="
cat > "$T/tricky.var" <<'EOF'
# full line comment
// other full line comment
semi = "a;b;c"; # trailing hash comment
hash = "a#b"; // trailing slash comment
url = "https://x.io/?a=1;b=2";
after = 7;   // spaced trailing
EOF
assert_eq "semicolons in string" "a;b;c" "$(var_get "$T/tricky.var" semi)"
assert_eq "hash in string"       "a#b"   "$(var_get "$T/tricky.var" hash)"
assert_eq "url value"  "https://x.io/?a=1;b=2" "$(var_get "$T/tricky.var" url)"
assert_eq "trailing comment"     "7"     "$(var_get "$T/tricky.var" after)"

echo "== last wins, defaults, missing =="
printf 'dup = "first";\ndup = "second";\n' > "$T/dup.var"
assert_eq "last wins" "second" "$(var_get "$T/dup.var" dup)"
assert_eq "default used" "fb"  "$(var_get "$T/dup.var" nope fb)"
assert_rc "missing rc=1" 1 var_get "$T/dup.var" nope
assert_rc "has true"  0 var_has "$T/dup.var" dup
assert_rc "has false" 1 var_has "$T/dup.var" nope
assert_rc "bad key rejected" 1 var_get "$T/dup.var" '9bad'

echo "== keys =="
cat > "$T/keys.var" <<'EOF'
ver.count = 2;
ver.0.id = "a";
ver.1.id = "b";
other = 1;
EOF
assert_eq "keys all"    "ver.count ver.0.id ver.1.id other" "$(var_keys "$T/keys.var" | tr '\n' ' ' | sed 's/ *$//')"
assert_eq "keys prefix" "ver.count ver.0.id ver.1.id"       "$(var_keys "$T/keys.var" ver. | tr '\n' ' ' | sed 's/ *$//')"

echo "== set / del =="
cp "$T/basic.var" "$T/rw.var"
var_set "$T/rw.var" x 99 --int
assert_eq "set int replace" "99" "$(var_get "$T/rw.var" x)"
var_set "$T/rw.var" brand new
assert_eq "set auto string" "new" "$(var_get "$T/rw.var" brand)"
var_set "$T/rw.var" auto_int 42
assert_eq "set auto int" "42" "$(var_get "$T/rw.var" auto_int)"
var_set "$T/rw.var" auto_bool true
assert_eq "set auto bool" "true" "$(var_get "$T/rw.var" auto_bool)"
var_set "$T/rw.var" quoted 'say "hi"; ok'
assert_eq "set escapes roundtrip" 'say "hi"; ok' "$(var_get "$T/rw.var" quoted)"
assert_rc "set bad int rejected" 1 var_set "$T/rw.var" bad 4x --int
assert_rc "set bad bool rejected" 1 var_set "$T/rw.var" bad yes --bool
assert_rc "set bad key rejected" 1 var_set "$T/rw.var" 'a-b' 1
grep -q '^x = 99;$' "$T/rw.var" && ok "set canonical form" || fail "set canonical form" "line not found"
var_del "$T/rw.var" x
assert_rc "del removes" 1 var_has "$T/rw.var" x
assert_rc "del keeps others" 0 var_has "$T/rw.var" x2

echo "== includes =="
mkdir -p "$T/inc/sub"
cat > "$T/inc/base.var" <<'EOF'
a = "from-base";
shared = "base";
include "sub/more.var";
b = "after-include";
EOF
cat > "$T/inc/sub/more.var" <<'EOF'
c = "from-included";
shared = "included";
EOF
assert_eq "include value"   "from-included" "$(var_get "$T/inc/base.var" c)"
assert_eq "include order"   "included"      "$(var_get "$T/inc/base.var" shared)"
assert_eq "after include"   "after-include" "$(var_get "$T/inc/base.var" b)"
assert_eq "before include"  "from-base"     "$(var_get "$T/inc/base.var" a)"
printf 'include "nope.var";\nx = 1;\n' > "$T/inc/missing.var"
assert_rc "missing include fails" 1 var_get "$T/inc/missing.var" x
printf 'include "c2.var";\n' > "$T/inc/c1.var"
printf 'include "c1.var";\n' > "$T/inc/c2.var"
assert_rc "include cycle fails" 1 var_get "$T/inc/c1.var" anything
# set/del never write into included files
var_set "$T/inc/base.var" c "top-override"
assert_eq "set shadows include" "top-override" "$(var_get "$T/inc/base.var" c)"
assert_eq "included file untouched" "from-included" "$(var_get "$T/inc/sub/more.var" c)"

echo "== validate =="
assert_rc "validate good" 0 var_validate "$T/basic.var" "$T/tricky.var" "$T/inc/base.var"
printf 'oops no semicolon\n' > "$T/bad1.var"
assert_rc "validate catches missing semicolon" 1 var_validate "$T/bad1.var"
printf 'k = "unterminated;\n' > "$T/bad2.var"
assert_rc "validate catches bad string" 1 var_validate "$T/bad2.var"
printf 'k = maybe;\n' > "$T/bad3.var"
assert_rc "validate catches bad value" 1 var_validate "$T/bad3.var"
printf '9k = 1;\n' > "$T/bad4.var"
assert_rc "validate catches bad key" 1 var_validate "$T/bad4.var"
printf 'k = 1; junk after\n' > "$T/bad5.var"
assert_rc "validate catches junk after semicolon" 1 var_validate "$T/bad5.var"
printf 'include "nope.var";\n' > "$T/bad6.var"
assert_rc "validate catches missing include" 1 var_validate "$T/bad6.var"

echo "== CLI =="
assert_eq "cli get" "1" "$("$VAR" get "$T/basic.var" x)"
assert_rc "cli has" 0 "$VAR" has "$T/basic.var" x
assert_eq "cli keys" "x" "$("$VAR" keys "$T/basic.var" | head -1)"
cp "$T/basic.var" "$T/cli.var"
"$VAR" set "$T/cli.var" cli_key cli_val >/dev/null
assert_eq "cli set" "cli_val" "$("$VAR" get "$T/cli.var" cli_key)"
"$VAR" del "$T/cli.var" cli_key >/dev/null
assert_rc "cli del" 1 "$VAR" has "$T/cli.var" cli_key
assert_rc "cli validate" 0 "$VAR" validate "$T/basic.var"
"$VAR" dump "$T/basic.var" | grep -q "^x2[[:space:]]" && ok "cli dump" || fail "cli dump" "no x2 row"

echo ""
echo "RESULT: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
