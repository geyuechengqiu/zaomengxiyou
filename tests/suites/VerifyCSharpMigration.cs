using Godot;
using Godot.Collections;
using System;

public partial class VerifyCSharpMigration : Node
{
    private int _checks;
    private int _failures;
    private void Check(bool ok, string message)
    {
        _checks++;
        if (!ok) { _failures++; GD.PushError(message); }
    }
    public override void _Ready()
    {
        try
        {
            foreach (string path in new[] { "res://addons/battle_foundation", "res://addons/simple_inventory", "res://game", "res://tests/suites" })
                CheckScriptTree(path);
            using var clock = new BattleClock();
            Check(clock.advance(double.NaN) == 0 && clock.physics_tick == 0, "invalid delta advances neither tick nor time");
            Check(!clock.set_time_scale(double.NaN) && !clock.set_time_scale(-1), "time scale rejects nonfinite/negative input");
            clock.request_hit_stop(0.2); clock.request_hit_stop(0.1);
            Check(clock.hit_stop_remaining == 0.2, "overlapping hit-stop uses longest duration");
            clock.paused = true;
            Check(clock.advance(1) == 0 && clock.hit_stop_remaining == 0.2, "menu pause freezes hit-stop");
            clock.paused = false; clock.set_time_scale(0.5);
            Check(Math.Abs(clock.advance(0.4) - 0.1) < 1e-12 && clock.physics_tick == 1, "hit-stop subtraction precedes time scaling");
            Check(Math.Abs(clock.advance(0.4, false, Callable.From<double, double>(value => value * 0.5)) - 0.1) < 1e-12, "combat filter participates before accumulating elapsed time");
            using var random = new BattleRandom();
            random.initialize(long.MinValue + 1);
            using var baseline = new RandomNumberGenerator { Seed = ((long.MinValue + 1).ToString(System.Globalization.CultureInfo.InvariantCulture) + ":combat").Hash() };
            Check(random.random_float() == baseline.Randf(), "named random stream reproduces original Godot seed/hash");
            var snapshot = random.snapshot();
            double expected = random.random_float();
            random.random_float("loot.items"); random.restore(snapshot);
            Check(random.random_float() == expected && snapshot["seed"].AsInt64() == long.MinValue + 1, "RNG snapshot preserves signed 64-bit seed/state and stream independence");
            using var factions = new BattleFactions();
            factions.set_relation("player", "enemy", -1);
            Check(factions.is_hostile("player", "enemy") && factions.is_hostile("enemy", "player") && factions.get_relation("player", "player") == 1 && factions.get_relation("neutral", "player") == 0, "faction rules preserve original mutual/default relations");
            GD.Print($"{(_failures == 0 ? "PASS" : "FAIL")} C# migration: {_checks} checks; script graph, native clock, RNG replay, faction rules");
            GetTree().Quit(_failures == 0 ? 0 : 1);
        }
        catch (Exception error) { GD.PushError(error.ToString()); GetTree().Quit(1); }
    }
    private void CheckScriptTree(string path)
    {
        using var directory = DirAccess.Open(path);
        if (directory == null) throw new InvalidOperationException(path);
        foreach (string name in directory.GetFiles())
        {
            if (!name.EndsWith(".gd") && !name.EndsWith(".cs")) continue;
            string scriptPath = path + "/" + name;
            // Plain C# helpers are compiled by Roslyn, not instantiated as Godot scripts.
            if (name.EndsWith(".cs") && !FileAccess.GetFileAsString(scriptPath).Contains("partial class")) continue;
            Check(ResourceLoader.Load<Script>(scriptPath)?.CanInstantiate() == true, "script graph: " + scriptPath);
        }
        foreach (string name in directory.GetDirectories())
            if (!name.StartsWith('.')) CheckScriptTree(path + "/" + name);
    }
}
