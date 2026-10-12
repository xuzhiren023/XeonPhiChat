#!/usr/bin/env bash
set -euo pipefail
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ $(uname -m) == k1om ]] || fail 'Model cache maintenance requires K1OM'
[[ $# -ge 3 ]] || fail 'Missing cache operation arguments'
action=$1; pin=$2; token=$3
[[ $pin =~ ^[a-f0-9]{40}$ && $token =~ ^[a-f0-9]{32}$ ]] || fail 'Invalid cache operation identity'
[[ $(cat /tmp/knc-phase3-workload.lock/phi-chat-owner 2>/dev/null) == "$token" ]] || fail 'Cache operation lost its workload lock'
size_of() {
    # Paths are restricted to ASCII without whitespace; metadata only.
    # shellcheck disable=SC2012
    LC_ALL=C ls -ln "$1" | awk '{print $5}'
}
identity_of() {
    local identity='-'
    if [[ -f $1.identity && ! -L $1.identity ]]; then identity=$(cat "$1.identity"); fi
    [[ $identity =~ ^[a-f0-9]{64}$ ]] || identity='-'
    printf '%s' "$identity"
}
valid_path() {
    local path=$1 base
    [[ $path =~ ^(/root/knc-phase3-run-[A-Za-z0-9-]+)/(model\.gguf|models/[A-Za-z0-9_.-]+\.gguf(\.part)?)$ ]] || return 1
    base=${BASH_REMATCH[1]}
    [[ -d $base && ! -L $base && ! -L $base/models && -f $base/build-passed.txt && ! -L $base/build-passed.txt ]] || return 1
    [[ $(cat "$base/build-passed.txt") == "$pin" && -f $path && ! -L $path && ! -L $path.identity ]]
}
case "$action" in
inventory)
    for base in /root/knc-phase3-run-*; do
        [[ -d $base && ! -L $base ]] || continue
        for path in "$base/model.gguf" "$base"/models/*.gguf "$base"/models/*.gguf.part; do
            valid_path "$path" || continue
            printf '%s\t%s\t%s\n' "$path" "$(size_of "$path")" "$(identity_of "$path")"
        done
    done
    ;;
remove)
    [[ $# == 6 ]] || fail 'Invalid cache removal arguments'
    path=$4; bytes=$5; identity=$6
    [[ $bytes =~ ^[0-9]+$ && ( $identity == '-' || $identity =~ ^[a-f0-9]{64}$ ) ]] || fail 'Invalid cache metadata'
    valid_path "$path" || fail "Cache path no longer matches the inventory: $path"
    [[ $(size_of "$path") == "$bytes" && $(identity_of "$path") == "$identity" ]] || fail "Cache file changed during cleanup: $path"
    # Unlinking a mapped/open file does not release its RAM. Never claim that it
    # does, and never kill another application to make this operation succeed.
    for maps in /proc/[0-9]*/maps; do
        [[ -r $maps ]] || continue
        if grep -Fq -- "$path" "$maps"; then fail "Model is mapped by a process; stop that workload first: $path"; fi
    done
    for fd in /proc/[0-9]*/fd/*; do
        [[ -L $fd ]] || continue
        target=$(readlink "$fd" 2>/dev/null || true)
        [[ $target != "$path" && $target != "$path (deleted)" ]] || fail "Model is open by a process; stop that workload first: $path"
    done
    rm -f "$path" "$path.identity"
    [[ ! -e $path && ! -L $path ]] || fail "Cache file remains after removal: $path"
    printf 'REMOVED\t%s\t%s\n' "$path" "$bytes"
    ;;
*) fail 'Unknown cache action';;
esac
