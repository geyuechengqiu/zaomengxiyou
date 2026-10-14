param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string[]]$Suites = @('csharp_migration', 'world_settings_speed', 'inventory_presentation', 'original_skill_panel', 'spawn_performance', 'pipa_support', 'base_attributes', 'fight_power', 'audio', 'loot_growth', 'combat_hud', 'hit_combo', 'wushuang_visual', 'super_armor_visual', 'double_jump', 'monster_spine', 'original_battle_ui', 'original_boss_presentation', 'camera_follow', 'map_visual', 'boss', 'level_progression', 'damage_number_pool', 'huaguoshan', 'huaguoshan_combat', 'shuiliandong', 'shuiliandong_combat', 'mihouwang_animation', 'mihouwang_skills', 'zaomeng_one_campaign', 'campaign_transitions'),
    [ValidateRange(1, 3600)][int]$TimeoutSeconds = 240
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
        $arguments = @('--headless', '--audio-driver', 'Dummy', '--path', ('"' + $taskRoot + '"'), '--log-file', ('"' + $taskLog + '"'), '--max-fps', '600', '--fixed-fps', '60', '--quit-after', '12000', ('res://tests/suites/verify_' + $suite + '.tscn'))
        $process = Start-Process -FilePath $Godot -ArgumentList $arguments -WindowStyle Hidden -PassThru
        $taskDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        while (-not $process.WaitForExit(1000)) {
            if ([DateTime]::UtcNow -gt $taskDeadline) {
                Stop-Process -Id $process.Id -Force
                throw "Godot suite timed out: $suite; see $taskLog"
            }
        }
        $output = Get-Content -Raw -LiteralPath $taskLog
        if ($process.ExitCode -ne 0 -or $output -match 'SCRIPT ERROR:|(?m)^ERROR:' -or $output -notmatch '(?m)^PASS') {
            $taskLines = $output -split "`n"
            $taskLines | Select-Object -First 100 | Write-Output
            if ($taskLines.Count -gt 100) { $taskLines | Select-Object -Last 25 | Write-Output }
            throw "Godot suite failed: $suite (exit $($process.ExitCode))"
        }
        $output -split "`n" | Where-Object { $_ -match '^PASS' } | Write-Output
    }
} finally {
    $env:APPDATA = $previousAppData
    $env:LOCALAPPDATA = $previousLocalData
}
#endregion
