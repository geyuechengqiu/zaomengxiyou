using Godot;

/// <summary>Use the same centered texture rectangle as the loot renderer.</summary>
[GlobalClass]
public partial class BattleLootPickupGeometry : RefCounted
{
    public bool touches(Rect2 player, Transform2D transform, Vector2 position,
        Vector2 textureSize, double scale, double radius)
    {
        var size = textureSize * (float)scale;
        var center = transform.AffineInverse() * position;
        var item = transform * new Rect2(center - size * .5f, size);
        var reach = player.Grow((float)(radius * scale));
        return size.X > 0 && size.Y > 0 ? reach.Intersects(item, true) : reach.HasPoint(position);
    }
}
