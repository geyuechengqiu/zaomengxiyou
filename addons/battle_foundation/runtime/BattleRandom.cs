using Godot;
using Godot.Collections;
using System;
using System.Globalization;

[GlobalClass]
public partial class BattleRandom : RefCounted
{
    private long _seed;
    private readonly System.Collections.Generic.Dictionary<StringName, RandomNumberGenerator> _streams = new();

    public void initialize(long value) { _seed = value; _streams.Clear(); }
    public double random_float(StringName? stream = null) => GetStream(stream ?? "combat").Randf();
    public long random_int(int minimum, int maximum, StringName? stream = null)
    {
        if (minimum > maximum) throw new ArgumentOutOfRangeException(nameof(maximum));
        return GetStream(stream ?? "combat").RandiRange(minimum, maximum);
    }
    public bool roll(double probability, StringName? stream = null) => random_float(stream) < Math.Clamp(probability, 0, 1);
    public Dictionary snapshot()
    {
        var states = new Dictionary();
        foreach (var (id, generator) in _streams) states[id] = unchecked((long)generator.State);
        return new Dictionary { ["seed"] = _seed, ["states"] = states };
    }
    public void restore(Dictionary data)
    {
        initialize(data["seed"].AsInt64());
        foreach (var (id, state) in data["states"].AsGodotDictionary())
            GetStream(id.AsStringName()).State = unchecked((ulong)state.AsInt64());
    }
    private RandomNumberGenerator GetStream(StringName id)
    {
        if (_streams.TryGetValue(id, out var generator)) return generator;
        // Godot's String.hash() is deterministic; .NET string.GetHashCode() is not.
        string key = _seed.ToString(CultureInfo.InvariantCulture) + ":" + id;
        generator = new RandomNumberGenerator { Seed = key.Hash() };
        _streams[id] = generator;
        return generator;
    }
}
