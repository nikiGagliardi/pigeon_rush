using System.Collections.Generic;
using Godot;
using PigeonRush.Core;
using PigeonRush.Rendering;

namespace PigeonRush.World;

public enum MachineKind
{
    Excavator,
    Roller,
}

/// <summary>
/// Mesh del cantiere: corsia chiusa, ponteggio con rete (più alto del volo massimo), coni,
/// carrelli segnaletici, cartelli e macchinari.
/// Le due estremità sono speculari: lato +Z (verso il piccione) e lato -Z (da dove arrivano le auto).
/// Per ogni estremità, dall'esterno verso il centro: cartello → carrello → invito con coni e rete diagonale.
/// In mezzo: barriera e rete dritta.
/// </summary>
public static class RoadWorksMeshes
{
    public static readonly float[] Lengths = { 160f, 200f, 240f };
    public const float TaperLength = 30f;
    public const float TrailerOffset = 3f;       // centro del carrello rispetto all'estremità
    public const float TaperStartOffset = 6f;    // l'invito inizia subito dietro al carrello
    public const float SignAhead = 40f;          // cartello "ROADWORKS" prima di ogni estremità
    public const float ScaffoldHeight = 8f;      // sopra FlyMaxY: impossibile passare sopra

    private static readonly Dictionary<(int, float), ArrayMesh> Cache = new();
    private static ArrayMesh? _beacons;
    private static ArrayMesh? _excavator;
    private static ArrayMesh? _roller;
    private static QuadMesh? _net;

    public static float Side(int lane) => lane == 0 ? -1f : 1f;

    /// <summary>Linea di separazione tra la corsia chiusa e quella aperta adiacente.</summary>
    public static float Boundary(int lane) => GameConfig.LaneX(lane) - Side(lane) * GameConfig.LaneWidth * 0.5f;

    public static float BarrierX(int lane) => Boundary(lane) + Side(lane) * 0.35f;

    /// <summary>Bordo esterno della corsia chiusa.</summary>
    public static float EdgeX(int lane) => GameConfig.LaneX(lane) + Side(lane) * GameConfig.LaneWidth * 0.5f;

    public static float SignPostX(int lane) => GameConfig.LaneX(lane) + Side(lane) * (GameConfig.LaneWidth * 0.5f + 0.8f);

    /// <summary>Distanza dal centro dove inizia l'invito (rete al bordo esterno).</summary>
    public static float TaperOuter(float length) => length * 0.5f - TaperStartOffset;

    /// <summary>Distanza dal centro dove l'invito raggiunge la barriera.</summary>
    public static float TaperInner(float length) => TaperOuter(length) - TaperLength;

    /// <summary>Rete di cantiere arancione semitrasparente (quad 1×1, scalato dal nodo).</summary>
    public static QuadMesh Net => _net ??= new QuadMesh
    {
        Size = Vector2.One,
        Material = new StandardMaterial3D
        {
            AlbedoColor = new Color(1f, 0.45f, 0.05f, 0.55f),
            Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
            CullMode = BaseMaterial3D.CullModeEnum.Disabled,
            Roughness = 1f,
        },
    };

    public static ArrayMesh Get(int lane, float length)
    {
        if (Cache.TryGetValue((lane, length), out var mesh))
            return mesh;
        mesh = Build(lane, length);
        Cache[(lane, length)] = mesh;
        return mesh;
    }

    public static ArrayMesh Machine(MachineKind kind) => kind == MachineKind.Excavator
        ? _excavator ??= BuildExcavator()
        : _roller ??= BuildRoller();

    /// <summary>Lampeggianti ambra del carrello, rivolti verso +Z (ruotare di 180° per l'altra estremità).</summary>
    public static ArrayMesh Beacons => _beacons ??= new LowPolyBuilder()
        .Sphere(0.16f, new Vector3(-1.15f, 3.95f, 1.5f), Vector3.One, Palette.Amber, 6, 3, unlit: true)
        .Sphere(0.16f, new Vector3(1.15f, 3.95f, 1.5f), Vector3.One, Palette.Amber, 6, 3, unlit: true)
        .Sphere(0.16f, new Vector3(-1.15f, 1.35f, 1.5f), Vector3.One, Palette.Amber, 6, 3, unlit: true)
        .Sphere(0.16f, new Vector3(1.15f, 1.35f, 1.5f), Vector3.One, Palette.Amber, 6, 3, unlit: true)
        .Build();

