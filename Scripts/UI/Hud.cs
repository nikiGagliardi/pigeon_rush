using System;
using Godot;
using PigeonRush.Core;
using PigeonRush.Rendering;

namespace PigeonRush.UI;

/// <summary>HUD costruito da codice. Legge lo stato della sessione ogni frame e aggiorna i testi solo se cambiano.</summary>
public partial class Hud : Control
{
    private Label _score = null!;
    private Label _distance = null!;
    private Label _best = null!;
    private Label _combo = null!;
    private Label _speed = null!;
    private Label _lock = null!;
    private Label _lowFly = null!;
    private IconBar _lives = null!;
    private IconBar _ammo = null!;
    private IconBar _boost = null!;

    private long _lastScore = -1;
    private int _lastDistance = -1;
    private int _lastCombo = -1;
    private int _lastBoost = -1;
    private float _comboPop;

    public event Action? PausePressed;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;

        // --- in alto a sinistra: punteggio ---
        var left = new VBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
        left.AddThemeConstantOverride("separation", 0);
        _score = UiStyle.MakeLabel("0", 48, Colors.White);
        _distance = UiStyle.MakeLabel("0 m", 24, new Color(1f, 1f, 1f, 0.9f));
        _best = UiStyle.MakeLabel("", 20, Palette.Gold);
        left.AddChild(_score);
        left.AddChild(_distance);
        left.AddChild(_best);
        AddChild(left);
        left.SetAnchorsAndOffsetsPreset(LayoutPreset.TopLeft, LayoutPresetMode.Minsize, 22);

        // --- in alto a destra: piume, cacca, boost, pausa ---
        var right = new VBoxContainer { MouseFilter = MouseFilterEnum.Ignore, Alignment = BoxContainer.AlignmentMode.Begin };
        right.AddThemeConstantOverride("separation", 8);

        var topRow = new HBoxContainer { MouseFilter = MouseFilterEnum.Ignore, Alignment = BoxContainer.AlignmentMode.End };
        topRow.AddThemeConstantOverride("separation", 16);
        _lives = new IconBar { Max = GameConfig.MaxLives, Shape = IconBar.IconShape.Feather, OnColor = Colors.White, IconSize = 34f };
        topRow.AddChild(_lives);
        var pause = new Button { Text = "II", FocusMode = FocusModeEnum.None, CustomMinimumSize = new Vector2(64f, 56f) };
        pause.AddThemeFontSizeOverride("font_size", 26);
        pause.AddThemeStyleboxOverride("normal", UiStyle.Flat(new Color(0f, 0f, 0f, 0.35f), 12));
        pause.AddThemeStyleboxOverride("hover", UiStyle.Flat(new Color(0f, 0f, 0f, 0.5f), 12));
        pause.AddThemeStyleboxOverride("pressed", UiStyle.Flat(new Color(0f, 0f, 0f, 0.6f), 12));
        pause.Pressed += () => PausePressed?.Invoke();
        topRow.AddChild(pause);
        right.AddChild(topRow);

        var ammoRow = MakeRow("POOP", out var ammoHolder);
        _ammo = new IconBar { Max = GameConfig.MaxAmmo, Shape = IconBar.IconShape.Circle, OnColor = Palette.Poop, IconSize = 18f, Gap = 4f };
        ammoHolder.AddChild(_ammo);
        right.AddChild(ammoRow);

        var boostRow = MakeRow("BOOST", out var boostHolder);
        _boost = new IconBar { Max = GameConfig.MaxBoostStacks, Shape = IconBar.IconShape.Segment, OnColor = Palette.Info, IconSize = 30f, Gap = 4f };
        boostHolder.AddChild(_boost);
        right.AddChild(boostRow);

        _speed = UiStyle.MakeLabel("", 20, Palette.Info, HorizontalAlignment.Right);
        right.AddChild(_speed);

        AddChild(right);
        right.GrowHorizontal = GrowDirection.Begin;
        right.SetAnchorsAndOffsetsPreset(LayoutPreset.TopRight, LayoutPresetMode.Minsize, 22);

