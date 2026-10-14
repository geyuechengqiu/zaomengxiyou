using Godot;
using System;

internal static class MapPresentationChecks
{
    internal static void Verify(Node session, Node2D visual, string spritePath, Action<bool, string> check)
    {
        var sprite = visual.GetNode<Sprite2D>(spritePath);
        var wind = (ShaderMaterial)sprite.Material;
        var ground = visual.GetNode<Node2D>("GroundArtwork");
        var before = ground.Transform;
        double phase = wind.GetShaderParameter("wind_phase").AsDouble();
        visual.Call("advance_visuals", .5);
        double advanced = wind.GetShaderParameter("wind_phase").AsDouble();
        check(advanced > phase && ground.Transform == before, "树冠随战斗时钟摆动，地板和平台位置保持固定");
        session.Call("set_paused", true);
        session.Call("advance_physics", 1.0);
        check(wind.GetShaderParameter("wind_phase").AsDouble() == advanced, "战斗暂停冻结树木摆动");
        session.Call("set_paused", false);
        var copy = GD.Load<PackedScene>(visual.SceneFilePath).Instantiate<Node2D>();
        try { check(copy.GetNode<Sprite2D>(spritePath).Material != wind, "不同关卡实例拥有独立树冠材质，互不污染摆动相位"); }
        finally { copy.Free(); }
        using var geometry = new BattleLootPickupGeometry();
        var player = new Rect2(0, 0, 20, 40);
        check(geometry.touches(player, new Transform2D(0, new Vector2(2, 3), 0, Vector2.Zero), new Vector2(60, 20), new Vector2(20, 10), 2, 0)
            && !geometry.touches(player, Transform2D.Identity, new Vector2(60, 20), new Vector2(20, 10), 2, 0),
            "拾取范围与绘制矩形使用相同地图变换，不受镜头缩放影响");
    }
}
