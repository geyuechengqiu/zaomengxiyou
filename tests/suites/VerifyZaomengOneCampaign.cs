using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public partial class VerifyZaomengOneCampaign : Node
{
    private Huaguoshan _flower = null!;
    private Shuiliandong _water = null!;
    private ZaomengOneWorldMap _map = null!;
    private int _checks;
    private readonly List<string> _failures = new();
    private void Check(bool value, string message) { ++_checks; if (!value) _failures.Add(message); }
    public override async void _Ready()
    {
        try { await Run(); } catch (Exception error) { _failures.Add(error.ToString()); }
        finally
        {
            if (IsInstanceValid(_map)) _map.Free();
            if (IsInstanceValid(_flower)) _flower.Free();
            if (IsInstanceValid(_water)) _water.Free();
        }
        await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
        foreach (var error in _failures) GD.PushError(error);
        if (_failures.Count == 0) GD.Print($"PASS ZaomengOne campaign: {_checks} checks; original map/10 stages/ZMX5 UI, genuine final-exit unlock once, save/load, character growth and equipped-item identity across levels");
        GetTree().Quit(_failures.Count == 0 ? 0 : 1);
    }
    private async Task Step(Node session, int frames=1)
    {
        for(int i=0;i<frames;++i) { await ToSignal(GetTree(), SceneTree.SignalName.PhysicsFrame); session.Call("advance_physics",1.0/60); }
    }
    private async Task Run()
    {
        // The suite runner provides an isolated APPDATA directory, including
        // NativeAOT; never erase a player's actual campaign save here.
        Check(OS.GetUserDataDir().Contains("zaomeng_one_campaign-user"), "验证必须使用隔离存档目录");
        if (_failures.Count>0) return;
        DirAccess.RemoveAbsolute(ProjectSettings.GlobalizePath(ZaomengOneCampaign.SavePath));
        var campaign = GetNode<ZaomengOneCampaign>("/root/ZaomengOneCampaign");
        campaign.LoadProgress();
        Check(campaign.Levels.Count==10 && campaign.IsUnlocked("1-1"), "原版十个选关点与第一关开放");
        // On repeat runs LoadProgress is explicit; a fresh campaign instance
        // keeps this fixture independent of prior successful suite runs.
        var testCampaign = new ZaomengOneCampaign(); AddChild(testCampaign);
        campaign = testCampaign;
        Check(!campaign.CanEnter("1-2") && !campaign.CanEnter("1-3") && !campaign.Enter("missing"), "锁定/缺少关卡不能进入");
        _map = GD.Load<PackedScene>(ZaomengOneCampaign.MapScene).Instantiate<ZaomengOneWorldMap>(); AddChild(_map);
        Check(_map.GetNode("Stages").GetChildCount()==10, "地图按钮全部预置");
        Check(_map.GetNode<TextureButton>("Chrome/btn_zc").TextureNormal.ResourcePath.Contains("original/world_map"), "造5世界入口");
        Check(_map.GetNodeOrNull("Selection")==null,"直接选关不保留二级面板");
        Check(_map.Theme.DefaultFont.ResourcePath.Contains("original/ui_font"),"保留造5字体和按钮主题");
        Check(!_map.SelectLevel("1-2") && _map.GetNode<TextureButton>("Stages/Stage_1_2").Disabled,"锁定水帘洞不切换场景");
        Check(!_map.GetNode<TextureButton>("Stages/Stage_1_1").Disabled,"花果山可直接挑战");
        Check(_map.GetNode<Control>("Stages/Stage_1_1/Glow").Visible && _map.GetNode<TextureButton>("Stages/Stage_1_1").TextureNormal.ResourcePath.EndsWith("stage_1-1_0.png"),"最新解锁关卡使用Godot发光、普通图标");
        Check(_map.GetNode<TextureButton>("Stages/Stage_1_2").TextureNormal.ResourcePath.EndsWith("stage_1-2_0.png"),"未开放关卡不发光");
        if(System.Array.Exists(OS.GetCmdlineUserArgs(),a=>a=="--capture-world-map"))
        {
            await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
            GetViewport().GetTexture().GetImage().SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/zaomeng1-world-map-preview.png"));
        }
        _map.Free(); _map = null!;
        _flower=GD.Load<PackedScene>("res://game/levels/huaguoshan.tscn").Instantiate<Huaguoshan>(); _flower.enable_player_controls=false;AddChild(_flower);
        var flow=_flower.flow;var session=_flower.session;var player=_flower.player;session.SetPhysicsProcess(false);
        Check(!campaign.RecordVictory("1-1",flow,session.Get("battle_id").AsStringName()) && !campaign.IsUnlocked("1-2"),"进行中、延迟怪物等待时不能记录胜利");
        foreach(var rv in flow.Get("regions").AsGodotArray())
        {
            var region=rv.AsGodotObject();var entry=region.Get("definition").AsGodotObject().Get("entry_rect").AsRect2();
            player.Position=new(entry.GetCenter().X,950);player.Velocity=Vector2.Zero;
            await Step(session);
            int ticks=0;
            while(!region.Get("completed").AsBool() && ticks++<2200)
            {
                foreach(var value in session.Call("get_entities").AsGodotArray())
                {
                    var actor=value.As<Node>();if(actor==player||!actor.Call("is_alive").AsBool())continue;
                    actor.Call("_finish_spawn_appearance");actor.Get("ai_controller").AsGodotObject().Set("enabled",false);
                    session.Call("apply_secondary_damage",actor,player,10000000.0,new StringName("verification"),new Dictionary());
                }
                await Step(session);
            }
            Check(region.Get("completed").AsBool(),"全部区域计划完成");
            if(flow.Get("current_region_index").AsInt32()<4)
            {
                player.Position=new(region.Get("definition").AsGodotObject().Get("exit_rect").AsRect2().GetCenter().X,950);
                Check(flow.Call("request_exit",player,false).AsBool(),"区域出口过渡");
            }
        }
        await Step(session,420);
        Check(!campaign.RecordVictory("1-1",flow,session.Get("battle_id").AsStringName()),"Boss已死但尚未确认最终出口不解锁");
        player.Position=_flower.GetNode<BattleFinalExit2D>("BattleSession/Actors/FinalExit").get_exit_rect().GetCenter();
        Check(flow.Call("request_exit",player,false).AsBool(),"真实最终出口结算");
        Check(campaign.RecordVictory("1-1",flow,session.Get("battle_id").AsStringName()) && campaign.CanEnter("1-2"),"花果山胜利解锁水帘洞");
        Check(!campaign.RecordVictory("1-1",flow,session.Get("battle_id").AsStringName()),"重复胜利回调不再次结算");
        var attrs=player.Get("attributes").AsGodotObject();attrs.Call("set_level",4);attrs.Call("set_experience",55.0);
        var inventory=player.Get("inventory").As<Node>();inventory.Call("set_display_name","悟空测试昵称");inventory.Set("spirit",12345);
        var item=inventory.Get("items").AsGodotArray()[0].AsGodotObject();
        item.Get("runtime").AsGodotObject().Set("enhancement_level",3);
        string uuid=item.Get("runtime").AsGodotObject().Get("unique_id").AsString();
        inventory.Call("equip_item",item);campaign.CaptureCharacter(player);
        double beforeAtk=attrs.Call("get_value",new StringName("atk")).AsDouble();
        double beforeHp=attrs.Call("get_value",new StringName("hpMax")).AsDouble();
        var fresh=new ZaomengOneCampaign();AddChild(fresh);
        Check(fresh.CanEnter("1-2") && fresh.IsCompleted("1-1"),"磁盘保存并恢复通关解锁");
        _water=GD.Load<PackedScene>("res://game/levels/shuiliandong.tscn").Instantiate<Shuiliandong>();_water.enable_player_controls=false;AddChild(_water);_water.session.SetPhysicsProcess(false);
        fresh.RestoreCharacter(_water.player,_water.session);
        var restored=_water.player.Get("inventory").As<Node>();var restoredAttrs=_water.player.Get("attributes").AsGodotObject();
        Check(restoredAttrs.Get("current_level").AsInt32()==4 && restoredAttrs.Call("get_value",new StringName("exp")).AsDouble()==55,"等级经验跨关卡保留");
        Check(restored.Get("spirit").AsInt32()==12345 && restored.Get("display_name").AsString()=="悟空测试昵称","灵魂与昵称保留");
        var armor=restored.Get("equip_slots").AsGodotDictionary()["armor"].AsGodotArray()[1].AsGodotObject();
        Check(IsInstanceValid(armor) && armor.Get("runtime").AsGodotObject().Get("unique_id").AsString()==uuid && armor.Get("runtime").AsGodotObject().Get("enhancement_level").AsInt32()==3,"装备唯一ID、强化和穿戴槽保留");
        Check(restoredAttrs.Call("get_value",new StringName("atk")).AsDouble()==beforeAtk,"恢复后实际属性重算一致");
        Check(restoredAttrs.Call("get_value",new StringName("hpMax")).AsDouble()==beforeHp,"跨关保留护甲强化生命属性");
        _water.flow.Call("stop");Check(!fresh.RecordVictory("1-2",_water.flow,_water.session.Get("battle_id").AsStringName()) && !fresh.IsUnlocked("1-3"),"失败/中止关卡不解锁");
        Check(!fresh.CanEnter("1-3"),"尚未制作关卡无法误进入其他地图");
        testCampaign.Free();fresh.Free();
    }
}
