param(
    [string]$Godot = 'D:/UserData/Downloads/godot/version/4.7.2 C#/godot-4.3-4.7.2-stable-mono.exe',
    [string]$Templates = 'D:/UserData/Downloads/godot/version/4.7.2 C#/spine-godot-templates-4.3-4.7.2-stable-mono.tpz',
    [switch]$Validation
)
$ErrorActionPreference = 'Stop'
$taskProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskCacheRoot = Join-Path $taskProjectRoot '.cleanup-backup'
$taskTemplateRoot = Join-Path $taskCacheRoot 'csharp-export-templates'
$taskOutputRoot = Join-Path $taskCacheRoot $(if ($Validation) { 'export-nativeaot-validation' } else { 'export-nativeaot' })
New-Item -ItemType Directory -Path $taskTemplateRoot, $taskOutputRoot -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$taskArchive = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Templates).Path)
try {
    foreach ($taskName in @('windows_debug_x86_64.exe', 'windows_release_x86_64.exe', 'version.txt')) {
        $taskEntry = $taskArchive.GetEntry($taskName)
        if ($null -eq $taskEntry) { throw "Missing template: $taskName" }
        [IO.Compression.ZipFileExtensions]::ExtractToFile($taskEntry, (Join-Path $taskTemplateRoot $taskName), $true)
    }
} finally { $taskArchive.Dispose() }
if ((Get-Content -LiteralPath (Join-Path $taskTemplateRoot 'version.txt') -Raw).Trim() -ne '4.7.2.stable.mono') {
    throw 'The export templates must match the Spine/.NET 4.7.2 editor'
}
# This installs only project-local packages/environment; no global editor/SDK settings change.
& (Join-Path $PSScriptRoot 'bootstrap.ps1') -Godot $Godot
$env:PATH = $env:DOTNET_ROOT + ';' + $env:PATH
$taskLog = Join-Path $taskCacheRoot $(if ($Validation) { 'nativeaot-export-validation.log' } else { 'nativeaot-export.log' })
$taskApp = Join-Path $taskOutputRoot 'zaomengxiyou.exe'
$taskPreset = if ($Validation) { 'Windows NativeAOT Validation' } else { 'Windows NativeAOT' }
$taskArguments = @('--headless', '--path', ('"' + $taskProjectRoot + '"'), '--export-release', ('"' + $taskPreset + '"'), ('"' + $taskApp + '"'), '--log-file', ('"' + $taskLog + '"'))
$taskProcess = Start-Process -FilePath $Godot -ArgumentList $taskArguments -WindowStyle Hidden -Wait -PassThru
if ($taskProcess.ExitCode -ne 0) { throw "Godot export failed (exit $($taskProcess.ExitCode)); see $taskLog" }
if ((Get-Content -LiteralPath $taskLog -Raw) -match '(?m)^ERROR:|SCRIPT ERROR:') {
    throw "Godot reported export errors despite its exit code; see $taskLog"
}
$taskLibrary = @(Get-ChildItem -LiteralPath $taskOutputRoot -Filter 'zaomengxiyou.dll' -Recurse)
if ($taskLibrary.Count -ne 1) { throw 'Export is missing its unique NativeAOT game library' }
& (Join-Path $PSScriptRoot 'verify_native.ps1') -Library $taskLibrary[0].FullName
Write-Output "Exported game: $taskApp"
