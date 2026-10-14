using Godot;
using Godot.Collections;
using Array = Godot.Collections.Array;

/// <summary>Common campaign bridge; direct test instances stay isolated.</summary>
public partial class ZaomengOneLevelScene : BattleLevelScene
{
    protected virtual string CampaignId => "";
    private Node? _bus;
    private Callable _callback;
    private bool _campaignPlay, _finished, _saveQueued;
    private ZaomengOneCampaign Campaign => GetNode<ZaomengOneCampaign>("/root/ZaomengOneCampaign");
    public override void _Ready()
    {
        base._Ready(); _campaignPlay = GetParent() == GetTree().Root;
        if (_campaignPlay) Campaign.RestoreCharacter(player, session);
        if (_campaignPlay) player.GetNode<BattleSkillLoadout>("SkillLoadout").Changed += () => Campaign.CaptureCharacter(player);
        if (_campaignPlay)
        {
            var inventory=player.Get("inventory").AsGodotObject();
            inventory.Connect("item_changed",Callable.From(QueueCharacterSave));
            inventory.Connect("currency_changed",Callable.From<long>(_ => QueueCharacterSave()));
            inventory.Connect("display_name_changed",Callable.From<string>(_ => QueueCharacterSave()));
        }
        _bus = GetNode("/root/CoreSystem").Get("event_bus").As<Node>();
        _callback = Callable.From<string, Array>(OnCampaignEvent); _bus.Connect("event_pushed", _callback);
        var view = GetNodeOrNull<Control>("HUD/CampaignResult");
        if (view != null)
        {
            view.GetNode<Button>("Overlay/Panel/Return").Pressed += ReturnToMap;
            view.GetNode<Button>("Overlay/Panel/Retry").Pressed += RestartLevel;
        }
    }
    private void QueueCharacterSave()
    {
        if (_saveQueued) return;
        _saveQueued=true;
        Callable.From(() =>
        {
            _saveQueued=false;
            if (IsInsideTree() && IsInstanceValid(player)) Campaign.CaptureCharacter(player);
        }).CallDeferred();
    }
    private void OnCampaignEvent(string id, Array args)
    {
        if (args.Count != 1 || args[0].VariantType != Variant.Type.Dictionary) return;
        var data = args[0].AsGodotDictionary();
        if (data.GetValueOrDefault("battle_id").AsStringName() != session.Get("battle_id").AsStringName()) return;
        if (id == "battle.boss.registered")
        {
            var audio = session.Get("audio").AsGodotObject();
            string music = audio.Get("catalog").As<Json>().Data.AsGodotDictionary().GetValueOrDefault("boss_music").AsString();
            audio.Call("play_music", music);
        }
        if (!_campaignPlay || _finished || id is not ("battle.level.victory" or "battle.level.failed")) return;
        _finished = true; bool won = id == "battle.level.victory";
        if (won) Campaign.RecordVictory(CampaignId, flow, session.Get("battle_id").AsStringName());
        Campaign.CaptureCharacter(player);
        var view = GetNode<Control>("HUD/CampaignResult/Overlay"); view.Visible = true;
        view.GetNode<Label>("Panel/Title").Text = won ? "关卡通关" : "挑战失败";
        view.GetNode<Label>("Panel/Details").Text = won ? $"{level_id}通关！\n已保存成长、装备与选关进度。" : "返回大地图或重新挑战。";
    }
    protected override void RestartLevel()
    {
        if (_campaignPlay)
        {
            Campaign.CaptureCharacter(player);
            Campaign.Enter(CampaignId);
            return;
        }
        base.RestartLevel();
    }
    private void ReturnToMap()
    {
        if (!_campaignPlay) return;
        Campaign.CaptureCharacter(player); Campaign.ReturnToMap();
    }
    public override void _Notification(int what)
    {
        if (what == NotificationWMCloseRequest && _campaignPlay && IsInstanceValid(player)) Campaign.CaptureCharacter(player);
    }
    public override void _ExitTree()
    {
        if (IsInstanceValid(_bus) && _bus!.IsConnected("event_pushed", _callback)) _bus.Disconnect("event_pushed", _callback);
        base._ExitTree();
    }
}
