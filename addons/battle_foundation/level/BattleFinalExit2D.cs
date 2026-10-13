using Godot;

/// <summary>Authored exit anchor: preview in the editor, activation area follows its transform.</summary>
[Tool]
[GlobalClass]
public partial class BattleFinalExit2D : Marker2D
{
	[Export] public bool preview_animation { get; set; } = true;
	[Export] public Vector2 activation_size { get; set; } = new(260, 260);
	[Export] public Vector2 activation_offset { get; set; } = new(0, -110);
	private AnimationPlayer? _preview;
	private Vector2 _lastSize, _lastOffset, _lastGatewayPosition;
	private bool _wasAnimating;

	public Rect2 get_exit_rect() => GlobalTransform * LocalExitRect();
	// Gateway carries a display scale of 2; follow its position, while keeping
	// the independently authored activation dimensions in anchor units.
	private Vector2 GatewayOffset => GetNodeOrNull<Node2D>("Gateway")?.Position ?? Vector2.Zero;
	private Rect2 LocalExitRect() => new(GatewayOffset + activation_offset - activation_size * 0.5f, activation_size);

	public override void _Ready()
	{
		SetProcess(Engine.IsEditorHint());
		if (!Engine.IsEditorHint()) return;
		var gateway = GetNode<Node2D>("Gateway");
		gateway.Visible = true;
		_preview = gateway.GetNode<AnimationPlayer>("AnimationPlayer");
		_preview.CallbackModeProcess = AnimationMixer.AnimationCallbackModeProcess.Manual;
		_preview.Play(gateway.Get("clip").AsStringName());
		_preview.Advance(0);
		_wasAnimating = preview_animation;
		QueueRedraw();
	}

	public override void _Process(double delta)
	{
		if (!Engine.IsEditorHint() || !IsInstanceValid(_preview)) return;
		if (preview_animation) _preview!.Advance(delta);
		else if (_wasAnimating) _preview!.Seek(0, true);
		_wasAnimating = preview_animation;
		if (_lastSize != activation_size || _lastOffset != activation_offset || _lastGatewayPosition != GatewayOffset)
		{
			_lastSize = activation_size; _lastOffset = activation_offset; _lastGatewayPosition = GatewayOffset;
			QueueRedraw();
		}
	}

	public override void _Draw()
	{
		if (!Engine.IsEditorHint()) return;
		DrawRect(LocalExitRect(), new Color(1, 0.8f, 0.15f, 0.08f));
		DrawRect(LocalExitRect(), new Color(1, 0.8f, 0.15f, 0.7f), false, 2);
	}
}
