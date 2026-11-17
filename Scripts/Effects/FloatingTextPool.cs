using System.Collections.Generic;
using Godot;

namespace PigeonRush.Effects;

/// <summary>Testi 3D che salgono e svaniscono (+punti, "Close call!", ecc.).</summary>
public partial class FloatingTextPool : Node3D
{
    private sealed class Entry
    {
        public Label3D Label = null!;
        public Color Color;
        public float Age;
        public float Life;
        public bool Active;
    }

    private const int PoolSize = 12;
    private readonly List<Entry> _entries = new();

    public override void _Ready()
    {
        for (var i = 0; i < PoolSize; i++)
        {
            var label = new Label3D
            {
                Billboard = BaseMaterial3D.BillboardModeEnum.Enabled,
                NoDepthTest = true,
                FontSize = 64,
                OutlineSize = 14,
                PixelSize = 0.008f,
                Visible = false,
            };
            AddChild(label);
            _entries.Add(new Entry { Label = label });
        }
    }

    public void Spawn(string text, Color color, Vector3 position, float scale = 1f, float life = 0.9f)
    {
        var entry = GetFree();
        entry.Active = true;
        entry.Age = 0f;
        entry.Life = life;
        entry.Color = color;

        var label = entry.Label;
        label.Text = text;
        label.PixelSize = 0.008f * scale;
        label.Position = position;
        label.Modulate = color;
        label.OutlineModulate = new Color(0f, 0f, 0f, 0.85f);
        label.Visible = true;
    }

    public void Tick(float dt)
    {
        foreach (var entry in _entries)
        {
            if (!entry.Active)
                continue;

            entry.Age += dt;
            var t = entry.Age / entry.Life;
            if (t >= 1f)
            {
                entry.Active = false;
                entry.Label.Visible = false;
                continue;
            }

            var label = entry.Label;
            label.Position += new Vector3(0f, 2.2f * dt, 0f);
            var alpha = t < 0.6f ? 1f : 1f - (t - 0.6f) / 0.4f;
            label.Modulate = new Color(entry.Color, alpha);
            label.OutlineModulate = new Color(0f, 0f, 0f, 0.85f * alpha);
        }
    }

    private Entry GetFree()
    {
        Entry? oldest = null;
        foreach (var entry in _entries)
        {
            if (!entry.Active)
                return entry;
            if (oldest == null || entry.Age > oldest.Age)
                oldest = entry;
        }

        return oldest!;
    }
}
