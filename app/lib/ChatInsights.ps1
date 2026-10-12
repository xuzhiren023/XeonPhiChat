# Read-only presentation of existing backend telemetry. No card operations.
function New-ChatMetrics {
    return [pscustomobject]@{phase='Preparing';context_tokens=0;prompt_tokens=$null;output_tokens=0;
        output_estimated=$true;generation_tps=$null;generation_estimated=$true;prompt_tps=$null;
        elapsed_seconds=0;omitted_pairs=0;complete=$false}
}
function Read-InsightFile([string]$Directory,[string]$Name) {
    $path=Join-Path $Directory $Name
    if (Test-Path -LiteralPath $path) { try { return Read-JsonFile $path } catch {} }
    return $null
}
function Update-JobInsights($Job,$Status,[bool]$Complete) {
    $m=$Job.conversation.metrics
    $m.elapsed_seconds=$Job.watch.Elapsed.TotalSeconds
    $resources=Read-InsightFile $Job.dir 'resource-settings.json'
    if ($resources) { $m.context_tokens=[int]$resources.context }
    $budget=Read-InsightFile $Job.dir 'prompt-budget.json'
    if ($budget) {
        $m.context_tokens=[int]$budget.context_tokens; $m.omitted_pairs=[int]$budget.omitted_pairs
        if ($null -ne $budget.prompt_tokens) { $m.prompt_tokens=[int]$budget.prompt_tokens }
    }
    $m.output_tokens=[int][math]::Ceiling($Job.rate.EstimatedTokens); $m.output_estimated=$true
    $m.generation_tps=$Job.estimatedRate; $m.generation_estimated=$true
    $live=Read-InsightFile $Job.dir 'live-progress.json'
    if ($live) {
        $m.phase=switch ($live.stage) { 'generating' {'Generating'} 'prefill' {'Processing prompt'} 'check' {'Counting context'} default {'Preparing'} }
        $n=$live.native
        # Consumed includes the prompt and generated tokens. Check-mode samples
        # belong to a separate preflight and must never count as generation.
        if ($n -and $n.Stage -ceq 'prefill' -and $null -ne $m.prompt_tokens -and $budget) {
            $generating=($live.stage -ceq 'generating')
            if ($generating -and $n.Consumed -ge $m.prompt_tokens) {
                $m.output_tokens=[int]($n.Consumed-$m.prompt_tokens); $m.output_estimated=$false
            }
            $phase=if ($generating) {'generation'} else {'prompt'}
            $samples=$Job.metricSamples
            if ($samples.Count -and ($samples[-1].phase -cne $phase -or $n.SampleSeconds -lt $samples[-1].seconds -or $n.Consumed -lt $samples[-1].tokens)) { $samples.Clear() }
            if (!$samples.Count -or $n.SampleSeconds -gt $samples[-1].seconds) {
                $null=$samples.Add([pscustomobject]@{phase=$phase;seconds=[double]$n.SampleSeconds;tokens=[long]$n.Consumed})
                while ($samples.Count -gt 2 -and $samples[-1].seconds-$samples[1].seconds -ge 10) { $samples.RemoveAt(0) }
            }
            if ($samples.Count -gt 1) {
                $span=$samples[-1].seconds-$samples[0].seconds
                if ($span -ge 1) {
                    $speed=($samples[-1].tokens-$samples[0].tokens)/$span
                    if ($generating) { $m.generation_tps=$speed; $m.generation_estimated=$false }
                    else { $m.prompt_tps=$speed }
                }
            }
        }
    }
    if ($Complete) {
        $m.complete=$true
        $m.phase=if ($Status -and $Status.state -ceq 'done') {'Completed'} elseif ($Status -and $Status.state -ceq 'cancelled') {'Stopped'} else {'Interrupted'}
        if ($Status -and $Status.PSObject.Properties['result'] -and $Status.result -and $Status.result.PSObject.Properties['generation_tokens']) {
            $r=$Status.result
            $m.output_tokens=[int]$r.generation_tokens; $m.output_estimated=$false
            $m.generation_tps=$r.generation_tps; $m.generation_estimated=$false; $m.prompt_tps=$r.prompt_tps
            $m.context_tokens=[int]$r.context
        }
    }
}
function Format-TokenRate($Rate,[bool]$Estimated=$false) {
    if ($null -eq $Rate) { return '--' }
    return ('{0}{1:N1} tokens/s' -f $(if ($Estimated) {'~'} else {''}),$Rate)
}
function Update-ChatInsights {
    $m=$script:conversation.metrics
    $capacity=0; $used=$null; $estimated=$false
    if ($m) {
        $capacity=$m.context_tokens
        if ($null -ne $m.prompt_tokens) { $used=$m.prompt_tokens+$m.output_tokens; $estimated=$m.output_estimated }
    } elseif (!$script:conversation.messages.Count) { $used=0 }
    if (!$capacity -and (Test-SelectedReady) -and $script:loadedModel.PSObject.Properties['resources']) { $capacity=$script:loadedModel.resources.context_tokens }
    $known=($capacity -gt 0 -and $null -ne $used)
    $fraction=if ($known) { [math]::Min(1.0,[math]::Max(0.0,$used/[double]$capacity)) } else {0.0}
    $controls.ContextArc.Visibility=if ($fraction -gt 0) {'Visible'} else {'Collapsed'}
    $controls.ContextFull.Visibility=if ($fraction -ge 1) {'Visible'} else {'Collapsed'}
    if ($fraction -gt 0 -and $fraction -lt 1) {
        $angle=2*[math]::PI*$fraction
        $x=16+11*[math]::Sin($angle); $y=16-11*[math]::Cos($angle)
        $path=[string]::Format([Globalization.CultureInfo]::InvariantCulture,'M 16,5 A 11,11 0 {0} 1 {1},{2}',[int]($fraction -gt 0.5),$x,$y)
        $controls.ContextArc.Data=[Windows.Media.Geometry]::Parse($path)
    }
    $color=if ($fraction -ge 0.9) {'#E4AC72'} else {'#B7CBC4'}
    $controls.ContextArc.Stroke=$color; $controls.ContextFull.Stroke=$color
    $controls.ContextLabel.Text=if ($fraction -gt 0 -and $fraction -lt 0.01) {'<1%'} elseif ($known) { '{0}{1:0}%' -f $(if ($estimated) {'~'} else {''}),[math]::Floor($fraction*100) } else {'--'}
    $tooltip=if ($known) { '{0}{1:N0} / {2:N0} context tokens used. Includes the sent prompt and reply; excludes unsent drafts. Capacity is allocated for this model on the card.' -f $(if ($estimated) {'About '} else {''}),$used,$capacity } else {'Context usage appears after the model is loaded and the next prompt is counted.'}
    if ($m -and $m.omitted_pairs -gt 0) { $tooltip+=' Older messages remain in chat history; '+$m.omitted_pairs+' older pair(s) were omitted from this model context.' }
    $controls.ContextUsage.ToolTip=$tooltip
    $controls.StatsContext.Text=if ($known) { '{0}{1:N0} / {2:N0}' -f $(if ($estimated) {'~'} else {''}),$used,$capacity } else {'--'}
    $controls.StatsState.Text=if ($m) { $m.phase+' - this chat' } else {'No response yet - this chat'}
    $controls.Speed.Text=if ($m) { Format-TokenRate $m.generation_tps $m.generation_estimated } else {'--'}
    $controls.PromptSpeed.Text=if ($m) { Format-TokenRate $m.prompt_tps } else {'--'}
    $controls.StatsOutput.Text=if ($m) { '{0}{1:N0}' -f $(if ($m.output_estimated) {'~'} else {''}),$m.output_tokens } else {'--'}
    $controls.StatsPrompt.Text=if ($m -and $null -ne $m.prompt_tokens) { '{0:N0}' -f $m.prompt_tokens } else {'--'}
    $controls.StatsElapsed.Text=if ($m) { '{0:N1}s' -f $m.elapsed_seconds } else {'--'}
    $controls.StatsNote.Text=if ($m -and $m.complete -and $m.phase -ceq 'Completed') {'Last response - measured averages'} elseif ($m -and $m.complete) {'Last response - sampled counts; ~ marks an estimate'} else {'Live card samples - ~ marks a text-based estimate'}
}
