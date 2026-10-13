using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public partial class VerifyWorldSettingsSpeed : Node
{
    private ZaomengOneWorldMap? _map;
    private BattleLevelScene? _level;
    private readonly List<string> _errors = new(); private int _checks;
    private void Check(bool value,string description) { ++_checks; if (!value) _errors.Add(description); }
    private async Task Frame() => await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
    private async Task Click(Vector2 point)
    {
        GetViewport().PushInput(new InputEventMouseMotion {Position=point,GlobalPosition=point},true);
        GetViewport().PushInput(new InputEventMouseButton {Position=point,GlobalPosition=point,ButtonIndex=MouseButton.Left,Pressed=true},true);
        await Frame();
        GetViewport().PushInput(new InputEventMouseButton {Position=point,GlobalPosition=point,ButtonIndex=MouseButton.Left,Pressed=false},true);
        await Frame();
    }
    private async Task Capture(string name)
    {
        if (!System.Array.Exists(OS.GetCmdlineUserArgs(),arg=>arg=="--ui-capture")) return;
        await Frame(); await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
        using var image=GetViewport().GetTexture().GetImage(); image.SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/world-settings-"+name+".png"));
    }
    public override async void _Ready()
    {
        try { await Run(); } catch(Exception e) { _errors.Add(e.ToString()); }
        finally { if(IsInstanceValid(_map)) _map!.Free(); if(IsInstanceValid(_level)) _level!.Free(); _map=null; _level=null; }
        await Frame(); GC.Collect(); GC.WaitForPendingFinalizers(); await Frame();
        foreach(var error in _errors) GD.PushError(error);
        if(_errors.Count==0) GD.Print($"PASS world settings speed: {_checks} checks; actual pointer modal barriers, latest unlocked shader halo, original settings/audio, player attack/movement clocks and monster 80% cadence");
        GetTree().Quit(_errors.Count==0?0:1);
    }
    private async Task Run()
    {
        var campaign=GetNode<ZaomengOneCampaign>("/root/ZaomengOneCampaign"); campaign.persistence_enabled=false;
        var config=new ConfigFile(); config.SetValue("campaign","version",1);
        config.SetValue("campaign","completed",new Godot.Collections.Array<string>{"1-1","1-2"});
        config.Save(ZaomengOneCampaign.SavePath); campaign.LoadProgress();
        _map=GD.Load<PackedScene>(ZaomengOneCampaign.MapScene).Instantiate<ZaomengOneWorldMap>();AddChild(_map);await Frame();
        Check(_map.GetNodeOrNull("Biyujing")==null && _map.GetNodeOrNull("Progress")==null,"移除辅助地图入口与进度文字");
        Check(_map.GetNodeOrNull("Stages/Stage_1_1/State")==null,"地图不再显示额外关卡状态文字");
        Check(_map.GetNode<Control>("Stages/Stage_1_3/Glow").Visible && !_map.GetNode<Control>("Stages/Stage_1_2/Glow").Visible,"第二关后第三关桃花源发光，与是否已制作分离");
        Check(_map.GetNode<CanvasItem>("Stages/Stage_1_3/Glow").Material is ShaderMaterial,"发光由Godot着色器生成");
        Check(_map.GetNode<TextureButton>("Stages/Stage_1_3").Disabled,"未制作关卡不误进入");
        Check(campaign.MapName=="东胜神洲（七魔王）" && _map.GetNode<Label>("MapName").Text==campaign.MapName,"地图名称显示在世界图标上方");
        var first=_map.GetNode<TextureButton>("Stages/Stage_1_1");
        var point=first.GetGlobalRect().GetCenter();
        GetViewport().PushInput(new InputEventMouseMotion {Position=point,GlobalPosition=point},true);await Frame();
        Check(first.GetDrawMode()==BaseButton.DrawMode.Hover && first.TextureHover.ResourcePath.EndsWith("stage_1-1_1.png") && first.TooltipText=="","真实悬浮恢复原版高亮及描边名称，没有额外黑色提示框");
        await Capture("hover");
        var water=_map.GetNode<TextureButton>("Stages/Stage_1_2");
        point=water.GetGlobalRect().GetCenter();
        GetViewport().PushInput(new InputEventMouseMotion {Position=point,GlobalPosition=point},true);await Frame();await Frame();
        Check(first.TextureHover==first.TextureNormal && water.TextureHover!=water.TextureNormal && !_map.GetNode<Control>("Stages/Stage_1_3/Glow").Visible,"换选关卡后仅当前关卡有描边，旧关卡和最新关卡光效不会残留");
        await Capture("water-hover");
        var latest=_map.GetNode<TextureButton>("Stages/Stage_1_3");point=latest.GetGlobalRect().GetCenter();
        GetViewport().PushInput(new InputEventMouseMotion {Position=point,GlobalPosition=point},true);await Frame();
        Check(latest.Disabled && latest.TextureDisabled==latest.TextureHover,"尚未制作关卡也可悬浮显示名称，点击限制不变");
        var locked=_map.GetNode<TextureButton>("Stages/Stage_4_1");point=locked.GetGlobalRect().GetCenter();
        GetViewport().PushInput(new InputEventMouseMotion {Position=point,GlobalPosition=point},true);await Frame();
        Check(locked.TextureHover==locked.TextureNormal && _map.GetNode<Control>("Stages/Stage_1_3/Glow").Visible,"未解锁地点不能产生残留轮廓，恢复最新可挑战关卡光效");
        var world=_map.GetNode<TextureButton>("Chrome/btn_zc");
        Check(world.TextureNormal.ResourcePath=="res://assets/ui/original/world_map/btn_zc_0.png","世界按钮使用原版世界图标");
        await Click(world.GetGlobalRect().GetCenter());
        Check(first.TextureHover==first.TextureNormal && water.TextureHover==water.TextureNormal,"模态界面打开后清除所有关卡悬浮描边");
        Check(_map.GetNode<Control>("Notice").Visible && _map.GetNodeOrNull("WorldSelector")==null,"世界按钮点击逻辑仍是现有接口，不添加选图逻辑");
        await Click(_map.GetNode<Control>("Notice/OK").GetGlobalRect().GetCenter());
        await Capture("map");
        var hud=_map.GetNode<Control>("HUD");var bag=hud.GetNode<Control>("Inventory");
        var settings=_map.GetNode<OriginalSettingsPanel>("Settings");
        await Click(_map.GetNode<Control>("Chrome/btn_bb").GetGlobalRect().GetCenter());
        Check(bag.Visible,"地图背包入口绑定真实角色库存");
        await Click(_map.GetNode<Control>("Chrome/btn_sz").GetGlobalRect().GetCenter());
        Check(bag.Visible && !settings.Visible,"背包遮罩阻止点击底层地图设置");
        hud.Call("set_inventory_open",false);await Frame();
        await Click(_map.GetNode<Control>("Chrome/btn_sz").GetGlobalRect().GetCenter());
        Check(settings.Visible,"关闭背包后设置可点击");
        await Capture("main");
        settings.Page("Sound");await Frame();
        settings.GetNode<Godot.Range>("Sound/Hit/Volume").Value=35;
        settings.GetNode<Godot.Range>("Sound/Skill/Volume").Value=65;
        settings.GetNode<Godot.Range>("Sound/Music/Volume").Value=45;
        Check(Math.Abs(AudioServer.GetBusVolumeDb(AudioServer.GetBusIndex("BattleHit"))-Mathf.LinearToDb(.35f))<.01,"打击音效单独调节");
        Check(Math.Abs(AudioServer.GetBusVolumeDb(AudioServer.GetBusIndex("BattleSkill"))-Mathf.LinearToDb(.65f))<.01,"技能音效单独调节");
        Check(Math.Abs(AudioServer.GetBusVolumeDb(AudioServer.GetBusIndex("Music"))-Mathf.LinearToDb(.45f))<.01,"音乐单独调节");
        settings.GetNode<BaseButton>("Sound/Skill/Mute").ButtonPressed=true;
        Check(AudioServer.IsBusMute(AudioServer.GetBusIndex("BattleSkill"))&&!AudioServer.IsBusMute(AudioServer.GetBusIndex("BattleHit")),"技能静音不影响打击音效");
        Check(AudioServer.GetBusSend(AudioServer.GetBusIndex("BattleHit"))=="SFX" && AudioServer.GetBusSend(AudioServer.GetBusIndex("BattleSkill"))=="SFX","独立音效通道仍受总音效音量与静音控制");
        await Capture("sound");
        settings.Page("More");await Capture("more");settings.Page("Display");await Capture("display");
        await Click(_map.GetNode<Control>("Chrome/btn_jn").GetGlobalRect().GetCenter());
        Check(!hud.GetNode<Control>("SkillPanel").Visible && settings.Visible,"设置遮罩阻止底层技能入口");
        settings.set_open(false);await Frame();_map.Free();_map=null;await Frame();
        _level=GD.Load<PackedScene>("res://game/levels/huaguoshan.tscn").Instantiate<BattleLevelScene>();_level.enable_player_controls=false;AddChild(_level);await Frame();
        _level.session.SetPhysicsProcess(false);
        Check(_level.GetNodeOrNull("HUD/CampaignResult/Map")==null,"关卡内删除大地图按钮");
        var player=_level.player;var attrs=player.Get("attributes").AsGodotObject();var policy=new BattlePlaybackPolicy();
        Check(attrs.Call("has_attribute",new StringName("attackSpeed")).AsBool() && attrs.Call("has_attribute",new StringName("baseRunSpeed")).AsBool(),"玩家具备独立攻速和基础奔跑属性");
        attrs.Call("set_base_value",new StringName("attackSpeed"),2.0);
        Check(policy.attack_rate(player,"sunwukong_attack1")==2 && policy.attack_rate(player,"sunwukong_skill1")==1,"攻速加成只影响普通攻击");
        Check(policy.attack_rate(player,"zaomeng1_little_monkey_hit1")==.8 && policy.attack_rate(player,"zaomeng1_gorilla_hit1")==.8 && policy.attack_rate(player,"zaomeng1_mountain_monkey_hit1")==.8,"造1三种怪物普攻统一80%");
        Check(policy.attack_rate(player,"zaomeng1_mihou_king_skill1")==1,"猕猴王独立技能时序不重复减速");
        var animation=player.Get("animation").AsGodotObject();animation.Call("play_action",new StringName("run"),true);
        player.Set("move_axis",1.0);
        attrs.Call("set_base_value",new StringName("runSpeed"),300.0);
        Check(Math.Abs(policy.animation_delta(player,.2)-.1)<.00001,"移动动画按当前速度/基础奔跑速度缩放");
        player.Get("motion").AsGodotObject().Set("movement_speed_scale",.5);
        Check(Math.Abs(policy.animation_delta(player,.2)-.05)<.00001,"减速倍率同时作用于行走动画");
        player.Get("motion").AsGodotObject().Set("movement_speed_scale",1.0);
        attrs.Call("set_base_value",new StringName("runSpeed"),600.0);
        for(int i=0;i<120 && !player.Get("motion").AsGodotObject().Get("grounded").AsBool();++i) player.Call("advance_simulation",1.0/60);
        Check(player.Get("motion").AsGodotObject().Get("grounded").AsBool(),"普攻时序验证先真实落地");
        // Advance the actual GAS source-frame clock: doubled speed reaches two source frames per frame.
        player.Set("move_axis",0.0);
        player.Get("motion").AsGodotObject().Set("grounded",true);
        player.Get("action_state").AsGodotObject().Call("enter",0,new Dictionary());
        player.Get("action_state").AsGodotObject().Set("grounded",true);
        player.Call("try_activate_skill",new StringName("sunwukong_attack1"),new Dictionary());
        var cast=player.Get("attack_instance").AsGodotObject();
        Check(IsInstanceValid(cast)&&cast.Get("active").AsBool(),"实际普攻已激活");
        player.Call("advance_simulation",1.0/60);
        Check(Math.Abs(cast.Get("elapsed").AsDouble()-1.0/30)<.00001,"伤害时间轴随攻速同步推进");
        Check(Math.Abs(animation.Call("get_playback_time").AsDouble()-cast.Get("elapsed").AsDouble())<.00001,"普攻动画与命中判定时间一致");
        policy.Dispose();
    }
}
