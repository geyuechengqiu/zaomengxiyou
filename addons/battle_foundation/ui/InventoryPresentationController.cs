using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;

/// <summary>Authored original sale/batch panels, machine identity and presentation-only title interface.</summary>
public partial class InventoryPresentationController : Node
{
    [Signal] public delegate void TitleRequestedEventHandler();
    private Control View => GetParent<Control>();
    private GodotObject? Inventory => View.Get("inventory").AsGodotObject();
    private Control Confirm => View.GetNode<Control>("Confirm");
    private Control Batch => View.GetNode<Control>("BatchSell");
    private Control PowerTip => View.GetNode<Control>("PowerTooltip");
    private GodotObject? _saleItem;
    private readonly List<(GodotObject Item,int Count)> _quote = new();
    private readonly List<(GodotObject Source,StringName Signal,Callable Callback)> _connections=new();
    private bool _syncing;
    private bool Modal => Confirm.Visible || Batch.Visible;
    public override void _Ready() => Callable.From(Initialize).CallDeferred();
    private void Listen(GodotObject source,StringName signal,Callable callback)
    { source.Connect(signal,callback); _connections.Add((source,signal,callback)); }
    private void Initialize()
    {
        GetNode<UiModalManager>("/root/UiModalManager").RegisterBranch(View);
        Listen(View.GetNode<BaseButton>("BatchSell/Yes"),"pressed",Callable.From(() => SellBatch()));
        Listen(View.GetNode<BaseButton>("BatchSell/No"),"pressed",Callable.From(() => Batch.Hide()));
        for (int i=0;i<10;++i) Listen(View.GetNode<CheckBox>("BatchSell/Qualities/Q"+i),"toggled",Callable.From<bool>(_ => UpdateQuote()));
        var input=View.GetNode<LineEdit>("Confirm/Count"); Listen(input,"text_changed",Callable.From<string>(_ => UpdateSaleCaption()));
        Listen(input,"focus_exited",Callable.From(() => SetCount(Count)));
        Listen(Confirm,"visibility_changed",Callable.From(() => { if (Confirm.Visible) Callable.From(SyncConfirmation).CallDeferred(); }));
        Listen(View,"visibility_changed",Callable.From(() =>
        {
            Batch.Hide(); PowerTip.Hide(); View.GetNode<Control>("TitleNotice").Hide();
            if (View.Visible) EnsureNumber();
        }));
        var power=View.GetNode<Control>("FightPower"); power.MouseFilter=Control.MouseFilterEnum.Stop;
        Listen(power,"mouse_entered",Callable.From(ShowPower)); Listen(power,"mouse_exited",Callable.From(() => PowerTip.Hide()));
        Listen(View.GetNode<BaseButton>("TitleButton"),"pressed",Callable.From(() =>
        { if (Modal) return; EmitSignal(SignalName.TitleRequested); View.GetNode<Control>("TitleNotice").Show(); }));
        Listen(View.GetNode<BaseButton>("TitleNotice/OK"),"pressed",Callable.From(() => View.GetNode<Control>("TitleNotice").Hide()));
        if (Inventory is {} inventory) Listen(inventory,"item_changed",Callable.From(() => { if (Batch.Visible) UpdateQuote(); }));
        if (View.Get("actor").AsGodotObject() is {} actor)
            Listen(actor.Get("attributes").AsGodotObject(),"snapshot_changed",Callable.From<Dictionary>(_ => { if (PowerTip.Visible) ShowPower(); }));
        if (View.Visible) EnsureNumber();
    }
    public void EnsureNumber()
    {
        var inventory=Inventory; if (inventory==null) return;
        if (inventory.Get("player_number").AsString().Length==0)
        {
            string code=OS.GetUniqueId();
            if (code.Length==0) { GD.PushError("平台没有提供机器码，编号未生成"); return; }
            inventory.Set("player_number",code);
            inventory.EmitSignal("item_changed");
        }
        var value=View.GetNode<Label>("PlayerNumber/Drawer/Value");
        value.Text=inventory.Get("player_number").AsString(); value.TooltipText=value.Text;
        value.TextOverrunBehavior=TextServer.OverrunBehavior.TrimEllipsis;
        View.GetNode<BaseButton>("PlayerNumber/Drawer/Copy").Disabled=false;
    }
    public void ToggleSelectedLock()
    {
        Inventory?.Call("toggle_lock",View.Get("_selected"));
        View.GetNode<Control>("Context").Hide(); View.Call("refresh");
    }
    public void OpenSelectedSale()
    {
        if (Inventory==null || Modal) return;
        _saleItem=View.Get("_selected").AsGodotObject();
        if (_saleItem==null || !CanSell(_saleItem,false)) return;
        View.Set("_confirmation",new StringName("sell"));
        View.GetNode<LineEdit>("Confirm/Count").Text=_saleItem.Get("quantity").AsInt32().ToString();
        View.GetNode<Control>("Context").Hide(); View.Call("_hide_tip"); Confirm.Show(); SyncConfirmation();
    }
    private int Count => int.TryParse(View.GetNode<LineEdit>("Confirm/Count").Text,out int n) ? n : 1;
    public void IncreaseCount() => SetCount(Count+1);
    public void DecreaseCount() => SetCount(Count-1);
    private void SetCount(int value)
    {
        int max=_saleItem?.Get("quantity").AsInt32() ?? 1;
        View.GetNode<LineEdit>("Confirm/Count").Text=Math.Clamp(value,1,Math.Max(1,max)).ToString(); UpdateSaleCaption();
    }
    private void SyncConfirmation()
    {
        if (!IsInsideTree() || !Confirm.Visible) return;
        bool sale=View.Get("_confirmation").AsString()=="sell";
        foreach (string path in new[]{"Icon","Slot","NumberBar","Count","Less","More"}) Confirm.GetNode<Control>(path).Visible=sale;
        Confirm.GetNode<Label>("Title").Text=sale ? "物品出售" : "解锁背包";
        Confirm.GetNode<Label>("Title").Visible=!sale;
        _saleItem=sale ? View.Get("_selected").AsGodotObject() : null;
        if (_saleItem!=null) { Confirm.GetNode<TextureRect>("Icon").Texture=_saleItem.Get("icon").As<Texture2D>(); SetCount(Count); }
    }
    private void UpdateSaleCaption()
    {
        if (_syncing || _saleItem==null || View.Get("_confirmation").AsString()!="sell") return;
        _syncing=true;
        string name=_saleItem.Get("name").AsString().Replace("[","[lb]");
        Confirm.GetNode<RichTextLabel>("Text").Text=$"[center]你确定出售 [color=#ff6600]{name} × {Math.Clamp(Count,1,Math.Max(1,_saleItem.Get("quantity").AsInt32()))}[/color] 吗？[/center]";
        foreach (var (path,disabled) in new[]{("Less",Count<=1),("More",Count>=_saleItem.Get("quantity").AsInt32())})
        {
            var button=Confirm.GetNode<TextureButton>(path); button.Disabled=disabled;
            (button.Material as ShaderMaterial)?.SetShaderParameter("is_disabled",disabled);
        }
        _syncing=false;
    }
    public void ConfirmSale()
    {
        if (Inventory==null || !Confirm.Visible) return;
        if (View.Get("_confirmation").AsString()=="sell")
        {
            _saleItem=View.Get("_selected").AsGodotObject();
            if (_saleItem==null || !CanSell(_saleItem,false)) { Confirm.Hide(); return; }
            SetCount(Count);
        }
        View.Call("confirm_operation"); _saleItem=null;
    }
    private bool CanSell(GodotObject item,bool equipmentOnly)
    {
        if (!IsInstanceValid(item) || Inventory==null || item.Get("locked").AsBool() || item.Get("quantity").AsInt32()<=0) return false;
        if (equipmentOnly && item.Get("category").AsInt32()!=2) return false;
        var data=item.Get("original_data").AsGodotDictionary();
        if (data.GetValueOrDefault("isSell",1).AsInt32()==0) return false;
        var extract=data.GetValueOrDefault("extract",new Dictionary()).AsGodotDictionary();
        if (extract.GetValueOrDefault("level",0).AsInt32()>0 || extract.GetValueOrDefault("exp",0).AsInt32()>0) return false;
        foreach (var owned in Inventory.Get("items").AsGodotArray())
            if (owned.AsGodotObject()==item) return Inventory.Call("_can_change",item).AsBool();
        return false;
    }
    public void OpenBatch()
    {
        if (Inventory==null || Modal) return;
        View.GetNode<Control>("Context").Hide(); View.Call("_hide_tip"); Batch.Show(); UpdateQuote();
    }
    public void UpdateQuote()
    {
        if (Inventory==null) return; _quote.Clear(); long price=0;
        foreach (var value in Inventory.Get("items").AsGodotArray())
        {
            var item=value.AsGodotObject(); if (item==null || !CanSell(item,true)) continue;
            if (!View.GetNode<CheckBox>("BatchSell/Qualities/Q"+InventoryBagPolicy.Quality(item)).ButtonPressed) continue;
            int n=item.Get("quantity").AsInt32(); _quote.Add((item,n)); price+=Inventory.Call("get_sell_price",item).AsInt64()*n;
        }
        Batch.GetNode<Label>("Summary").Text=$"符合条件：{_quote.Count} 件装备\n预计获得：{price} 灵魂\n锁定、已穿戴及不可出售的装备不会出售";
        Batch.GetNode<BaseButton>("Yes").Disabled=_quote.Count==0;
    }
    public int SellBatch()
    {
        if (Inventory==null || !Batch.Visible) return 0;
        // Capture identity/count at confirmation, then revalidate each instance against concurrent changes.
        UpdateQuote(); var candidates=_quote.ToArray(); int sold=0;
        foreach (var (item,count) in candidates)
            if (CanSell(item,true) && Inventory.Call("sell_item",item,count).AsBool()) sold++;
        Batch.Hide(); View.Call("refresh"); return sold;
    }
    public void ShowPower()
    {
        if (Modal || !View.Visible) return;
        var actor=View.Get("actor").AsGodotObject(); if (actor==null) return;
        var result=actor.Get("attributes").AsGodotObject().Call("get_fight_power_breakdown").AsGodotDictionary();
        double correction=result.GetValueOrDefault("correction",0).AsDouble();
        PowerTip.GetNode<Label>("Text").Text=$"总战斗力：{result["total"].AsInt64()}\n角色战力：{result.GetValueOrDefault("attribute_power",0).AsInt64()}\n修正战力：{correction:+0;-0;+0}（当前版本）\n修正战力用于平衡各职业战力差异，会随版本变化";
        View.Call("_hide_tip"); PowerTip.Show(); PlacePower();
    }
    private void PlacePower() => PowerTip.Position=(View.GetLocalMousePosition()+new Vector2(15,15)).Clamp(Vector2.Zero,(View.Size-PowerTip.Size).Max(Vector2.Zero));
    public override void _Process(double delta)
    {
        if (!View.Visible) return;
        if (PowerTip.Visible) PlacePower();
        if (Batch.Visible) { View.GetNode<Control>("Context").Hide(); View.Call("_hide_tip"); }
    }
    public override void _Input(InputEvent e)
    {
        if (!UiModalManager.CanReceive(View)) return;
        if (!View.Visible || e is not InputEventKey { Pressed:true, Echo:false, Keycode:Key.Escape }) return;
        if (Batch.Visible) { Batch.Hide(); GetViewport().SetInputAsHandled(); }
        else if (View.GetNode<Control>("TitleNotice").Visible) { View.GetNode<Control>("TitleNotice").Hide(); GetViewport().SetInputAsHandled(); }
        else if (Confirm.Visible) { Confirm.Hide(); GetViewport().SetInputAsHandled(); }
    }
    public override void _ExitTree()
    {
        foreach (var (source,signal,callback) in _connections)
            if (IsInstanceValid(source) && source.IsConnected(signal,callback)) source.Disconnect(signal,callback);
        _connections.Clear(); _quote.Clear(); _saleItem=null;
    }
}
