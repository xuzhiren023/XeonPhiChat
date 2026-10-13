# BusyBox/mawk compatible /proc/PID/smaps parser. Paths are launcher-controlled.
# Output: read-only shared model size/RSS KiB, total RSS KiB, unsafe model maps.
/^[0-9a-fA-F]+-[0-9a-fA-F]+[[:space:]]/ {
    model = ($6 == path)
    shared = (model && $2 == "r--s")
    if (model && !shared) unsafe++
    # KNC's proc reader can repeat VMA records while the address space changes.
    # A virtual address range represents one mapping, even if streamed twice.
    duplicate = seen[$1]++
    next
}
duplicate { next }
$1 == "Size:" && shared { mapped += $2; next }
$1 == "Rss:" { total += $2; if (shared) resident += $2; rows++ }
END {
    if (!rows) exit 2
    printf "%.0f %.0f %.0f %.0f\n", mapped, resident, total, unsafe
}
