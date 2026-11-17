using System;
using Godot;
using PigeonRush.Core;

namespace PigeonRush.World;

/// <summary>Veicolo contromano. Viaggia a velocità piccione + traffico.</summary>
public partial class Vehicle : Hazard
{
    private const float FlashOnTime = 0.14f;
    private const float FlashOffTime = 0.12f;

    private readonly MeshInstance3D _body;
    private readonly MeshInstance3D _splat;
    private readonly Node3D _highBeams;
    private readonly MeshInstance3D[] _flares = new MeshInstance3D[2];
    private readonly MeshInstance3D[] _beams = new MeshInstance3D[2];

    private int _flashesLeft;
    private float _flashTimer;
    private bool _flashOn;

    public VehicleKind Kind { get; private set; }
    public VehicleSpec Spec { get; private set; } = VehicleCatalog.Car;
    public int Lane { get; private set; }
    public bool IsHit { get; private set; }

    /// <summary>Ha già lampeggiato in questo passaggio (un avvertimento per veicolo).</summary>
    public bool HasFlashed { get; private set; }

    public Vehicle()
    {
        _body = new MeshInstance3D();
        AddChild(_body);
        _splat = new MeshInstance3D
        {
            Mesh = VehicleMeshes.Splat,
            Visible = false,
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        };
        AddChild(_splat);

        _highBeams = new Node3D { Visible = false };
        AddChild(_highBeams);
        for (var i = 0; i < 2; i++)
        {
            _flares[i] = new MeshInstance3D
            {
                Mesh = HighBeamVisuals.Flare,
                CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
            };
            _beams[i] = new MeshInstance3D
            {
                Mesh = HighBeamVisuals.Beam,
                RotationDegrees = new Vector3(-90f, 0f, 0f),
                CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
            };
            _highBeams.AddChild(_flares[i]);
            _highBeams.AddChild(_beams[i]);
        }
    }

    public void Activate(VehicleKind kind, int variant, int lane, float x, float z)
    {
        Kind = kind;
        Spec = VehicleCatalog.Get(kind);
        Lane = lane;
        IsHit = false;
        HasFlashed = false;
        _flashesLeft = 0;
        _highBeams.Visible = false;
        ResetFlags();

        _body.Mesh = VehicleMeshes.Get(kind, variant);
        _splat.Visible = false;
        Position = new Vector3(x, 0f, z);

        LocalBoxes.Clear();
        LocalBoxes.Add(new Aabb(
            new Vector3(-Spec.Width * 0.5f, 0f, -Spec.Length * 0.5f),
            new Vector3(Spec.Width, Spec.Height, Spec.Length)));

        CellMask = LaneMask(lane, 0) | (Spec.BlocksMid ? LaneMask(lane, 1) : 0);

        // fari alla posizione giusta per questo tipo di mezzo
        var front = Spec.Length * 0.5f;
        for (var i = 0; i < 2; i++)
        {
            var side = i == 0 ? -1f : 1f;
            _flares[i].Position = new Vector3(side * Spec.HeadlightX, Spec.HeadlightY, front + 0.2f);
            _beams[i].Position = new Vector3(side * Spec.HeadlightX, Spec.HeadlightY, front + HighBeamVisuals.BeamLength * 0.5f);
        }
    }

    /// <summary>Lampeggia con gli abbaglianti <paramref name="count"/> volte.</summary>
    public void FlashHighBeams(int count)
    {
        HasFlashed = true;
        _flashesLeft = count;
        _flashOn = true;
        _flashTimer = FlashOnTime;
        _highBeams.Visible = true;
    }

    public void TickLights(float dt)
    {
        if (_flashesLeft <= 0)
            return;

        _flashTimer -= dt;
        if (_flashTimer > 0f)
            return;

        if (_flashOn)
        {
            _flashOn = false;
            _flashesLeft--;
            _highBeams.Visible = false;
            _flashTimer = FlashOffTime;
        }
        else
        {
            _flashOn = true;
            _highBeams.Visible = true;
            _flashTimer = FlashOnTime;
        }
    }

    /// <summary>Zona del tetto (o abitacolo) che conta come bersaglio, in coordinate mondo.</summary>
    public Aabb TargetBox(float padXZ, float padTop)
    {
        var s = Spec;
        return new Aabb(
            Position + new Vector3(-s.Width * 0.5f - padXZ, s.TargetBottom, -s.Length * 0.5f - padXZ),
            new Vector3(s.Width + padXZ * 2f, s.TargetTop - s.TargetBottom + padTop, s.Length + padXZ * 2f));
    }

    /// <summary>True se il piccione, restando dov'è, verrebbe investito da questo mezzo.</summary>
    public bool IsInPath(Aabb pigeon)
    {
        var halfWidth = Spec.Width * 0.5f;
        var overlapX = pigeon.End.X > Position.X - halfWidth - 0.2f && pigeon.Position.X < Position.X + halfWidth + 0.2f;
        var belowRoof = pigeon.Position.Y < Spec.Height + 0.2f;
        return overlapX && belowRoof;
    }

    public void MarkHit(Vector3 worldPoint)
    {
        IsHit = true;
        var local = worldPoint - Position;
        var s = Spec;
        var y = Kind == VehicleKind.Cabrio ? 1.36f : s.TargetTop + 0.02f;
        _splat.Position = new Vector3(
            Mathf.Clamp(local.X, -s.Width * 0.3f, s.Width * 0.3f),
            y,
            Mathf.Clamp(local.Z, -s.Length * 0.35f, s.Length * 0.35f));
        _splat.Rotation = new Vector3(0f, Random.Shared.NextSingle() * Mathf.Tau, 0f);
        _splat.Visible = true;
    }
}
