param(
    [string]$Godot = 'D:/UserData/Downloads/godot/version/4.7.2 C#/godot-4.3-4.7.2-stable-mono.exe',
    [string]$Dotnet = ''
)
$ErrorActionPreference = 'Stop'
$taskProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskUserAppData = $env:APPDATA
$taskUserLocalAppData = $env:LOCALAPPDATA
try {
    # Bootstrap builds before opening Godot, including on a clean checkout.
    & (Join-Path $PSScriptRoot 'bootstrap.ps1') -Godot $Godot -Dotnet $Dotnet
} finally {
    # Keep the user's existing editor preferences and game saves.
    $env:APPDATA = $taskUserAppData
    $env:LOCALAPPDATA = $taskUserLocalAppData
}
# The child inherits bootstrap's SDK PATH, DOTNET_ROOT and matching NuGet cache.
# This is an interactive editor requested by the user, so it needs a visible window.
$taskEditor = Start-Process -FilePath $Godot -ArgumentList @('--editor', '--path', ('"' + $taskProjectRoot + '"')) -PassThru
Write-Output "Godot editor started: PID $($taskEditor.Id); SDK $env:DOTNET_ROOT"
