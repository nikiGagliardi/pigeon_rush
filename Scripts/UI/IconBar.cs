using Godot;

namespace PigeonRush.UI;

/// <summary>Barra di icone disegnate (munizioni, segmenti boost): nessuna texture necessaria.</summary>
public partial class IconBar : Control
{
    public enum IconShape
    {
        Circle,
        Poop,
        Segment,
    }

    private int _value = -1;

    public int Max { get; set; } = 3;
    public IconShape Shape { get; set; } = IconShape.Circle;
    public Color OnColor { get; set; } = Colors.White;
    public Color OffColor { get; set; } = new(1f, 1f, 1f, 0.2f);
    public float IconSize { get; set; } = 26f;
    public float Gap { get; set; } = 6f;

    public override void _Ready()
    {
        MouseFilter = MouseFilterEnum.Ignore;
        CustomMinimumSize = new Vector2(Max * (IconSize + Gap) - Gap, IconSize);
    }

    public void SetValue(int value)
    {
        if (value == _value)
            return;
        _value = value;
        QueueRedraw();
    }

    public override void _Draw()
    {
        for (var i = 0; i < Max; i++)
        {
            var color = i < _value ? OnColor : OffColor;
            var left = i * (IconSize + Gap);
            var center = new Vector2(left + IconSize * 0.5f, IconSize * 0.5f);

            switch (Shape)
            {
                case IconShape.Circle:
                    DrawCircle(center, IconSize * 0.42f, color);
                    break;
                case IconShape.Segment:
                    DrawRect(new Rect2(left, IconSize * 0.3f, IconSize, IconSize * 0.4f), color);
                    break;
                case IconShape.Poop:
                    // tre "gocce" impilate, con contorno scuro per leggibilità su qualsiasi sfondo
                    var s = IconSize;
                    var outline = new Color(0f, 0f, 0f, color.A * 0.6f);
                    DrawCircle(center + new Vector2(0f, 0.2f * s), 0.4f * s, outline);
                    DrawCircle(center + new Vector2(0f, 0.2f * s), 0.34f * s, color);
                    DrawCircle(center + new Vector2(0f, -0.04f * s), 0.29f * s, outline);
                    DrawCircle(center + new Vector2(0f, -0.04f * s), 0.24f * s, color);
                    DrawCircle(center + new Vector2(0.02f * s, -0.25f * s), 0.18f * s, outline);
                    DrawCircle(center + new Vector2(0.02f * s, -0.25f * s), 0.13f * s, color);
                    break;
            }
        }
    }
}
