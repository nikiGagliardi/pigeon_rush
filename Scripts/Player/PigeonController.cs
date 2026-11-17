using Godot;
using PigeonRush.Core;
using PigeonRush.Rendering;

namespace PigeonRush.Player;

/// <summary>
/// Movimento libero del piccione nel rettangolo di volo (X/Y), con inerzia e inclinazione.
/// Resta sempre a Z = 0: è il mondo a venirgli incontro.
/// </summary>
public partial class PigeonController : Node3D
{
    private PigeonModel _model = null!;
    private MeshInstance3D _shadow = null!;
    private Vector3 _velocity;
    private float _invulnerable;
    private float _blinkTimer;
    private float _idleTime;

    public Vector3 Velocity => _velocity;
    public bool IsInvulnerable => _invulnerable > 0f;

    public Aabb Bounds => new(Position - GameConfig.PigeonHalfExtents, GameConfig.PigeonHalfExtents * 2f);

    public override void _Ready()
    {
        Position = new Vector3(0f, GameConfig.PigeonStartY, 0f);

        _model = new PigeonModel();
        AddChild(_model);

        _shadow = new MeshInstance3D
        {
            Mesh = new CylinderMesh { TopRadius = 0.5f, BottomRadius = 0.5f, Height = 0.02f, RadialSegments = 12, Rings = 1 },
            MaterialOverride = Palette.ShadowBlob,
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
            TopLevel = true,
        };
        AddChild(_shadow);
        UpdateShadow();
    }

    /// <param name="input">Direzione desiderata, componenti in [-1, 1] (Y positivo = su).</param>
    /// <param name="flapRate">Velocità del battito d'ali.</param>
    public void Tick(float dt, Vector2 input, float flapRate)
    {
        var target = new Vector3(input.X * GameConfig.MaxLateralSpeed, input.Y * GameConfig.MaxVerticalSpeed, 0f);
        _velocity = _velocity.MoveToward(target, GameConfig.FlyAcceleration * dt);

        var p = Position + _velocity * dt;
        if (p.X < -GameConfig.FlyHalfWidth || p.X > GameConfig.FlyHalfWidth)
        {
            p.X = Mathf.Clamp(p.X, -GameConfig.FlyHalfWidth, GameConfig.FlyHalfWidth);
            _velocity.X = 0f;
        }

        if (p.Y < GameConfig.FlyMinY || p.Y > GameConfig.FlyMaxY)
        {
            p.Y = Mathf.Clamp(p.Y, GameConfig.FlyMinY, GameConfig.FlyMaxY);
            _velocity.Y = 0f;
        }

        Position = p;

        // inclinazione: rollio sulle virate, beccheggio salendo/scendendo
        var bank = -_velocity.X / GameConfig.MaxLateralSpeed * Mathf.DegToRad(35f);
        var pitch = _velocity.Y / GameConfig.MaxVerticalSpeed * Mathf.DegToRad(22f);
        var k = 1f - Mathf.Exp(-10f * dt);
        _model.Rotation = _model.Rotation.Lerp(new Vector3(pitch, 0f, bank), k);

        // in salita sbatte di più, in discesa plana
        _model.Flap(dt, flapRate * (input.Y > 0.3f ? 1.4f : input.Y < -0.5f ? 0.6f : 1f));

        TickInvulnerability(dt);
        UpdateShadow();
    }

    /// <summary>Volo "di presentazione" nel menu iniziale.</summary>
    public void TickIdle(float dt)
    {
        _idleTime += dt;
        Position = new Vector3(Mathf.Sin(_idleTime * 0.7f) * 1.2f, GameConfig.PigeonStartY + Mathf.Sin(_idleTime * 1.3f) * 0.4f, 0f);
        _model.Rotation = new Vector3(Mathf.Cos(_idleTime * 1.3f) * 0.12f, 0f, -Mathf.Cos(_idleTime * 0.7f) * 0.25f);
        _model.Flap(dt, 11f);
        UpdateShadow();
    }

    /// <summary>Caduta dopo il game over.</summary>
    public void TickCrash(float dt)
    {
        _model.Visible = true;
        _velocity.X = Mathf.MoveToward(_velocity.X, 0f, 8f * dt);
        _velocity.Y -= 22f * dt;
        var p = Position + _velocity * dt;
        if (p.Y < 0.25f)
        {
            p.Y = 0.25f;
            _velocity = Vector3.Zero;
        }
        else
        {
            _model.Rotation += new Vector3(4f * dt, 0f, 7f * dt);
        }

        Position = p;
        _model.Glide(dt);
        UpdateShadow();
    }

    public void StartInvulnerability()
    {
        _invulnerable = GameConfig.InvulnerableTime;
        _blinkTimer = 0f;
    }

    private void TickInvulnerability(float dt)
    {
        if (_invulnerable <= 0f)
            return;

        _invulnerable -= dt;
        _blinkTimer += dt;
        _model.Visible = _invulnerable <= 0f || Mathf.PosMod(_blinkTimer, 0.16f) < 0.1f;
    }

    private void UpdateShadow()
    {
        var height01 = Mathf.Clamp(Position.Y / GameConfig.FlyMaxY, 0f, 1f);
        var scale = Mathf.Lerp(1.1f, 0.45f, height01);
        _shadow.GlobalPosition = new Vector3(Position.X, 0.03f, Position.Z);
        _shadow.Scale = new Vector3(scale, 1f, scale * 1.3f);
    }
}
