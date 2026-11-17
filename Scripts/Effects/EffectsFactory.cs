using Godot;
using PigeonRush.Rendering;

namespace PigeonRush.Effects;

public static class EffectsFactory
{
    /// <summary>Esplosione di piume quando il piccione viene colpito. Riavviare con Restart().</summary>
    public static CpuParticles3D CreateFeatherBurst() => new()
    {
        Emitting = false,
        OneShot = true,
        Amount = 18,
        Lifetime = 1.1,
        Explosiveness = 0.95f,
        LocalCoords = false,
        Mesh = new LowPolyBuilder()
            .Box(new Vector3(0.09f, 0.012f, 0.26f), Vector3.Zero, new Color("f2f2f2"))
            .Box(new Vector3(0.07f, 0.012f, 0.2f), new Vector3(0f, 0f, 0.02f), Palette.PigeonWing, new Vector3(0f, 30f, 0f))
            .Build(),
        Direction = new Vector3(0f, 1f, 0f),
        Spread = 180f,
        InitialVelocityMin = 2f,
        InitialVelocityMax = 6f,
        Gravity = new Vector3(0f, -3f, 6f),
        AngularVelocityMin = -360f,
        AngularVelocityMax = 360f,
        ScaleAmountMin = 0.7f,
        ScaleAmountMax = 1.3f,
    };
}
