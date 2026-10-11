using Godot;

/// <summary>Optional authored spawn admission. A full arena pauses births instead of discarding them.</summary>
public partial class BattleSpawnBudget : Node
{
    [Export(PropertyHint.Range, "1,64")] public int maximum_live_monsters { get; set; } = 6;

    public bool allow_spawn()
    {
        var session = GetParent().GetParent();
        int living = 0;
        foreach (var value in session.Call("get_entities").AsGodotArray())
        {
            var actor = value.AsGodotObject();
            if (actor.Get("faction_id").AsStringName() == "enemy" && actor.Call("is_alive").AsBool())
                if (++living >= maximum_live_monsters) return false;
        }
        return true;
    }

    public double get_due_time(BattleSpawnPlanInstance plan, double elapsed) => System.Math.Max(plan.next_due, elapsed);
}
