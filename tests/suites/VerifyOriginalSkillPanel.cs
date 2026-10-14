using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public partial class VerifyOriginalSkillPanel : Node
{
    private BattleLevelScene _scene = null!;
    private BattleSkillLoadout _skills = null!;
    private OriginalSkillPanel _panel = null!;
    private readonly List<string> _errors = new();
    private int _checks;
    private void Check(bool ok, string message) { ++_checks; if (!ok) _errors.Add(message); }
    private async Task Frame() => await ToSignal(GetTree(), SceneTree.SignalName.ProcessFrame);
    private void Move(Vector2 point) => GetViewport().PushInput(new InputEventMouseMotion {Position=point,GlobalPosition=point},true);
    private void Mouse(Vector2 point,bool pressed,MouseButton button=MouseButton.Left)
        => GetViewport().PushInput(new InputEventMouseButton {Position=point,GlobalPosition=point,ButtonIndex=button,Pressed=pressed},true);
    private static Vector2 Center(Control cell) => cell.GetGlobalTransformWithCanvas()*(cell.Size*.5f);
    private async Task Capture(string name)
    {
        if (!System.Array.Exists(OS.GetCmdlineUserArgs(), x => x == "--skill-panel-capture")) return;
        await Frame(); await ToSignal(RenderingServer.Singleton, RenderingServer.SignalName.FramePostDraw);
        using var image = GetViewport().GetTexture().GetImage();
        image.SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/skill-panel-"+name+".png"));
    }
    public override async void _Ready()
    {
        try { await Run(); } catch (Exception e) { _errors.Add(e.ToString()); }
        finally { if (IsInstanceValid(_scene)) _scene.Free(); }
        await Frame();
        _scene = null!; _skills = null!; _panel = null!;
        GC.Collect(); GC.WaitForPendingFinalizers(); await Frame();
        foreach (string error in _errors) GD.PushError(error);
        if (_errors.Count==0) GD.Print($"PASS original skill panel: {_checks} checks; original art, grade-0 learning, atomic upgrades, live damage/MP/CD, loadout/input/HUD, passive critical, persistence and modal ownership");
        GetTree().Quit(_errors.Count==0?0:1);
    }
    private async Task Run()
    {
        _scene=GD.Load<PackedScene>("res://game/levels/biyujing.tscn").Instantiate<BattleLevelScene>();
        _scene.enable_player_controls=false; AddChild(_scene); _scene.session.SetPhysicsProcess(false); _scene.flow.Call("stop");
        await Frame(); _skills=_scene.player.GetNode<BattleSkillLoadout>("SkillLoadout"); _panel=_scene.original_hud.GetNode<OriginalSkillPanel>("SkillPanel");
        _panel.Bind(_skills); // Rebinding must not duplicate button or signal handlers.
        GetNode("/root/CoreSystem").Get("operation_manager").AsGodotObject().Get("bindings").AsGodotObject().Call("reset_profile",_skills.Operations.Get("operation_profile"),false);
        var attrs=_scene.player.Get("attributes").AsGodotObject(); var bag=_skills.Inventory;
        Check(_skills.Active.Count==5 && _skills.Active[4]==0,"初始第五槽为空");
        Check(_skills.Level(1101080)==0 && !_skills.Available(1101080),"火魔斩保持未学习且当前阶段不能解锁");
        Check(!_skills.Abilities.Call("has_ability", new StringName("sunwukong_skill8")).AsBool(),"战斗GAS没有学习火魔斩");
        Check(!_skills.Operations.Get("ability_slots").AsGodotDictionary()[new StringName("skill_5")].AsStringName().ToString().Contains("skill8"),"L键不再触发火魔斩");
        Check(_skills.Passive==1301010 && _scene.player.Get("damage_rules").As<BattleDamageRules>().get_number("passive_id")==1301010,"重击实际装配到伤害规则");
        Check(_skills.Level(1101010)==1 && _skills.Level(1101040)==1,"原角色初始四技能一级");
        var initial=_skills.SaveData();
        bag.Set("spirit",10000); long spirit=bag.Get("spirit").AsInt64();
        Check(!_skills.Upgrade(1101080) && bag.Get("spirit").AsInt64()==spirit,"火魔斩升级拒绝且不消耗灵魂");
        Check(!_skills.Equip("active",4,1101080),"未学习火魔斩不能装配");
        Check(_skills.Next(1101010)!["role_level"].AsInt32()==6 && _skills.Next(1101010)!["spirit"].AsInt32()==75,"原升龙斩二级需要人物六级、75灵魂");
        Check(!_skills.Upgrade(1101010) && _skills.Level(1101010)==1 && bag.Get("spirit").AsInt64()==spirit,"人物等级不足无部分事务");
        attrs.Call("set_level",6); bag.Set("spirit",74);
        Check(!_skills.Upgrade(1101010) && bag.Get("spirit").AsInt64()==74,"灵魂不足无升级或扣款");
        bag.Set("spirit",75);
        Check(_skills.Upgrade(1101010) && _skills.Level(1101010)==2 && bag.Get("spirit").AsInt64()==0,"满足条件原子升级扣75灵魂");
        Check(_scene.player.Get("damage_rules").As<BattleDamageRules>().skill_levels[new StringName("sunwukong_skill1")].AsInt32()==2,"实际技能等级更新");
        var ability=_skills.Ability(1101010)!;
        var cost=ability.Call("get_feature","VitalCostFeature").AsGodotObject();
        var cooldown=ability.Call("get_feature","CooldownFeature").AsGodotObject();
        // Activate the real skill to check the cost and cooldown, not just the exported table.
        attrs.Call("set_base_value",new StringName("mpMax"),10000.0);
        var mana=attrs.Call("get_vital",new StringName("mana")).AsGodotObject(); mana.Call("set_current_value",10000.0);
        _scene.player.Get("action_state").AsGodotObject().Call("enter",0,new Dictionary());
        Check(_scene.player.Call("try_activate_skill",new StringName("sunwukong_skill1"),new Dictionary()).AsBool(),"升级后真实技能可释放");
        ability.Call("update", .001); // Resources commit on the first simulation update.
        Check(Math.Abs(mana.Get("current_value").AsDouble()-9956)<.01,"二级升龙斩实际耗魔44");
        Check(Math.Abs(cooldown.Call("get_cooldown_remaining",ability).AsDouble()-2.3)<.01,"二级升龙斩真实冷却2.3秒");
        Check(!_skills.Equip("active",4,1101010) && _skills.Active[0]==1101010,"冷却或释放中不能移动技能");
        Check(!_skills.MoveSlot("active",0,1) && !_skills.MoveSlot("active",1,0) && _skills.Active[0]==1101010 && _skills.Active[1]==1101020,"交换任一侧处于释放或冷却时均失败，不部分覆盖装配");
        Check(!_skills.Unequip("active",0),"冷却或释放中不能卸下");
        _scene.player.Call("cancel_skill"); ability.Call("update",5.0);
        _scene.player.Get("action_state").AsGodotObject().Call("enter",0,new Dictionary());
        Check(_skills.Equip("active",4,1101010) && _skills.Active[0]==0 && _skills.Active[4]==1101010,"已学技能移动清空原槽，不能重复装配");
        Check(_scene.original_hud.GetNode<TextureRect>("Skills/Slots/Slot4/Icon").Texture!=null && _scene.original_hud.GetNode<TextureRect>("Skills/Slots/Slot0/Icon").Texture==null,"HUD空槽与新槽图标同步");
        Check(_skills.Operations.Get("ability_slots").AsGodotDictionary()[new StringName("skill_5")].AsStringName()==new StringName("sunwukong_skill1"),"L语义槽实际改为升龙斩");
        Check(!_skills.Equip("passive",0,1101020) && _skills.Passive==1301010,"拖到错误类型保持原配置");
        Check(_skills.Unequip("active",4) && _skills.Active[4]==0,"卸下主动技能清空输入槽");
        var save=_skills.SaveData(); save["passive"]=0; _skills.Restore(save);
        Check(_scene.player.Get("damage_rules").As<BattleDamageRules>().get_number("passive_id")==0,"取消被动不会残留伤害规则");
        var target=_scene.session.Call("spawn_entity_2d","monsters",new StringName("剑舞"),new Vector2(1800,1056),new StringName(""),false).As<Node>();
        target.Get("ai_controller").As<Node>().Set("enabled",false);
        var strategy=_scene.session.Get("damage_strategy").AsGodotObject();
        var ctx=new Dictionary { ["ability_id"]=new StringName("sunwukong_attack5"),["test_damage_random_1"]=true,["random_values"]=new Dictionary { [new StringName("calDamage")]=.5,[new StringName("baojiRatio")]=.9,[new StringName("calPhysicalDamage")]=.5 } };
        var normal=strategy.Call("calculate_result",target,_scene.player,ctx).AsGodotObject();
        Check(!normal.Get("is_crit").AsBool(),"未装重击时普攻末击不保证暴击");
        Check(_skills.Equip("passive",0,1301010),"重新装配重击");
        var critical=strategy.Call("calculate_result",target,_scene.player,ctx).AsGodotObject();
        Check(critical.Get("is_crit").AsBool() && critical.Get("calculated_damage").AsDouble()>normal.Get("calculated_damage").AsDouble(),"重击使真实普攻末击必定暴击并提高伤害");
        ctx["ability_id"]=new StringName("sunwukong_attack1");
        Check(!strategy.Call("calculate_result",target,_scene.player,ctx).AsGodotObject().Get("is_crit").AsBool(),"重击不错误放大普攻第一击");
        var damageCtx=new Dictionary { ["ability_id"]=new StringName("sunwukong_skill1"),["random_values"]=ctx["random_values"],["test_damage_random_1"]=true };
        double upgraded=strategy.Call("calculate_result",target,_scene.player,damageCtx).AsGodotObject().Get("calculated_damage").AsDouble();
        var down=_skills.SaveData(); down["levels"].AsGodotDictionary()["1101010"]=1; _skills.Restore(down);
        Check(upgraded>strategy.Call("calculate_result",target,_scene.player,damageCtx).AsGodotObject().Get("calculated_damage").AsDouble(),"技能升级真实伤害同步提升");
        _skills.Restore(initial); attrs.Call("set_level",1); bag.Set("spirit",0);
        var unlearned = _skills.SaveData(); unlearned["levels"].AsGodotDictionary()["1101020"] = 0;
        unlearned["active"] = new Godot.Collections.Array {1101010,0,1101030,1101040,0}; _skills.Restore(unlearned);
        Check(!_skills.Abilities.Call("has_ability",new StringName("sunwukong_skill2")).AsBool(),"未学习技能从GAS移除");
        attrs.Call("set_level",2); bag.Set("spirit",45);
        Check(_skills.Upgrade(1101020) && _skills.Active[1]==1101020 && _skills.Abilities.Call("has_ability",new StringName("sunwukong_skill2")).AsBool(),"学习成功自动装入首个空槽并创建真实技能");
        Check(bag.Get("spirit").AsInt64()==0,"学习消耗原45灵魂");
        _skills.Restore(initial); attrs.Call("set_level",1);
        _scene.original_hud.Call("open_module",new StringName("skill"));
        Check(_panel.Visible && _scene.session.Get("clock").AsGodotObject().Get("paused").AsBool(),"技能面板接管输入并暂停战斗");
        Check(_panel.GetNode<TextureRect>("Main/Background").Texture.GetSize()==new Vector2(940,590),"原版940x590技能界面素材");
        Check(!_panel.GetNode<Control>("Main/Rows/S1101080").Visible && !_panel.GetNode<Control>("Main/Rows/S1101070").Visible,"未转职悟空完全隐藏转职技能");
        var skillName=_panel.GetNode<Label>("Main/Rows/S1101030/Name");
        Check(skillName.GetThemeFont("font").ResourcePath.EndsWith("ui_font.ttf") && _panel.GetNode<Label>("Main/Rows/S1101030/Level").Position.X<275,"原方正粗圆字体及名称紧邻等级");
        Check(_panel.GetNode<TextureRect>("Main/Rows/S1101030/Element").Texture.ResourcePath.EndsWith("fire_element.png"),"火系技能展示原元素图标");
        Check(!_panel.GetNode<Control>("Main/SecretTab").Visible && !_panel.GetNode<CanvasItem>("Main/Rows/S1101030/LearnGlow").Visible,"原两标签及已学习技能不显示学习光效");
        await Capture("active");
        _panel.SelectTab(1); Check(_panel.GetNode<Control>("Main/Rows/S1301010").Visible && !_panel.GetNode<Control>("Main/Rows/S1101010").Visible,"特殊技能页显示重击与悟空无双");
        await Capture("passive"); _panel.SelectTab(0); _panel.OpenUpgrade(1101010);
        Check(_panel.GetNode<Label>("Upgrade/Cost").Text.Contains("75") && _panel.GetNode<Label>("Upgrade/Requirements").Text.Contains("6"),"升级弹窗读取真实下一等级要求");
        await Capture("upgrade");
        attrs.Call("set_level",50); bag.Set("spirit",10000);
        _panel.GetNode<BaseButton>("Upgrade/Batch").EmitSignal("pressed");
        Check(_panel.BatchUpgrading && _skills.Level(1101010)==2,"连续升级先完成第一笔");
        _panel._Process(.51); Check(_skills.Level(1101010)==3,"连续升级每0.5秒完成下一笔");
        _panel.CloseUpgrade(); _panel._Process(1); Check(!_panel.BatchUpgrading && _skills.Level(1101010)==3,"关闭弹窗停止连续升级");
        _panel.OpenKeyboard(); Check(_panel.GetNode<Control>("Keyboard").Visible && !_panel.GetNode<Control>("Main").Visible,"原按键装配模板切换");
        Check(_panel.GetNode<Label>("Keyboard/active4/Key").Text=="L","空第五槽仍显示真实L键");
        Check(_panel.GetNodeOrNull("Keyboard/Stock1101010/Level")==null && _panel.GetNodeOrNull("Keyboard/Stock1301010/Level")==null && _panel.GetNodeOrNull("Keyboard/Stock1201010/Level")==null,"原版技能图标无额外等级数字，主动/被动/无双一致");
        Check(!_panel.GetNode<Control>("Keyboard/Pages").Visible && _panel.GetNode<TextureRect>("Keyboard/Item0/Background").Texture.ResourcePath.EndsWith("slot_0.png"),"单页没有多余数字与翻页按钮，空道具格使用原版背包边框");
        Check(_panel.GetNode<TextureButton>("Keyboard/itemsTab").TextureNormal.ResourcePath.EndsWith("items_tab_2.png") && _panel.GetNode<Label>("Keyboard/Tip").Position.Y==533,"选中关卡道具标签高亮，说明位于原版底部位置");
        await Capture("keyboard");
        _skills.Equip("active",4,1101010);
        var cell=_panel.GetNode<Control>("Keyboard/active4");
        cell.EmitSignal("gui_input",new InputEventMouseButton {Pressed=true,DoubleClick=true,ButtonIndex=MouseButton.Left});
        Check(_skills.Active[4]==0,"界面双击卸下已装主动技能");
        var beforeDragging=_skills.SaveData();
        await Frame(); await Frame();
        var stock=_panel.GetNode<Control>("Keyboard/Stock1101040");
        var destination=_panel.GetNode<Control>("Keyboard/active4");
        Move(Center(_panel.GetNode<Control>("Keyboard/Stock1301010")));await Frame();
        Check(_panel.GetNode<Label>("Tooltip/Name").Text=="重击" && !_panel.GetNode<Label>("Tooltip/Stats").Visible && _panel.GetNode<Control>("Tooltip").Size.Y<110,"被动技能提示只显示原版名称和描述，无等级/魔法/冷却数字，框体自适应高度");
        await Capture("keyboard-passive-tooltip");
        Move(Center(stock)); await Frame();
        var tooltip=_panel.GetNode<Control>("Tooltip"); var preview=_panel.GetNode<Control>("DragIcon");
        Check(tooltip.Visible && !tooltip.ZAsRelative && tooltip.ZIndex>_panel.GetNode<Control>("Keyboard").ZIndex,"真实鼠标悬浮框绘制在按键设置界面之前");
        Check(_panel.GetNode<Label>("Tooltip/Name").Text=="烈焰风暴" && _panel.GetNode<Label>("Tooltip/Stats").Text.Contains("技能等级: Lv.1") && tooltip.Size.Y>150,"主动技能按原版保留必要等级/冷却/魔法，名称独立显示");
        var tooltipPoint=_panel.GetGlobalTransformWithCanvas().AffineInverse()*Center(stock)+new Vector2(15,15);
        Check(tooltip.Position.DistanceTo(tooltipPoint.Clamp(Vector2.Zero,(_panel.Size-tooltip.Size).Max(Vector2.Zero)))<1,"悬浮框使用本次鼠标位置并限制在视口内，不滞留在上次悬浮位置");
        await Capture("keyboard-tooltip");
        Mouse(Center(stock),true);Move(Center(destination));
        Check(preview.Visible && !tooltip.Visible && preview.ZIndex>_panel.GetNode<Control>("Keyboard").ZIndex,"拖动图标显示在窗口前方且隐藏悬浮框");
        await Capture("keyboard-drag");
        Mouse(Center(destination),false); await Frame();
        Check(_skills.Active[3]==0 && _skills.Active[4]==1101040 && !preview.Visible,"真实拖动库存技能到空槽，清理原槽和拖动预览");
        var occupied=_panel.GetNode<Control>("Keyboard/active1");
        Mouse(Center(destination),true);Move(Center(occupied));Mouse(Center(occupied),false);
        Check(_skills.Active[1]==1101040 && _skills.Active[4]==1101020,"同一帧快速拖放已装技能至已占用槽，原子交换两个技能");
        var storm=_skills.Ability(1101040)!;
        Check(_skills.Operations.Get("ability_slots").AsGodotDictionary()[new StringName("skill_2")].AsStringName()==new StringName("sunwukong_skill4")
            && storm.Call("get_feature","BattleFrameTimelineFeature").AsGodotObject().Get("branch_windows").AsGodotArray()[0].As<BattleSkillBranch>().operation=="skill_2"
            && _scene.original_hud.GetNode<TextureRect>("Skills/Slots/Slot1/Icon").Texture==storm.Call("get_definition").AsGodotObject().Get("icon").As<Texture2D>(),"拖动换槽同步真实操作槽、二段技能分支和HUD图标");
        var wrong=_panel.GetNode<Control>("Keyboard/item0");
        Mouse(Center(occupied),true);Move(Center(wrong));Mouse(Center(wrong),false);
        Check(_skills.Active[1]==1101040 && _skills.Items[0]=="" && _panel.GetNode<Control>("Notice").Visible && !preview.Visible,"跨类型拖放拒绝装配，来源技能不丢失");
        _panel.CloseTop(); await Frame();
        var outside=_panel.GetGlobalTransformWithCanvas()*new Vector2(930,570);
        Mouse(Center(occupied),true);Move(outside);Mouse(outside,false);
        Check(_skills.Active[1]==1101040 && _panel.SelectedSkill==0 && !preview.Visible,"拖出格子释放取消，不卸下来源技能");
        Mouse(Center(stock),true);Move(Center(destination));Mouse(Center(destination),true,MouseButton.Right);Mouse(Center(destination),false);
        Check(_skills.Active[1]==1101040 && _skills.Active[4]==1101020 && !preview.Visible,"右键取消拖放，后续左键松开不能误装配");
        Mouse(Center(stock),true);Move(Center(destination));
        GetViewport().PushInput(new InputEventKey {Keycode=Key.Escape,PhysicalKeycode=Key.Escape,Pressed=true},true);
        Mouse(Center(destination),false);
        Check(_panel.GetNode<Control>("Keyboard").Visible && _panel.SelectedSkill==0 && !preview.Visible,"Esc先取消拖动，保留按键窗口");
        Mouse(Center(stock),true);Move(Center(destination));
        _panel.GetWindow().EmitSignal(Window.SignalName.FocusExited);
        Mouse(Center(destination),false);
        Check(_skills.Active[4]==1101020 && _panel.SelectedSkill==0 && !preview.Visible,"窗口失去焦点后取消拖放，无残留图标或误装配");
        var eyeStock=_panel.GetNode<Control>("Keyboard/Stock1101030");
        var empty=_panel.GetNode<Control>("Keyboard/active3");
        Move(Center(eyeStock)); Mouse(Center(eyeStock),true); Mouse(Center(eyeStock),false);
        Mouse(Center(empty),true); Mouse(Center(empty),false);
        Check(_skills.Active[2]==0 && _skills.Active[3]==1101030 && _panel.SelectedSkill==0,"保留单击选择再点击目标槽装配的操作方式");
        var panelScale=_panel.Scale;var panelPosition=_panel.Position;
        _panel.Scale=new Vector2(.9f,.9f);_panel.Position=new Vector2(20,12);
        Mouse(Center(destination),true);Move(Center(empty));Mouse(Center(empty),false);
        Check(_skills.Active[3]==1101020 && _skills.Active[4]==1101030,"界面缩放和偏移后拖放仍按目标格子的真实坐标交换");
        _panel.Scale=panelScale;_panel.Position=panelPosition;
        _skills.Restore(beforeDragging);
        await Frame();
        var campaign=GetNode<ZaomengOneCampaign>("/root/ZaomengOneCampaign"); campaign.persistence_enabled=false;
        campaign.CaptureCharacter(_scene.player);
        _skills.Restore(initial); campaign.RestoreCharacter(_scene.player,_scene.session);
        Check(_skills.Level(1101010)==3 && _skills.Active[4]==0,"关卡存档恢复技能等级和空槽");
        var malicious=_skills.SaveData(); malicious["levels"].AsGodotDictionary()["1101080"]=50; malicious["active"]=new Godot.Collections.Array {1101080,1101010,1101010,1101030,1101040}; _skills.Restore(malicious);
        Check(_skills.Level(1101080)==0 && _skills.Active[0]==0 && _skills.Active[2]==0,"旧或异常存档不能开启火魔斩或重复技能");
        Check(_scene.player.Get("damage_rules").As<BattleDamageRules>().get_number("passive_id")==1301010,"重复恢复被动来源不累加");
        _panel.GetNode<BaseButton>("Keyboard/Close").EmitSignal("pressed");
        Check(_panel.Visible && !_panel.GetNode<Control>("Keyboard").Visible,"按键窗口关闭返回技能面板");
        _panel.set_open(false); Check(!_scene.original_hud.Call("is_module_open").AsBool() && !_scene.session.Get("clock").AsGodotObject().Get("paused").AsBool(),"关闭技能面板恢复战斗");
        _skills.Restore(initial); Check(_skills.Equip("active",4,1101030),"火眼可移动至第五槽");
        _skills.Operations.Set("enabled",true);
        var controller=_skills.Operations.Get("controller").AsGodotObject();
        var bindings=GetNode("/root/CoreSystem").Get("operation_manager").AsGodotObject().Get("bindings").AsGodotObject();
        var oldKeys=InputMap.ActionGetEvents("battle_player.skill_5"); var originalKey=oldKeys[0];
        _panel.set_open(true); _panel.OpenKeyboard();
        _panel.GetNode<Control>("Keyboard/active4/Key").EmitSignal("gui_input",new InputEventMouseButton {Pressed=true,ButtonIndex=MouseButton.Left});
        Check(bindings.Call("is_remapping").AsBool(),"原模板点击键名进入真实改键捕获");
        bindings.Call("capture_event",new InputEventKey {PhysicalKeycode=Key.T,Keycode=Key.T,Pressed=true});
        Check(_panel.GetNode<Label>("Keyboard/active4/Key").Text=="T","模板实时显示保存后的按键");
        _panel.set_open(false); _skills.Operations.Call("advance_input",.01);
        _scene.player.Get("motion").As<BattleMotionController2D>().grounded=true;
        attrs.Call("get_vital",new StringName("mana")).AsGodotObject().Call("set_current_value",10000.0);
        _scene.player.Get("action_state").AsGodotObject().Call("enter",0,new Dictionary());
        controller.Call("process_native_event",new InputEventKey {PhysicalKeycode=Key.T,Keycode=Key.T,Pressed=true});
        _skills.Operations.Call("advance_simulation",.01); _skills.Abilities.Call("advance_simulation",.01);
        Check(_skills.Ability(1101030)!.Get("is_active").AsBool(),"换槽改键后T按下实际释放火眼");
        controller.Call("process_native_event",new InputEventKey {PhysicalKeycode=Key.T,Keycode=Key.T,Pressed=false});
        Check(!_skills.Ability(1101030)!.Get("is_active").AsBool(),"换槽改键后火眼松键仍立即取消");
        bindings.Call("set_binding",new StringName("battle_player.skill_5"),originalKey,false);
        // Use actual input/controller dispatch and the battle clock, including
        // cancel/derived cast handling; resource inspection alone misses this.
        _skills.Restore(initial);
        foreach (var pair in new[] { (Slot: 3, Key: Key.O), (Slot: 4, Key: Key.L) })
        {
            _scene.player.Call("cancel_skill", new StringName("verification"));
            _skills.Abilities.Call("advance_simulation", 4.0);
            _skills.Equip("active", pair.Slot, 1101040);
            _scene.player.Get("action_state").AsGodotObject().Call("enter", 0, new Dictionary());
            _scene.player.Get("motion").As<BattleMotionController2D>().grounded = true;
            attrs.Call("get_vital", new StringName("mana")).AsGodotObject().Call("set_current_value", 10000.0);
            void Press(bool pressed) => controller.Call("process_native_event", new InputEventKey {PhysicalKeycode=pair.Key,Keycode=pair.Key,Pressed=pressed});
            Press(true); _scene.session.Call("advance_physics", .05); Press(false);
            Check(_skills.Ability(1101040)!.Get("is_active").AsBool(), "烈焰风暴第一段通过当前槽位按键释放");
            Press(true); _scene.session.Call("advance_physics", .05); Press(false);
            _scene.session.Call("advance_physics", .05);
            Check(_skills.Abilities.Call("get_ability_instance", new StringName("sunwukong_skill4_1")).AsGodotObject().Get("is_active").AsBool(), "再次按当前槽位按键真实触发烈焰风暴二段，兼容换槽");
        }
        _scene.player.Call("cancel_skill", new StringName("verification"));
        var potion=GD.Load<Script>("res://addons/simple_inventory/src/core/Item.gd").Call("new").AsGodotObject();
        potion.Set("item_id",new StringName("skill_test_potion")); potion.Set("name","测试补给"); potion.Set("category",1); potion.Set("max_stack",10); potion.Set("quantity",2);
        potion.Set("original_data",new Dictionary { ["isUse"]=1,["quality"]=10,["attributeT1"]="hp",["attributeV1"]="10" });
        bag.Call("add_item",potion);
        Check(_skills.EquipItem(0,"skill_test_potion"),"原模板可装配背包中可用补给");
        _panel.set_open(true);_panel.OpenKeyboard();await Frame();await Frame();
        Check(_panel.GetNode<TextureRect>("Keyboard/Item0/Background").Texture.ResourcePath.EndsWith("slot_2.png") && _panel.GetNode<Label>("Keyboard/Item0/Count").Text=="2","有道具时使用原版品质边框并保留实际堆叠数量");
        var itemSource=_panel.GetNode<Control>("Keyboard/item0");var itemTarget=_panel.GetNode<Control>("Keyboard/item1");
        Mouse(Center(itemSource),true);Move(Center(itemTarget));Mouse(Center(itemTarget),false);
        Check(_skills.Items[0]=="" && _skills.Items[1]=="skill_test_potion","道具Q/E槽同样支持真实快速拖放，不能重复装配同一道具");
        Mouse(Center(itemTarget),true);Move(Center(itemSource));Mouse(Center(itemSource),false);
        Check(_skills.Items[0]=="skill_test_potion" && _skills.Items[1]=="","道具拖回Q槽同步保存");
        _panel.set_open(false);
        var health=attrs.Call("get_vital",new StringName("health")).AsGodotObject(); health.Call("set_current_value",100.0);
        controller.Call("process_native_event",new InputEventKey {PhysicalKeycode=Key.Q,Keycode=Key.Q,Pressed=true});
        controller.Call("process_native_event",new InputEventKey {PhysicalKeycode=Key.Q,Keycode=Key.Q,Pressed=false});
        Check(health.Get("current_value").AsDouble()==110 && _skills.FindItem("skill_test_potion")!.Get("quantity").AsInt32()==1,"装配Q键真正使用补给且只扣一次");
        for (int i=1;i<17;++i)
        {
            var extra=GD.Load<Script>("res://addons/simple_inventory/src/core/Item.gd").Call("new").AsGodotObject();
            extra.Set("item_id",new StringName("skill_page_"+i));extra.Set("name","分页补给");extra.Set("category",1);
            extra.Set("original_data",new Dictionary{["isUse"]=1,["attributeT1"]="hp",["attributeV1"]="10"});bag.Call("add_item",extra);
        }
        _panel.set_open(true);_panel.OpenKeyboard();await Frame();await Frame();
        var second=_panel.GetNode<BaseButton>("Keyboard/Pages/Page1");
        Check(_panel.GetNode<Control>("Keyboard/Pages").Visible && second.Visible && !_panel.GetNode<Control>("Keyboard/Pages/Page2").Visible,"超过16种道具时才出现原版圆形编号分页");
        Move(Center(second));Mouse(Center(second),true);Mouse(Center(second),false);await Frame();
        var last=_panel.GetNode<Control>("Keyboard/Item0");Mouse(Center(last),true);Move(Center(itemTarget));Mouse(Center(itemTarget),false);
        Check(_skills.Items[1].StartsWith("skill_page_") && _panel.GetNode<TextureButton>("Keyboard/Pages/Page1").TextureNormal.ResourcePath.EndsWith("bag_page_2.png"),"真实点击第二页并拖放该页道具到E槽，分页显示和装配索引同步");
        _panel.set_open(false);
        _skills.Operations.Set("enabled",false);
        _scene.session.Call("despawn_entity",target.Get("entity_id"));
    }
}
