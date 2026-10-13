using Godot;
using System;

public partial class BattleAudioPreferences : Node
{
    private const string Path = "user://battle-audio-mix.cfg";
    public override void _Ready()
    {
        var config = new ConfigFile(); config.Load(Path);
        foreach (string name in new[] { "BattleHit", "BattleSkill" })
        {
            if (AudioServer.GetBusIndex(name) < 0)
            {
                AudioServer.AddBus(); int index = AudioServer.BusCount - 1;
                AudioServer.SetBusName(index, name); AudioServer.SetBusSend(index, "SFX");
            }
            SetVolume(name, config.GetValue(name, "volume", 1.0).AsDouble());
            SetMute(name, config.GetValue(name, "muted", false).AsBool());
        }
    }
    public double Volume(string name) => Mathf.DbToLinear(AudioServer.GetBusVolumeDb(AudioServer.GetBusIndex(name)));
    public bool Muted(string name) => AudioServer.IsBusMute(AudioServer.GetBusIndex(name));
    public void SetVolume(string name, double value) => AudioServer.SetBusVolumeDb(AudioServer.GetBusIndex(name), value <= 0 ? -80 : Mathf.LinearToDb((float)Math.Clamp(value, 0, 1)));
    public void SetMute(string name, bool value) => AudioServer.SetBusMute(AudioServer.GetBusIndex(name), value);
    public void Save()
    {
        var config = new ConfigFile();
        foreach (string name in new[] { "BattleHit", "BattleSkill" }) { config.SetValue(name,"volume",Volume(name)); config.SetValue(name,"muted",Muted(name)); }
        config.Save(Path);
    }
}