        // --- centro in alto: combo ---
        _combo = UiStyle.MakeLabel("", 44, Palette.Gold, HorizontalAlignment.Center);
        AddChild(_combo);
        _combo.GrowHorizontal = GrowDirection.Both;
        _combo.SetAnchorsAndOffsetsPreset(LayoutPreset.CenterTop, LayoutPresetMode.Minsize, 24);
        _combo.PivotOffset = new Vector2(0f, 30f);

        // --- centro in basso: suggerimenti ---
        var bottom = new VBoxContainer { MouseFilter = MouseFilterEnum.Ignore, Alignment = BoxContainer.AlignmentMode.End };
        _lock = UiStyle.MakeLabel("TARGET LOCKED! Drop now", 30, Palette.Reticle, HorizontalAlignment.Center);
        _lowFly = UiStyle.MakeLabel("LOW FLYING  x1.5", 22, Palette.Info, HorizontalAlignment.Center);
        bottom.AddChild(_lock);
        bottom.AddChild(_lowFly);
        AddChild(bottom);
        bottom.GrowHorizontal = GrowDirection.Both;
        bottom.GrowVertical = GrowDirection.Begin;
        bottom.SetAnchorsAndOffsetsPreset(LayoutPreset.CenterBottom, LayoutPresetMode.Minsize, 36);
        _lock.Modulate = new Color(1f, 1f, 1f, 0f);
        _lowFly.Modulate = new Color(1f, 1f, 1f, 0f);
    }

    public void SetBest(long best) => _best.Text = best > 0 ? $"Best {UiFormat.Number(best)}" : "";

    public void Refresh(float dt, GameSession session, bool locked, bool lowFlying)
    {
        var score = session.Score;
        if (score.Score != _lastScore)
        {
            _lastScore = score.Score;
            _score.Text = UiFormat.Number(_lastScore);
        }

        var metres = (int)score.Distance;
        if (metres != _lastDistance)
        {
            _lastDistance = metres;
            _distance.Text = $"{UiFormat.Number(metres)} m";
        }

        _lives.SetValue(session.Lives);
        _ammo.SetValue(session.Ammo);

        var stacks = session.Speed.BoostStacks;
        _boost.SetValue(stacks);
        if (stacks != _lastBoost)
        {
            _lastBoost = stacks;
            _speed.Text = stacks > 0 ? $"SPEED x{UiFormat.Multiplier(session.Speed.Multiplier)}" : "";
        }

        var combo = score.Combo;
        if (combo != _lastCombo)
        {
            if (combo > _lastCombo && combo >= 2)
                _comboPop = 1f;
            _lastCombo = combo;
            _combo.Text = combo >= 2 ? $"COMBO x{score.ComboMultiplier}" : "";
        }

        _comboPop = Mathf.Max(0f, _comboPop - dt * 4f);
        var popScale = 1f + _comboPop * 0.35f;
        _combo.Scale = new Vector2(popScale, popScale);
        _combo.Modulate = new Color(1f, 1f, 1f, combo >= 2 ? 0.5f + 0.5f * Mathf.Clamp(score.ComboTimeLeft * 2f, 0f, 1f) : 0f);

        FadeTo(_lock, locked && session.Ammo > 0 ? 1f : 0f, dt);
        FadeTo(_lowFly, lowFlying ? 1f : 0f, dt);
    }

    private static void FadeTo(Control control, float alpha, float dt)
    {
        var current = control.Modulate.A;
        var next = Mathf.MoveToward(current, alpha, dt * 6f);
        if (!Mathf.IsEqualApprox(current, next))
            control.Modulate = new Color(1f, 1f, 1f, next);
    }

    private static HBoxContainer MakeRow(string caption, out HBoxContainer holder)
    {
        var row = new HBoxContainer { MouseFilter = MouseFilterEnum.Ignore, Alignment = BoxContainer.AlignmentMode.End };
        row.AddThemeConstantOverride("separation", 10);
        row.AddChild(UiStyle.MakeLabel(caption, 18, new Color(1f, 1f, 1f, 0.8f)));
        holder = new HBoxContainer { MouseFilter = MouseFilterEnum.Ignore };
        row.AddChild(holder);
        return row;
    }
}
