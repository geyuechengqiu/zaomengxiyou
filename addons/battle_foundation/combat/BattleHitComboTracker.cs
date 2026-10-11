using Godot;
using Godot.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;

[GlobalClass]
public partial class BattleHitComboTracker : Node
{
    [Signal] public delegate void combo_changedEventHandler(StringName owner_id, long count, long maximum);
    [Export(PropertyHint.Range, "0.01,10.0")] public double timeout_seconds { get; set; } = 1.5;
    public long maximum_combo { get; private set; }
    public Node session => GetParent();
    private sealed class Role { public long Count; public long Maximum; public double LastHit; }
    private readonly System.Collections.Generic.Dictionary<StringName, Role> _roles = new();
    private readonly System.Collections.Generic.Dictionary<StringName, StringName> _owners = new();
    private readonly HashSet<long> _pending = new();
    private long _settledFloor;
    private StringName[] _roleIds = [];
    private bool _roleIdsChanged;
    private Node _eventBus = null!;
    private Callable _eventCallback;
    private double Now => session.Get("clock").As<BattleClock>().elapsed;

    public override void _EnterTree()
    {
        _settledFloor = session.Get("_damage_serial").AsInt64();
        _eventBus = GetNode("/root/CoreSystem").Get("event_bus").As<Node>();
        _eventCallback = Callable.From<string, Array>(OnEvent);
        _eventBus.Connect("event_pushed", _eventCallback);
    }
    public override void _ExitTree()
    {
        if (IsInstanceValid(_eventBus) && _eventBus.IsConnected("event_pushed", _eventCallback))
            _eventBus.Disconnect("event_pushed", _eventCallback);
    }
    public void register_role(StringName owner_id)
    {
        if (_roles.TryAdd(owner_id, new Role())) _roleIdsChanged = true;
    }
    public int get_pending_settlement_count() => _pending.Count;
    public int get_registered_role_count() => _roles.Count;
    public int get_hit_owner_count() => _owners.Count;
    public bool set_hit_owner(StringName source_id, StringName owner_id)
    {
        if (!_roles.ContainsKey(owner_id)) return false;
        _owners[source_id] = owner_id;
        return true;
    }
    public long get_count(StringName owner_id) => _roles.TryGetValue(owner_id, out var role) ? role.Count : 0;
    public long get_maximum(StringName owner_id) => _roles.TryGetValue(owner_id, out var role) ? role.Maximum : 0;
    public void advance_combat()
    {
        // Callbacks can despawn a role, so iteration must use a stable ID snapshot.
        if (_roleIdsChanged) { _roleIds = _roles.Keys.ToArray(); _roleIdsChanged = false; }
        foreach (var id in _roleIds) Expire(id);
    }
    private void Expire(StringName id)
    {
        if (_roles.TryGetValue(id, out var row) && row.Count > 0 && Now - row.LastHit >= timeout_seconds - 0.0000001)
            reset_chain(id);
    }
    public void reset_chain(StringName owner_id)
    {
        if (!_roles.TryGetValue(owner_id, out var row) || row.Count == 0) return;
        row.Count = 0;
        Notify(owner_id);
    }
    public void clear_battle()
    {
        foreach (var id in _roles.Keys.ToArray()) reset_chain(id);
        _roles.Clear(); _owners.Clear(); _pending.Clear();
        _roleIds = []; _roleIdsChanged = false;
        _settledFloor = session.Get("_damage_serial").AsInt64();
        maximum_combo = 0;
    }
    public void remove_entity(StringName entity_id)
    {
        reset_chain(entity_id);
        if (_roles.Remove(entity_id)) _roleIdsChanged = true;
        _owners.Remove(entity_id);
        foreach (var key in _owners.Where(pair => pair.Value == entity_id).Select(pair => pair.Key).ToArray())
            _owners.Remove(key);
    }
    private void Notify(StringName id)
    {
        EmitSignal(SignalName.combo_changed, id, get_count(id), get_maximum(id));
        session.Call("publish_event", new StringName("battle.hit_combo.changed"), session.Call("get_entity", id), default(Variant),
            new Dictionary { ["owner_id"] = id, ["count"] = get_count(id), ["maximum"] = get_maximum(id), ["level_maximum"] = maximum_combo });
    }
    private void OnEvent(string id, Array payload)
    {
        if (payload.Count != 1 || payload[0].VariantType != Variant.Type.Dictionary) return;
        var data = payload[0].AsGodotDictionary();
        if (data.GetValueOrDefault("battle_id").AsStringName() != session.Get("battle_id").AsStringName()) return;
        switch (id)
        {
            case "battle.entity_spawned" when data.GetValueOrDefault("category").AsString() == "characters":
                register_role(data["target_entity_id"].AsStringName()); return;
            case "battle.entity.killed": reset_chain(data["target_entity_id"].AsStringName()); return;
            case "battle.entity_despawned": remove_entity(data["target_entity_id"].AsStringName()); return;
            case "battle.damage.settled": break;
            default: return;
        }
        string damageId = data.GetValueOrDefault("damage_id", "").AsString();
        int separator = damageId.IndexOf("/damage/", System.StringComparison.Ordinal);
        long serial = separator >= 0 && long.TryParse(damageId[(separator + 8)..], NumberStyles.Integer, CultureInfo.InvariantCulture, out long value) ? value : 0;
        if (serial <= _settledFloor || !_pending.Add(serial)) return;
        while (_pending.Remove(_settledFloor + 1)) _settledFloor++;
        if (data.GetValueOrDefault("damage_kind", new StringName("attack")).AsStringName() != "attack"
            || data.GetValueOrDefault("normal_damage", 0).AsDouble() == 0
            || data.GetValueOrDefault("is_dodged", false).AsBool() || data.GetValueOrDefault("is_immune", false).AsBool()) return;
        var source = data["source_entity_id"].AsStringName();
        var ownerId = _owners.GetValueOrDefault(source, source);
        if (!_roles.TryGetValue(ownerId, out var row)) return;
        var owner = session.Call("get_entity", ownerId).AsGodotObject();
        if (!IsInstanceValid(owner) || !owner.Call("is_alive").AsBool()) return;
        Expire(ownerId);
        row.Count++;
        row.Maximum = System.Math.Max(row.Maximum, row.Count);
        maximum_combo = System.Math.Max(maximum_combo, row.Count);
        row.LastHit = Now;
        Notify(ownerId);
    }
}
