using System.Collections.Generic;
using Godot;
using PigeonRush.Core;

namespace PigeonRush.World;

/// <summary>
/// Ostacolo che scorre verso il piccione. Le hitbox sono AABB locali (nessuna rotazione):
/// collisioni manuali, deterministiche ed economiche anche su mobile.
/// </summary>
public abstract partial class Hazard : Node3D
{
    protected readonly List<Aabb> LocalBoxes = new();

    public int BoxCount => LocalBoxes.Count;

    /// <summary>Celle della griglia corsie × fasce occupate da questo ostacolo.</summary>
    public int CellMask { get; protected set; }

    /// <summary>Già superato il piccione (per il calcolo del passaggio a filo).</summary>
    public bool PassedPigeon { get; set; }

    /// <summary>Si è sovrapposto al piccione almeno una volta.</summary>
    public bool TouchedPigeon { get; set; }

    /// <summary>Estremo posteriore (Z minima) in coordinate mondo, usato per il despawn.</summary>
    public virtual float RearZ
    {
        get
        {
            var min = float.MaxValue;
            foreach (var box in LocalBoxes)
                min = Mathf.Min(min, box.Position.Z);
            return Position.Z + (LocalBoxes.Count > 0 ? min : 0f);
        }
    }

    /// <summary>Estremo anteriore (Z massima, verso il piccione) in coordinate mondo.</summary>
    public float FrontZ
    {
        get
        {
            var max = float.MinValue;
            foreach (var box in LocalBoxes)
                max = Mathf.Max(max, box.Position.Z + box.Size.Z);
            return Position.Z + (LocalBoxes.Count > 0 ? max : 0f);
        }
    }

    /// <summary>Animazioni opzionali (luci lampeggianti ecc.).</summary>
    public virtual void Animate(float dt)
    {
    }

    /// <summary>Hitbox in coordinate mondo, estesa all'indietro di <paramref name="sweep"/> per non "saltare" il piccione ad alta velocità.</summary>
    public Aabb WorldBox(int index, float sweep = 0f)
    {
        var local = LocalBoxes[index];
        var origin = Position + local.Position;
        return new Aabb(
            new Vector3(origin.X, origin.Y, origin.Z - sweep),
            new Vector3(local.Size.X, local.Size.Y, local.Size.Z + sweep));
    }

    protected void ResetFlags()
    {
        PassedPigeon = false;
        TouchedPigeon = false;
    }

    /// <summary>Distanza minima sul piano XY tra due box (0 se si sovrappongono).</summary>
    public static float GapXY(Aabb a, Aabb b)
    {
        var gx = Mathf.Max(0f, Mathf.Max(a.Position.X - b.End.X, b.Position.X - a.End.X));
        var gy = Mathf.Max(0f, Mathf.Max(a.Position.Y - b.End.Y, b.Position.Y - a.End.Y));
        return Mathf.Sqrt(gx * gx + gy * gy);
    }

    protected static int LaneMask(int lane, int band) => Cells.Of(lane, band);
}
