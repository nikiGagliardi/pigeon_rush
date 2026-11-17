using Godot;
using PigeonRush.Rendering;

namespace PigeonRush.Player;

/// <summary>
/// Piccione low-poly procedurale (piccione torraiolo). Guarda verso -Z.
/// Parti animate: testa (oscilla), coda (segue il battito), ali in due segmenti
/// (braccio + mano) con la mano in ritardo di fase per un battito "a onda".
/// </summary>
public partial class PigeonModel : Node3D
{
    private static readonly Vector3 HeadPivot = new(0f, 0.2f, -0.4f);
    private static readonly Vector3 TailPivot = new(0f, 0.03f, 0.4f);
    private const float ShoulderX = 0.17f;
    private const float ElbowX = 0.44f;

    private static ArrayMesh? _bodyMesh;
    private static ArrayMesh? _headMesh;
    private static ArrayMesh? _tailMesh;
    private static readonly ArrayMesh?[] InnerWingMeshes = new ArrayMesh?[2];
    private static readonly ArrayMesh?[] OuterWingMeshes = new ArrayMesh?[2];

    private readonly Node3D _head;
    private readonly Node3D _tail;
    private readonly Node3D[] _shoulders = new Node3D[2];
    private readonly Node3D[] _elbows = new Node3D[2];
    private float _phase;

    public PigeonModel()
    {
        AddChild(new MeshInstance3D { Mesh = BodyMesh });

        _head = new Node3D { Position = HeadPivot };
        _head.AddChild(new MeshInstance3D { Mesh = HeadMesh });
        AddChild(_head);

        _tail = new Node3D { Position = TailPivot };
        _tail.AddChild(new MeshInstance3D { Mesh = TailMesh });
        AddChild(_tail);

        for (var i = 0; i < 2; i++)
        {
            var side = i == 0 ? -1f : 1f;
            _shoulders[i] = new Node3D { Position = new Vector3(side * ShoulderX, 0.1f, -0.06f) };
            _shoulders[i].AddChild(new MeshInstance3D { Mesh = InnerWing(side) });
            _elbows[i] = new Node3D { Position = new Vector3(side * ElbowX, 0f, 0f) };
            _elbows[i].AddChild(new MeshInstance3D { Mesh = OuterWing(side) });
            _shoulders[i].AddChild(_elbows[i]);
            AddChild(_shoulders[i]);
        }
    }

    /// <param name="rate">Velocità angolare del battito (rad/s).</param>
    /// <param name="amplitude">Ampiezza del braccio in radianti (la mano aggiunge un'onda in ritardo).</param>
    public void Flap(float dt, float rate, float amplitude = 0.75f)
    {
        _phase += dt * rate;
        var arm = Mathf.Sin(_phase) * amplitude + 0.1f;
        var hand = Mathf.Sin(_phase - 0.8f) * amplitude * 0.65f;
        SetWings(arm, hand);

        // la testa resta quasi ferma mentre il corpo sobbalza; la coda compensa il battito
        _head.Position = HeadPivot + new Vector3(0f, -Mathf.Sin(_phase) * 0.012f, 0f);
        _head.Rotation = new Vector3(Mathf.Sin(_phase) * 0.05f, 0f, 0f);
        _tail.Rotation = new Vector3(-0.08f + Mathf.Sin(_phase + 0.5f) * 0.07f, 0f, 0f);
    }

    /// <summary>Ali aperte e ferme (planata / caduta).</summary>
    public void Glide(float dt)
    {
        var k = 1f - Mathf.Exp(-6f * dt);
        for (var i = 0; i < 2; i++)
        {
            var side = i == 0 ? -1f : 1f;
            _shoulders[i].Rotation = _shoulders[i].Rotation.Lerp(new Vector3(0f, 0f, side * 0.12f), k);
            _elbows[i].Rotation = _elbows[i].Rotation.Lerp(new Vector3(0f, 0f, side * 0.06f), k);
        }

        _tail.Rotation = _tail.Rotation.Lerp(new Vector3(-0.15f, 0f, 0f), k);
    }

    /// <param name="arm">Angolo del braccio (positivo = ala alzata).</param>
    /// <param name="hand">Angolo aggiuntivo della mano rispetto al braccio.</param>
    private void SetWings(float arm, float hand)
    {
        for (var i = 0; i < 2; i++)
        {
            var side = i == 0 ? -1f : 1f;
            // rotazione su Z: positiva alza l'ala destra, negativa alza la sinistra
            _shoulders[i].Rotation = new Vector3(0f, 0f, side * arm);
            _elbows[i].Rotation = new Vector3(0f, 0f, side * hand);
        }
    }

