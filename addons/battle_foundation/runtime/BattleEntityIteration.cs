using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;

/// <summary>Reuse ordered entity snapshots between membership changes.</summary>
[GlobalClass]
public partial class BattleEntityIteration : RefCounted
{
    private readonly record struct Entry(Node Actor, bool AcceptsInput, IBattleCombatStep? CombatStep);
    private Entry[] _entries = System.Array.Empty<Entry>();
    private long _revision = -1;
    private static readonly StringName InputMethod = "advance_input";
    private static readonly StringName SimulationMethod = "advance_simulation";
    public int rebuild_count { get; private set; }

    private Entry[] Snapshot(Dictionary entities, long revision)
    {
        if (_revision == revision) return _entries;
        var entries = new List<Entry>(entities.Count);
        foreach (var pair in entities)
        {
            var actor = pair.Value.As<Node>();
            if (IsInstanceValid(actor)) entries.Add(new(actor, actor.HasMethod(InputMethod), actor.GetNodeOrNull("CombatRules") as IBattleCombatStep));
        }
        _entries = entries.ToArray();
        _revision = revision;
        ++rebuild_count;
        return _entries;
    }

    public void advance_input(Dictionary entities, long revision, double delta)
    {
        // A local snapshot also preserves iteration order during reentrant spawns.
        var entries = Snapshot(entities, revision);
        foreach (var entry in entries)
            if (entry.AcceptsInput && IsInstanceValid(entry.Actor) && !entry.Actor.IsQueuedForDeletion())
                entry.Actor.Call(InputMethod, delta);
    }

    public void advance_simulation(Dictionary entities, long revision, double delta)
    {
        var entries = Snapshot(entities, revision);
        foreach (var entry in entries)
            if (IsInstanceValid(entry.Actor) && !entry.Actor.IsQueuedForDeletion())
                entry.Actor.Call(SimulationMethod, delta);
        // Spatial effects see every actor's current position, regardless of the
        // entity registration order. Components are cached with the snapshot.
        foreach (var entry in entries)
            if (entry.CombatStep is GodotObject component && IsInstanceValid(component) && IsInstanceValid(entry.Actor) && !entry.Actor.IsQueuedForDeletion())
                entry.CombatStep.advance_combat(delta);
    }

    public void clear()
    {
        _entries = System.Array.Empty<Entry>();
        _revision = -1;
    }
}
