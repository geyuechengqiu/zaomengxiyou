using Godot;

// Shut down vendor workers while their logger and owning modules still exist.
// Their Thread callbacks retain the RefCounted worker, so PREDELETE alone cannot
// break the cycle at application exit.
public partial class CoreLifetime : Node
{
    public override void _ExitTree()
    {
        var saveManager = GetNodeOrNull("/root/CoreSystem/save_manager");
        if (saveManager == null) return;
        foreach (var entry in saveManager.Get("_strategies").AsGodotDictionary())
        {
            var io = entry.Value.AsGodotObject().Get("_io_manager").AsGodotObject();
            if (IsInstanceValid(io)) io.Call("_shutdown");
        }
    }
}
