#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$checks=0
function Check([bool]$Value,[string]$Message) { $script:checks++; if (!$Value) { throw ('FAIL: '+$Message) }; Write-Output ('PASS: '+$Message) }
function Read([string]$Relative) { Get-Content -LiteralPath (Join-Path $root $Relative) -Raw | ConvertFrom-Json }
$manifest=Read 'assets/optimized-models.json'
foreach ($entry in $manifest.models) {
    $model=Read ('app/config/models/'+$entry.id+'.yaml')
    Check ($entry.bytes -eq $model.file_size_bytes -and $entry.sha256 -ceq $model.sha256 -and $entry.path -ceq $model.model_path) ($entry.id+': import manifest and app agree on complete artifact identity')
}
$id='lfm2.5-8b-a1b-uncensored-gaston-matrices-q5_k'
$gaston=@($manifest.models | Where-Object id -CEQ $id)[0]
$model=Read ('app/config/models/'+$id+'.yaml')
$provenance=Read $gaston.provenance_file
Check ($gaston.runtime_status -ceq 'blocked_lfm2moe' -and !$gaston.native_acceptance -and !$provenance.knc_execution_validated) 'catalog and provenance do not claim native acceptance'
Check ($provenance.bytes -eq 5830593408 -and $provenance.sha256 -ceq '852cd73ed6ba7d8fcd6ebeae577a75fa7de5f3239c9fe0dce7bf8cc077e20ec3' -and $gaston.sha256 -ceq $provenance.sha256) 'Gaston pins the completed Q5_K artifact, not source Q8_0'
Check ($model.source_quantization -ceq 'Q8_0' -and $model.requantization -and !$model.imatrix_used_for_this_conversion -and $provenance.requantization -and !$provenance.imatrix_used_for_this_conversion) 'Q8_0 requantization and absent conversion imatrix are explicit'
Check ($model.revision -ceq $provenance.source.revision -and $model.repository -ceq $provenance.source.repo -and $model.source_sha256 -ceq $provenance.source.files[0].sha256 -and $model.quantizer_commit -ceq $provenance.quantizer.commit) 'source and quantizer provenance agree across the catalog'
$auditPath=Join-Path $root $gaston.audit_file
Check ($provenance.audit.file -ceq $gaston.audit_file -and (Get-Item -LiteralPath $auditPath).Length -eq $provenance.audit.bytes -and (Get-FileHash -LiteralPath $auditPath).Hash.ToLowerInvariant() -ceq $provenance.audit.sha256) 'full retained tensor audit matches its pinned size and SHA-256'
$audit=Read $gaston.audit_file
$tensors=@($audit.tensors.PSObject.Properties.Value)
Check ($tensors.Count -eq 256 -and @($tensors | Where-Object type -CEQ 'Q5_K').Count -eq 155 -and @($tensors | Where-Object type -CEQ 'F32').Count -eq 101) 'all 256 tensors have exactly the documented Q5_K/F32 types'
$expected=@{matrix=67;expert_matrix=66;router_matrix=22;normalization=61;short_convolution=18;routing_bias=22}
foreach ($category in $expected.Keys) {
    Check (@($tensors | Where-Object category -CEQ $category).Count -eq $expected[$category]) ('audit category '+$category+' is complete')
}
$expertSamples=0
foreach ($property in $audit.tensors.PSObject.Properties) {
    if ($property.Value.category -cne 'expert_matrix') { continue }
    $samples=@($audit.sampled_relative_rmse_by_expert.($property.Name))
    Check ($property.Value.shape[2] -eq 32 -and $samples.Count -eq 32) ($property.Name+': all expert slices sampled')
    $expertSamples+=$samples.Count
}
Check ($expertSamples -eq 2112 -and $expertSamples -eq $provenance.expert_slices_numerically_sampled -and $audit.f32_exceptions_byte_identical -and $audit.sampled_relative_rmse_max -eq $provenance.sampled_relative_rmse_max) 'sampling summary and byte-identical exceptions agree with audit'
foreach ($relative in @($gaston.provenance_file,$gaston.audit_file)) {
    $content=Get-Content -LiteralPath (Join-Path $root $relative) -Raw
    Check ($content -notmatch '(?i)[a-z]:\\|/Users/|_bluepower.local') ('distribution evidence has no personal absolute paths: '+$relative)
}
Write-Output ('PASS: '+$checks+' pinned model provenance checks; no weights or hardware needed.')
