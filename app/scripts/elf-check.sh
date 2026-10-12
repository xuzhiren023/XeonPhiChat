#!/usr/bin/env bash
# Sourced by run-smoke.sh; fail() is supplied by the caller.
check_elf() {
    local binary=$1 header
    local -a bytes=()
    [[ -f $binary ]] || fail "missing ELF file: $binary"
    # MPSS BusyBox 1.19.4's small od supports -b, but not -A/-t/-N/-j.
    # Limit input with dd; discard each od line's address field using awk.
    # -b prints octal bytes: ELF magic, class=2, data=1, e_machine=181 (0265).
    if ! header=$(dd if="$binary" bs=1 count=20 2>/dev/null | od -b |
        awk '{ for (i = 2; i <= NF; i++) printf "%s ", $i } END { print "" }'); then
        fail "cannot read ELF header: $binary"
    fi
    read -r -a bytes <<< "$header"
    [[ ${#bytes[@]} == 20 ]] || fail "truncated or unreadable ELF header: $binary"
    [[ ${bytes[0]} == 177 && ${bytes[1]} == 105 && ${bytes[2]} == 114 && ${bytes[3]} == 106 \
        && ${bytes[4]} == 002 && ${bytes[5]} == 001 && ${bytes[18]} == 265 && ${bytes[19]} == 000 ]] \
        || fail "not an ELF64 little-endian K1OM executable: $binary"
}
