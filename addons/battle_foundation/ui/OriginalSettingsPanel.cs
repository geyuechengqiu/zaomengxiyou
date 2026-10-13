using Godot;
using System;
using Range = Godot.Range;

/// <summary>Authored original settings assets. Unimplemented entries retain explicit signals.</summary>
public partial class OriginalSettingsPanel : Control
{
    [Signal] public delegate void menu_changedEventHandler(bool open);
    [Signal] public delegate void FeatureRequestedEventHandler(StringName feature);
    public Node? controller { get; private set; }
    private GodotObject Audio => GetNode("/root/CoreSystem").Get("audio_manager").AsGodotObject();
    private BattleAudioPreferences Mix => GetNode<BattleAudioPreferences>("/root/BattleAudioPreferences");
    private bool _refreshing;
    public override void _Ready()
    {
        GetNode<UiModalManager>("/root/UiModalManager").RegisterBranch(this);
        Hide();
        Button("Main/Close", () => set_open(false)); Button("Main/Resume", () => set_open(false));
        Button("Main/Sound", () => Page("Sound")); Button("Main/More", () => Page("More"));
        Button("Main/Display", () => Page("Display"));
        Button("Main/Help", () => Request("help")); Button("Main/Home", () => Request("main_menu"));
        Button("Main/Retry", () => { set_open(false); GetTree().ReloadCurrentScene(); });
        Button("Main/Map", () =>
        {
            if (controller?.GetParent()?.Get("actor").As<Node>() is Node actor) GetNode<ZaomengOneCampaign>("/root/ZaomengOneCampaign").CaptureCharacter(actor);
            set_open(false); GetNode<ZaomengOneCampaign>("/root/ZaomengOneCampaign").ReturnToMap();
        });
        foreach (string page in new[] { "Sound", "Display", "More" }) Button(page + "/Close", () => Page("Main"));
        Button("Notice/OK", () => GetNode<Control>("Notice").Hide());
        GetNode<BaseButton>("Sound/MasterMute").Toggled += value => { if (!_refreshing) { Audio.Call("set_master_muted", value); Save(); } };
        foreach (var (name, bus, type) in new[] { ("Hit","BattleHit",-1),("Skill","BattleSkill",-1),("Music","Music",0) })
        {
            GetNode<Range>("Sound/"+name+"/Volume").ValueChanged += value =>
            {
                if (_refreshing) return;
                if (type < 0) Mix.SetVolume(bus, value / 100); else Audio.Call("set_volume", type, value / 100);
                GetNode<Label>("Sound/"+name+"/Value").Text = $"{Math.Round(value)}%";
                Save();
            };
            GetNode<BaseButton>("Sound/"+name+"/Mute").Toggled += value =>
            { if (_refreshing) return; if (type < 0) Mix.SetMute(bus,value); else Audio.Call("set_muted",type,value); Save(); };
        }
        foreach (var node in Buttons(GetNode("More/Options")))
            if (node is BaseButton button) button.Pressed += () => Request(button.GetMeta("feature").AsStringName());
        foreach (var node in GetNode<Control>("Display/Options").GetChildren())
            if (node is BaseButton button) button.Pressed += () => Request(button.GetMeta("feature").AsStringName());
    }
    private void Button(string path, Action action) => GetNode<BaseButton>(path).Pressed += action;
    private System.Collections.Generic.IEnumerable<BaseButton> Buttons(Node root)
    {
        foreach (var child in root.GetChildren())
        {
            if (child is BaseButton button) yield return button;
            foreach (var nested in Buttons(child)) yield return nested;
        }
    }
    public void bind_controller(Node value) { controller = value; ConfigureMain(); }
    private void ConfigureMain()
    {
        bool battle = controller != null;
        foreach (string name in new[] { "Retry", "Map" }) GetNode<Control>("Main/"+name).Visible = battle;
        foreach (string name in new[] { "Display", "Home" }) GetNode<Control>("Main/"+name).Visible = !battle;
        string[] order = battle ? new[] { "Resume", "Retry", "Map", "Sound", "More", "Help" } : new[] { "Resume", "Display", "Sound", "More", "Help", "Home" };
        for (int i=0; i<order.Length; ++i) GetNode<Control>("Main/"+order[i]).Position = new(399,185+i*44);
    }
    public void set_open(bool open)
    {
        if (Visible == open) return;
        if (open) { ConfigureMain(); Page("Main"); RefreshSound(); } else Save();
        Visible = open;
        controller?.Call("set_control_blocked", new StringName("original_settings"), open);
        EmitSignal(SignalName.menu_changed, open);
    }
    public void Page(string name)
    {
        foreach (string page in new[] { "Main", "Sound", "Display", "More" }) GetNode<Control>(page).Visible = page == name;
        GetNode<Control>("Notice").Hide(); if (name == "Sound") RefreshSound();
    }
    public void RefreshSound()
    {
        _refreshing = true;
        GetNode<BaseButton>("Sound/MasterMute").SetPressedNoSignal(Audio.Call("is_master_muted").AsBool());
        foreach (var (name, bus, type) in new[] { ("Hit","BattleHit",-1),("Skill","BattleSkill",-1),("Music","Music",0) })
        {
            double volume = type < 0 ? Mix.Volume(bus) : Audio.Call("get_volume",type).AsDouble();
            GetNode<Range>("Sound/"+name+"/Volume").SetValueNoSignal(Math.Round(volume*100));
            GetNode<Label>("Sound/"+name+"/Value").Text = $"{Math.Round(volume*100)}%";
            GetNode<BaseButton>("Sound/"+name+"/Mute").SetPressedNoSignal(type < 0 ? Mix.Muted(bus) : Audio.Call("is_muted",type).AsBool());
        }
        _refreshing = false;
    }
    private void Save() { Audio.Call("save_preferences"); Mix.Save(); }
    private void Request(StringName feature)
    {
        EmitSignal(SignalName.FeatureRequested, feature);
        GetNode<Label>("Notice/Text").Text = "该功能暂未开放"; GetNode<Control>("Notice").Show();
    }
    public override void _Input(InputEvent e)
    {
        if (!IsVisibleInTree() || !UiModalManager.CanReceive(this) || e is not InputEventKey {Pressed:true,Echo:false,Keycode:Key.Escape}) return;
        if (GetNode<Control>("Notice").Visible) GetNode<Control>("Notice").Hide();
        else if (!GetNode<Control>("Main").Visible) Page("Main"); else set_open(false);
        GetViewport().SetInputAsHandled();
    }
    public override void _ExitTree() { if (IsInstanceValid(controller)) controller!.Call("set_control_blocked", new StringName("original_settings"), false); }
}
