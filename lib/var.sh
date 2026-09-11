#!/bin/bash
# ============================================================================
# lib/var.sh - parser library for .var variable files (VAR-SPEC v1)
# ----------------------------------------------------------------------------
#   . path/to/lib/var.sh
#   var_get registry.var registry.latest      # -> x86_64-v90130a1
#   var_set accounts.var user.arun.admin true --bool
#
# Requires bash 4+ (associative arrays). No external dependencies.
# See docs/VAR-SPEC.md for the format. Behavior notes:
#   - get/has/keys/dump resolve `include` directives depth-first, last wins.
#   - set/del only touch the TOP file, never an included file.
# ============================================================================

if [ "${BASH_VERSINFO[0]:-0}" -lt 4 ]; then
  echo "var.sh: bash 4+ required" >&2
  return 1 2>/dev/null || exit 1
fi

# --- internals ---------------------------------------------------------------
_VAR_KEY_RE='^[A-Za-z_][A-Za-z0-9_.]*$'

_var_realpath() { # $1 = path -> canonical path (best effort)
  if command -v readlink >/dev/null 2>&1; then
    readlink -f "$1" 2>/dev/null || printf '%s' "$1"
  else
    printf '%s' "$1"
  fi
}

_var_trim() { # $1 = text -> trimmed (leading/trailing spaces, tabs, CR)
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

# _var_split_line LINE
# Splits one raw line. Sets globals and returns 0 for a statement:
#   _SPLIT_KIND = assign | include
#   _SPLIT_KEY  = key (assign) or include path (include)
#   _SPLIT_VAL  = raw value text (assign; still quoted/escaped)
# Returns 1 for blank/comment lines, 2 for malformed lines.
_var_split_line() {
  local line="$1" rest key val i c closed
  _SPLIT_KIND=""; _SPLIT_KEY=""; _SPLIT_VAL=""
  line="$(_var_trim "$line")"
  case "$line" in
    ''|'#'*|'//'*) return 1 ;;
  esac
  # include "path";
  if [[ "$line" == include[[:space:]]* ]]; then
    rest="${line#include}"
    rest="$(_var_trim "$rest")"
    if [[ "$rest" =~ ^\"([^\"]+)\"[[:space:]]*\;[[:space:]]*(#.*|//.*)?$ ]]; then
      _SPLIT_KIND="include"; _SPLIT_KEY="${BASH_REMATCH[1]}"
      return 0
    fi
    return 2
  fi
  # key = value;
  if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_.]*)[[:space:]]*=[[:space:]]*(.*)$ ]]; then
    key="${BASH_REMATCH[1]}"
    rest="${BASH_REMATCH[2]}"
  else
    return 2
  fi
  # value: quoted string (escape-aware) or bare token up to ';'
  if [[ "$rest" == '"'* ]]; then
    val=""; i=1; closed=0
    while [ "$i" -lt "${#rest}" ]; do
      c="${rest:$i:1}"
      if [ "$c" = '\' ]; then
        val+="$c${rest:$((i+1)):1}"; i=$((i+2)); continue
      fi
      if [ "$c" = '"' ]; then closed=1; i=$((i+1)); break; fi
      val+="$c"; i=$((i+1))
    done
    [ "$closed" -eq 1 ] || return 2
    rest="${rest:$i}"
    rest="$(_var_trim "$rest")"
    [[ "$rest" == ';'* ]] || return 2
    rest="${rest#';'}"
    rest="$(_var_trim "$rest")"
    case "$rest" in ''|'#'*|'//'*) ;;
      *) return 2 ;;  # junk after ';'
    esac
    _SPLIT_KIND="assign"; _SPLIT_KEY="$key"; _SPLIT_VAL="\"$val\""
    return 0
  fi
  # bare value: everything up to the first ';'
  case "$rest" in
    *';'*) val="${rest%%';'*}" ;;
    *) return 2 ;;
  esac
  rest="${rest#*';'}"
  rest="$(_var_trim "$rest")"
  case "$rest" in ''|'#'*|'//'*) ;;
    *) return 2 ;;
  esac
  val="$(_var_trim "$val")"
  [ -n "$val" ] || return 2
  _SPLIT_KIND="assign"; _SPLIT_KEY="$key"; _SPLIT_VAL="$val"
  return 0
}

# _var_unescape TEXT -> decoded string (handles \\ \" \n \t \r)
_var_unescape() {
  local s="$1" out="" i=0 c n
  while [ "$i" -lt "${#s}" ]; do
    c="${s:$i:1}"
    if [ "$c" = '\' ]; then
      n="${s:$((i+1)):1}"
      case "$n" in
        '\') out+='\' ;; '"') out+='"' ;;
        n) out+=$'\n' ;; t) out+=$'\t' ;; r) out+=$'\r' ;;
        *) out+="\\$n" ;;  # unknown escape: keep literally
      esac
      i=$((i+2))
    else
      out+="$c"; i=$((i+1))
    fi
  done
  printf '%s' "$out"
}

# _var_escape TEXT -> escaped for storage inside double quotes
_var_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

