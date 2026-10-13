using Godot;
using System.Collections.Generic;

/// <summary>GUI picking follows scene order, not CanvasItem.z_index.</summary>
public partial class UiModalManager : Node
{
    private static readonly List<Control> Windows = new();
    private readonly Dictionary<Control, (Callable Changed,Callable Exiting)> _subscriptions = new();
    private static long _sequence;
    public static Control? Top
    {
        get
        {
            Control? result = null; long order = -1;
            foreach (var window in Windows)
                if (IsInstanceValid(window) && window.IsVisibleInTree() && window.GetMeta("modal_order", 0).AsInt64() > order)
                { result = window; order = window.GetMeta("modal_order", 0).AsInt64(); }
            return result;
        }
    }
    public static bool CanReceive(Control owner)
    {
        var top = Top;
        return top == null || top == owner || top.IsAncestorOf(owner) || owner.IsAncestorOf(top);
    }
    public override void _Ready()
    {
        ProcessMode = ProcessModeEnum.Always;
    }
    public void RegisterBranch(Control root)
    {
        Register(root);
        foreach (var child in root.GetChildren()) if (child is Control control) RegisterBranch(control);
    }
    private void Register(Node node)
    {
        if (node is not Control window || !window.GetMeta("ui_modal", false).AsBool() || _subscriptions.ContainsKey(window)) return;
        Windows.Add(window);
        var changed = Callable.From(() => Promote(window));
        var exiting = Callable.From(() => Remove(window));
        _subscriptions.Add(window, (changed,exiting)); window.Connect(Control.SignalName.VisibilityChanged, changed);
        window.Connect(Node.SignalName.TreeExiting,exiting);
        if (window.IsVisibleInTree()) changed.CallDeferred();
    }
    private void Promote(Control window)
    {
        if (!IsInstanceValid(window) || !window.IsVisibleInTree()) return;
        window.SetMeta("modal_order", ++_sequence);
        var visible = Windows.FindAll(w => IsInstanceValid(w) && w.IsVisibleInTree());
        visible.Sort((a,b) => a.GetMeta("modal_order",0).AsInt64().CompareTo(b.GetMeta("modal_order",0).AsInt64()));
        for (int i=0;i<visible.Count;++i) { visible[i].ZAsRelative=false; visible[i].ZIndex=Mathf.Min(4090,500+i*100); }
        // Defer mutation: visibility callbacks may run while children enter the tree.
        Callable.From(() =>
        {
            if (!IsInstanceValid(window) || !window.IsVisibleInTree()) return;
            for (Node item = window; item.GetParent() is Control || item.GetParent() is CanvasLayer; item = item.GetParent())
                item.GetParent().MoveChild(item, -1);
        }).CallDeferred();
    }
    private void Remove(Node node)
    {
        if (node is not Control window || !_subscriptions.Remove(window, out var changed)) return;
        Windows.Remove(window);
        if (window.IsConnected(Control.SignalName.VisibilityChanged, changed.Changed)) window.Disconnect(Control.SignalName.VisibilityChanged, changed.Changed);
        if (window.IsConnected(Node.SignalName.TreeExiting,changed.Exiting)) window.Disconnect(Node.SignalName.TreeExiting,changed.Exiting);
    }
    public override void _ExitTree()
    {
        foreach (var pair in _subscriptions)
            if (IsInstanceValid(pair.Key))
            {
                if (pair.Key.IsConnected(Control.SignalName.VisibilityChanged, pair.Value.Changed)) pair.Key.Disconnect(Control.SignalName.VisibilityChanged, pair.Value.Changed);
                if (pair.Key.IsConnected(Node.SignalName.TreeExiting,pair.Value.Exiting)) pair.Key.Disconnect(Node.SignalName.TreeExiting,pair.Value.Exiting);
            }
        _subscriptions.Clear(); Windows.Clear();
    }
}
