Set-StrictMode -Version Latest

function Assert-PhiJobProtocol($Request) {
    if ($null -eq $Request) { throw 'Missing backend request.' }
    if ($Request.PSObject.Properties['protocol_version'] -and $Request.protocol_version -cne 1) {
        throw 'Unsupported Phi job protocol version.'
    }
    if ($Request.PSObject.Properties['images'] -or $Request.PSObject.Properties['attachments']) {
        throw 'This backend supports text only; image input requires a qualified vision adapter.'
    }
    if ($Request.action -ceq 'Chat') {
        foreach ($message in @($Request.messages)) {
            if ($message.PSObject.Properties['images'] -or $message.PSObject.Properties['attachments'] -or
                $message.content -isnot [string]) {
                throw 'Job protocol v1 accepts text messages only.'
            }
        }
    }
}