    private static ArrayMesh Build(int lane, float length)
    {
        var b = new LowPolyBuilder();
        var half = length * 0.5f;
        var side = Side(lane);
        var laneX = GameConfig.LaneX(lane);
        var boundary = Boundary(lane);
        var barrierX = BarrierX(lane);
        var inner = TaperInner(length);

        // asfalto fresato e linea gialla provvisoria (in Svizzera la segnaletica di cantiere è gialla)
        b.Box(new Vector3(GameConfig.LaneWidth - 0.3f, 0.02f, length), new Vector3(laneX, 0.012f, 0f), Palette.MilledAsphalt);
        b.Box(new Vector3(0.16f, 0.025f, length + 20f), new Vector3(boundary, 0.016f, 0f), Palette.WorksYellow);

        // barriere bianche/rosse nel tratto centrale, con lampeggiante ogni 10 m
        var index = 0;
        for (var z = -inner + 1f; z < inner; z += 2f, index++)
        {
            b.Box(new Vector3(0.45f, 0.9f, 1.9f), new Vector3(barrierX, 0.45f, z), index % 2 == 0 ? Palette.WorksRed : Palette.SignWhite);
            if (index % 5 == 0)
                b.Box(new Vector3(0.16f, 0.16f, 0.16f), new Vector3(barrierX, 1.0f, z), Palette.Amber, unlit: true);
        }

        // ponteggio dritto: montanti e correnti
        var poleX = barrierX + side * 0.25f;
        for (var z = -inner; z <= inner; z += 3f)
            b.Box(new Vector3(0.08f, ScaffoldHeight, 0.08f), new Vector3(poleX, ScaffoldHeight * 0.5f, z), Palette.Metal);
        foreach (var y in new[] { 2.6f, 5.2f, ScaffoldHeight - 0.1f })
            b.Block(poleX - 0.04f, poleX + 0.04f, y - 0.04f, y + 0.04f, -inner, inner, Palette.Metal);

        // estremità speculari: +1 = lato piccione, -1 = lato da cui arrivano le auto
        foreach (var end in new[] { 1f, -1f })
        {
            AddTaper(b, lane, end * TaperOuter(length), end * inner);
            AddTrailer(b, lane, end * (half - TrailerOffset), end);
            AddSign(b, lane, end * (half + SignAhead), end);
        }

        return b.Build();
    }

    /// <summary>Invito: coni e ponteggio in diagonale dal bordo esterno (outerZ) alla barriera (innerZ).</summary>
    private static void AddTaper(LowPolyBuilder b, int lane, float outerZ, float innerZ)
    {
        var side = Side(lane);
        var edge = EdgeX(lane);
        var barrierX = BarrierX(lane);

        const int cones = 12;
        for (var i = 0; i <= cones; i++)
        {
            var t = (float)i / cones;
            var x = Mathf.Lerp(edge - side * 0.3f, barrierX, t);
            var z = Mathf.Lerp(outerZ, innerZ, t);
            b.Cone(0.22f, 0.75f, new Vector3(x, 0f, z), Palette.WorksOrange, 8);
            b.Cylinder(0.15f, 0.17f, 0.12f, new Vector3(x, 0.42f, z), Palette.SignWhite, 8);
            b.Box(new Vector3(0.5f, 0.05f, 0.5f), new Vector3(x, 0.025f, z), Palette.Trim);
        }

        var dx = barrierX - edge;
        var dz = innerZ - outerZ;
        var diagonal = Mathf.Sqrt(dx * dx + dz * dz);
        var yaw = Mathf.RadToDeg(Mathf.Atan2(dx, dz));
        for (var i = 0; i <= 6; i++)
        {
            var t = i / 6f;
            b.Box(new Vector3(0.08f, ScaffoldHeight, 0.08f), new Vector3(edge + dx * t, ScaffoldHeight * 0.5f, outerZ + dz * t), Palette.Metal);
        }

        foreach (var y in new[] { 2.6f, 5.2f, ScaffoldHeight - 0.1f })
            b.Box(new Vector3(0.08f, 0.08f, diagonal), new Vector3(edge + dx * 0.5f, y, outerZ + dz * 0.5f), Palette.Metal, new Vector3(0f, yaw, 0f));
    }

    /// <summary>Carrello con freccia verso le corsie aperte; <paramref name="facing"/> = verso del pannello (+1/-1 su Z).</summary>
    private static void AddTrailer(LowPolyBuilder b, int lane, float tz, float facing)
    {
        var side = Side(lane);
        var laneX = GameConfig.LaneX(lane);

        b.Box(new Vector3(2.2f, 0.9f, 3.0f), new Vector3(laneX, 0.85f, tz), Palette.WorksYellow);
        b.Wheel(laneX - 1.0f, tz, 0.4f, 0.25f);
        b.Wheel(laneX + 1.0f, tz, 0.4f, 0.25f);
        b.Box(new Vector3(0.12f, 1.4f, 0.12f), new Vector3(laneX, 1.9f, tz), Palette.Metal);
        b.Box(new Vector3(2.6f, 2.6f, 0.15f), new Vector3(laneX, 2.65f, tz + facing * 1.4f), Palette.PanelBlack);

        const float arrowY = 2.65f;
        var arrowZ = tz + facing * 1.49f;
        b.Box(new Vector3(1.5f, 0.2f, 0.05f), new Vector3(laneX + side * 0.15f, arrowY, arrowZ), Palette.Amber, unlit: true);
        b.Box(new Vector3(0.75f, 0.2f, 0.05f), new Vector3(laneX - side * 0.42f, arrowY + 0.24f, arrowZ), Palette.Amber, new Vector3(0f, 0f, -side * 45f), unlit: true);
        b.Box(new Vector3(0.75f, 0.2f, 0.05f), new Vector3(laneX - side * 0.42f, arrowY - 0.24f, arrowZ), Palette.Amber, new Vector3(0f, 0f, side * 45f), unlit: true);
    }

