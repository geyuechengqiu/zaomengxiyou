using Godot;
using System;

[GlobalClass]
public partial class BattleClock : RefCounted
{
    // Keep serialized/cross-language names stable while the remaining consumers migrate.
    public double elapsed { get; set; }
    public long physics_tick { get; set; }
    public bool paused { get; set; }
    public double time_scale = 1;
    public double hit_stop_remaining { get; set; }
    public double last_delta { get; set; }

    public bool set_time_scale(double value)
    {
        if (!double.IsFinite(value) || value < 0) return false;
        time_scale = value;
        return true;
    }

    public void request_hit_stop(double seconds)
    {
        if (double.IsFinite(seconds) && seconds > 0)
            hit_stop_remaining = Math.Max(hit_stop_remaining, seconds);
    }

    public double advance(double unscaled_delta, bool tree_paused = false, Callable combat_delta_filter = default)
    {
        last_delta = 0;
        if (!double.IsFinite(unscaled_delta) || unscaled_delta <= 0 || paused || tree_paused) return 0;
        physics_tick++;
        double stopped = Math.Min(hit_stop_remaining, unscaled_delta);
        hit_stop_remaining = Math.Max(0, hit_stop_remaining - stopped);
        last_delta = (unscaled_delta - stopped) * time_scale;
        if (!combat_delta_filter.Equals(default(Callable))) last_delta = combat_delta_filter.Call(last_delta).AsDouble();
        elapsed += last_delta;
        return last_delta;
    }
}