# _var_type_of RAW -> prints: string | int | bool | BAD
_var_type_of() {
  local raw="$1"
  if [[ "$raw" == '"'*'"' ]]; then echo "string"; return; fi
  if [[ "$raw" =~ ^-?[0-9]+$ ]]; then echo "int"; return; fi
  if [ "$raw" = "true" ] || [ "$raw" = "false" ]; then echo "bool"; return; fi
  echo "BAD"
}

# _var_decode RAW -> decoded value text (string inner content unescaped,
# int/bool verbatim). Caller must have checked the type first.
_var_decode() {
  local raw="$1"
  if [[ "$raw" == '"'* ]] && [[ "$raw" == *'"' ]]; then
    _var_unescape "${raw:1:${#raw}-2}"
  else
    printf '%s' "$raw"
  fi
}

# _var_resolve FILE STACK OUTFILE
# Writes the include-resolved statement stream to OUTFILE, one per line:
#   source_path<TAB>lineno<TAB>raw_line
# STACK = "|" separated realpaths (cycle detection). Returns nonzero + error
# message if a file is missing/unreadable or a cycle is found.
_var_resolve() {
  local file="$1" stack="$2" out="$3"
  local real dir line lineno=0 inc incpath rc
  real="$(_var_realpath "$file")"
  case "$stack" in
    *"|$real|"*) echo "var: include cycle at $file" >&2; return 1 ;;
  esac
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    echo "var: cannot read $file" >&2; return 1
  fi
  stack="$stack$real|"
  dir="$(dirname "$file")"
  while IFS= read -r line || [ -n "$line" ]; do
    lineno=$((lineno+1))
    _var_split_line "$line"; rc=$?
    if [ "$rc" -eq 0 ] && [ "$_SPLIT_KIND" = "include" ]; then
      case "$_SPLIT_KEY" in
        /*) incpath="$_SPLIT_KEY" ;;
        *) incpath="$dir/$_SPLIT_KEY" ;;
      esac
      _var_resolve "$incpath" "$stack" "$out" || return 1
    else
      printf '%s\t%d\t%s\n' "$file" "$lineno" "$line" >> "$out"
    fi
  done < "$file"
  return 0
}

_var_resolved_tmp() { # $1 = file -> prints tmp path with resolved stream
  local tmp
  tmp="$(mktemp /tmp/var-resolve-XXXXXX)" || return 1
  if ! _var_resolve "$1" "|" "$tmp"; then rm -f "$tmp"; return 1; fi
  printf '%s' "$tmp"
}

# --- public API --------------------------------------------------------------

# var_get FILE KEY [DEFAULT] -> value on stdout; exit 1 if missing (no default)
var_get() {
  local file="$1" key="$2" def="${3-__VAR_NODEFAULT__}"
  local tmp src ln raw found=0 val rc t
  [[ "$key" =~ $_VAR_KEY_RE ]] || { echo "var: bad key '$key'" >&2; return 1; }
  tmp="$(_var_resolved_tmp "$file")" || return 1
  while IFS=$'\t' read -r src ln raw || [ -n "$raw" ]; do
    _var_split_line "$raw"; rc=$?
    [ "$rc" -eq 0 ] || continue
    [ "$_SPLIT_KIND" = "assign" ] || continue
    [ "$_SPLIT_KEY" = "$key" ] || continue
    t="$(_var_type_of "$_SPLIT_VAL")"
    [ "$t" = "BAD" ] && continue
    val="$(_var_decode "$_SPLIT_VAL")"
    found=1  # keep going: last wins
  done < "$tmp"
  rm -f "$tmp"
  if [ "$found" -eq 1 ]; then printf '%s' "$val"; return 0; fi
  if [ "$def" != "__VAR_NODEFAULT__" ]; then printf '%s' "$def"; return 0; fi
  return 1
}

# var_has FILE KEY -> exit 0 if the key resolves to a valid value
var_has() {
  var_get "$1" "$2" "__VAR_NODEFAULT__" >/dev/null 2>&1
}

# var_keys FILE [PREFIX] -> one key per line (resolved, deduped, file order)
var_keys() {
  local file="$1" prefix="${2-}"
  local tmp src ln raw rc
  declare -A _seen=()
  tmp="$(_var_resolved_tmp "$file")" || return 1
  while IFS=$'\t' read -r src ln raw || [ -n "$raw" ]; do
    _var_split_line "$raw"; rc=$?
    [ "$rc" -eq 0 ] || continue
    [ "$_SPLIT_KIND" = "assign" ] || continue
    [ "$(_var_type_of "$_SPLIT_VAL")" = "BAD" ] && continue
    case "$_SPLIT_KEY" in "$prefix"*) ;;
      *) continue ;;
    esac
    if [ -z "${_seen[$_SPLIT_KEY]+x}" ]; then
      _seen[$_SPLIT_KEY]=1
      printf '%s\n' "$_SPLIT_KEY"
    fi
  done < "$tmp"
  rm -f "$tmp"
}

# var_dump FILE -> TAB-separated "key<TAB>type<TAB>decoded value" per key
var_dump() {
  local file="$1" key
  while IFS= read -r key; do
    [ -n "$key" ] || continue
    printf '%s\t%s\t%s\n' "$key" "$(_var_type_of_key "$file" "$key")" "$(var_get "$file" "$key")"
  done < <(var_keys "$file")
}

_var_type_of_key() { # FILE KEY -> type of the resolved value (last valid wins)
  local file="$1" key="$2"
  local tmp src ln raw rc t cur="BAD"
  tmp="$(_var_resolved_tmp "$file")" || return 1
  while IFS=$'\t' read -r src ln raw || [ -n "$raw" ]; do
    _var_split_line "$raw"; rc=$?
    [ "$rc" -eq 0 ] || continue
    [ "$_SPLIT_KIND" = "assign" ] && [ "$_SPLIT_KEY" = "$key" ] || continue
    t="$(_var_type_of "$_SPLIT_VAL")"
    [ "$t" = "BAD" ] || cur="$t"  # last valid wins
  done < "$tmp"
  rm -f "$tmp"
  printf '%s' "$cur"
}

# var_set FILE KEY VALUE [--string|--int|--bool|--auto]
# Replaces the first top-file definition in place, or appends. Never writes
# into included files.
var_set() {
  local file="$1" key="$2" value="$3" want="${4---auto}"
  local line out added=0 raw new t
  [[ "$key" =~ $_VAR_KEY_RE ]] || { echo "var: bad key '$key'" >&2; return 1; }
  [ -e "$file" ] || : > "$file"  # create if missing
  [ -f "$file" ] && [ -w "$file" ] || { echo "var: cannot write $file" >&2; return 1; }
  case "$want" in
    --int)    [[ "$value" =~ ^-?[0-9]+$ ]] || { echo "var: not an int: $value" >&2; return 1; }
              new="$key = $value;" ;;
    --bool)   { [ "$value" = "true" ] || [ "$value" = "false" ]; } || { echo "var: not a bool: $value" >&2; return 1; }
              new="$key = $value;" ;;
    --string) new="$key = \"$(_var_escape "$value")\";" ;;
    --auto)   if [[ "$value" =~ ^-?[0-9]+$ ]]; then new="$key = $value;"
              elif [ "$value" = "true" ] || [ "$value" = "false" ]; then new="$key = $value;"
              else new="$key = \"$(_var_escape "$value")\";"; fi ;;
    *) echo "var: bad type flag $want (want --string|--int|--bool|--auto)" >&2; return 1 ;;
  esac
  out="$(mktemp /tmp/var-set-XXXXXX)" || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    if [ "$added" -eq 0 ]; then
      _var_split_line "$line"
      if [ "$?" -eq 0 ] && [ "$_SPLIT_KIND" = "assign" ] && [ "$_SPLIT_KEY" = "$key" ]; then
        printf '%s\n' "$new" >> "$out"; added=1; continue
      fi
    fi
    printf '%s\n' "$line" >> "$out"
  done < "$file"
  if [ "$added" -eq 0 ]; then printf '%s\n' "$new" >> "$out"; fi
  cat "$out" > "$file"; rm -f "$out"
}

# var_del FILE KEY -> removes every top-file definition of KEY
var_del() {
  local file="$1" key="$2" line out
  [[ "$key" =~ $_VAR_KEY_RE ]] || { echo "var: bad key '$key'" >&2; return 1; }
  [ -f "$file" ] || return 0
  out="$(mktemp /tmp/var-del-XXXXXX)" || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    _var_split_line "$line"
    if [ "$?" -eq 0 ] && [ "$_SPLIT_KIND" = "assign" ] && [ "$_SPLIT_KEY" = "$key" ]; then
      continue
    fi
    printf '%s\n' "$line" >> "$out"
  done < "$file"
  cat "$out" > "$file"; rm -f "$out"
}

# var_validate FILE... -> strict check (exit 1 on any error; dupes = warning)
var_validate() {
  local file fail=0
  for file in "$@"; do
    _var_validate_one "$file" || fail=1
  done
  return "$fail"
}

_var_validate_one() {
  local file="$1" tmp src ln raw rc t fail=0
  declare -A _seen=()
  tmp="$(_var_resolved_tmp "$file")" || return 1
  while IFS=$'\t' read -r src ln raw || [ -n "$raw" ]; do
    _var_split_line "$raw"; rc=$?
    if [ "$rc" -eq 2 ]; then
      echo "var: $src:$ln: malformed line: $raw" >&2; fail=1; continue
    fi
    [ "$rc" -eq 0 ] || continue
    [ "$_SPLIT_KIND" = "assign" ] || continue
    t="$(_var_type_of "$_SPLIT_VAL")"
    if [ "$t" = "BAD" ]; then
      echo "var: $src:$ln: bad value for '${_SPLIT_KEY}': ${_SPLIT_VAL}" >&2; fail=1; continue
    fi
    if [ -n "${_seen[${_SPLIT_KEY}]+x}" ]; then
      echo "var: $src:$ln: warning: '${_SPLIT_KEY}' shadows an earlier definition" >&2
    else
      _seen[${_SPLIT_KEY}]=1
    fi
  done < "$tmp"
  rm -f "$tmp"
  return "$fail"
}
