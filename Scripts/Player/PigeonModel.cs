using Godot;
using PigeonRush.Rendering;

namespace PigeonRush.Player;

/// <summary>Piccione low-poly procedurale: corpo unico + due ali animate. Guarda verso -Z.</summary>
public partial class PigeonModel : Node3D
{
    private static ArrayMesh? _bodyMesh;
    private static ArrayMesh? _leftWingMesh;
    private static ArrayMesh? _rightWingMesh;

    private readonly Node3D _leftWing;
    private readonly Node3D _rightWing;
    private float _phase;

    public PigeonModel()
    {
        AddChild(new MeshInstance3D { Mesh = BodyMesh });

        _leftWing = new Node3D { Position = new Vector3(-0.2f, 0.1f, -0.05f) };
        _leftWing.AddChild(new MeshInstance3D { Mesh = LeftWingMesh });
        AddChild(_leftWing);

        _rightWing = new Node3D { Position = new Vector3(0.2f, 0.1f, -0.05f) };
        _rightWing.AddChild(new MeshInstance3D { Mesh = RightWingMesh });
        AddChild(_rightWing);
    }

    /// <param name="rate">Velocità angolare del battito (rad/s).</param>
    /// <param name="amplitude">Ampiezza in radianti.</param>
    public void Flap(float dt, float rate, float amplitude = 0.85f)
    {
        _phase += dt * rate;
        var angle = Mathf.Sin(_phase) * amplitude + 0.12f;
        _leftWing.Rotation = new Vector3(0f, 0f, -angle);
        _rightWing.Rotation = new Vector3(0f, 0f, angle);
    }

    /// <summary>Ali aperte e ferme (planata / caduta).</summary>
    public void Glide(float dt)
    {
        var k = 1f - Mathf.Exp(-6f * dt);
        _leftWing.Rotation = _leftWing.Rotation.Lerp(new Vector3(0f, 0f, -0.15f), k);
        _rightWing.Rotation = _rightWing.Rotation.Lerp(new Vector3(0f, 0f, 0.15f), k);
    }

    private static ArrayMesh BodyMesh => _bodyMesh ??= new LowPolyBuilder()
        .Sphere(0.3f, Vector3.Zero, new Vector3(1f, 0.85f, 1.45f), Palette.PigeonBody)                       // corpo
        .Sphere(0.22f, new Vector3(0f, 0.08f, -0.3f), new Vector3(1f, 1f, 0.9f), Palette.PigeonNeck)          // collo verde
        .Sphere(0.17f, new Vector3(0f, 0.16f, -0.38f), new Vector3(1.05f, 0.7f, 0.8f), Palette.PigeonNeckPurple, 7, 4)
        .Sphere(0.16f, new Vector3(0f, 0.27f, -0.5f), Vector3.One, Palette.PigeonHead)                        // testa
        .Cylinder(0f, 0.045f, 0.16f, new Vector3(0f, 0.24f, -0.68f), Palette.Beak, 5, new Vector3(-90f, 0f, 0f)) // becco
        .Sphere(0.05f, new Vector3(0f, 0.29f, -0.6f), new Vector3(1.3f, 0.8f, 1f), new Color("eeeeee"), 5, 3) // cera
        .Sphere(0.035f, new Vector3(-0.11f, 0.31f, -0.58f), Vector3.One, Palette.Eye, 5, 3)
        .Sphere(0.035f, new Vector3(0.11f, 0.31f, -0.58f), Vector3.One, Palette.Eye, 5, 3)
        .Box(new Vector3(0.34f, 0.05f, 0.38f), new Vector3(0f, 0.04f, 0.5f), Palette.PigeonTail, new Vector3(-8f, 0f, 0f)) // coda
        .Box(new Vector3(0.35f, 0.055f, 0.08f), new Vector3(0f, 0.035f, 0.66f), Palette.PigeonWingBar, new Vector3(-8f, 0f, 0f))
        .Box(new Vector3(0.05f, 0.08f, 0.05f), new Vector3(-0.08f, -0.24f, 0.08f), Palette.Foot)               // zampe raccolte
        .Box(new Vector3(0.05f, 0.08f, 0.05f), new Vector3(0.08f, -0.24f, 0.08f), Palette.Foot)
        .Build();

    private static ArrayMesh LeftWingMesh => _leftWingMesh ??= BuildWing(-1f);
    private static ArrayMesh RightWingMesh => _rightWingMesh ??= BuildWing(1f);

    /// <param name="side">-1 = sinistra, +1 = destra. Il mesh si estende dal perno verso l'esterno.</param>
    private static ArrayMesh BuildWing(float side)
    {
        return new LowPolyBuilder()
            .Box(new Vector3(0.42f, 0.06f, 0.44f), new Vector3(side * 0.21f, 0f, 0.04f), Palette.PigeonWing)
            .Box(new Vector3(0.4f, 0.05f, 0.34f), new Vector3(side * 0.6f, 0f, 0.1f), Palette.PigeonWing, new Vector3(0f, side * -10f, 0f))
            .Box(new Vector3(0.3f, 0.065f, 0.06f), new Vector3(side * 0.22f, 0.01f, 0.1f), Palette.PigeonWingBar)
            .Box(new Vector3(0.3f, 0.065f, 0.06f), new Vector3(side * 0.22f, 0.01f, 0.2f), Palette.PigeonWingBar)
            .Box(new Vector3(0.22f, 0.045f, 0.3f), new Vector3(side * 0.88f, 0f, 0.16f), Palette.PigeonWingBar, new Vector3(0f, side * -18f, 0f))
            .Build();
    }
}
