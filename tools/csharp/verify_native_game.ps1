param(
    [string]$Game = '',
    [string[]]$Suites = @(),
    [int]$TimeoutSeconds = 240
)
$ErrorActionPreference = 'Stop'
$taskProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskCacheRoot = Join-Path $taskProjectRoot '.cleanup-backup'
if (-not $Game) {
    $taskDirectory = if ($Suites.Count) { 'export-nativeaot-validation' } else { 'export-nativeaot' }
    $Game = Join-Path $taskCacheRoot ($taskDirectory + '/zaomengxiyou.exe')
}
$Game = (Resolve-Path -LiteralPath $Game).Path
$taskRuns = if ($Suites.Count) { $Suites } else { @('main_level') }
$taskPreviousAppData = $env:APPDATA
$taskPreviousLocalData = $env:LOCALAPPDATA
try {
    foreach ($taskSuite in $taskRuns) {
        if ($taskSuite -notmatch '^[a-z_]+$') { throw "Invalid suite: $taskSuite" }
        $taskPrefix = Join-Path $taskCacheRoot ('native-game-' + $taskSuite)
        $env:APPDATA = $taskPrefix + '-user'
        $env:LOCALAPPDATA = $env:APPDATA
        New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
        $taskFrames = if ($taskSuite -eq 'main_level') { 300 } else { 12000 }
        $taskArguments = @('--headless', '--audio-driver', 'Dummy', '--max-fps', '600', '--fixed-fps', '60', '--quit-after', "$taskFrames", '--log-file', ('"' + $taskPrefix + '.log"'))
        if ($taskSuite -ne 'main_level') { $taskArguments += @('--', ('--verify-suite=' + $taskSuite)) }
        $taskProcess = Start-Process -FilePath $Game -ArgumentList $taskArguments -WorkingDirectory (Split-Path $Game) -WindowStyle Hidden -RedirectStandardOutput ($taskPrefix + '.out') -RedirectStandardError ($taskPrefix + '.err') -PassThru
        $taskDeadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
        while (-not $taskProcess.WaitForExit(1000)) {
            if ([DateTime]::UtcNow -gt $taskDeadline) {
                Stop-Process -Id $taskProcess.Id
                throw "NativeAOT suite timed out: $taskSuite"
            }
        }
        $taskOutput = (Get-Content -LiteralPath ($taskPrefix + '.out') -Raw) + (Get-Content -LiteralPath ($taskPrefix + '.err') -Raw)
        if ($taskProcess.ExitCode -ne 0 -or $taskOutput -match 'SCRIPT ERROR:|(?m)^ERROR:|instances were leaked' -or ($taskSuite -ne 'main_level' -and $taskOutput -notmatch '(?m)^PASS')) {
            $taskOutput -split "`n" | Select-Object -Last 60 | Write-Output
            throw "NativeAOT suite failed: $taskSuite (exit $($taskProcess.ExitCode))"
        }
        if ($taskSuite -eq 'main_level') { Write-Output 'PASS NativeAOT main scene: 300 frames, world map/UI/audio, clean exit' }
        else { $taskOutput -split "`n" | Where-Object { $_ -match '^PASS' } | Write-Output }
    }
} finally {
    $env:APPDATA = $taskPreviousAppData
    $env:LOCALAPPDATA = $taskPreviousLocalData
}
