# BusyBox-compatible. Same accounting as Read-MemorySnapshot in Memory.ps1.
# Output: MemFree KiB, allocatable estimate KiB, cache credit KiB.
BEGIN {
    split("MemTotal MemFree MemAvailable Cached Shmem Unevictable Dirty Writeback Active(file) Inactive(file)", names, " ")
    for (i in names) wanted[names[i]]=1
}
{
    key=$1; sub(/:$/, "", key)
    if (key in wanted) {
        if (seen[key]++ || NF != 3 || $2 !~ /^[0-9]+$/ || $3 != "kB") bad=1
        value[key]=$2+0
    }
}
END {
    if (!seen["MemTotal"] || !seen["MemFree"] || value["MemTotal"] <= 0) bad=1
    for (key in value) if (value[key] > value["MemTotal"]) bad=1
    if (bad) exit 1
    free=value["MemFree"]; available=free; credit=0
    if (seen["MemAvailable"]) available=value["MemAvailable"]
    else if (seen["Cached"] && seen["Shmem"] && seen["Unevictable"] && seen["Dirty"] && seen["Writeback"] && seen["Active(file)"] && seen["Inactive(file)"]) {
        cache=value["Cached"]-value["Shmem"]-value["Unevictable"]
        lru=value["Active(file)"]+value["Inactive(file)"]
        credit=(cache < lru ? cache : lru)-value["Dirty"]-value["Writeback"]
        if (credit < 0) credit=0
        available=free+credit
        if (available > value["MemTotal"]) available=value["MemTotal"]
    }
    printf "%.0f %.0f %.0f\n", free, available, credit
}
