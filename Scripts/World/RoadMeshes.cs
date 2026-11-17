using System;
using Godot;
using PigeonRush.Core;
using PigeonRush.Rendering;

namespace PigeonRush.World;

/// <summary>
/// Segmento di autostrada lungo <see cref="GameConfig.SegmentLength"/>: la nostra carreggiata (3 corsie),
/// spartitraffico New Jersey con lampioni, carreggiata opposta, guardrail e vegetazione.
/// Più varianti generate con seed diversi per evitare ripetizioni evidenti.
/// </summary>
public static class RoadMeshes
{
    private const int VariantCount = 5;
    private const float CarriagewayWidth = GameConfig.RoadHalfWidth * 2f + 2.4f; // corsie + banchine
    // Guida a destra: i mezzi contromano (verso +Z) hanno lo spartitraffico alla loro sinistra (+X),
    // la carreggiata opposta (traffico verso -Z) sta quindi sul lato +X.
    public const float MedianX = 7.1f;
    public const float OppositeCenterX = 14.2f;
    public const float OuterGuardrailX = -7.0f;

    private static ArrayMesh[]? _variants;

    public static ArrayMesh[] Variants
    {
        get
        {
            if (_variants != null)
                return _variants;

            _variants = new ArrayMesh[VariantCount];
            for (var i = 0; i < VariantCount; i++)
                _variants[i] = Build(1234 + i * 97);
            return _variants;
        }
    }

    private static ArrayMesh Build(int seed)
    {
        var rng = new Random(seed);
        var b = new LowPolyBuilder();
        const float length = GameConfig.SegmentLength;
        const float half = length * 0.5f;

        // --- nostra carreggiata ---
        b.Box(new Vector3(CarriagewayWidth, 0.1f, length), new Vector3(0f, -0.05f, 0f), Palette.Asphalt);
        AddLaneMarkings(b, 0f);

        // guardrail esterno
        b.Box(new Vector3(0.1f, 0.32f, length), new Vector3(OuterGuardrailX, 0.62f, 0f), Palette.Metal);
        for (var z = -half + 2f; z < half; z += 4f)
            b.Box(new Vector3(0.12f, 0.75f, 0.12f), new Vector3(OuterGuardrailX - 0.1f, 0.375f, z), Palette.ConcreteDark);

        // spartitraffico New Jersey
        b.Box(new Vector3(0.75f, 0.45f, length), new Vector3(MedianX, 0.225f, 0f), Palette.Concrete);
        b.Box(new Vector3(0.32f, 0.5f, length), new Vector3(MedianX, 0.7f, 0f), Palette.Concrete);

        // lampione doppio sullo spartitraffico
        const float poleHeight = 9f;
        b.Cylinder(0.1f, 0.14f, poleHeight, new Vector3(MedianX, poleHeight * 0.5f + 0.9f, 0f), Palette.Metal, 6);
        b.Box(new Vector3(4.6f, 0.1f, 0.14f), new Vector3(MedianX, poleHeight + 0.85f, 0f), Palette.Metal);
        b.Box(new Vector3(0.7f, 0.12f, 0.3f), new Vector3(MedianX + 2.2f, poleHeight + 0.75f, 0f), Palette.Lamp, unlit: true);
        b.Box(new Vector3(0.7f, 0.12f, 0.3f), new Vector3(MedianX - 2.2f, poleHeight + 0.75f, 0f), Palette.Lamp, unlit: true);

        // --- carreggiata opposta (solo scenografia) ---
        b.Box(new Vector3(CarriagewayWidth, 0.1f, length), new Vector3(OppositeCenterX, -0.05f, 0f), Palette.AsphaltDark);
        AddLaneMarkings(b, OppositeCenterX);
        b.Box(new Vector3(0.1f, 0.32f, length), new Vector3(OppositeCenterX + 7.0f, 0.62f, 0f), Palette.Metal);

        // --- vegetazione e dettagli ---
        AddTrees(b, rng, -9.5f, -55f, rng.Next(6, 11), half);
        AddTrees(b, rng, 24f, 75f, rng.Next(6, 11), half);

        if (rng.NextSingle() < 0.45f)
            AddHouse(b, rng, rng.NextSingle() < 0.5f ? -32f - rng.NextSingle() * 15f : 40f + rng.NextSingle() * 20f, half);

        return b.Build();
    }

