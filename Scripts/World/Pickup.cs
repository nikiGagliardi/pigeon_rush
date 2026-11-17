using Godot;
using PigeonRush.Rendering;

namespace PigeonRush.World;

public enum PickupKind
{
    /// <summary>Briciole: ricaricano la cacca.</summary>
    Crumbs,

    /// <summary>Piuma: +1 vita.</summary>
    Feather,
}

/// <summary>Oggetto raccoglibile sospeso in aria, ruota e ondeggia.</summary>
public partial class Pickup : Node3D
{
    private static ArrayMesh? _crumbsMesh;
    private static ArrayMesh? _featherMesh;

    private readonly MeshInstance3D _mesh;
    private float _phase;
    private float _baseY;

    public PickupKind Kind { get; private set; }

    public Pickup()
    {
        _mesh = new MeshInstance3D { CastShadow = GeometryInstance3D.ShadowCastingSetting.Off };
        AddChild(_mesh);
    }

    public void Activate(PickupKind kind, Vector3 position)
    {
        Kind = kind;
        Position = position;
        _baseY = position.Y;
        _phase = position.X;
        _mesh.Mesh = kind == PickupKind.Crumbs ? CrumbsMesh : FeatherMesh;
    }

    public void Animate(float dt)
    {
        _phase += dt;
        _mesh.Rotation = new Vector3(0f, _phase * 2.5f, 0f);
        Position = new Vector3(Position.X, _baseY + Mathf.Sin(_phase * 4f) * 0.15f, Position.Z);
    }

    private static ArrayMesh CrumbsMesh => _crumbsMesh ??= new LowPolyBuilder()
        .Box(new Vector3(0.22f, 0.16f, 0.2f), new Vector3(0f, 0f, 0f), Palette.Crumb, new Vector3(10f, 20f, 5f))
        .Box(new Vector3(0.16f, 0.14f, 0.18f), new Vector3(0.22f, 0.08f, 0.1f), Palette.CrumbDark, new Vector3(30f, 0f, 15f))
        .Box(new Vector3(0.18f, 0.12f, 0.14f), new Vector3(-0.2f, -0.05f, 0.12f), Palette.Crumb, new Vector3(0f, 45f, 20f))
        .Box(new Vector3(0.14f, 0.12f, 0.16f), new Vector3(0.05f, 0.15f, -0.2f), Palette.CrumbDark, new Vector3(25f, 10f, 0f))
        .Add(new TorusMesh { InnerRadius = 0.48f, OuterRadius = 0.56f, Rings = 12, RingSegments = 4 },
            new Transform3D(Basis.FromEuler(new Vector3(Mathf.Pi * 0.5f, 0f, 0f)), Vector3.Zero), Palette.Gold, unlit: true)
        .Build();

    private static ArrayMesh FeatherMesh => _featherMesh ??= new LowPolyBuilder()
        .Sphere(0.3f, new Vector3(0f, 0.05f, 0f), new Vector3(0.45f, 0.1f, 1.6f), new Color("ffffff"), 6, 3, new Vector3(0f, 0f, 70f))
        .Cylinder(0.02f, 0.02f, 0.9f, Vector3.Zero, new Color("e0e0e0"), 4, new Vector3(90f, 0f, 0f))
        .Add(new TorusMesh { InnerRadius = 0.55f, OuterRadius = 0.63f, Rings = 12, RingSegments = 4 },
            new Transform3D(Basis.FromEuler(new Vector3(Mathf.Pi * 0.5f, 0f, 0f)), Vector3.Zero), Palette.Info, unlit: true)
        .Build();
}
