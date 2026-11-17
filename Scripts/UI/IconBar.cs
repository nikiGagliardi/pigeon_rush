using Godot;

namespace PigeonRush.UI;

/// <summary>Barra di icone disegnate (piume, munizioni, segmenti boost): nessuna texture necessaria.</summary>
public partial class IconBar : Control
{
    public enum IconShape
    {
        Circle,
        Feather,
        Segment,
    }

    private static readonly Vector2[] FeatherShape =
    {
        new(0f, -0.5f), new(0.2f, -0.2f), new(0.2f, 0.2f), new(0.04f, 0.5f),
        new(-0.04f, 0.5f), new(-0.2f, 0.2f), new(-0.2f, -0.2f),
    };

    private readonly Vector2[] _scratch = new Vector2[FeatherShape.Length];
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
                case IconShape.Feather:
                    var rotation = Mathf.DegToRad(25f);
                    for (var p = 0; p < FeatherShape.Length; p++)
                        _scratch[p] = center + FeatherShape[p].Rotated(rotation) * IconSize;
                    DrawColoredPolygon(_scratch, color);
                    DrawLine(center + new Vector2(0f, 0.55f).Rotated(rotation) * IconSize,
                        center + new Vector2(0f, -0.35f).Rotated(rotation) * IconSize,
                        new Color(0f, 0f, 0f, 0.35f), 2f);
                    break;
            }
        }
    }
}
