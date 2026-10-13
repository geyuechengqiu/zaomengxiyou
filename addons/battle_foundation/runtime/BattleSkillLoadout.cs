using Godot;
using Godot.Collections;
using System;
using Array = Godot.Collections.Array;

/// <summary>Per-character original skills, levels and equipped slots. No shared resource mutation.</summary>
public partial class BattleSkillLoadout : Node
{
    [Signal] public delegate void ChangedEventHandler();
    public Array<Dictionary> Rows { get; private set; } = new();
    public Dictionary Levels { get; private set; } = new();
    public Array<int> Active { get; private set; } = new() {1101010,1101020,1101030,1101040,0};
    public int Passive { get; private set; } = 1301010;
    public int Peerless { get; private set; } = 1201010;
    public Array<string> Items { get; private set; } = new() {"", ""};
    public string LastError { get; private set; } = "";
    public Node Actor { get; private set; } = null!;
    public Node Inventory => Actor.Get("inventory").As<Node>();
    public GodotObject Abilities => Actor.Get("abilities").AsGodotObject();
    public Node Operations => Actor.Get("operations").As<Node>();
    public int RoleLevel => Actor.Get("attributes").AsGodotObject().Get("current_level").AsInt32();
    private BattleDamageRules Rules => Actor.Get("damage_rules").As<BattleDamageRules>();
    private bool _initialized;
    private Control? _hud;
    private Node? _bus;
    private Callable _eventCallback;

