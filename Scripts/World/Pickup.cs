using Godot;
using PigeonRush.Rendering;

namespace PigeonRush.World;

public enum PickupKind
{
    /// <summary>Briciole: ricaricano la cacca.</summary>
    Crumbs,
}

/// <summary>
/// Oggetto raccoglibile sospeso in aria: ruota, ondeggia, ha un alone dorato pulsante
/// e un raggio di luce fino all'asfalto (fa capire subito corsia e altezza).
/// </summary>
public partial class Pickup : Node3D
{
    private const float MeshScale = 1.7f;

    private static ArrayMesh? _crumbsMesh;
    private static QuadMesh? _halo;
    private static CylinderMesh? _beam;

    private readonly MeshInstance3D _mesh;
    private readonly MeshInstance3D _haloInstance;
    private readonly MeshInstance3D _beamInstance;
    private float _phase;
    private float _baseY;

    public PickupKind Kind { get; private set; }

    public Pickup()
    {
        _mesh = new MeshInstance3D
        {
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
            Scale = Vector3.One * MeshScale,
        };
        AddChild(_mesh);

        _haloInstance = new MeshInstance3D { Mesh = Halo, CastShadow = GeometryInstance3D.ShadowCastingSetting.Off };
        AddChild(_haloInstance);

        _beamInstance = new MeshInstance3D { Mesh = Beam, CastShadow = GeometryInstance3D.ShadowCastingSetting.Off };
        AddChild(_beamInstance);
    }

    public void Activate(PickupKind kind, Vector3 position)
    {
        Kind = kind;
        Position = position;
        _baseY = position.Y;
        _phase = position.X;
        _mesh.Mesh = CrumbsMesh;

        // raggio dall'asfalto all'oggetto: cilindro alto 1, scalato sull'altezza
        _beamInstance.Position = new Vector3(0f, -_baseY * 0.5f, 0f);
        _beamInstance.Scale = new Vector3(1f, _baseY, 1f);
    }

    public void Animate(float dt)
    {
        _phase += dt;
        _mesh.Rotation = new Vector3(0f, _phase * 2.5f, 0f);
        var bob = Mathf.Sin(_phase * 4f) * 0.15f;
        Position = new Vector3(Position.X, _baseY + bob, Position.Z);
        _beamInstance.Position = new Vector3(0f, -(_baseY + bob) * 0.5f, 0f);
        _beamInstance.Scale = new Vector3(1f, _baseY + bob, 1f);

        var pulse = 1f + Mathf.Sin(_phase * 6f) * 0.15f;
        _haloInstance.Scale = new Vector3(pulse, pulse, pulse);
    }

    /// <summary>Alone dorato additivo, sempre rivolto alla camera.</summary>
    internal static QuadMesh Halo => _halo ??= new QuadMesh
    {
        Size = new Vector2(3.2f, 3.2f),
        Material = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            BlendMode = BaseMaterial3D.BlendModeEnum.Add,
            BillboardMode = BaseMaterial3D.BillboardModeEnum.Enabled,
            BillboardKeepScale = true, // altrimenti il billboard ignora la scala e l'alone non pulsa
            AlbedoColor = new Color(1f, 0.78f, 0.2f),
            AlbedoTexture = HighBeamVisuals.RadialGlow,
        },
    };

    /// <summary>Raggio verticale additivo (alto 1, scalato in base all'altezza dell'oggetto).</summary>
    internal static CylinderMesh Beam => _beam ??= new CylinderMesh
    {
        TopRadius = 0.07f,
        BottomRadius = 0.18f,
        Height = 1f,
        RadialSegments = 8,
        Rings = 1,
        CapTop = false,
        CapBottom = false,
        Material = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            BlendMode = BaseMaterial3D.BlendModeEnum.Add,
            CullMode = BaseMaterial3D.CullModeEnum.Disabled,
            AlbedoColor = new Color(0.45f, 0.34f, 0.08f),
        },
    };

    internal static ArrayMesh CrumbsMesh => _crumbsMesh ??= new LowPolyBuilder()
        .Box(new Vector3(0.22f, 0.16f, 0.2f), new Vector3(0f, 0f, 0f), Palette.Crumb, new Vector3(10f, 20f, 5f))
        .Box(new Vector3(0.16f, 0.14f, 0.18f), new Vector3(0.22f, 0.08f, 0.1f), Palette.CrumbDark, new Vector3(30f, 0f, 15f))
        .Box(new Vector3(0.18f, 0.12f, 0.14f), new Vector3(-0.2f, -0.05f, 0.12f), Palette.Crumb, new Vector3(0f, 45f, 20f))
        .Box(new Vector3(0.14f, 0.12f, 0.16f), new Vector3(0.05f, 0.15f, -0.2f), Palette.CrumbDark, new Vector3(25f, 10f, 0f))
        .Add(new TorusMesh { InnerRadius = 0.48f, OuterRadius = 0.56f, Rings = 12, RingSegments = 4 },
            new Transform3D(Basis.FromEuler(new Vector3(Mathf.Pi * 0.5f, 0f, 0f)), Vector3.Zero), Palette.Gold, unlit: true)
        .Build();
}
