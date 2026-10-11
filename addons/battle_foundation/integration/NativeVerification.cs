using Godot;
using System;

internal static class NativeVerification
{
    private static bool _scheduled;
    // The vendor release template deliberately disables CLI scene overrides.
    // Only the separate validation preset enables this one-shot scene router.
    public static void Schedule(Node owner)
    {
        if (_scheduled || !OS.HasFeature("native_validation")) return;
        foreach (string argument in OS.GetCmdlineUserArgs())
        {
            const string prefix = "--verify-suite=";
            if (!argument.StartsWith(prefix, StringComparison.Ordinal)) continue;
            string suite = argument[prefix.Length..];
            if (suite.Length == 0) throw new ArgumentException("Empty verification suite");
            foreach (char letter in suite)
                if (letter != '_' && (letter < 'a' || letter > 'z')) throw new ArgumentException("Invalid verification suite");
            string path = "res://tests/suites/verify_" + suite + ".tscn";
            if (!ResourceLoader.Exists(path)) throw new ArgumentException("Verification scene is missing: " + suite);
            _scheduled = true;
            owner.GetTree().CallDeferred(SceneTree.MethodName.ChangeSceneToFile, path);
            return;
        }
    }
}
