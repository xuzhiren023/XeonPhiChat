# Frontend conversation state, independent of WPF and card execution.
function New-ChatSession([string]$Model) {
    return [pscustomobject]@{id=[Guid]::NewGuid().ToString('N');model=$Model;locked=$false;title='New chat';custom_title=$false;metrics=$null;updated_utc=[DateTime]::UtcNow.ToString('o');messages=(New-Object Collections.ArrayList);bubbles=(New-Object Collections.ArrayList);images=@();draft='';transcript=''}
}
function Lock-ChatSession($Session,[string]$Model,[string]$Prompt) {
    if ($Session.locked -and $Session.model -cne $Model) { throw 'A conversation keeps its original model.' }
    $Session.model=$Model; $Session.locked=$true
    if (!$Session.custom_title -and $Session.title -ceq 'New chat') {
        $title=([regex]::Replace($Prompt,'\s+',' ')).Trim()
        $Session.title=if ($title.Length -gt 48) { $title.Substring(0,48)+'...' } else { $title }
    }
    $Session.updated_utc=[DateTime]::UtcNow.ToString('o')
}
function Rename-ChatSession($Session,[string]$Title) {
    $title=([regex]::Replace($Title,'\s+',' ')).Trim()
    if (!$title -or $title.Length -gt 80) { throw 'Use a chat name between 1 and 80 characters.' }
    $Session.title=$title; $Session.custom_title=$true
}
function Save-ChatSessions([string]$Path,[string]$Epoch,[hashtable]$Sessions,[string]$Selected) {
    if (!$Epoch) { return }
    Write-JsonFile $Path ([pscustomobject]@{schema_version=1;epoch=$Epoch;selected=$Selected;sessions=@($Sessions.Values | Sort-Object updated_utc -Descending)})
}
function Read-ChatSessions([string]$Path,[string]$Epoch,[string[]]$Models) {
    $sessions=@{}; $selected=''
    if (Test-Path -LiteralPath $Path) {
        $saved=Read-JsonFile $Path
        if ($saved.schema_version -eq 1 -and $saved.epoch -ceq $Epoch) {
            foreach ($row in @($saved.sessions)) {
                if ($row.model -cnotin $Models -or $row.id -notmatch '^[a-f0-9]{32}$') { continue }
                $session=New-ChatSession $row.model
                foreach ($name in @('id','locked','title','updated_utc','draft','transcript')) { $session.$name=$row.$name }
                foreach ($name in @('custom_title','metrics','images')) { if ($row.PSObject.Properties[$name]) { $session.$name=$row.$name } }
                if ($session.metrics -and !$session.metrics.complete) { $session.metrics.complete=$true; $session.metrics.phase='Interrupted' }
                foreach ($message in @($row.messages)) { $null=$session.messages.Add($message) }
                foreach ($bubble in @($row.bubbles)) {
                    if ($bubble.state -ceq 'streaming') { $bubble.state='interrupted' }
                    $null=$session.bubbles.Add($bubble)
                }
                # A closed/crashed app may have saved the pending user turn.
                if ($session.messages.Count % 2 -eq 1) {
                    $last=if ($session.bubbles.Count) { $session.bubbles[-1].text } else { '' }
                    if (!$last) { $last='[Response interrupted]' }
                    $null=$session.messages.Add([pscustomobject]@{role='assistant';content=$last})
                }
                $sessions[$session.id]=$session
            }
            $selected=[string]$saved.selected
        } else { Remove-Item -LiteralPath $Path -Force }
    }
    return [pscustomobject]@{sessions=$sessions;selected=$selected}
}
function Split-AssistantContent([string]$Text,[bool]$StartsThinking=$false,[bool]$Complete=$false) {
    $thinking=$StartsThinking; $thought=New-Object Text.StringBuilder; $answer=New-Object Text.StringBuilder
    # Hide partial control tags between stream chunks. Never invent reasoning.
    if (!$Complete) {
        foreach ($tag in @('<think>','</think>')) {
            for ($i=1;$i -lt $tag.Length;$i++) {
                if ($Text.EndsWith($tag.Substring(0,$i),[StringComparison]::Ordinal)) { $Text=$Text.Substring(0,$Text.Length-$i); break }
            }
        }
    }
    foreach ($part in [regex]::Split($Text,'(<think>|</think>)')) {
        if ($part -ceq '<think>') { $thinking=$true }
        elseif ($part -ceq '</think>') { $thinking=$false }
        elseif ($thinking) { $null=$thought.Append($part) }
        else { $null=$answer.Append($part) }
    }
    return [pscustomobject]@{reasoning=$thought.ToString().Trim();answer=$answer.ToString().Trim();thinking=($thinking -and !$Complete)}
}
function Complete-ChatTurn($Session,$Bubble,[string]$Text,[string]$State) {
    $Bubble.text=$Text; $Bubble.state=$State
    $content=if ($Text.Trim()) { $Text } elseif ($State -ceq 'stopped') { '[Response interrupted]' } else { '[No response]' }
    if ($Bubble.starts_thinking -and !$content.Contains('</think>')) { $content+='</think>[Response interrupted]' }
    $null=$Session.messages.Add([pscustomobject]@{role='assistant';content=$content})
    $Session.transcript+=$content+"`r`n`r`n"
    $Session.updated_utc=[DateTime]::UtcNow.ToString('o')
}
