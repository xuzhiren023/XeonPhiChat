Set-StrictMode -Version Latest

function Assert-PhiJobProtocol($Request) {
    if ($null -eq $Request) { throw 'Missing backend request.' }
    $version=if ($Request.PSObject.Properties['protocol_version']) { $Request.protocol_version } else { 2 }
    if ($version -cnotin @(1,2)) {
        throw 'Unsupported Phi job protocol version.'
    }
    if ($Request.PSObject.Properties['images'] -or $Request.PSObject.Properties['attachments']) {
        throw 'Images belong to individual user messages.'
    }
    if ($Request.action -ceq 'Chat') {
        $null=Get-ThinkingDepth $Request
        foreach ($message in @($Request.messages)) {
            if ($message.PSObject.Properties['attachments'] -or
                $message.content -isnot [string]) {
                throw 'Invalid chat message.'
            }
            $images=@(Get-MessageImages $message)
            if ($images.Count -gt 4 -or ($images.Count -and ($version -eq 1 -or $message.role -cne 'user'))) { throw 'Images require a protocol v2 user message, with at most four attachments.' }
            foreach ($image in $images) { Assert-ImageReference $image }
        }
    }
}