    public override void _Ready() => Callable.From(Initialize).CallDeferred();
    public void Initialize()
    {
        if (_initialized) return;
        Actor = GetParent();
        if (!IsInstanceValid(Actor.Get("abilities").AsGodotObject())) return;
        _initialized = true;
        foreach (var row in GD.Load<Json>("res://data/characters/sunwukong/skills/panel_rules.json").Data.AsGodotDictionary()["skills"].AsGodotArray())
        {
            var data = row.AsGodotDictionary(); Rows.Add(data);
            Levels[data["id"].AsInt32().ToString()] = data["initial_level"];
        }
        _bus = GetNode("/root/CoreSystem").Get("event_bus").As<Node>();
        _eventCallback = Callable.From<string, Array>(OnBattleEvent);
        _bus.Connect("event_pushed", _eventCallback);
        Apply();
    }
    public Dictionary? Find(int id) { foreach (var row in Rows) if (row["id"].AsInt32() == id) return row; return null; }
    public int Level(int id) => Levels.GetValueOrDefault(id.ToString(), 0).AsInt32();
    public bool Available(int id) => Find(id)?.GetValueOrDefault("available", false).AsBool() ?? false;
    public bool Learned(int id) => Available(id) && Level(id) > 0;
    public GodotObject? Ability(int id)
    {
        var row = Find(id); string key = row?.GetValueOrDefault("ability", "").AsString() ?? "";
        return key.Length == 0 ? null : Abilities.Call("get_ability_instance", new StringName(key)).AsGodotObject();
    }
    public Dictionary? Next(int id)
    {
        if (!Available(id)) return null;
        var row = Find(id)!;
        foreach (var entry in row["levels"].AsGodotArray())
        { var next = entry.AsGodotDictionary(); if (next["level"].AsInt32() == Level(id) + 1) return next; }
        return null;
    }
    private bool Reject(string message) { LastError = message; return false; }
    public bool Upgrade(int id)
    {
        var row = Find(id);
        if (row == null || !Available(id)) return Reject("转职后才能学习此技能");
        if (row["type"].AsInt32() != 1) return Reject("被动与无双技能随角色解锁");
        var next = Next(id);
        if (next == null) return Reject("技能已满级");
        if (RoleLevel < next["role_level"].AsInt32()) return Reject($"人物需达到{next["role_level"].AsInt32()}级");
        long cost = next["spirit"].AsInt64(), spirit = Inventory.Get("spirit").AsInt64();
        if (cost < 0 || spirit < cost) return Reject("灵魂不足");
        bool newlyLearned = Level(id) == 0;
        Levels[id.ToString()] = next["level"];
        Inventory.Set("spirit", spirit - cost);
        if (newlyLearned)
            for (int i = 0; i < Active.Count; ++i) if (Active[i] == 0) { Active[i] = id; break; }
        LastError = ""; Apply();
        Inventory.EmitSignal("currency_changed", spirit - cost);
        EmitSignal(SignalName.Changed); return true;
    }
    public double Remaining(int id)
    {
        var ability = Ability(id);
        if (!IsInstanceValid(ability)) return 0;
        var feature = ability!.Call("get_feature", "CooldownFeature").AsGodotObject();
        return IsInstanceValid(feature) ? feature.Call("get_cooldown_remaining", ability).AsDouble() : 0;
    }
    private bool Busy(int id)
    {
        if (id == 0) return false;
        var ability = Ability(id);
        return Remaining(id) > 0 || (IsInstanceValid(ability) && ability!.Get("is_active").AsBool());
    }
    public bool Equip(string group, int index, int id)
    {
        int type = group == "active" ? 1 : group == "passive" ? 2 : group == "peerless" ? 3 : 0;
        if (type == 0 || index < 0 || index >= (type == 1 ? 5 : 1)) return Reject("装配位置无效");
        if (!Learned(id) || Find(id)!["type"].AsInt32() != type) return Reject("技能未学习或类型不匹配");
        int old = type == 1 ? Active[index] : type == 2 ? Passive : Peerless;
        if (old == id) return true;
        if (Busy(old) || Busy(id)) return Reject("技能释放或冷却中，不能更换");
        if (type == 1) { for (int i = 0; i < Active.Count; ++i) if (Active[i] == id) Active[i] = 0; Active[index] = id; }
        else if (type == 2) Passive = id; else Peerless = id;
        LastError = ""; Apply(); EmitSignal(SignalName.Changed); return true;
    }
    public bool Unequip(string group, int index)
    {
        if (group == "item") { if (index < 0 || index > 1) return Reject("装配位置无效"); Items[index] = ""; }
        else if (group == "active")
        {
            if (index < 0 || index >= Active.Count) return Reject("装配位置无效");
            if (Busy(Active[index])) return Reject("技能释放或冷却中，不能卸下");
            Active[index] = 0;
        }
        else return Reject("被动与无双技能无需卸下");
        LastError = ""; Apply(); EmitSignal(SignalName.Changed); return true;
    }
    public bool MoveSlot(string group, int source, int target)
    {
        int count=group=="active"?Active.Count:group=="item"?Items.Count:0;
        if (source<0 || target<0 || source>=count || target>=count) return Reject("装配位置无效");
        if (group=="active")
        {
            if (Active[source]==0) return Reject("来源格子为空");
            if (Busy(Active[source]) || Busy(Active[target])) return Reject("技能释放或冷却中，不能更换");
            if (source==target) return true;
            (Active[source],Active[target])=(Active[target],Active[source]);
        }
        else
        {
            if (FindItem(Items[source])==null || (Items[target].Length>0 && FindItem(Items[target])==null)) return Reject("道具不存在或不能在战斗中使用");
            if (source==target) return true;
            (Items[source],Items[target])=(Items[target],Items[source]);
        }
        LastError=""; Apply(); EmitSignal(SignalName.Changed); return true;
    }
    public bool EquipItem(int index, string id)
    {
        if (index < 0 || index > 1 || FindItem(id) == null) return Reject("道具不存在或不能在战斗中使用");
        for (int i = 0; i < 2; ++i) if (Items[i] == id) Items[i] = "";
        Items[index] = id; LastError = ""; EmitSignal(SignalName.Changed); return true;
    }
    public GodotObject? FindItem(string id)
    {
        if (id.Length == 0) return null;
        foreach (var value in Inventory.Get("items").AsGodotArray())
        {
            if (value.VariantType != Variant.Type.Object || !IsInstanceValid(value.AsGodotObject())) continue;
            var item = value.AsGodotObject();
            if (item.Get("item_id").AsString() == id && UsableItem(item)) return item;
        }
        return null;
    }
    public static bool UsableItem(GodotObject item)
    {
        var data = item.Get("original_data").AsGodotDictionary();
        if (item.Get("quantity").AsInt32() <= 0 || data.GetValueOrDefault("isUse", 0).AsInt32() == 0) return false;
        for (int i = 1; i <= 3; ++i)
            if (data.GetValueOrDefault("attributeT" + i, "").AsString() is "hp" or "mp") return true;
        return false;
    }
    public void BindHUD(Control hud) { _hud = hud; RefreshHUD(); }
    private void SetEnabled(string key, bool enabled)
    {
        var ability = Abilities.Call("get_ability_instance", new StringName(key)).AsGodotObject();
        if (IsInstanceValid(ability)) ability.Set("disabled", !enabled);
    }
    private void SyncActive(string key, bool learned)
    {
        var id = new StringName(key);
        bool exists = Abilities.Call("has_ability", id).AsBool();
        if (!learned) { if (exists) Abilities.Call("forget_ability", id); return; }
        if (!exists) Abilities.Call("learn_ability", GD.Load<Resource>("res://data/characters/sunwukong/skills/" + key.Replace("sunwukong_", "") + ".tres").Call("duplicate_deep", 2));
        SetEnabled(key, true);
    }
    private void Apply()
    {
        foreach (var row in Rows)
        {
            string key = row["ability"].AsString(); int id = row["id"].AsInt32();
            if (key.Length > 0)
            {
                Rules.skill_levels[new StringName(key)] = Level(id);
                if (row["type"].AsInt32() == 1) SyncActive(key, Learned(id)); else SetEnabled(key, Learned(id));
            }
        }
        // Compound attacks inherit their parent's level and learning restriction.
        Rules.skill_levels[new StringName("sunwukong_skill4_1")] = Level(1101040);
        Rules.skill_levels[new StringName("sunwukong_skill8_slam")] = 0;
        SyncActive("sunwukong_skill4_1", Learned(1101040)); SyncActive("sunwukong_skill8_slam", false);
        Rules.remove_source("skills.passive");
        if (Passive == 1301010 && Learned(Passive)) Rules.set_source("skills.passive", new Dictionary { ["passive_id"] = Passive });
        var slots = Operations.Get("ability_slots").AsGodotDictionary();
        for (int i = 0; i < Active.Count; ++i)
            slots[new StringName("skill_" + (i + 1))] = new StringName(Learned(Active[i]) ? Find(Active[i])!["ability"].AsString() : "");
        SyncBranches();
        RefreshHUD();
    }
    private void SyncBranches()
    {
        for (int i = 0; i < Active.Count; ++i)
        {
            if (!Learned(Active[i])) continue;
            var ability = Ability(Active[i]);
            var timeline = ability?.Call("get_feature", "BattleFrameTimelineFeature").AsGodotObject();
            if (!IsInstanceValid(timeline)) continue;
            // Branch resources belong to this actor's ability instance. Copy the
            // array and entries before rebinding; cached .tres defaults stay intact.
            var branches = timeline!.Get("branch_windows").AsGodotArray().Duplicate();
            for (int b = 0; b < branches.Count; ++b)
            {
                var original = branches[b].As<BattleSkillBranch>();
                if (!original.target_ability_id.ToString().StartsWith("sunwukong_skill", StringComparison.Ordinal)) continue;
                var branch = (BattleSkillBranch)original.Duplicate();
                branch.operation = "skill_" + (i + 1);
                branches[b] = branch;
            }
            timeline.Set("branch_windows", branches);
        }
    }
    public void RefreshHUD()
    {
        if (!IsInstanceValid(_hud)) return;
        var abilities = _hud!.Get("_abilities").AsGodotArray();
        var cooldowns = _hud.Get("_cooldowns").AsGodotArray();
        if (abilities.Count != 5 || cooldowns.Count != 5) return;
        for (int i = 0; i < 5; ++i)
        {
            var ability = Learned(Active[i]) ? Ability(Active[i]) : null;
            abilities[i] = IsInstanceValid(ability) ? Variant.From(ability) : default;
            var cooldown = IsInstanceValid(ability) ? ability!.Call("get_feature", "CooldownFeature").AsGodotObject() : null;
            cooldowns[i] = IsInstanceValid(cooldown) ? Variant.From(cooldown) : default;
            var slot = _hud.GetNode("Skills/Slots").GetChild(i);
            slot.GetNode<TextureRect>("Icon").Texture = IsInstanceValid(ability) ? ability!.Call("get_definition").AsGodotObject().Get("icon").As<Texture2D>() : null;
        }
    }
    public Dictionary SaveData() => new()
    {
        ["version"] = 1, ["levels"] = Levels.Duplicate(true), ["active"] = Active.Duplicate(),
        ["passive"] = Passive, ["peerless"] = Peerless, ["items"] = Items.Duplicate()
    };
    public void Restore(Dictionary saved)
    {
        Initialize();
        if (saved.GetValueOrDefault("version", 0).AsInt32() != 1) { Apply(); return; }
        var levels = saved.GetValueOrDefault("levels", new Dictionary()).AsGodotDictionary();
        foreach (var row in Rows)
        {
            int id = row["id"].AsInt32();
            int maximum = row["type"].AsInt32() == 1 ? row["levels"].AsGodotArray().Count : 1;
            Levels[id.ToString()] = Available(id) ? Math.Clamp(levels.GetValueOrDefault(id.ToString(), Levels[id.ToString()]).AsInt32(), 0, maximum) : 0;
        }
        var active = saved.GetValueOrDefault("active", new Array()).AsGodotArray();
        var used = new System.Collections.Generic.HashSet<int>();
        for (int i = 0; i < 5; ++i)
        {
            int id = i < active.Count ? active[i].AsInt32() : 0;
            Active[i] = Learned(id) && Find(id)!["type"].AsInt32() == 1 && used.Add(id) ? id : 0;
        }
        Passive = saved.GetValueOrDefault("passive", 1301010).AsInt32() == 1301010 && Learned(1301010) ? 1301010 : 0;
        Peerless = 1201010;
        var items = saved.GetValueOrDefault("items", new Array()).AsGodotArray();
        for (int i = 0; i < 2; ++i) Items[i] = i < items.Count ? items[i].AsString() : "";
        if (Items[0] == Items[1]) Items[1] = "";
        LastError = ""; Apply(); EmitSignal(SignalName.Changed);
    }
    private void OnBattleEvent(string id, Array payload)
    {
        if (id != "battle.operation_intent" || payload.Count != 1) return;
        var data = payload[0].AsGodotDictionary();
        if (data.GetValueOrDefault("source_entity_id").AsStringName() != Actor.Get("entity_id").AsStringName() || data.GetValueOrDefault("phase").AsString() != "pressed") return;
        string intent = data.GetValueOrDefault("intent").AsString();
        if (intent is not ("item_1" or "item_2") || !Operations.Get("controller").AsGodotObject().Call("has_control").AsBool() || !Actor.Call("is_alive").AsBool()) return;
        int index = intent == "item_1" ? 0 : 1; var item = FindItem(Items[index]);
        if (item != null) Inventory.Call("use_item", item);
    }
    public override void _ExitTree()
    {
        if (IsInstanceValid(_bus) && _bus!.IsConnected("event_pushed", _eventCallback)) _bus.Disconnect("event_pushed", _eventCallback);
        if (_initialized && IsInstanceValid(Actor) && IsInstanceValid(Rules)) Rules.remove_source("skills.passive");
    }
}
