using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;
using Array = Godot.Collections.Array;

/// <summary>Source campaign order and persistent character instances.</summary>
public partial class ZaomengOneCampaign : Node
{
    public const string MapScene = "res://game/world_map/zaomeng1_world_map.tscn";
    public const string SavePath = "user://zaomeng1-campaign.cfg";
    public string MapName { get; private set; } = "东胜神洲（七魔王）";
    public Array<Dictionary> Levels { get; private set; } = new();
    public int unlocked_index { get; private set; }
    public string active_level_id { get; private set; } = "";
    public Dictionary character_state { get; private set; } = new();
    public bool persistence_enabled { get; set; } = true;
    private readonly HashSet<string> _completed = new(), _settledBattles = new();
    private bool _changing;

    public override void _Ready()
    {
        var data = GD.Load<Json>("res://data/campaigns/zaomeng1/world_map.json").Data.AsGodotDictionary();
        MapName = data.GetValueOrDefault("display_name", MapName).AsString();
        foreach (var row in data["levels"].AsGodotArray()) Levels.Add(row.AsGodotDictionary());
        LoadProgress();
    }
    public Dictionary? Find(string id)
    {
        foreach (var row in Levels) if (row["id"].AsString() == id) return row;
        return null;
    }
    public bool IsUnlocked(string id)
    {
        for (int i = 0; i < Levels.Count; ++i) if (Levels[i]["id"].AsString() == id) return i <= unlocked_index;
        return false;
    }
    public bool IsCompleted(string id) => _completed.Contains(id);
    public bool CanEnter(string id) => IsUnlocked(id) && (Find(id)?.GetValueOrDefault("scene").AsString().Length ?? 0) > 0;
    public bool Enter(string id)
    {
        if (_changing || !CanEnter(id)) return false;
        string scene = Find(id)!["scene"].AsString();
        if (!ResourceLoader.Exists(scene)) return false;
        string previousId = active_level_id;
        active_level_id = id;
        _changing = true;
        bool accepted = GetLoadingScreen().Begin(Find(id)!, success =>
        {
            _changing = false;
            if (!success) active_level_id = previousId;
        });
        if (!accepted) { _changing = false; active_level_id = previousId; }
        return accepted;
    }
    public StageLoadingScreen GetLoadingScreen()
    {
        var screen = GetNodeOrNull<StageLoadingScreen>("/root/StageLoadingScreen");
        if (screen != null) return screen;
        screen = GD.Load<PackedScene>("res://game/loading/stage_loading_screen.tscn").Instantiate<StageLoadingScreen>();
        GetTree().Root.AddChild(screen);
        return screen;
    }
    public bool ReturnToMap() => ChangeScene(MapScene);
    private bool ChangeScene(string path)
    {
        if (_changing) return false;
        _changing = true;
        Callable.From(() =>
        {
            GetTree().Paused = false;
            Error result = GetTree().ChangeSceneToFile(path);
            _changing = false;
            if (result != Error.Ok) GD.PushError($"场景切换失败：{path} ({result})");
        }).CallDeferred();
        return true;
    }
    // Boss death alone cannot unlock anything: the flow must accept the final
    // exit after every participating region, birth plan and condition completes.
    public bool RecordVictory(string id, Node flow, StringName battleId)
    {
        var row = Find(id);
        if (row == null || !IsUnlocked(id) || flow.Get("state").AsInt32() != 2 || battleId.IsEmpty) return false;
        if (flow.Get("definition").AsGodotObject().Get("definition_id").AsString() != row["name"].AsString()) return false;
        if (!_settledBattles.Add(battleId.ToString())) return false;
        _completed.Add(id);
        for (int i = 0; i < Levels.Count; ++i)
            if (Levels[i]["id"].AsString() == id) unlocked_index = Math.Max(unlocked_index, Math.Min(Levels.Count - 1, i + 1));
        SaveProgress(); return true;
    }
    public void CaptureCharacter(Node player)
    {
        var attrs = player.Get("attributes").AsGodotObject();
        var inventory = player.Get("inventory").As<Node>();
        var items = new Array(); var equipped = new Dictionary();
        foreach (var value in inventory.Get("items").AsGodotArray())
            if (value.VariantType == Variant.Type.Object && IsInstanceValid(value.AsGodotObject())) items.Add(value.AsGodotObject().Call("get_save_data"));
        foreach (var slot in inventory.Get("equip_slots").AsGodotDictionary())
        {
            var item = slot.Value.AsGodotArray()[1];
            if (item.VariantType == Variant.Type.Object && IsInstanceValid(item.AsGodotObject())) equipped[slot.Key] = item.AsGodotObject().Call("get_save_data");
        }
        character_state = new()
        {
            ["level"] = attrs.Get("current_level"), ["exp"] = attrs.Call("get_value", new StringName("exp")),
            ["spirit"] = inventory.Get("spirit"), ["display_name"] = inventory.Get("display_name"),
            ["player_number"] = inventory.Get("player_number"), ["show_fashion"] = inventory.Get("show_fashion"),
            ["bag_capacities"] = inventory.Get("bag_capacities").AsGodotDictionary().Duplicate(true),
            ["items"] = items, ["equipped"] = equipped,
            ["skills"] = player.GetNode<BattleSkillLoadout>("SkillLoadout").SaveData()
        };
        SaveProgress();
    }
    public void RestoreCharacter(Node player, Node session)
    {
        if (character_state.Count == 0) return;
        var attrs = player.Get("attributes").AsGodotObject();
        attrs.Call("set_level", character_state["level"]); attrs.Call("set_experience", character_state["exp"]);
        var inventory = player.Get("inventory").As<Node>();
        inventory.Get("items").AsGodotArray().Fill(default);
        var slots = inventory.Get("equip_slots").AsGodotDictionary();
        foreach (var slot in slots) slot.Value.AsGodotArray()[1] = default;
        var catalog = session.GetNode("Loot").Get("catalog").AsGodotObject();
        var capacities = inventory.Get("bag_capacities").AsGodotDictionary(); capacities.Clear();
        foreach (var pair in character_state["bag_capacities"].AsGodotDictionary()) capacities[pair.Key] = pair.Value;
        foreach (var row in character_state["items"].AsGodotArray())
        {
            var item = RestoreItem(row.AsGodotDictionary(), catalog);
            if (item != null) inventory.Call("try_add_item", item, false);
        }
        foreach (var pair in character_state["equipped"].AsGodotDictionary())
        {
            var item = RestoreItem(pair.Value.AsGodotDictionary(), catalog);
            if (item == null || !slots.ContainsKey(pair.Key)) continue;
            item.Get("runtime").AsGodotObject().Set("owner_inventory_id", inventory.GetInstanceId());
            slots[pair.Key].AsGodotArray()[1] = item;
        }
        inventory.Set("spirit", character_state["spirit"]); inventory.Set("player_number", character_state["player_number"]);
        inventory.Call("set_display_name", character_state["display_name"]); inventory.Set("show_fashion", character_state["show_fashion"]);
        inventory.Call("_notify_equipment", new StringName("campaign_restore")); inventory.EmitSignal("item_changed");
        if (character_state.TryGetValue("skills", out var savedSkills) && savedSkills.VariantType == Variant.Type.Dictionary)
            player.GetNode<BattleSkillLoadout>("SkillLoadout").Restore(savedSkills.AsGodotDictionary());
        foreach (string id in new[] { "health", "mana" })
        {
            var vital = attrs.Call("get_vital", new StringName(id)).AsGodotObject();
            vital.Call("set_current_value", vital.Call("get_max_value"));
        }
    }
    private static GodotObject? RestoreItem(Dictionary row, GodotObject catalog)
    {
        var definition = catalog.Call("get_definition", new StringName(row["item_id"].AsString())).AsGodotObject();
        if (!IsInstanceValid(definition)) return null;
        var item = definition.Call("create_instance").AsGodotObject();
        item.Set("quantity", row["quantity"]); item.Set("locked", row["locked"]);
        var state = item.Get("runtime").AsGodotObject();
        foreach (var pair in row["state"].AsGodotDictionary()) state.Set(pair.Key.AsString(), pair.Value);
        return item;
    }
    public void SaveProgress()
    {
        if (!persistence_enabled) return;
        var file = new ConfigFile(); file.SetValue("campaign", "version", 1);
        file.SetValue("campaign", "completed", new Array<string>(_completed)); file.SetValue("character", "state", character_state);
        Error result = file.Save(SavePath);
        if (result != Error.Ok) GD.PushError($"造1进度保存失败：{result}");
    }
    public void LoadProgress()
    {
        _completed.Clear(); _settledBattles.Clear(); unlocked_index = 0; character_state = new();
        var file = new ConfigFile();
        if (file.Load(SavePath) != Error.Ok || file.GetValue("campaign", "version", 0).AsInt32() != 1) return;
        foreach (var value in file.GetValue("campaign", "completed", new Array()).AsGodotArray())
            if (Find(value.AsString()) != null) _completed.Add(value.AsString());
        while (unlocked_index < Levels.Count - 1 && _completed.Contains(Levels[unlocked_index]["id"].AsString())) ++unlocked_index;
        character_state = file.GetValue("character", "state", new Dictionary()).AsGodotDictionary();
    }
}
