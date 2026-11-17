using System;
using System.Collections.Generic;
using Godot;
using PigeonRush.Rendering;

namespace PigeonRush.World;

/// <summary>
/// Mesh della galleria: montagna "scavata" con due canne (la nostra e quella opposta),
/// rivestimento interno, lampade, nicchie SOS, delineatori, ventilatori e portale d'ingresso.
/// </summary>
public static class TunnelMeshes
{
    public static readonly float[] Lengths = { 320f, 400f, 480f, 560f };

    public const float SignX = -0.2f;
    public const float SignY = 8.3f;

    private const float LeftWall = -7.2f;
    private const float PillarLeft = 6.9f;   // lo spartitraffico (x 7.1) resta dentro il pilastro
    private const float PillarRight = 7.6f;
    private const float RightWall = 21.6f;
    private const float MountainLeft = -70f;
    private const float MountainRight = 80f;
    private const float MountainTop = 24f;

    private static readonly Dictionary<float, ArrayMesh> Cache = new();

    public static ArrayMesh Get(float length)
    {
        if (Cache.TryGetValue(length, out var mesh))
            return mesh;
        mesh = Build(length);
        Cache[length] = mesh;
        return mesh;
    }

    private static ArrayMesh Build(float length)
    {
        var rng = new Random((int)length);
        var b = new LowPolyBuilder();
        var half = length * 0.5f;
        const float ceiling = Tunnel.CeilingY;

        // --- massa della montagna attorno alle due canne ---
        b.Block(MountainLeft, LeftWall, 0f, MountainTop, -half, half, Palette.Rock);
        b.Block(PillarLeft, PillarRight, 0f, ceiling, -half, half, Palette.TunnelWall);
        b.Block(RightWall, MountainRight, 0f, MountainTop, -half, half, Palette.Rock);
        b.Block(LeftWall, RightWall, ceiling, MountainTop, -half, half, Palette.Rock);
        b.Block(MountainLeft, MountainRight, MountainTop, MountainTop + 0.8f, -half, half, Palette.Grass);

        // cupole e abeti sulla cima per una silhouette meno squadrata
        for (var i = 0; i < 5 + (int)(length / 60f); i++)
        {
            var x = MountainLeft + 15f + rng.NextSingle() * (MountainRight - MountainLeft - 30f);
            var z = -half + rng.NextSingle() * length;
            var r = 16f + rng.NextSingle() * 14f;
            b.Sphere(r, new Vector3(x, MountainTop, z), new Vector3(1f, 0.45f, 1f), rng.NextSingle() < 0.5f ? Palette.TreeMid : Palette.Grass, 7, 4);
        }

        for (var i = 0; i < 10; i++)
        {
            var x = MountainLeft + rng.NextSingle() * (MountainRight - MountainLeft);
            var z = -half + rng.NextSingle() * length;
            var h = 5f + rng.NextSingle() * 4f;
            b.Cone(1.6f + rng.NextSingle(), h, new Vector3(x, MountainTop + 0.5f, z), Palette.TreeDark);
        }

        // --- rivestimento interno (canna nostra + opposta) ---
        // arretrato di 2 cm alle estremità: facce di testa coincidenti con la roccia del portale = sfarfallio
        var lz = half - 0.02f;
        b.Block(LeftWall, LeftWall + 0.06f, 0f, ceiling, -lz, lz, Palette.TunnelWall);
        b.Block(PillarLeft - 0.06f, PillarLeft, 0f, ceiling, -lz, lz, Palette.TunnelWall);
        b.Block(PillarRight, PillarRight + 0.06f, 0f, ceiling, -lz, lz, Palette.TunnelWall);
        b.Block(RightWall - 0.06f, RightWall, 0f, ceiling, -lz, lz, Palette.TunnelWall);
        b.Block(LeftWall, RightWall, ceiling - 0.06f, ceiling, -lz, lz, Palette.TunnelCeiling);
        b.Block(LeftWall + 0.06f, LeftWall + 0.1f, 0.3f, 2.6f, -lz, lz, Palette.TunnelTile);   // fascia chiara bassa
        b.Block(PillarLeft - 0.1f, PillarLeft - 0.06f, 0.3f, 2.6f, -lz, lz, Palette.TunnelTile);

        // --- impianti ---
        for (var z = -half + 3f; z < half; z += 6f)
        {
            b.Box(new Vector3(0.3f, 0.08f, 1.6f), new Vector3(-2.8f, ceiling - 0.1f, z), Palette.TunnelLamp, unlit: true);
            b.Box(new Vector3(0.3f, 0.08f, 1.6f), new Vector3(2.8f, ceiling - 0.1f, z), Palette.TunnelLamp, unlit: true);
        }

        for (var z = -half + 12f; z < half; z += 25f)
        {
            b.Box(new Vector3(0.05f, 0.12f, 0.25f), new Vector3(LeftWall + 0.12f, 0.9f, z), Palette.Amber, unlit: true);
            b.Box(new Vector3(0.05f, 0.12f, 0.25f), new Vector3(PillarLeft - 0.12f, 0.9f, z), Palette.Amber, unlit: true);
        }

        for (var z = -half + 25f; z < half; z += 50f)
            b.Box(new Vector3(0.05f, 0.45f, 0.9f), new Vector3(LeftWall + 0.12f, 1.8f, z), Palette.SosGreen, unlit: true);

        for (var z = -half + Tunnel.FanStart; z < half - Tunnel.FanEndMargin; z += Tunnel.FanSpacing)
        {
            foreach (var x in new[] { -Tunnel.FanX, Tunnel.FanX })
            {
                var y = ceiling - 0.6f;
                b.Cylinder(Tunnel.FanRadius, Tunnel.FanRadius, Tunnel.FanLength, new Vector3(x, y, z), Palette.Metal, 10, new Vector3(90f, 0f, 0f));
                b.Cylinder(Tunnel.FanRadius * 0.7f, Tunnel.FanRadius * 0.7f, Tunnel.FanLength + 0.05f, new Vector3(x, y, z), Palette.Trim, 8, new Vector3(90f, 0f, 0f));
                b.Box(new Vector3(0.15f, 0.55f, 0.4f), new Vector3(x, ceiling - 0.28f, z), Palette.Metal);
            }
        }

        // --- portale d'ingresso (lato +Z, quello che vede il piccione) ---
        var p0 = half;
        var p1 = half + Tunnel.PortalDepth;
        const float frameTop = 7.2f;
        b.Block(LeftWall - 0.8f, LeftWall, 0f, frameTop, p0, p1, Palette.Concrete);
        b.Block(PillarLeft, PillarRight, 0f, frameTop, p0, p1, Palette.Concrete);
        b.Block(RightWall, RightWall + 0.8f, 0f, frameTop, p0, p1, Palette.Concrete);
        b.Block(LeftWall - 0.8f, RightWall + 0.8f, ceiling, frameTop, p0, p1, Palette.Concrete);
        b.Box(new Vector3(9f, 1.5f, 0.15f), new Vector3(SignX, SignY, p0 + 0.08f), Palette.SignBlue);

        return b.Build();
    }
}
