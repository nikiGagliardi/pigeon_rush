using System;
using Godot;
using PigeonRush.Audio;

namespace PigeonRush.UI;

/// <summary>Helper per creare controlli con stile coerente (tutto da codice, nessun .tres).</summary>
public static class UiStyle
{
    public static readonly Color PanelBg = new(0.07f, 0.09f, 0.14f, 0.9f);
    public static readonly Color Accent = new("ffd54a");
    public static readonly Color AccentDark = new("e0a800");
    public static readonly Color TextDark = new("1d1d1d");

    public static Label MakeLabel(string text, int fontSize, Color color, HorizontalAlignment align = HorizontalAlignment.Left)
    {
        var label = new Label
        {
            Text = text,
            HorizontalAlignment = align,
            MouseFilter = Control.MouseFilterEnum.Ignore,
        };
        label.AddThemeFontSizeOverride("font_size", fontSize);
        label.AddThemeColorOverride("font_color", color);
        label.AddThemeColorOverride("font_outline_color", new Color(0f, 0f, 0f, 0.85f));
        label.AddThemeConstantOverride("outline_size", Math.Max(4, fontSize / 6));
        return label;
    }

    public static Button MakeButton(string text, int fontSize = 34)
    {
        var button = new Button
        {
            Text = text,
            CustomMinimumSize = new Vector2(340f, 84f),
        };
        button.Pressed += () => GameAudio.Instance?.PlayUi(Sfx.UiClick);
        button.AddThemeFontSizeOverride("font_size", fontSize);
        button.AddThemeColorOverride("font_color", TextDark);
        button.AddThemeColorOverride("font_hover_color", TextDark);
        button.AddThemeColorOverride("font_pressed_color", TextDark);
        button.AddThemeColorOverride("font_focus_color", TextDark);
        button.AddThemeStyleboxOverride("normal", Flat(Accent, 18));
        button.AddThemeStyleboxOverride("hover", Flat(Accent.Lightened(0.15f), 18));
        button.AddThemeStyleboxOverride("pressed", Flat(AccentDark, 18));

        var focus = Flat(new Color(0f, 0f, 0f, 0f), 18);
        focus.DrawCenter = false;
        focus.BorderColor = Colors.White;
        focus.SetBorderWidthAll(4);
        button.AddThemeStyleboxOverride("focus", focus);
        return button;
    }

    public static StyleBoxFlat Flat(Color color, int radius, float margin = 12f)
    {
        var style = new StyleBoxFlat { BgColor = color };
        style.SetCornerRadiusAll(radius);
        style.SetContentMarginAll(margin);
        return style;
    }

    public static PanelContainer MakePanel()
    {
        var panel = new PanelContainer();
        panel.AddThemeStyleboxOverride("panel", Flat(PanelBg, 26, 44f));
        return panel;
    }
}
