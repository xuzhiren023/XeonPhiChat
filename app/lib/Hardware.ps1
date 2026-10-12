# Pure parser: no commands, files, network or configuration changes.
function Read-MicHardware {
    param([string]$Text, [object[]]$Profiles, [switch]$AllowWarm)
    $devices = [regex]::Matches($Text, '(?m)^\s*Device No:\s*(\d+)')
    if ($devices.Count -ne 1) { throw 'Expected exactly one MIC device in micinfo; do not guess between cards.' }
    $fields = @{}
    foreach ($entry in @(
        @('cores', 'Total No of Active Cores', ''),
        @('gddr_mib', 'GDDR Size', 'MB'),
        @('temperature_c', 'Die Temp', 'C'),
        @('frequency_khz', 'Frequency', 'kHz')
    )) {
        $pattern = '(?m)^\s*' + [regex]::Escape($entry[1]) + '\s*:\s*(\d+)\s*' + $entry[2] + '\s*$'
        $m = [regex]::Matches($Text, $pattern)
        if ($m.Count -ne 1) { throw "Missing or ambiguous micinfo field: $($entry[1])" }
        $fields[$entry[0]] = [int]$m[0].Groups[1].Value
    }
    $skuMatch = [regex]::Match($Text, '(?m)^\s*Board SKU\s*:\s*([^\r\n]+)')
    if (!$skuMatch.Success) { throw 'Board SKU is missing.' }
    $sku = $skuMatch.Groups[1].Value.Trim()
    $matches = @($Profiles | Where-Object {
        $_.expected_cores -eq $fields.cores -and
        $fields.gddr_mib -ge $_.gddr_min_mib -and $fields.gddr_mib -le $_.gddr_max_mib -and
        $sku -match $_.sku_pattern
    })
    if ($matches.Count -ne 1) { throw 'Unknown or inconsistent SKU/core/memory combination; no safe hardware profile selected.' }
    $profile = $matches[0]
    $limit = if ($AllowWarm) { $profile.thermal_stop_c } else { $profile.thermal_warn_c }
    if ($fields.temperature_c -lt 1 -or $fields.temperature_c -ge $limit) {
        throw "Die temperature $($fields.temperature_c) C is invalid or at/above the project's $limit C limit. Wait for the card to cool and check airflow."
    }
    $rpm = [regex]::Match($Text, '(?m)^\s*Fan RPM\s*:\s*(\d+)\s*$')
    if ($profile.cooling_type -eq 'active') {
        if ($Text -notmatch '(?m)^\s*SMC HW Revision\s*:[^\r\n]*Active' -or !$rpm.Success -or [int]$rpm.Groups[1].Value -le 0) {
            throw 'Active-card profile requires an active board description and a positive fan RPM.'
        }
    }
    $ecc = [regex]::Match($Text, '(?m)^\s*ECC Mode\s*:\s*(Enabled|Disabled)\s*$')
    if (!$ecc.Success) { throw 'ECC state is missing or unreadable.' }
    return [pscustomobject]@{
        profile = $profile; sku = $sku; cores = $fields.cores; gddr_mib = $fields.gddr_mib
        temperature_c = $fields.temperature_c; frequency_khz = $fields.frequency_khz
        ecc = $ecc.Groups[1].Value; device_number = [int]$devices[0].Groups[1].Value
    }
}
