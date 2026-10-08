param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string[]]$Suites = @('wushuang', 'wukong_skills', 'monster_ai', 'buffs', 'hit_reaction', 'battle_presentation', 'scene_attributes', 'character_components', 'original_feedback', 'wooden_dummy', 'wukong_attack_effects', 'wukong_context_attacks', 'original_damage', 'damage_numbers', 'damage_number_pool', 'single_attack', 'skill_timeline', 'core_events', 'attribute_pipeline', 'stage_four', 'player_operations', 'wukong_state_machine', 'plugins', 'stage_one')
)
#region 项目根目录与隔离日志
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$previousAppData = $env:APPDATA
$previousLocalData = $env:LOCALAPPDATA
$logDirectory = Join-Path $taskRoot '.cleanup-backup'
New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
#endregion
#region Godot伤害与插件回归
try {
    foreach ($suite in $Suites) {
        if ($suite -notmatch '^[a-z_]+$') { throw "Invalid suite: $suite" }
        $env:APPDATA = Join-Path $logDirectory ('stage8-' + $suite + '-user')
        $env:LOCALAPPDATA = $env:APPDATA
        $taskLog = Join-Path $logDirectory ('stage8-' + $suite + '.log')
        $arguments = @('--headless', '--path', ('"' + $taskRoot + '"'), '--log-file', ('"' + $taskLog + '"'), '--max-fps', '600', '--fixed-fps', '60', '--quit-after', '12000', ('res://examples/verify_' + $suite + '.tscn'))
        $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
        $output = Get-Content -Raw -LiteralPath $taskLog
        if ($process.ExitCode -ne 0 -or $output -match 'SCRIPT ERROR:|(?m)^ERROR:' -or $output -notmatch '(?m)^PASS') {
            Write-Output $output
            throw "Godot suite failed: $suite (exit $($process.ExitCode))"
        }
        $output -split "`n" | Where-Object { $_ -match '^PASS' } | Write-Output
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalData
}
#endregion
