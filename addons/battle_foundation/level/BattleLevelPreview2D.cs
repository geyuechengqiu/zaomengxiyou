using Godot;
using Godot.Collections;

/// <summary>Editor-only overlays read the same region, birth plan and marker data as gameplay.</summary>
[Tool]
[GlobalClass]
public partial class BattleLevelPreview2D : Node2D
{
    // Data scripts have editor placeholders; read their exported properties through Resource.
    [Export] public Array<Resource> regions { get; set; } = new();
    [Export] public Array<Resource> plans { get; set; } = new();
    [Export] public NodePath spawn_points_path { get; set; } = "../SpawnPoints";
    [Export] public Font? label_font { get; set; }
    [Export] public bool show_regions { get; set; } = true;
    [Export] public bool show_entry_areas { get; set; } = true;
    [Export] public bool show_birth_points { get; set; } = true;
    private double _refresh;

    public override void _Ready()
    {
        SetProcess(Engine.IsEditorHint());
        if (Engine.IsEditorHint()) QueueRedraw();
    }
    public override void _Process(double delta)
    {
        if (!Engine.IsEditorHint()) return;
        _refresh += delta;
        if (_refresh >= 0.125) { _refresh = 0; QueueRedraw(); }
    }
    private Rect2 MapRect(Rect2 rect) => GlobalTransform.AffineInverse() * GetParent<Node2D>().GlobalTransform * rect;
    private void Label(Vector2 position, string text, Color color, int size = 28)
        => DrawString(label_font ?? ThemeDB.FallbackFont, position, text, HorizontalAlignment.Left, -1, size, color);

    public override void _Draw()
    {
        if (!Engine.IsEditorHint()) return;
        foreach (var region in regions)
        {
            if (region == null) continue;
            if (show_regions)
            {
                var rect = MapRect(region.Get("bounds").AsRect2());
                var color = new Color(0.2f, 0.8f, 1, 0.75f);
                DrawRect(rect, new Color(color, 0.035f));
                DrawRect(rect, color, false, 3);
                Label(rect.Position + new Vector2(18, 110), region.Get("display_name").AsString(), color, 36);
            }
            if (show_entry_areas)
            {
                var rect = MapRect(region.Get("entry_rect").AsRect2());
                var color = new Color(0.35f, 1, 0.4f, 0.85f);
                DrawRect(rect, new Color(color, 0.05f));
                DrawRect(rect, color, false, 2);
                Label(rect.Position + new Vector2(6, 150), "进入触发区", color);
            }
        }
        if (!show_birth_points || GetNodeOrNull<Node>(spawn_points_path) is not Node points) return;
        foreach (var child in points.GetChildren())
        {
            if (child is not Node2D marker) continue;
            var id = marker.Get("spawn_point_id").AsStringName();
            var point = ToLocal(marker.GlobalPosition);
            var color = new Color(1, 0.55f, 0.1f);
            DrawCircle(point, 18, new Color(color, 0.2f));
            DrawArc(point, 18, 0, Mathf.Tau, 24, color, 2);
            DrawLine(point + new Vector2(-28, 0), point + new Vector2(28, 0), color, 2);
            DrawLine(point + new Vector2(0, -28), point + new Vector2(0, 28), color, 2);
            if (marker.Get("random_position").AsBool())
                DrawRect(GlobalTransform.AffineInverse() * marker.GlobalTransform * marker.Get("random_rect").AsRect2(), color, false, 2);
            Label(point + new Vector2(24, -16), id.ToString().Replace("huaguoshan_birth_", "出生点 "), color);
            int line = 0;
            foreach (var plan in plans)
            {
                if (plan == null || plan.Get("spawn_point_id").AsStringName() != id) continue;
                var monsters = plan.Get("monster_ids").AsGodotArray();
                if (monsters.Count == 0) continue;
                double interval = plan.Get("interval_seconds").AsDouble();
                double first = plan.Get("delay_seconds").AsDouble() + interval;
                Label(point + new Vector2(24, 18 + line++ * 32), $"{monsters[0]} ×{monsters.Count}", color);
                Label(point + new Vector2(24, 18 + line++ * 32), $"首只 {first:0.##}秒 / 间隔 {interval:0.##}秒", color);
            }
        }
    }
}
