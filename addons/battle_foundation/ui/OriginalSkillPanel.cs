using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;

/// <summary>Original SWF art and layout; original progression and semantic keyboard loadout.</summary>
public partial class OriginalSkillPanel : Control
{
    public BattleSkillLoadout Loadout { get; private set; } = null!;
    public int Tab { get; private set; }
    public int SelectedSkill { get; private set; }
    public bool BatchUpgrading { get; private set; }
    private int _upgradeId, _page, _itemTab;
    private double _batchTime;
    private string _selectedGroup = "", _selectedItem = "";
    private Vector2 _dragStart, _pointer;
    private int _sourceIndex = -1;
    private Window? _window;
    private bool _pressing, _dragged;
    private const string KeyboardHint = "拖动技能或道具图标可携带至副本使用；每次可携带1种妖王助阵";
    private readonly List<GodotObject> _items = new();
    private readonly List<(Control Cell, string Group, int Index)> _targets = new();
    private readonly List<(Control Cell, int Id)> _stock = new();
    private GodotObject? _bindings;
    private Callable _changed, _currency, _inventoryChanged, _attributes, _mapping, _remapFinished, _remapFailed;
    private bool Blocked => GetNode<Control>("Notice").Visible || GetNode<Control>("Upgrade").Visible;
    private bool CanEdit => Visible && !Blocked && UiModalManager.CanReceive(this) && _bindings?.Call("is_remapping").AsBool() != true;
    public override void _Ready()
    {
        GetNode<UiModalManager>("/root/UiModalManager").RegisterBranch(this);
        _window = GetWindow(); _window.FocusExited += CancelInteraction;
        _pointer = GetGlobalTransformWithCanvas() * GetLocalMousePosition();
        BindButton("Main/Close", () => set_open(false));
        BindButton("Main/ActiveTab", () => SelectTab(0));
        BindButton("Main/SpecialTab", () => SelectTab(1));
        BindButton("Main/SecretTab", () => Notice("技能秘笈入口保留，秘技养成尚未开放"));
        BindButton("Main/Keyboard", OpenKeyboard);
        BindButton("Main/Job", () => Notice("转职入口保留，当前悟空尚未转职"));
        BindButton("Main/Reset", () => Notice("不能在副本中重置"));
        BindButton("Main/Help", () => Notice("升级技能消耗灵魂，需满足人物等级。\n按键设置中拖动技能装配；点击键名可改键。"));
        BindButton("Keyboard/Close", CloseTop);
        BindButton("Keyboard/itemsTab", () => SetItemTab(0));
        BindButton("Keyboard/monstersTab", () => SetItemTab(1));
        BindButton("Keyboard/emotesTab", () => SetItemTab(2));
        for (int i=0;i<5;++i)
        {
            var page=GetNode<BaseButton>("Keyboard/Pages/Page"+i);
            BindButton("Keyboard/Pages/Page"+i, () => { CancelInteraction(); _page=page.GetMeta("page_index",0).AsInt32(); RefreshItems(); });
        }
        BindButton("Upgrade/Close", CloseUpgrade);
        BindButton("Upgrade/Submit", () => UpgradeOnce(true));
        BindButton("Upgrade/Batch", () =>
        {
            if (Loadout.Level(_upgradeId) == 0) return;
            BatchUpgrading = !BatchUpgrading; _batchTime = 0;
            if (BatchUpgrading) UpgradeOnce(true);
        });
        BindButton("Notice/OK", () => GetNode<Control>("Notice").Hide());
        for (int i = 0; i < 16; ++i)
        {
            int index = i; var cell = GetNode<Control>("Keyboard/Item" + i);
            cell.GuiInput += e => ItemInput(e, index);
            cell.MouseEntered += () => ItemTooltip(index);
            cell.MouseExited += HideTooltip;
        }
        foreach (var (group, count) in new[] { ("active",5),("passive",1),("peerless",1),("item",2) })
            for (int i = 0; i < count; ++i)
            {
                var cell = GetNode<Control>("Keyboard/" + group + i); int index = i; string category = group;
                _targets.Add((cell, group, i));
                cell.GuiInput += e => TargetInput(e, category, index);
                cell.MouseEntered += () => TargetTooltip(category, index);
                cell.MouseExited += HideTooltip;
                if (group == "passive") continue;
                var key = cell.GetNode<Label>("Key"); key.MouseFilter = MouseFilterEnum.Stop;
                key.GuiInput += e =>
                {
                    if (e is InputEventMouseButton {Pressed:true,ButtonIndex:MouseButton.Left} && CanEdit)
                    {
                        CancelInteraction();
                        string intent = category == "active" ? "skill_" + (index + 1) : category == "peerless" ? "wushuang" : "item_" + (index + 1);
                        if (!_bindings!.Call("start_remap", Loadout.Operations.Get("controller"), new StringName(intent), true).AsBool()) Notice(_bindings.Get("last_error").AsString());
                        else SetText("Keyboard/Tip", "请按下新的按键（Esc取消）");
                        key.AcceptEvent();
                    }
                };
            }
    }
    private void BindButton(string path, Action action) => GetNode<BaseButton>(path).Pressed += () => { if (path.StartsWith("Notice/") || !GetNode<Control>("Notice").Visible) action(); };
    public void Bind(BattleSkillLoadout loadout)
    {
        if (Loadout == loadout) { Refresh(); return; }
        Loadout = loadout; Loadout.Initialize(); Loadout.BindHUD(GetParent<Control>());
        _changed = Callable.From(Refresh); Loadout.Connect(BattleSkillLoadout.SignalName.Changed, _changed);
        _currency = Callable.From<long>(_ => { if (Visible) RefreshUpgrade(); }); Loadout.Inventory.Connect("currency_changed", _currency);
        _inventoryChanged = Callable.From(() => { if (Visible) RefreshItems(); }); Loadout.Inventory.Connect("item_changed", _inventoryChanged);
        _attributes = Callable.From<Godot.Collections.Dictionary>(_ => { if (Visible) Refresh(); });
        Loadout.Actor.Get("attributes").AsGodotObject().Connect("snapshot_changed", _attributes);
        _bindings = GetNode("/root/CoreSystem").Get("operation_manager").AsGodotObject().Get("bindings").AsGodotObject();
        _mapping = Callable.From<StringName>(_ => RefreshKeys()); _bindings.Connect("mapping_changed", _mapping);
        _remapFinished = Callable.From<StringName, bool>((_, success) => { SetText("Keyboard/Tip", KeyboardHint); RefreshKeys(); }); _bindings.Connect("remap_finished", _remapFinished);
        _remapFailed = Callable.From<string>(Notice); _bindings.Connect("remap_failed", _remapFailed);
        foreach (var row in Loadout.Rows)
        {
            int id = row["id"].AsInt32(); var view = GetNode<Control>("Main/Rows/S" + id);
            view.MouseEntered += () => SkillTooltip(id); view.MouseExited += HideTooltip;
            if (row["type"].AsInt32() == 1)
            {
                BindButton("Main/Rows/S" + id + "/Upgrade", () => OpenUpgrade(id));
                BindButton("Main/Rows/S" + id + "/Secrets", () => Notice("秘技入口保留，秘技养成尚未开放"));
            }
            if (!row["available"].AsBool()) continue;
            var stock = GetNode<Control>("Keyboard/Stock" + id); _stock.Add((stock,id));
            stock.GuiInput += e => StockInput(e,id); stock.MouseEntered += () => SkillTooltip(id); stock.MouseExited += HideTooltip;
        }
        Refresh();
    }
    public void set_open(bool open)
    {
        if (Loadout == null || Visible == open) return;
        CancelDrag(); HideTooltip(); CloseUpgrade(); GetNode<Control>("Notice").Hide();
        GetNode<Control>("Keyboard").Hide(); GetNode<Control>("Main").Show();
        _bindings?.Call("cancel_remap");
        Loadout.Operations.Call("set_control_blocked", new StringName("skills_panel"), open);
        Visible = open; if (open) { SelectTab(0); Refresh(); }
        GetParent().EmitSignal("module_changed", open);
    }
    public void SelectTab(int tab)
    {
        if (Blocked) return; Tab = tab; CancelInteraction(); Refresh();
    }
    public void OpenKeyboard()
    {
        if (Blocked) return; CloseUpgrade(); CancelDrag(); HideTooltip();
        GetNode<Control>("Main").Hide(); GetNode<Control>("Keyboard").Show(); _itemTab=0; _page=0;
        SetText("Keyboard/Tip", KeyboardHint); Refresh();
    }
    private void SetItemTab(int tab)
    {
        if (Blocked) return; CancelInteraction(); _itemTab=tab; _page=0; RefreshItems();
        if (tab != 0) Notice(tab == 1 ? "妖王帖入口保留，当前未接入妖王召唤" : "表情入口保留，当前未接入表情道具");
    }
    public void CloseTop()
    {
        if (GetNode<Control>("Notice").Visible) { GetNode<Control>("Notice").Hide(); return; }
        if (GetNode<Control>("Upgrade").Visible) { CloseUpgrade(); return; }
        if (GetNode<Control>("Keyboard").Visible)
        { CancelDrag(); HideTooltip(); _bindings?.Call("cancel_remap"); GetNode<Control>("Keyboard").Hide(); GetNode<Control>("Main").Show(); Refresh(); return; }
        set_open(false);
    }
    public void OpenUpgrade(int id)
    {
        if (Blocked) return;
        if (!Loadout.Available(id)) { Notice("转职后才能学习此技能"); return; }
        _upgradeId=id; BatchUpgrading=false; _batchTime=0; CancelInteraction(); GetNode<Control>("Upgrade").Show(); RefreshUpgrade();
    }
    public void CloseUpgrade() { BatchUpgrading=false; _batchTime=0; GetNode<Control>("Upgrade").Hide(); }
    public bool UpgradeOnce(bool feedback)
    {
        bool success=Loadout.Upgrade(_upgradeId);
        if (!success) { BatchUpgrading=false; if (feedback) Notice(Loadout.LastError); }
        RefreshUpgrade(); return success;
    }
    public void Refresh()
    {
        if (Loadout == null) return;
        GetNode<Control>("Main/SecretTab").Hide(); // Original SkillModule hides btn3; row entrances remain available.
        foreach (var row in Loadout.Rows)
        {
            int id=row["id"].AsInt32(), type=row["type"].AsInt32(), level=Loadout.Level(id);
            var view=GetNode<Control>("Main/Rows/S"+id); view.Visible = Loadout.Available(id) && Tab == (type==1 ? 0 : 1);
            var name=view.GetNode<Label>("Name");
            view.GetNode<Label>("Level").Position=new Vector2(name.Position.X+name.GetThemeFont("font").GetStringSize(name.Text,HorizontalAlignment.Left,-1,name.GetThemeFontSize("font_size")).X+5,name.Position.Y);
            view.GetNode<TextureRect>("Icon").Modulate = Loadout.Learned(id) ? Colors.White : new Color(.45f,.45f,.45f);
            view.GetNode<Label>("Level").Text = type==1 ? (level>0 ? $"Lv.{level}" : "未学习") : "";
            if (type==1)
            {
                var upgrade=view.GetNode<TextureButton>("Upgrade"); upgrade.Visible=Loadout.Available(id);
                int f=level>0 ? 3 : 0;
                upgrade.TextureNormal=Texture("learn_button_"+f); upgrade.TextureHover=Texture("learn_button_"+(f+1)); upgrade.TexturePressed=Texture("learn_button_"+(f+2));
                upgrade.Disabled=Loadout.Next(id)==null;
                view.GetNode<CanvasItem>("LearnGlow").Visible=level==0 && Loadout.Available(id) && Loadout.Next(id) is {} next && Loadout.RoleLevel>=next["role_level"].AsInt32();
                view.GetNode<Control>("Locked").Visible=!Loadout.Available(id);
                view.GetNode<BaseButton>("Secrets").Visible = Loadout.Available(id) && Loadout.RoleLevel>=30 && level>0;
            }
        }
        GetNode<Control>("Main/ActiveSections").Visible=Tab==0; GetNode<Control>("Main/SpecialSections").Visible=Tab==1;
        foreach (var (name,selected) in new[] {("ActiveTab",Tab==0),("SpecialTab",Tab==1)})
            GetNode<TextureButton>("Main/"+name).TextureNormal=Texture((name=="ActiveTab"?"active_tab":"special_tab")+"_"+(selected?2:0));
        foreach (var (cell,id) in _stock)
        { cell.GetNode<TextureRect>("Icon").Modulate=Loadout.Learned(id)?Colors.White:new Color(.45f,.45f,.45f); }
        foreach (var (cell,group,index) in _targets)
        {
            Texture2D? icon=group=="item" ? Loadout.FindItem(Loadout.Items[index])?.Get("icon").As<Texture2D>() : SkillIcon(Equipped(group,index));
            cell.GetNode<TextureRect>("Icon").Texture=icon;
        }
        RefreshKeys(); RefreshItems(); RefreshUpgrade();
    }
    private int Equipped(string group,int index) => group=="active" ? Loadout.Active[index] : group=="passive" ? Loadout.Passive : group=="peerless" ? Loadout.Peerless : 0;
    private Texture2D Texture(string name)
        => TexturePath("res://assets/ui/skills/"+name+".png");
    private Texture2D TexturePath(string path)
        => BattleUiTextureCache.Get(path);
    private Texture2D? SkillIcon(int id) => Loadout.Find(id) is {} row && Loadout.Learned(id) ? TexturePath(row["icon"].AsString()) : null;
    private void SetText(string path,string text) => GetNode<Label>(path).Text=text;
    private static double Sample(Dictionary row,string field,int level)
    { var values=row[field].AsGodotArray(); return values[Math.Clamp(level,0,values.Count-1)].AsDouble(); }
    private void RefreshUpgrade()
    {
        if (Loadout==null || !GetNode<Control>("Upgrade").Visible) return;
        var row=Loadout.Find(_upgradeId)!; int level=Loadout.Level(_upgradeId); var next=Loadout.Next(_upgradeId);
        GetNode<TextureRect>("Upgrade/Icon").Texture=TexturePath(row["icon"].AsString());
        SetText("Upgrade/Name",row["name"].AsString()+$" Lv.{level}");
        SetText("Upgrade/Requirements",next==null ? "技能已满级" : $"人物等级需达到{next["role_level"].AsInt32()}级");
        SetText("Upgrade/Cost",next==null ? "" : $"消耗灵魂：{next["spirit"].AsInt64()}");
        SetText("Upgrade/Description",row["description"].AsString()); SetText("Upgrade/Growth",row["upgrade_description"].AsString());
        string arrow=next==null ? "" : $"  →  {Sample(row,"mp",level+1):0.##}";
        SetText("Upgrade/MP",$"魔法消耗：{(level>0?Sample(row,"mp",level).ToString("0.##"):"—")}"+arrow);
        SetText("Upgrade/Cooldown",$"技能冷却：{(level>0?Sample(row,"cooldown",level).ToString("0.##"):"—")}"+(next==null?"":$"  →  {Sample(row,"cooldown",level+1):0.##}")+" 秒");
        SetText("Upgrade/Spirit",$"当前灵魂：{Loadout.Inventory.Get("spirit").AsInt64()}");
        GetNode<BaseButton>("Upgrade/Submit").Visible=next!=null;
        var submit=GetNode<TextureButton>("Upgrade/Submit"); submit.TextureNormal=Texture("upgrade_button_"+(level>0?3:0)); submit.Disabled=BatchUpgrading;
        GetNode<BaseButton>("Upgrade/Batch").Visible=next!=null && level>0;
        GetNode<BaseButton>("Upgrade/Batch").TooltipText=BatchUpgrading ? "点击停止连续升级" : "每0.5秒升级一次，条件不足时停止";
    }
    private void RefreshKeys()
    {
        if (Loadout==null || _bindings==null) return;
        foreach (var (cell,group,index) in _targets)
        {
            string intent=group=="active" ? "skill_"+(index+1) : group=="peerless"?"wushuang":group=="item"?"item_"+(index+1):"";
            cell.GetNode<Label>("Key").Text=intent.Length==0 ? "" : GetParent().Call("get_intent_key",new StringName(intent)).AsString();
        }
    }
    private void RefreshItems()
    {
        if (Loadout==null) return; _items.Clear(); var ids=new HashSet<string>();
        if (_itemTab==0)
            foreach (var value in Loadout.Inventory.Get("items").AsGodotArray())
            {
                if (value.VariantType!=Variant.Type.Object || !IsInstanceValid(value.AsGodotObject())) continue;
                var item=value.AsGodotObject();
                if (BattleSkillLoadout.UsableItem(item) && ids.Add(item.Get("item_id").AsString())) _items.Add(item);
            }
        _page=Math.Clamp(_page,0,Math.Max(0,(_items.Count-1)/16));
        foreach (var (name,index) in new[] {("items",0),("monsters",1),("emotes",2)})
            GetNode<TextureButton>("Keyboard/"+name+"Tab").TextureNormal=Texture(name+"_tab_"+(_itemTab==index?2:0));
        int pages=Math.Max(1,(_items.Count+15)/16), shown=Math.Min(5,pages), start=Math.Clamp(_page-2,0,Math.Max(0,pages-5));
        GetNode<Control>("Keyboard/Pages").Visible=pages>1;
        for (int i=0;i<5;++i)
        {
            var page=GetNode<TextureButton>("Keyboard/Pages/Page"+i); page.Visible=i<shown;
            page.Position=new Vector2((250-shown*34)/2f+i*34,0); page.SetMeta("page_index",start+i);
            page.GetNode<Label>("Text").Text=(start+i+1).ToString();
            page.TextureNormal=TexturePath($"res://assets/ui/original/bag_page_{(start+i==_page?2:0)}.png");
        }
        for (int i=0;i<16;++i)
        {
            var cell=GetNode<Control>("Keyboard/Item"+i); int at=_page*16+i;
            cell.GetNode<TextureRect>("Icon").Texture=at<_items.Count?_items[at].Get("icon").As<Texture2D>():null;
            cell.GetNode<Label>("Count").Text=at<_items.Count?_items[at].Get("quantity").AsInt32().ToString():"";
            int skin=0;
            if (at<_items.Count)
            {
                int quality=_items[at].Get("original_data").AsGodotDictionary().GetValueOrDefault("quality",0).AsInt32();
                skin=Math.Clamp(int.Parse(Math.Abs(quality).ToString()[..1]),0,9)+1;
            }
            cell.GetNode<TextureRect>("Background").Texture=TexturePath($"res://assets/ui/original/slot_{skin}.png");
        }
    }
    private void StockInput(InputEvent e,int id)
    {
        if (!CanEdit || e is not InputEventMouseButton {Pressed:true,ButtonIndex:MouseButton.Left} mouse) return;
        if (!Loadout.Learned(id)) { Notice("技能未学习"); return; }
        string group=Loadout.Find(id)!["type"].AsInt32()==1?"active":Loadout.Find(id)!["type"].AsInt32()==2?"passive":"peerless";
        BeginSelect(id,group,"",GetNode<Control>("Keyboard/Stock"+id),mouse);
    }
    private void TargetInput(InputEvent e,string group,int index)
    {
        if (!CanEdit || e is not InputEventMouseButton {Pressed:true,ButtonIndex:MouseButton.Left} mouse) return;
        if (mouse.DoubleClick && group is "active" or "item")
        { CancelDrag(); if (!Loadout.Unequip(group,index)) Notice(Loadout.LastError); return; }
        if (_selectedGroup==group && (SelectedSkill>0 || _selectedItem.Length>0) && !_pressing)
        { Drop(group,index); CancelDrag(); return; }
        int id=Equipped(group,index); string item=group=="item"?Loadout.Items[index]:"";
        if (id>0 || item.Length>0) BeginSelect(id,group,item,GetNode<Control>("Keyboard/"+group+index),mouse,index);
    }
    private void ItemInput(InputEvent e,int index)
    {
        if (!CanEdit || e is not InputEventMouseButton {Pressed:true,ButtonIndex:MouseButton.Left} mouse || _page*16+index>=_items.Count) return;
        BeginSelect(0,"item",_items[_page*16+index].Get("item_id").AsString(),GetNode<Control>("Keyboard/Item"+index),mouse);
    }
    private void BeginSelect(int id,string group,string item,Control source,InputEventMouseButton mouse,int sourceIndex=-1)
    {
        SelectedSkill=id; _selectedGroup=group; _selectedItem=item; _sourceIndex=sourceIndex;
        _pointer=source.GetGlobalTransformWithCanvas()*mouse.Position; _dragStart=_pointer; _pressing=true; _dragged=false;
        GetNode<TextureRect>("DragIcon").Texture=group=="item"?Loadout.FindItem(item)?.Get("icon").As<Texture2D>():SkillIcon(id);
        HideTooltip();
    }
    private void Drop(string group,int index)
    {
        bool success=group==_selectedGroup && (_sourceIndex>=0 && group is "active" or "item"
            ? Loadout.MoveSlot(group,_sourceIndex,index)
            : group=="item"?Loadout.EquipItem(index,_selectedItem):Loadout.Equip(group,index,SelectedSkill));
        if (!success) Notice(group!=_selectedGroup?"只能装配到同类型的格子":Loadout.LastError);
    }
    private void CancelDrag()
    { _pressing=false; _dragged=false; SelectedSkill=0; _selectedGroup=""; _selectedItem=""; _sourceIndex=-1; GetNode<Control>("DragIcon").Hide(); }
    private void CancelInteraction() { CancelDrag(); HideTooltip(); }
    private Vector2 LocalPointer => GetGlobalTransformWithCanvas().AffineInverse()*_pointer;
    private void UpdateDrag()
    {
        if (_pressing && _pointer.DistanceTo(_dragStart)>6) _dragged=true;
        var drag=GetNode<Control>("DragIcon"); drag.Visible=_dragged;
        drag.Position=LocalPointer-drag.Size*.5f;
        RefreshOverlayLayer();
        if (GetNode<Control>("Tooltip").Visible) PositionTooltip();
    }
    private void RefreshOverlayLayer()
    {
        int layer=ZIndex;
        var keyboard=GetNode<Control>("Keyboard");
        if (keyboard.IsVisibleInTree()) layer=Math.Max(layer,keyboard.ZIndex);
        var tooltip=GetNode<Control>("Tooltip"); var drag=GetNode<Control>("DragIcon");
        tooltip.ZAsRelative=drag.ZAsRelative=false;
        tooltip.ZIndex=Math.Min(4095,layer+1); drag.ZIndex=Math.Min(4095,layer+2);
    }
    public override void _Input(InputEvent e)
    {
        if (!Visible || Loadout==null) return;
        if (e is InputEventMouse mouse) _pointer=mouse.Position;
        if (!UiModalManager.CanReceive(this)) { CancelInteraction(); return; }
        if (e is InputEventKey {Pressed:true,Echo:false,Keycode:Key.Escape})
        {
            if (_bindings?.Call("is_remapping").AsBool()==true) return;
            if (_pressing || SelectedSkill>0 || _selectedItem.Length>0) CancelInteraction(); else CloseTop();
            GetViewport().SetInputAsHandled(); return;
        }
        if (!CanEdit) { CancelInteraction(); return; }
        if (e is InputEventMouseButton {Pressed:true,ButtonIndex:MouseButton.Right} && (_pressing || SelectedSkill>0 || _selectedItem.Length>0))
        { CancelInteraction(); GetViewport().SetInputAsHandled(); return; }
        if (e is InputEventMouseMotion)
        {
            UpdateDrag();
            if (_dragged) GetViewport().SetInputAsHandled();
        }
        if (e is InputEventMouseButton {Pressed:false,ButtonIndex:MouseButton.Left} && _pressing)
        {
            UpdateDrag(); // Motion and release may arrive before the next frame.
            _pressing=false;
            if (_dragged)
            {
                foreach (var (cell,group,index) in _targets)
                    if (new Rect2(Vector2.Zero,cell.Size).HasPoint(cell.GetGlobalTransformWithCanvas().AffineInverse()*_pointer)) { Drop(group,index); break; }
                CancelDrag(); GetViewport().SetInputAsHandled();
            }
        }
    }
    public override void _Process(double delta)
    {
        if (!Visible) return;
        if (!CanEdit) CancelInteraction(); else UpdateDrag();
        if (BatchUpgrading && GetNode<Control>("Upgrade").Visible && !GetNode<Control>("Notice").Visible)
        { _batchTime+=delta; if (_batchTime>=.5) { _batchTime=0; UpgradeOnce(true); } }
    }
    private void Notice(string message)
    { CancelDrag(); HideTooltip(); SetText("Notice/Text",message); GetNode<Control>("Notice").Show(); }
    private void HideTooltip() => GetNode<Control>("Tooltip").Hide();
    private void SkillTooltip(int id)
    {
        if (!CanEdit || _pressing) return;
        var row=Loadout.Find(id); if (row==null) return; int level=Loadout.Level(id);
        bool details=row["type"].AsInt32()==1 && level>0 && row.GetValueOrDefault("hide_level_info",0).AsInt32()==0;
        string stats=details?$"技能等级: Lv.{level}\n冷却时间: {Sample(row,"cooldown",level):0.##}\n消耗魔法: {Sample(row,"mp",level):0.##}":"";
        ShowTooltip(row["name"].AsString(),row["description"].AsString(),stats);
    }
    private void ItemTooltip(int index)
    { if (_page*16+index<_items.Count) { var item=_items[_page*16+index]; ShowTooltip(item.Get("name").AsString(),item.Get("description").AsString()); } }
    private void TargetTooltip(string group,int index)
    { if (group=="item") { var item=Loadout.FindItem(Loadout.Items[index]); if (item!=null) ShowTooltip(item.Get("name").AsString(),item.Get("description").AsString()); } else SkillTooltip(Equipped(group,index)); }
    private void ShowTooltip(string name,string description,string stats="")
    {
        if (!CanEdit || _pressing) return;
        SetText("Tooltip/Name",name); SetText("Tooltip/Stats",stats); SetText("Tooltip/Text",description);
        var body=GetNode<Label>("Tooltip/Text"); var stat=GetNode<Label>("Tooltip/Stats"); stat.Visible=stats.Length>0;
        body.Position=new Vector2(20,stats.Length>0?125:50);
        float height=Math.Max(20,body.GetThemeFont("font").GetMultilineStringSize(description,HorizontalAlignment.Left,260,body.GetThemeFontSize("font_size")).Y+Math.Max(0,body.GetLineCount()-1)*4);
        body.Size=new Vector2(260,height); GetNode<Control>("Tooltip").Size=new Vector2(290,body.Position.Y+height+20);
        PositionTooltip();
        RefreshOverlayLayer(); GetNode<Control>("Tooltip").Show();
    }
    private void PositionTooltip()
    {
        var tip=GetNode<Control>("Tooltip");
        tip.Position=(LocalPointer+new Vector2(15,15)).Clamp(Vector2.Zero,(Size-tip.Size).Max(Vector2.Zero));
    }
    public override void _ExitTree()
    {
        if (IsInstanceValid(_window)) _window!.FocusExited -= CancelInteraction;
        _window=null;
        _items.Clear();
        if (Loadout==null || !IsInstanceValid(Loadout)) return;
        if (Loadout.IsConnected(BattleSkillLoadout.SignalName.Changed,_changed)) Loadout.Disconnect(BattleSkillLoadout.SignalName.Changed,_changed);
        foreach (var (obj,signal,callback) in new[] {( (GodotObject)Loadout.Inventory,"currency_changed",_currency),((GodotObject)Loadout.Inventory,"item_changed",_inventoryChanged),(Loadout.Actor.Get("attributes").AsGodotObject(),"snapshot_changed",_attributes),(_bindings!,"mapping_changed",_mapping),(_bindings!,"remap_finished",_remapFinished),(_bindings!,"remap_failed",_remapFailed)})
            if (IsInstanceValid(obj) && obj.IsConnected(signal,callback)) obj.Disconnect(signal,callback);
        _bindings?.Call("cancel_remap");
    }
}