    private static void AddLaneMarkings(LowPolyBuilder b, float centerX)
    {
        const float length = GameConfig.SegmentLength;
        var edge = GameConfig.RoadHalfWidth + 0.05f;
        b.Box(new Vector3(0.15f, 0.02f, length), new Vector3(centerX - edge, 0.01f, 0f), Palette.LineWhite);
        b.Box(new Vector3(0.15f, 0.02f, length), new Vector3(centerX + edge, 0.01f, 0f), Palette.LineWhite);

        // tratteggio: periodo 10 m (divisore di 40) così i segmenti combaciano
        for (var lane = 1; lane < GameConfig.LaneCount; lane++)
        {
            var x = centerX + GameConfig.LaneX(lane) - GameConfig.LaneWidth * 0.5f;
            for (var z = -length * 0.5f + 5f; z < length * 0.5f; z += 10f)
                b.Box(new Vector3(0.14f, 0.02f, 4.5f), new Vector3(x, 0.01f, z), Palette.LineWhite);
        }
    }

    private static void AddTrees(LowPolyBuilder b, Random rng, float nearX, float farX, int count, float half)
    {
        for (var i = 0; i < count; i++)
        {
            var x = nearX + (farX - nearX) * rng.NextSingle();
            var z = -half + rng.NextSingle() * half * 2f;
            var roll = rng.NextSingle();

            if (roll < 0.55f)
            {
                // abete
                var h = 3.5f + rng.NextSingle() * 3f;
                var r = 1.1f + rng.NextSingle() * 0.8f;
                b.Cylinder(0.15f, 0.2f, 1.2f, new Vector3(x, 0.6f, z), Palette.Trunk, 5);
                b.Cone(r, h, new Vector3(x, 1.0f, z), rng.NextSingle() < 0.5f ? Palette.TreeDark : Palette.TreeMid);
                b.Cone(r * 0.7f, h * 0.6f, new Vector3(x, 1.0f + h * 0.45f, z), Palette.TreeMid);
            }
            else if (roll < 0.85f)
            {
                // latifoglia
                var r = 1.3f + rng.NextSingle() * 0.9f;
                b.Cylinder(0.18f, 0.24f, 1.8f, new Vector3(x, 0.9f, z), Palette.Trunk, 5);
                b.Sphere(r, new Vector3(x, 1.8f + r * 0.8f, z), new Vector3(1f, 0.9f, 1f), Palette.TreeLight, 6, 4);
            }
            else
            {
                // roccia
                var r = 0.6f + rng.NextSingle() * 1.2f;
                b.Sphere(r, new Vector3(x, r * 0.3f, z), new Vector3(1.3f, 0.7f, 1f), Palette.Rock, 5, 3,
                    new Vector3(0f, rng.NextSingle() * 90f, 0f));
            }
        }
    }

    private static void AddHouse(LowPolyBuilder b, Random rng, float x, float half)
    {
        var z = -half * 0.5f + rng.NextSingle() * half;
        var walls = rng.NextSingle() < 0.5f ? new Color("efe6d2") : new Color("e8d9b5");
        var roof = rng.NextSingle() < 0.5f ? new Color("8e3b2e") : new Color("5b5f66");
        b.Box(new Vector3(7f, 4f, 9f), new Vector3(x, 2f, z), walls);
        b.Prism(new Vector3(7.6f, 2.6f, 9.6f), new Vector3(x, 5.3f, z), roof);
        b.Box(new Vector3(1.2f, 1.2f, 0.1f), new Vector3(x - 1.8f, 2.4f, z + 4.52f), Palette.Glass);
        b.Box(new Vector3(1.2f, 1.2f, 0.1f), new Vector3(x + 1.8f, 2.4f, z + 4.52f), Palette.Glass);
    }
}
