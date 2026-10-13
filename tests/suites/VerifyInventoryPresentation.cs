using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public partial class VerifyInventoryPresentation : Node
{
    private BattleLevelScene _scene=null!;
    private readonly List<string> _errors=new(); private int _checks;
    private void Check(bool ok,string message) { ++_checks; if (!ok) _errors.Add(message); }
    private async Task Frame() => await ToSignal(GetTree(),SceneTree.SignalName.ProcessFrame);
    private async Task Capture(string name)
    {
        if (!System.Array.Exists(OS.GetCmdlineUserArgs(),x=>x=="--inventory-capture")) return;
        await Frame(); await ToSignal(RenderingServer.Singleton,RenderingServer.SignalName.FramePostDraw);
        using var image=GetViewport().GetTexture().GetImage(); image.SavePng(ProjectSettings.GlobalizePath("res://.cleanup-backup/inventory-"+name+".png"));
    }
    public override async void _Ready()
    {
        try { await Run(); } catch (Exception error) { _errors.Add(error.ToString()); }
        finally { if (IsInstanceValid(_scene)) _scene.Free(); }
        await Frame(); _scene=null!; GC.Collect(); GC.WaitForPendingFinalizers(); await Frame();
        foreach (string error in _errors) GD.PushError(error);
        if (_errors.Count==0) GD.Print($"PASS inventory presentation: {_checks} checks; quality/type order, lock protection, original sale/count/cancel, bulk selection/revalidation, machine identity, power breakdown, title interface and fonts");
        GetTree().Quit(_errors.Count==0?0:1);
    }
    private async Task Run()
    {
        _scene=GD.Load<PackedScene>("res://game/levels/biyujing.tscn").Instantiate<BattleLevelScene>(); _scene.enable_player_controls=false;
        AddChild(_scene); _scene.session.SetPhysicsProcess(false); _scene.flow.Call("stop"); await Frame(); await Frame();
        var actor=_scene.player; var bag=actor.Get("inventory").AsGodotObject(); var hud=_scene.original_hud;
        var view=hud.Get("inventory_view").As<Control>(); var policy=view.GetNode<InventoryPresentationController>("PresentationController");
        bag.Set("player_number",""); hud.Call("set_inventory_open",true); await Frame();
        Check(bag.Get("player_number").AsString()==OS.GetUniqueId() && OS.GetUniqueId().Length>0,"首次开包采用完整机器码");
        string code=bag.Get("player_number").AsString(); hud.Call("set_inventory_open",false); hud.Call("set_inventory_open",true);
        Check(bag.Get("player_number").AsString()==code,"重复开包编号保持稳定");
        bag.Set("player_number","existing-number"); policy.EnsureNumber(); Check(bag.Get("player_number").AsString()=="existing-number","保留已有编号");
        var rows=bag.Call("get_bag_items","equipment").AsGodotArray();
        Check(rows[0].AsGodotObject().Get("item_id").AsString()=="110101003" && rows[1].AsGodotObject().Get("item_id").AsString()=="110101002","同品质按武器、头盔、防具排序");
        GodotObject Own(string id) => bag.Call("get_owned_item",GD.Load<Resource>("res://data/inventory/"+id+".tres")).AsGodotObject();
        var weapon=Own("110101003"); var armor=Own("110101001");
        bag.Call("equip_item",weapon); bag.Call("toggle_lock",armor);
        Check(armor.Get("locked").AsBool() && !bag.Call("sell_item",armor,1).AsBool(),"锁定原装备禁止出售");
        Check(armor.Call("get_save_data").AsGodotDictionary()["locked"].AsBool(),"锁定状态进入装备存档");
        var lockHost=view.GetNode<Control>("Grid/Slot0");
        view.Call("_open_context",armor,false,lockHost); view.GetNode<BaseButton>("Context/Lock").EmitSignal("pressed");
        Check(!armor.Get("locked").AsBool(),"点击解锁只执行一次");
        view.Call("_open_context",armor,false,lockHost); view.GetNode<BaseButton>("Context/Lock").EmitSignal("pressed");
        Check(armor.Get("locked").AsBool(),"点击锁定只执行一次且菜单关闭");
        GodotObject Add(string id,int quality)
        {
            var definition=GD.Load<Resource>("res://data/inventory/"+id+".tres").Duplicate(true);
            var metadata=definition.Get("original_data").AsGodotDictionary().Duplicate(true); metadata["quality"]=quality; definition.Set("original_data",metadata);
            Check(bag.Call("try_add_item",definition,false).AsBool(),"装备入库"); return bag.Call("get_owned_item",definition).AsGodotObject();
        }
        var normal=Add("110101001",0); var rare=Add("110101002",2); var lockLater=Add("110101003",1);
        rows=bag.Call("get_bag_items","equipment").AsGodotArray(); Check(rows[0].AsGodotObject()==rare,"拾取后自动按品质降序整理");
        var host=view.GetNode<Control>("Grid/Slot0"); view.Call("_open_context",normal,false,host); policy.OpenSelectedSale(); await Frame();
        Check(view.GetNode<Control>("Confirm").Visible && view.GetNode<TextureRect>("Confirm/Background").Texture.GetSize()==new Vector2(940,590),"原版物品出售面板素材");
        Check(view.GetNode<RichTextLabel>("Confirm/Text").Text.Contains("你确定出售") && view.GetNode<TextureRect>("Confirm/Icon").Texture==normal.Get("icon").As<Texture2D>(),"出售文本、名称颜色及物品图标");
        view.GetNode<LineEdit>("Confirm/Count").Text="999"; view.GetNode<BaseButton>("Confirm/More").EmitSignal("pressed");
        Check(view.GetNode<LineEdit>("Confirm/Count").Text=="1","装备出售数量限制为持有量"); await Capture("sale");
        Check(view.GetNode<BaseButton>("Confirm/Less").Disabled && view.GetNode<BaseButton>("Confirm/More").Disabled,"单件装备的数量加减按钮禁用且显示原灰色状态");
        view.GetNode<BaseButton>("Confirm/No").EmitSignal("pressed"); Check(bag.Call("get_owned_item",normal).AsGodotObject()==normal,"取消出售不移除装备");
        var stackDefinition=GD.Load<GDScript>("res://addons/simple_inventory/src/core/Item.gd").New().AsGodotObject();
        stackDefinition.Set("item_id",new StringName("verify_sale_quantity")); stackDefinition.Set("name","出售数量测试"); stackDefinition.Set("category",1);
        stackDefinition.Set("max_stack",99); stackDefinition.Set("quantity",3); stackDefinition.Set("original_data",new Dictionary { ["quality"]=0,["price"]=25,["isSell"]=1,["type"]="item" });
        Check(bag.Call("try_add_item",stackDefinition,false).AsBool(),"可堆叠物品入库"); var stack=bag.Call("get_owned_item",stackDefinition).AsGodotObject();
        view.Call("_open_context",stack,false,host); policy.OpenSelectedSale(); view.GetNode<LineEdit>("Confirm/Count").Text="1";
        long stackSpirit=bag.Get("spirit").AsInt64(); view.GetNode<BaseButton>("Confirm/Yes").EmitSignal("pressed");
        Check(stack.Get("quantity").AsInt32()==2 && bag.Get("spirit").AsInt64()==stackSpirit+5,"数量输入只出售指定数量并按单价结算");
        view.Call("_open_context",normal,false,host); policy.OpenSelectedSale(); bag.Call("toggle_lock",normal); view.GetNode<BaseButton>("Confirm/Yes").EmitSignal("pressed");
        Check(bag.Call("get_owned_item",normal).AsGodotObject()==normal,"确认前锁定的装备再次校验保护"); bag.Call("toggle_lock",normal);
        view.GetNode<BaseButton>("Sort").EmitSignal("pressed"); Check(view.GetNode<Control>("BatchSell").Visible,"原一键出售按钮打开品质多选");
        Check(view.GetNode<BaseButton>("BatchSell/Yes").Disabled,"没有选择品质时不可出售");
        view.GetNode<CheckBox>("BatchSell/Qualities/Q0").ButtonPressed=true; view.GetNode<CheckBox>("BatchSell/Qualities/Q1").ButtonPressed=true;
        Check(!view.GetNode<BaseButton>("BatchSell/Yes").Disabled,"同时选择普通和优秀品质"); bag.Call("toggle_lock",lockLater);
        Check(view.GetNode<Label>("BatchSell/Summary").Text.Contains("2 件装备"),"锁定变化立即更新出售预览");
        long expected=bag.Call("get_sell_price",normal).AsInt64()+bag.Call("get_sell_price",Own("110101002")).AsInt64(); long before=bag.Get("spirit").AsInt64();
        await Capture("batch"); Check(policy.SellBatch()==2,"一键出售准确匹配品质且重检锁定");
        Check(bag.Get("spirit").AsInt64()==before+expected,"按原价格累计出售灵魂");
        Check(bag.Call("get_owned_item",armor).AsGodotObject()==armor && bag.Call("get_owned_item",lockLater).AsGodotObject()==lockLater,"保留两件锁定装备");
        Check(bag.Call("get_owned_item",rare).AsGodotObject()==rare && bag.Call("get_owned_item",weapon).AsGodotObject()==weapon,"保留未选择品质和已装备物品");
        Check(bag.Call("get_owned_item",stack).AsGodotObject()==stack && stack.Get("quantity").AsInt32()==2,"装备一键出售不卖相同品质的补给或材料");
        Check(policy.SellBatch()==0 && bag.Get("spirit").AsInt64()==before+expected,"关闭的出售窗口不能重复结算");
        view.GetNode<Control>("FightPower").EmitSignal("mouse_entered");
        var power=actor.Get("attributes").AsGodotObject().Call("get_fight_power_breakdown").AsGodotDictionary();
        Check(view.GetNode<Control>("PowerTooltip").Visible && view.GetNode<Label>("PowerTooltip/Text").Text.Contains("总战斗力："+power["total"].AsInt64()),"战力悬浮显示属性系统真实总战力");
        Check(view.GetNode<Label>("PowerTooltip/Text").Text.Contains("角色战力："+power["attribute_power"].AsInt64()) && view.GetNode<Label>("PowerTooltip/Text").Text.Contains("修正战力：+0"),"战力明细和实际修正值"); await Capture("power");
        view.GetNode<Control>("FightPower").EmitSignal("mouse_exited"); Check(!view.GetNode<Control>("PowerTooltip").Visible,"移出战力数字隐藏提示");
        int requests=0; policy.TitleRequested += ()=>requests++; view.GetNode<BaseButton>("TitleButton").EmitSignal("pressed");
        Check(requests==1 && view.GetNode<Control>("TitleNotice").Visible,"称号按钮仅触发预留接口"); view.GetNode<BaseButton>("TitleNotice/OK").EmitSignal("pressed");
        Check(actor.Get("attributes").AsGodotObject().Call("get_fight_power_breakdown").AsGodotDictionary()["total"].AsInt64()==power["total"].AsInt64(),"称号入口不附加属性");
        view.Call("_show_item_tip",rare,host,false); Check(view.GetNode<Label>("Tooltip/Name").GetThemeConstant("outline_size")==2,"装备名称保持原黑色描边"); await Capture("tooltip");
        hud.Call("set_inventory_open",false); Check(!view.GetNode<Control>("PowerTooltip").Visible && !view.GetNode<Control>("BatchSell").Visible,"关闭背包清理弹窗");
        var campaign=GetNode<ZaomengOneCampaign>("/root/ZaomengOneCampaign"); campaign.persistence_enabled=false;
        string lockedUid=armor.Get("runtime").AsGodotObject().Get("unique_id").AsString(); campaign.CaptureCharacter(actor);
        bag.Set("player_number",""); bag.Call("toggle_lock",armor); campaign.RestoreCharacter(actor,_scene.session);
        Check(bag.Get("player_number").AsString()=="existing-number","跨关存档恢复编号");
        GodotObject? restored=null;
        foreach (var value in bag.Call("get_bag_items","equipment").AsGodotArray())
        {
            var item=value.AsGodotObject();
            if (item.Get("runtime").AsGodotObject().Get("unique_id").AsString()==lockedUid) restored=item;
        }
        Check(restored!=null && restored.Get("locked").AsBool(),"读档恢复同一装备身份及锁定状态");
    }
}