    // ------------------------------------------------------------------ mesh

    private static ArrayMesh BodyMesh => _bodyMesh ??= BuildBody();
    private static ArrayMesh HeadMesh => _headMesh ??= BuildHead();
    private static ArrayMesh TailMesh => _tailMesh ??= BuildTail();

    private static ArrayMesh InnerWing(float side)
    {
        var i = side < 0f ? 0 : 1;
        return InnerWingMeshes[i] ??= BuildInnerWing(side);
    }

    private static ArrayMesh OuterWing(float side)
    {
        var i = side < 0f ? 0 : 1;
        return OuterWingMeshes[i] ??= BuildOuterWing(side);
    }

    private static ArrayMesh BuildBody()
    {
        var b = new LowPolyBuilder()
            .Sphere(0.3f, new Vector3(0f, 0f, 0.02f), new Vector3(1f, 0.88f, 1.5f), Palette.PigeonBody, 14, 9)            // corpo
            .Sphere(0.26f, new Vector3(0f, -0.07f, 0.05f), new Vector3(0.95f, 0.72f, 1.35f), Palette.PigeonBelly, 12, 7)  // pancia
            .Sphere(0.23f, new Vector3(0f, 0.01f, -0.27f), new Vector3(1f, 1f, 0.95f), Palette.PigeonChest, 12, 8)        // petto
            .Sphere(0.17f, new Vector3(0f, 0.15f, -0.36f), new Vector3(1f, 1.05f, 0.9f), Palette.PigeonNeck, 12, 7)       // collo verde
            .Sphere(0.15f, new Vector3(0f, 0.08f, -0.41f), new Vector3(1.05f, 0.8f, 0.8f), Palette.PigeonNeckPurple, 12, 7) // riflesso viola
            .Sphere(0.17f, new Vector3(0f, 0.07f, 0.36f), new Vector3(1f, 0.55f, 1f), Palette.PigeonRump, 10, 6);         // groppone chiaro

        // zampe raccolte sotto il corpo
        foreach (var x in new[] { -0.08f, 0.08f })
        {
            b.Cylinder(0.022f, 0.026f, 0.1f, new Vector3(x, -0.24f, 0.1f), Palette.Foot, 6, new Vector3(-30f, 0f, 0f));
            for (var t = -1; t <= 1; t++)
                b.Box(new Vector3(0.018f, 0.018f, 0.075f), new Vector3(x + t * 0.022f, -0.28f, 0.14f), Palette.Foot, new Vector3(-15f, t * 20f, 0f));
        }

        return b.Build();
    }

    /// <summary>Testa con becco, cera, occhi (iride, pupilla, riflesso). Origine al perno del collo.</summary>
    private static ArrayMesh BuildHead()
    {
        var b = new LowPolyBuilder()
            .Sphere(0.15f, new Vector3(0f, 0.08f, -0.12f), new Vector3(0.95f, 0.95f, 1.08f), Palette.PigeonHead, 12, 8)
            .Sphere(0.1f, new Vector3(0f, 0.12f, -0.2f), new Vector3(0.9f, 0.7f, 1f), Palette.PigeonHead, 10, 6)          // fronte
            .Cylinder(0f, 0.038f, 0.15f, new Vector3(0f, 0.06f, -0.31f), Palette.Beak, 6, new Vector3(-92f, 0f, 0f))     // becco sup.
            .Cylinder(0f, 0.014f, 0.04f, new Vector3(0f, 0.058f, -0.385f), Palette.BeakTip, 5, new Vector3(-100f, 0f, 0f)) // punta
            .Cylinder(0f, 0.026f, 0.11f, new Vector3(0f, 0.03f, -0.29f), Palette.Beak, 5, new Vector3(-96f, 0f, 0f))      // becco inf.
            .Sphere(0.045f, new Vector3(0f, 0.09f, -0.245f), new Vector3(1.1f, 0.7f, 1.2f), Palette.Cere, 8, 5);         // cera

        foreach (var side in new[] { -1f, 1f })
        {
            b.Sphere(0.04f, new Vector3(side * 0.124f, 0.11f, -0.17f), new Vector3(0.5f, 1f, 1f), Palette.EyeRing, 8, 5);
            b.Sphere(0.031f, new Vector3(side * 0.132f, 0.11f, -0.17f), new Vector3(0.6f, 1f, 1f), Palette.Eye, 8, 5);
            b.Sphere(0.016f, new Vector3(side * 0.147f, 0.11f, -0.172f), new Vector3(0.6f, 1f, 1f), Palette.Pupil, 6, 4);
            b.Sphere(0.006f, new Vector3(side * 0.155f, 0.118f, -0.18f), Vector3.One, new Color("ffffff"), 4, 3, unlit: true);
        }

        return b.Build();
    }

