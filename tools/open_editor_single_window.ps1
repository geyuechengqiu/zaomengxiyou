param(
    [string]$Godot,
    [switch]$PrintCommand,
    [switch]$PersistSingleWindow,
    [switch]$ConfigureOnly
)

#region 项目与编辑器路径
$ErrorActionPreference = 'Stop'
$taskRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($Godot)) {
    $metadataPath = Join-Path $taskRoot '.godot/editor/project_metadata.cfg'
    if (Test-Path -LiteralPath $metadataPath) {
        $metadata = Get-Content -Raw -LiteralPath $metadataPath
        $pathMatch = [regex]::Match($metadata, '(?m)^executable_path="([^"]+)"\s*$')
        if ($pathMatch.Success) { $Godot = $pathMatch.Groups[1].Value }
    }
}

if ([string]::IsNullOrWhiteSpace($Godot) -or !(Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw 'Pass -Godot with the path to the Spine-enabled Godot executable.'
}
$Godot = (Resolve-Path -LiteralPath $Godot).Path
#endregion

#region 单窗口编辑器入口
$editorArguments = @('--path', $taskRoot, '--editor', '--single-window')
if ($ConfigureOnly -and !$PersistSingleWindow) {
    throw '-ConfigureOnly requires -PersistSingleWindow.'
}
if ($PrintCommand) {
    [pscustomobject]@{ Executable = $Godot; Arguments = $editorArguments; PersistSingleWindow = [bool]$PersistSingleWindow }
    return
}

# 不与同版本编辑器同时写全局设置，也绝不强制终止用户的编辑器。
if ($PersistSingleWindow) {
    $openEditors = @(Get-CimInstance Win32_Process | Where-Object {
        $_.ExecutablePath -eq $Godot -and $_.CommandLine -match '(?:^|\s)(?:--editor|-e)(?:\s|$)'
    })
    if ($openEditors.Count -gt 0) {
        throw 'Save and close the running Godot editor first, then retry -PersistSingleWindow.'
    }
    # Windows GUI 版 exe 用 & 启动时可能立即返回；必须等待保存进程真正退出。
    $configureLog = Join-Path $taskRoot '.godot/window-mode-configure.log'
    New-Item -ItemType Directory -Path (Split-Path -Parent $configureLog) -Force | Out-Null
    # 辅助工程不加载游戏插件；自检插件仅在显式验证参数下运行。
    $helperRoot = Join-Path $PSScriptRoot 'editor/window_mode_helper'
    $configureArguments = @('--headless', '--path', ('"' + $helperRoot + '"'), '--editor', '--single-window',
        '--script', 'res://configure_editor_window_mode.gd', '--quit-after', '1800',
        '--log-file', ('"' + $configureLog + '"'))
    $configureProcess = Start-Process -FilePath $Godot -ArgumentList $configureArguments -WindowStyle Hidden -Wait -PassThru
    $configureOutput = Get-Content -Raw -LiteralPath $configureLog
    if ($configureProcess.ExitCode -ne 0 -or $configureOutput -notmatch '(?m)^PASS single-window setting saved:' -or
        $configureOutput -match 'SCRIPT ERROR:|(?m)^ERROR:') {
        Write-Output $configureOutput
        throw "Failed to persist single-window mode (exit $($configureProcess.ExitCode))."
    }
    $configureOutput -split "`n" | Where-Object { $_ -match '^PASS' } | Write-Output
    if ($ConfigureOnly) { return }
}

# 此参数只对新进程生效；请先保存并关闭原编辑器，再使用此入口。
& $Godot @editorArguments
#endregion
