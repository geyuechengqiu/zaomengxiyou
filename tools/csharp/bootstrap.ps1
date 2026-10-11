param(
    [string]$Godot = 'D:/UserData/Downloads/godot/version/4.7.2 C#/godot-4.3-4.7.2-stable-mono.exe',
    [string]$Dotnet = '',
    [switch]$PublishNative,
    [ValidateSet('win-x64', 'win-arm64', 'linux-x64', 'linux-arm64', 'osx-x64', 'osx-arm64')]
    [string]$RuntimeIdentifier = 'win-x64',
    [string]$OutputDirectory = ''
)
$ErrorActionPreference = 'Stop'
$taskProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$taskGodotRoot = Split-Path -Parent (Resolve-Path -LiteralPath $Godot).Path
$taskPackages = Join-Path $taskProjectRoot '.godot/mono/packages'
New-Item -ItemType Directory -Force -Path $taskPackages | Out-Null
$taskPackageFiles = @(Get-ChildItem -LiteralPath (Join-Path $taskGodotRoot 'GodotSharp/Tools/nupkgs') -Filter '*.nupkg')
if ($taskPackageFiles.Count -lt 4) { throw 'The Godot installation is missing matching Spine NuGet packages' }
foreach ($taskPackage in $taskPackageFiles) {
    Copy-Item -LiteralPath $taskPackage.FullName -Destination $taskPackages -Force
}
if (-not $Dotnet) {
    $taskPortableDotnet = Join-Path $taskProjectRoot '.cleanup-backup/csharp-sdk/dotnet.exe'
    $Dotnet = if (Test-Path -LiteralPath $taskPortableDotnet) { $taskPortableDotnet } else { 'dotnet' }
}
$Dotnet = (Get-Command $Dotnet -ErrorAction Stop).Source
$taskSdkVersions = @(& $Dotnet --list-sdks)
if ($LASTEXITCODE -ne 0 -or -not ($taskSdkVersions -match '^8\.0\.')) {
    throw "No .NET 8 SDK found at $Dotnet. A runtime alone cannot build. Install the .NET 8 SDK or pass its dotnet.exe via -Dotnet."
}
$env:DOTNET_CLI_HOME = Join-Path $taskProjectRoot '.cleanup-backup/dotnet-home'
$env:NUGET_PACKAGES = Join-Path $taskProjectRoot '.godot/mono/nuget-cache'
$env:DOTNET_NOLOGO = '1'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:APPDATA = Join-Path $taskProjectRoot '.cleanup-backup/dotnet-appdata'
$env:LOCALAPPDATA = Join-Path $taskProjectRoot '.cleanup-backup/dotnet-localappdata'
New-Item -ItemType Directory -Force -Path $env:APPDATA, $env:LOCALAPPDATA | Out-Null
$env:DOTNET_ROOT = Split-Path -Parent $Dotnet
# Godot searches PATH for the build CLI; DOTNET_ROOT alone only selects its runtime.
$env:PATH = $env:DOTNET_ROOT + [IO.Path]::PathSeparator + $env:PATH
if ($PublishNative) {
    if (-not $OutputDirectory) { $OutputDirectory = Join-Path $taskProjectRoot ".cleanup-backup/nativeaot/$RuntimeIdentifier" }
    & $Dotnet publish (Join-Path $taskProjectRoot 'zaomengxiyou.csproj') --configuration ExportRelease --runtime $RuntimeIdentifier --output $OutputDirectory '-p:NuGetAudit=false'
    if ($LASTEXITCODE -ne 0) { throw 'NativeAOT publish failed' }
    if ($RuntimeIdentifier -eq 'win-x64') {
        & (Join-Path $PSScriptRoot 'verify_native.ps1') -Library (Join-Path $OutputDirectory 'zaomengxiyou.dll')
    }
    Write-Output "NativeAOT output: $OutputDirectory"
} else {
    & $Dotnet build (Join-Path $taskProjectRoot 'zaomengxiyou.csproj') --configuration Debug '-p:NuGetAudit=false'
    if ($LASTEXITCODE -ne 0) { throw 'C# build failed' }
}
