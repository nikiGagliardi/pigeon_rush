using System;
using Godot;
using PigeonRush.Rendering;

namespace PigeonRush.World;

/// <summary>Cielo, sole, nebbia e fondale statico (prato infinito + montagne ticinesi in lontananza).</summary>
public static class SceneryFactory
{
    public static WorldEnvironment CreateEnvironment()
    {
        var sky = new ProceduralSkyMaterial
        {
            SkyTopColor = new Color("3d7fd1"),
            SkyHorizonColor = new Color("a9c9e8"),
            GroundBottomColor = new Color("5b7f3c"),
            GroundHorizonColor = new Color("a9c98f"),
        };

        var environment = new Godot.Environment
        {
            BackgroundMode = Godot.Environment.BGMode.Sky,
            Sky = new Sky { SkyMaterial = sky },
            AmbientLightSource = Godot.Environment.AmbientSource.Sky,
            AmbientLightEnergy = AmbientEnergy,
            TonemapMode = Godot.Environment.ToneMapper.Filmic,
            // Nebbia "a profondità": nitido fino a FogBegin, poi sale fino a coprire tutto a FogEnd
            // (dove nascono i mezzi, così non compaiono dal nulla). In modalità Depth FogDensity è l'intensità massima.
            FogEnabled = true,
            FogMode = Godot.Environment.FogModeEnum.Depth,
            FogDepthBegin = FogBegin,
            FogDepthEnd = FogEnd,
            FogDepthCurve = 1.6f,
            FogDensity = 1f,
            FogLightColor = FogColor,
            FogSkyAffect = 0f, // il cielo resta saturo, non velato
        };

        return new WorldEnvironment { Environment = environment };
    }

    public const float SunEnergy = 1.1f;
    public const float AmbientEnergy = 1.0f;
    public const float FogBegin = 90f;
    public const float FogEnd = 300f;
    public static readonly Color FogColor = new("a3bed6");
    public static readonly Color TunnelFogColor = new(0.22f, 0.21f, 0.19f);

    public static DirectionalLight3D CreateSun() => new()
    {
        RotationDegrees = new Vector3(-55f, -35f, 0f),
        LightColor = new Color("fff3dc"),
        LightEnergy = SunEnergy,
        ShadowEnabled = true,
        DirectionalShadowMode = DirectionalLight3D.ShadowMode.Orthogonal,
        DirectionalShadowMaxDistance = 80f,
    };

    /// <summary>Elementi lontani e fermi: la camera non avanza mai, quindi sembrano a distanza infinita.</summary>
    public static Node3D CreateBackdrop()
    {
        var root = new Node3D { Name = "Backdrop" };

        root.AddChild(new MeshInstance3D
        {
            Mesh = new PlaneMesh { Size = new Vector2(3000f, 3000f) },
            MaterialOverride = new StandardMaterial3D { AlbedoColor = Palette.Grass, Roughness = 1f },
            Position = new Vector3(0f, -0.12f, 0f),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        });

        // le montagne stanno oltre la fine della nebbia: la ignorano, e il "velo" è già nei loro colori
        root.AddChild(new MeshInstance3D
        {
            Mesh = BuildMountains(),
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
            MaterialOverride = new StandardMaterial3D
            {
                VertexColorUseAsAlbedo = true,
                VertexColorIsSrgb = true,
                Roughness = 1f,
                DisableFog = true,
            },
        });

        return root;
    }

    private static ArrayMesh BuildMountains()
    {
        var rng = new Random(42);
        var b = new LowPolyBuilder();

        // catena sul fondo + due fianchi di valle
        for (var i = 0; i < 9; i++)
            AddPeak(b, rng, new Vector3(-420f + i * 105f + rng.NextSingle() * 40f, 0f, -430f - rng.NextSingle() * 60f), 1.2f);

        for (var i = 0; i < 6; i++)
        {
            var z = -180f - i * 50f;
            AddPeak(b, rng, new Vector3(-170f - rng.NextSingle() * 60f, 0f, z), 0.9f);
            AddPeak(b, rng, new Vector3(170f + rng.NextSingle() * 60f, 0f, z), 0.9f);
        }

        return b.Build();
    }

    private static void AddPeak(LowPolyBuilder b, Random rng, Vector3 basePosition, float scale)
    {
        var height = (110f + rng.NextSingle() * 110f) * scale;
        var radius = (70f + rng.NextSingle() * 50f) * scale;
        var color = rng.NextSingle() < 0.5f ? Palette.Mountain : Palette.MountainLight;
        b.Cone(radius, height, basePosition, color, 6 + rng.Next(3));

        // cappello di neve
        var capHeight = height * 0.28f;
        b.Cone(radius * 0.28f + 1f, capHeight, basePosition + new Vector3(0f, height - capHeight - 0.5f, 0f), Palette.Snow, 6);
    }
}
