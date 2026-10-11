param([Parameter(Mandatory = $true)][string]$Library)
$ErrorActionPreference = 'Stop'
$taskLibrary = (Resolve-Path -LiteralPath $Library).Path
$taskStream = [IO.File]::OpenRead($taskLibrary)
$taskReader = [IO.BinaryReader]::new($taskStream)
try {
    if ($taskReader.ReadUInt16() -ne 0x5A4D) { throw 'Not a Windows PE binary' }
    $taskStream.Position = 0x3C
    $taskPeOffset = $taskReader.ReadUInt32()
    $taskStream.Position = $taskPeOffset
    if ($taskReader.ReadUInt32() -ne 0x4550) { throw 'Invalid PE signature' }
    if ($taskReader.ReadUInt16() -ne 0x8664) { throw 'Expected win-x64 binary' }
    $taskOptionalOffset = $taskPeOffset + 24
    $taskStream.Position = $taskOptionalOffset
    if ($taskReader.ReadUInt16() -ne 0x20B) { throw 'Expected PE32+ binary' }
    $taskStream.Position = $taskOptionalOffset + 112 + 14 * 8
    if ($taskReader.ReadUInt32() -ne 0 -or $taskReader.ReadUInt32() -ne 0) {
        throw 'Binary contains a CLR header; this is an IL assembly, not NativeAOT'
    }
} finally { $taskReader.Dispose(); $taskStream.Dispose() }
if (-not ('ZaomengNativeBuildProbe' -as [type])) {
    Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
[UnmanagedFunctionPointer(CallingConvention.Cdecl)]
public delegate int ZaomengNativeBuildProbe();
'@
}
# NativeAOT libraries cannot be unloaded. Keep the handle until this process exits.
$taskHandle = [Runtime.InteropServices.NativeLibrary]::Load($taskLibrary)
$taskEntry = [Runtime.InteropServices.NativeLibrary]::GetExport($taskHandle, 'godotsharp_game_main_init')
if ($taskEntry -eq [IntPtr]::Zero) { throw 'Godot game initialization entry is missing' }
$taskProbeEntry = [Runtime.InteropServices.NativeLibrary]::GetExport($taskHandle, 'zaomengxiyou_native_build_contract')
$taskProbe = [Runtime.InteropServices.Marshal]::GetDelegateForFunctionPointer($taskProbeEntry, [ZaomengNativeBuildProbe])
$taskFlags = $taskProbe.Invoke()
if ($taskFlags -ne 7) { throw "NativeAOT contract failed: $taskFlags (expected 64-bit, dynamic code disabled, JIT disabled)" }
Write-Output 'PASS NativeAOT binary: PE32+ x64, CLR header absent, Godot entry exported, dynamic code/JIT disabled'
