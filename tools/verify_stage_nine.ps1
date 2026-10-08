param(
    [Parameter(Mandatory=$true)][string]$Godot,
    [string[]]$Suites = @('hit_reaction', 'wooden_dummy', 'wukong_attack_effects', 'original_damage', 'damage_numbers', 'single_attack', 'skill_timeline', 'core_events', 'attribute_pipeline', 'stage_four', 'player_operations', 'wukong_state_machine', 'plugins', 'stage_one')
)
# 复用已有隔离用户目录、正常退出和日志检查；不启动或关闭日常编辑器。
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'verify_stage_eight.ps1') -Godot $Godot -Suites $Suites
