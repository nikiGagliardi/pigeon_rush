using Godot;
using PigeonRush.Rendering;

namespace PigeonRush.UI;

/// <summary>
/// Controlli touch: metà sinistra = joystick flottante (appare dove appoggi il dito),
/// metà destra = sgancio. Attivi solo su dispositivi con touchscreen.
/// </summary>
public partial class TouchControls : Control
{
    private const float StickRadius = 95f;
    private const float KnobRadius = 40f;
    private const float PoopButtonRadius = 78f;
    private static readonly Vector2 PauseArea = new(200f, 130f);

    private bool _enabled;
    private int _stickIndex = -1;
    private Vector2 _origin;
    private Vector2 _knob;
    private bool _poopQueued;
    private float _poopFlash;
    private int _ammo = -1;

    public Vector2 MoveVector { get; private set; }

    /// <summary>Cacche disponibili, mostrate sul pulsante DROP.</summary>
    public int Ammo
    {
        get => _ammo;
        set
        {
            if (value == _ammo)
                return;
            _ammo = value;
            if (Visible)
                QueueRedraw();
        }
    }

    public static bool IsTouchDevice => DisplayServer.IsTouchscreenAvailable();

    public bool Enabled
    {
        get => _enabled;
        set
        {
            _enabled = value;
            ResetState();
            Visible = value && IsTouchDevice;
        }
    }

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;
        Visible = false;
    }

    /// <summary>Restituisce true una sola volta per ogni tocco sul lato destro.</summary>
    public bool ConsumePoop()
    {
        var queued = _poopQueued;
        _poopQueued = false;
        return queued;
    }

    public override void _Process(double delta)
    {
        if (_poopFlash <= 0f)
            return;
        _poopFlash = Mathf.Max(0f, _poopFlash - (float)delta * 5f);
        QueueRedraw();
    }

    public override void _Input(InputEvent @event)
    {
        if (!_enabled)
            return;

        var size = GetViewportRect().Size;
        switch (@event)
        {
            case InputEventScreenTouch touch when touch.Pressed:
                if (touch.Position.X > size.X - PauseArea.X && touch.Position.Y < PauseArea.Y)
                    return; // lascia lavorare il pulsante pausa

                if (touch.Position.X < size.X * 0.5f)
                {
                    if (_stickIndex < 0)
                    {
                        _stickIndex = touch.Index;
                        _origin = touch.Position;
                        _knob = touch.Position;
                        UpdateVector();
                    }
                }
                else
                {
                    _poopQueued = true;
                    _poopFlash = 1f;
                }

                QueueRedraw();
                break;

            case InputEventScreenTouch touch when !touch.Pressed:
                if (touch.Index == _stickIndex)
                {
                    _stickIndex = -1;
                    MoveVector = Vector2.Zero;
                    QueueRedraw();
                }

                break;

            case InputEventScreenDrag drag when drag.Index == _stickIndex:
                _knob = drag.Position;
                UpdateVector();
                QueueRedraw();
                break;
        }
    }

    public override void _Draw()
    {
        var size = GetViewportRect().Size;

        if (_stickIndex >= 0)
        {
            DrawCircle(_origin, StickRadius, new Color(1f, 1f, 1f, 0.1f));
            DrawArc(_origin, StickRadius, 0f, Mathf.Tau, 48, new Color(1f, 1f, 1f, 0.35f), 3f);
            DrawCircle(_knob, KnobRadius, new Color(1f, 1f, 1f, 0.45f));
        }
        else
        {
            var hint = new Vector2(170f, size.Y - 170f);
            DrawArc(hint, StickRadius, 0f, Mathf.Tau, 48, new Color(1f, 1f, 1f, 0.18f), 3f);
            DrawCircle(hint, KnobRadius * 0.6f, new Color(1f, 1f, 1f, 0.15f));
        }

        var button = new Vector2(size.X - 170f, size.Y - 170f);
        var empty = _ammo == 0;
        var fill = empty ? Palette.Danger : Palette.Poop;
        fill.A = (empty ? 0.25f : 0.3f) + _poopFlash * 0.4f;
        DrawCircle(button, PoopButtonRadius * (1f + _poopFlash * 0.12f), fill);
        DrawArc(button, PoopButtonRadius, 0f, Mathf.Tau, 48, new Color(1f, 1f, 1f, 0.6f), 3f);

        var font = GetThemeDefaultFont();
        var ink = new Color(0.15f, 0.12f, 0.08f);
        DrawString(font, button + new Vector2(-PoopButtonRadius, -6f), "DROP",
            HorizontalAlignment.Center, PoopButtonRadius * 2f, 24, ink);
        DrawString(font, button + new Vector2(-PoopButtonRadius, 34f), _ammo >= 0 ? _ammo.ToString() : "",
            HorizontalAlignment.Center, PoopButtonRadius * 2f, 40, empty ? Colors.White : ink);
    }

    private void UpdateVector()
    {
        var delta = _knob - _origin;
        if (delta.Length() > StickRadius)
        {
            // joystick "trascinabile": l'origine segue il dito
            delta = delta.Normalized() * StickRadius;
            _origin = _knob - delta;
        }

        MoveVector = new Vector2(delta.X / StickRadius, -delta.Y / StickRadius);
    }

    private void ResetState()
    {
        _stickIndex = -1;
        _poopQueued = false;
        MoveVector = Vector2.Zero;
        QueueRedraw();
    }
}