    /// <summary>Cartello "ROADWORKS" + limite 80 sulla banchina (i testi sono Label3D nel nodo).</summary>
    private static void AddSign(LowPolyBuilder b, int lane, float sz, float facing)
    {
        var sx = SignPostX(lane);
        b.Cylinder(0.05f, 0.05f, 3.6f, new Vector3(sx, 1.8f, sz - facing * 0.05f), Palette.Metal, 6);
        b.Box(new Vector3(1.6f, 1.0f, 0.08f), new Vector3(sx, 2.3f, sz), Palette.WorksYellow);
        b.Cylinder(0.45f, 0.45f, 0.06f, new Vector3(sx, 3.4f, sz), Palette.SignWhite, 16, new Vector3(90f, 0f, 0f));
        b.Add(new TorusMesh { InnerRadius = 0.36f, OuterRadius = 0.46f, Rings = 16, RingSegments = 4 },
            new Transform3D(Basis.FromEuler(new Vector3(Mathf.Pi * 0.5f, 0f, 0f)), new Vector3(sx, 3.4f, sz + facing * 0.04f)), Palette.WorksRed);
    }

    /// <summary>Escavatore con braccio alzato verso +Z. Origine al centro dei cingoli, a terra.</summary>
    private static ArrayMesh BuildExcavator() => new LowPolyBuilder()
        .Box(new Vector3(2.6f, 0.8f, 4.2f), new Vector3(0f, 0.4f, 0f), Palette.Trim)                                   // cingoli
        .Box(new Vector3(2.4f, 1.3f, 3.0f), new Vector3(0f, 1.45f, -0.3f), Palette.MachineYellow)                     // torretta
        .Box(new Vector3(1.0f, 1.3f, 1.2f), new Vector3(-0.6f, 2.75f, 0.5f), Palette.Glass)                            // cabina
        .Box(new Vector3(1.05f, 0.1f, 1.25f), new Vector3(-0.6f, 3.42f, 0.5f), Palette.MachineYellow)
        .Box(new Vector3(0.5f, 0.5f, 4.0f), new Vector3(0.45f, 3.6f, 2.6f), Palette.MachineYellow, new Vector3(-45f, 0f, 0f)) // braccio
        .Box(new Vector3(0.4f, 0.4f, 3.0f), new Vector3(0.45f, 3.7f, 4.75f), Palette.MachineYellow, new Vector3(60f, 0f, 0f))  // avambraccio
        .Box(new Vector3(1.0f, 0.7f, 0.7f), new Vector3(0.45f, 2.4f, 5.5f), Palette.Trim)                               // benna
        .Build();

    /// <summary>Rullo compressore. Origine al centro, a terra.</summary>
    private static ArrayMesh BuildRoller()
    {
        var b = new LowPolyBuilder()
            .Box(new Vector3(2.0f, 1.2f, 2.4f), new Vector3(0f, 1.6f, -0.2f), Palette.MachineYellow)
            .Box(new Vector3(1.7f, 0.08f, 1.7f), new Vector3(0f, 3.0f, -0.3f), Palette.MachineYellow)
            .Cylinder(0.75f, 0.75f, 2.0f, new Vector3(0f, 0.75f, 1.6f), Palette.Trim, 10, new Vector3(0f, 0f, 90f))
            .Cylinder(0.65f, 0.65f, 1.9f, new Vector3(0f, 0.65f, -1.5f), Palette.Trim, 10, new Vector3(0f, 0f, 90f))
            .Box(new Vector3(0.9f, 0.6f, 0.9f), new Vector3(0f, 2.5f, -0.3f), Palette.Glass);
        foreach (var x in new[] { -0.8f, 0.8f })
        foreach (var z in new[] { -1.1f, 0.5f })
            b.Box(new Vector3(0.08f, 0.8f, 0.08f), new Vector3(x, 2.6f, z), Palette.Trim);
        return b.Build();
    }
}
