using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

internal static class NativeCompilationContract
{
#if !TOOLS
    // A packaging probe can validate that this DLL contains native machine code
    // without initializing Godot, scenes, rendering or the platform SDK.
    [UnmanagedCallersOnly(EntryPoint = "zaomengxiyou_native_build_contract")]
    public static int GetFlags()
    {
        int flags = System.Environment.Is64BitProcess ? 1 : 0;
        if (!RuntimeFeature.IsDynamicCodeSupported) flags |= 2;
        if (!RuntimeFeature.IsDynamicCodeCompiled) flags |= 4;
        return flags;
    }
#endif
}
