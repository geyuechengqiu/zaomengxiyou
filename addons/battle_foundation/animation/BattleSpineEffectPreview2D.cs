using Godot;
using System;

/// <summary>Editor-only preview of effects on the saved master animation timeline.</summary>
[Tool, GlobalClass]
public partial class BattleSpineEffectPreview2D : Node2D
{
    [Export] public NodePath animation_player_path { get; set; } = "../AnimationPlayer";
    [Export] public StringName preview_action { get; set; } = "idle";
    [Export] public double preview_time { get; set; }
    private GDScript? _pose;

    public override void _Ready()
    {
        ProcessPriority = 100;
        SetProcess(Engine.IsEditorHint());
        if (Engine.IsEditorHint()) Refresh();
    }

    public override void _Process(double delta) => Refresh();

    private void Refresh()
    {
        if (!Engine.IsEditorHint() || !IsInsideTree()) return;
        var player = GetNodeOrNull<AnimationPlayer>(animation_player_path);
        if (player == null || !player.HasAnimation(preview_action)) return;
        var master = player.GetAnimation(preview_action);
        var root = player.GetNode(player.RootNode);
        // Explicit bridge to the project's existing Spine pose sampler; no
        // assembly loading/reflection and no independent runtime effect clock.
        _pose ??= GD.Load<GDScript>("res://addons/battle_foundation/animation/spine_timeline_pose.gd");
        foreach (var node in GetChildren())
        {
            if (node is not Node2D sprite || !sprite.IsClass("SpineSprite")) continue;
            var nested = sprite.GetNodeOrNull<AnimationPlayer>("SpineAnimationTrack/AnimationPlayer");
            var data = sprite.Get("skeleton_data_res").AsGodotObject();
            if (nested == null || data == null || !data.Call("is_skeleton_data_loaded").AsBool()) continue;
            sprite.Set("update_mode", 2);
            nested.CallbackModeProcess = AnimationMixer.AnimationCallbackModeProcess.Manual;
            sprite.Visible = false;
            for (int track = 0; track < master.GetTrackCount(); ++track)
            {
                var path = master.TrackGetPath(track);
                if (!master.TrackIsEnabled(track) || master.TrackGetType(track) != Animation.TrackType.Value ||
                    path.GetSubNameCount() != 1 || path.GetSubName(0) != "visible" ||
                    root.GetNodeOrNull(path.GetConcatenatedNames()) != sprite) continue;
                for (int key = master.TrackGetKeyCount(track) - 1; key >= 0; --key)
                    if (master.TrackGetKeyTime(track, key) <= preview_time + 0.0000001)
                    { sprite.Visible = master.TrackGetKeyValue(track, key).AsBool(); break; }
            }
            if (!_pose.Call("apply", sprite, nested, master, root, Math.Max(0, preview_time), true).AsBool())
            {
                sprite.Visible = false;
                sprite.Call("get_animation_state").AsGodotObject().Call("clear_track", 0);
            }
        }
    }
}