    /// <summary>Coda a ventaglio di 7 penne con banda scura terminale. Origine alla base della coda.</summary>
    private static ArrayMesh BuildTail()
    {
        var b = new LowPolyBuilder();
        for (var i = -3; i <= 3; i++)
        {
            var angle = i * 9f;
            var rad = Mathf.DegToRad(angle);
            var dir = new Vector3(Mathf.Sin(rad), 0f, Mathf.Cos(rad));
            var lift = 0.002f * (3 - System.Math.Abs(i)); // le centrali stanno sopra, niente z-fighting
            b.Sphere(1f, dir * 0.2f + new Vector3(0f, lift, 0f), new Vector3(0.07f, 0.016f, 0.24f), Palette.PigeonTail, 6, 3, new Vector3(-6f, angle, 0f));
            b.Sphere(1f, dir * 0.4f + new Vector3(0f, lift + 0.004f, 0f), new Vector3(0.072f, 0.017f, 0.06f), Palette.PigeonTailBand, 6, 3, new Vector3(-6f, angle, 0f));
        }

        b.Sphere(0.12f, new Vector3(0f, 0.01f, 0.02f), new Vector3(1.1f, 0.35f, 1f), Palette.PigeonBody, 8, 4); // attacco
        return b.Build();
    }

    /// <summary>Braccio dell'ala: copritrici, scapolari, due barre scure, remiganti secondarie. Origine alla spalla.</summary>
    private static ArrayMesh BuildInnerWing(float side)
    {
        var b = new LowPolyBuilder()
            .Sphere(1f, new Vector3(side * 0.23f, 0f, 0.03f), new Vector3(0.26f, 0.035f, 0.19f), Palette.PigeonWing, 10, 5)
            .Sphere(1f, new Vector3(side * 0.1f, 0.02f, 0.1f), new Vector3(0.14f, 0.03f, 0.2f), Palette.PigeonBody, 8, 4);

        // le due barre nere tipiche del piccione torraiolo
        b.Box(new Vector3(0.3f, 0.075f, 0.035f), new Vector3(side * 0.24f, 0.004f, 0.08f), Palette.PigeonPrimaryDark, new Vector3(0f, side * -8f, 0f));
        b.Box(new Vector3(0.28f, 0.075f, 0.035f), new Vector3(side * 0.24f, 0.004f, 0.15f), Palette.PigeonPrimaryDark, new Vector3(0f, side * -8f, 0f));

        for (var k = 0; k < 5; k++)
        {
            var x = side * (0.07f + k * 0.085f);
            b.Sphere(1f, new Vector3(x, -0.006f, 0.19f), new Vector3(0.075f, 0.014f, 0.15f), Palette.PigeonSecondary, 6, 3, new Vector3(0f, side * k * 4f, 0f));
        }

        return b.Build();
    }

    /// <summary>Mano dell'ala: copritrici e 6 remiganti primarie a ventaglio. Origine al gomito.</summary>
    private static ArrayMesh BuildOuterWing(float side)
    {
        var b = new LowPolyBuilder()
            .Sphere(1f, new Vector3(side * 0.12f, 0f, 0.02f), new Vector3(0.14f, 0.028f, 0.13f), Palette.PigeonWing, 8, 4);

        Color[] shades =
        {
            Palette.PigeonPrimaryDark, Palette.PigeonPrimaryDark, Palette.PigeonPrimaryMid,
            Palette.PigeonPrimaryMid, Palette.PigeonPrimaryLight, Palette.PigeonPrimaryLight,
        };

        var basePoint = new Vector3(side * 0.12f, -0.004f, 0.04f);
        for (var k = 0; k < shades.Length; k++)
        {
            // dalla punta (in avanti) verso l'interno (all'indietro), a ventaglio
            var yaw = -side * k * 9f;
            var rad = Mathf.DegToRad(yaw);
            var dir = new Vector3(side * Mathf.Cos(rad), 0f, -side * Mathf.Sin(rad));
            var length = 0.3f - k * 0.02f;
            b.Sphere(1f, basePoint + dir * length * 0.85f + new Vector3(0f, -k * 0.002f, 0f),
                new Vector3(length, 0.012f, 0.05f), shades[k], 6, 3, new Vector3(0f, yaw, 0f));
        }

        return b.Build();
    }
}
