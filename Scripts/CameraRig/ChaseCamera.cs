using System;
using Godot;
using PigeonRush.Player;

namespace PigeonRush.CameraRig;

/// <summary>Camera alle spalle del piccione: inseguimento morbido, FOV che si allarga col boost, shake sui colpi.</summary>
public partial class ChaseCamera : Camera3D
{
    private readonly Random _rng = new();
    private Vector3 _smoothed;
    private float _trauma;
    private float _roll;

    public PigeonController? Target { get; set; }

    public override void _Ready()
    {
        Fov = 66f;
        Near = 0.1f;
        Far = 700f;
    }

    public void Snap()
    {
        if (Target != null)
            _smoothed = Desired(Target.Position);
    }

    public void AddTrauma(float amount) => _trauma = Mathf.Min(1f, _trauma + amount);

    /// <param name="ceiling">Quota massima consentita alla camera (soffitto delle gallerie).</param>
    public void Tick(float dt, float boostNormalized, float speedNormalized, float ceiling = float.MaxValue)
    {
        if (Target == null)
            return;

        var p = Target.Position;
        var k = 1f - Mathf.Exp(-7f * dt);
        _smoothed = _smoothed.Lerp(Desired(p), k);
        if (_smoothed.Y > ceiling)
            _smoothed.Y = ceiling; // il limite scende già in modo graduale: nessuno scatto

        _trauma = Mathf.Max(0f, _trauma - dt * 1.6f);
        var shake = _trauma * _trauma;
        var offset = new Vector3(RandSigned() * 0.6f, RandSigned() * 0.45f, 0f) * shake;

        var lookAt = new Vector3(p.X * 0.85f, p.Y * 0.85f + 0.4f, -14f);
        LookAtFromPosition(_smoothed + offset, lookAt, Vector3.Up);

        _roll = Mathf.Lerp(_roll, -Target.Velocity.X * 0.006f + RandSigned() * shake * 0.05f, k);
        RotateObjectLocal(Vector3.Back, _roll);

        var targetFov = 66f + boostNormalized * 16f + speedNormalized * 6f;
        Fov = Mathf.Lerp(Fov, targetFov, 1f - Mathf.Exp(-3f * dt));
    }

    private static Vector3 Desired(Vector3 pigeon) => new(pigeon.X * 0.7f, pigeon.Y * 0.75f + 2.3f, 7.5f);

    private float RandSigned() => _rng.NextSingle() * 2f - 1f;
}
