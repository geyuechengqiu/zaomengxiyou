using Godot;
using System.Collections.Generic;

[GlobalClass]
public partial class BattleFactions : RefCounted
{
    public enum Relation { HOSTILE = -1, NEUTRAL = 0, FRIENDLY = 1 }
    private readonly Dictionary<(StringName, StringName), int> _relations = new();
    public void set_relation(StringName first, StringName second, int relation, bool mutual = true)
    {
        _relations[(first, second)] = relation;
        if (mutual) _relations[(second, first)] = relation;
    }
    public int get_relation(StringName first, StringName second)
    {
        if (_relations.TryGetValue((first, second), out int relation)) return relation;
        if (first == "neutral" || second == "neutral") return 0;
        return first == second ? 1 : 0;
    }
    public bool is_hostile(StringName first, StringName second) => get_relation(first, second) == -1;
}
