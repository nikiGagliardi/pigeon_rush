using System;
using Godot;
using PigeonRush.Core;
using PigeonRush.Rendering;

namespace PigeonRush.UI;

/// <summary>Schermate a tutto schermo: titolo, pausa, game over. Gira anche col gioco in pausa.</summary>
public partial class Screens : Control
{
    private Control _title = null!;
    private Control _pause = null!;
    private Control _gameOver = null!;
    private Button _playButton = null!;
    private Button _resumeButton = null!;
    private Button _retryButton = null!;
    private Label _titleBest = null!;
    private Label _overScore = null!;
    private Label _overStats = null!;
    private Label _overRecord = null!;

    public event Action? StartPressed;
    public event Action? ResumePressed;
    public event Action? RestartPressed;

    public override void _Ready()
    {
        SetAnchorsPreset(LayoutPreset.FullRect);
        MouseFilter = MouseFilterEnum.Ignore;
        ProcessMode = ProcessModeEnum.Always;

        BuildTitle();
        BuildPause();
        BuildGameOver();
        HideAll();
    }

    public void ShowTitle(long best)
    {
        HideAll();
        _titleBest.Text = best > 0 ? $"Best: {UiFormat.Number(best)}" : "";
        _title.Visible = true;
        _playButton.GrabFocus();
    }

    public void ShowPause()
    {
        HideAll();
        _pause.Visible = true;
        _resumeButton.GrabFocus();
    }

    public void ShowGameOver(GameSession session, long best, bool newRecord)
    {
        HideAll();
        var score = session.Score;
        _overScore.Text = UiFormat.Number(score.Score);
        _overStats.Text =
            $"{UiFormat.Number((long)score.Distance)} m flown\n{score.Hits} vehicles splatted  •  best combo x{Math.Min(score.BestCombo, GameConfig.MaxComboMultiplier)}\n{score.NearMisses} close calls";
        _overRecord.Text = newRecord ? "NEW BEST!" : $"Best: {UiFormat.Number(best)}";
        _overRecord.AddThemeColorOverride("font_color", newRecord ? Palette.Gold : new Color(1f, 1f, 1f, 0.8f));
        _gameOver.Visible = true;
        _retryButton.GrabFocus();
    }

    public void HideAll()
    {
        _title.Visible = false;
        _pause.Visible = false;
        _gameOver.Visible = false;
        GetViewport()?.GuiReleaseFocus();
    }

    public override void _UnhandledInput(InputEvent @event)
    {
        if (_pause.Visible && @event.IsActionPressed(Actions.Pause))
        {
            GetViewport().SetInputAsHandled();
            ResumePressed?.Invoke();
        }
    }

    private void BuildTitle()
    {
        _title = MakeOverlay(0.25f, out var box);
        box.AddChild(UiStyle.MakeLabel("PIGEON RUSH", 76, Palette.Gold, HorizontalAlignment.Center));
        box.AddChild(UiStyle.MakeLabel("Wrong way down the motorway. Dodge, splat, speed up!", 24, Colors.White, HorizontalAlignment.Center));
        box.AddChild(Spacer(10f));

        _playButton = UiStyle.MakeButton("PLAY");
        _playButton.Pressed += () => StartPressed?.Invoke();
        box.AddChild(Centered(_playButton));

        _titleBest = UiStyle.MakeLabel("", 24, Palette.Gold, HorizontalAlignment.Center);
        box.AddChild(_titleBest);
        box.AddChild(Spacer(6f));

        var help = TouchControls.IsTouchDevice
            ? "Left side: drag to fly  •  Right side: tap to drop"
            : "WASD / arrows: fly  •  Space: drop  •  Esc: pause\nGamepad: left stick  •  A / right trigger";
        box.AddChild(UiStyle.MakeLabel(help, 20, new Color(1f, 1f, 1f, 0.75f), HorizontalAlignment.Center));
        box.AddChild(UiStyle.MakeLabel("One hit and you're out! Splat vehicles to fly faster, grab crumbs to refill your poop.", 18,
            new Color(1f, 1f, 1f, 0.6f), HorizontalAlignment.Center));
    }

    private void BuildPause()
    {
        _pause = MakeOverlay(0.5f, out var box);
        box.AddChild(UiStyle.MakeLabel("PAUSED", 64, Colors.White, HorizontalAlignment.Center));
        box.AddChild(Spacer(8f));

        _resumeButton = UiStyle.MakeButton("RESUME");
        _resumeButton.Pressed += () => ResumePressed?.Invoke();
        box.AddChild(Centered(_resumeButton));

        var restart = UiStyle.MakeButton("RESTART");
        restart.Pressed += () => RestartPressed?.Invoke();
        box.AddChild(Centered(restart));
    }

    private void BuildGameOver()
    {
        _gameOver = MakeOverlay(0.45f, out var box);
        box.AddChild(UiStyle.MakeLabel("SQUASHED!", 64, Palette.Danger, HorizontalAlignment.Center));
        _overScore = UiStyle.MakeLabel("0", 72, Colors.White, HorizontalAlignment.Center);
        box.AddChild(_overScore);
        _overRecord = UiStyle.MakeLabel("", 28, Palette.Gold, HorizontalAlignment.Center);
        box.AddChild(_overRecord);
        _overStats = UiStyle.MakeLabel("", 22, new Color(1f, 1f, 1f, 0.85f), HorizontalAlignment.Center);
        box.AddChild(_overStats);
        box.AddChild(Spacer(8f));

        _retryButton = UiStyle.MakeButton("TRY AGAIN");
        _retryButton.Pressed += () => RestartPressed?.Invoke();
        box.AddChild(Centered(_retryButton));
    }

    private Control MakeOverlay(float dim, out VBoxContainer box)
    {
        var root = new Control { MouseFilter = MouseFilterEnum.Stop };
        AddChild(root);
        root.SetAnchorsPreset(LayoutPreset.FullRect);

        var shade = new ColorRect { Color = new Color(0f, 0f, 0f, dim), MouseFilter = MouseFilterEnum.Ignore };
        root.AddChild(shade);
        shade.SetAnchorsPreset(LayoutPreset.FullRect);

        var center = new CenterContainer { MouseFilter = MouseFilterEnum.Ignore };
        root.AddChild(center);
        center.SetAnchorsPreset(LayoutPreset.FullRect);

        var panel = UiStyle.MakePanel();
        center.AddChild(panel);

        box = new VBoxContainer { Alignment = BoxContainer.AlignmentMode.Center };
        box.AddThemeConstantOverride("separation", 14);
        panel.AddChild(box);
        return root;
    }

    private static Control Centered(Control child)
    {
        var holder = new CenterContainer { MouseFilter = MouseFilterEnum.Ignore };
        holder.AddChild(child);
        return holder;
    }

    private static Control Spacer(float height) => new()
    {
        CustomMinimumSize = new Vector2(0f, height),
        MouseFilter = MouseFilterEnum.Ignore,
    };
}
