using System;
using System.Collections.Generic;
using Godot;
using PigeonRush.Core;
using PigeonRush.Rendering;
using PigeonRush.World;

namespace PigeonRush.Player;

/// <summary>
/// Sgancio della cacca con mirino automatico.
/// Ogni frame cerca il mezzo che verrebbe centrato sganciando ADESSO (stessa corsia, tetto sotto il piccione,
/// davanti entro <see cref="GameConfig.LockMaxAhead"/>) e mostra un anello sul tetto.
/// Se c'è un bersaglio, la traiettoria viene calcolata per intercettarlo.
/// </summary>
public partial class PoopSystem : Node3D
{
    private sealed class Poop
    {
        public MeshInstance3D Node = null!;
        public Vector3 Velocity;
        public bool Active;
        public bool OnRoad;
    }

    private const int PoolSize = 16;

    private static ArrayMesh? _dropMesh;
    private static ArrayMesh? _roadSplatMesh;
    private static ArrayMesh? _reticleMesh;

    private readonly List<Poop> _poops = new();
    private MeshInstance3D _reticle = null!;
    private float _cooldown;
    private float _pulse;

    public Vehicle? LockedTarget { get; private set; }

    public event Action<Vehicle, Vector3>? VehicleHit;

    /// <summary>La cacca ha mancato i mezzi ed è finita sull'asfalto.</summary>
    public event Action<Vector3>? RoadHit;

    public override void _Ready()
    {
        for (var i = 0; i < PoolSize; i++)
        {
            var node = new MeshInstance3D
            {
                Mesh = DropMesh,
                Visible = false,
                CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
            };
            AddChild(node);
            _poops.Add(new Poop { Node = node });
        }

        _reticle = new MeshInstance3D
        {
            Mesh = ReticleMesh,
            Visible = false,
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        };
        AddChild(_reticle);
    }

    /// <summary>Aggiorna il bersaglio agganciato e la posizione del mirino. Chiamare dopo aver mosso i veicoli.</summary>
    public void UpdateLock(float dt, PigeonController pigeon, IReadOnlyList<Vehicle> vehicles, float approachSpeed)
    {
        _cooldown = Mathf.Max(0f, _cooldown - dt);
        _pulse += dt;

        var from = DropOrigin(pigeon);
        Vehicle? best = null;
        var bestAhead = float.MaxValue;
        foreach (var vehicle in vehicles)
        {
            if (vehicle.IsHit || !ComputeShot(from, vehicle, approachSpeed, out _))
                continue;

            var ahead = from.Z - vehicle.FrontZ;
            if (ahead < bestAhead)
            {
                bestAhead = ahead;
                best = vehicle;
            }
        }

        LockedTarget = best;
        if (best == null)
        {
            _reticle.Visible = false;
            return;
        }

        var spec = best.Spec;
        var radius = spec.Width * 0.55f;
        var pulse = 1f + Mathf.Sin(_pulse * 14f) * 0.12f;
        _reticle.Visible = true;
        _reticle.Position = best.Position + new Vector3(0f, spec.TargetTop + 0.08f, 0f);
        _reticle.Scale = new Vector3(radius * pulse, 1f, radius * pulse);
    }

    /// <returns>true se la cacca è partita.</returns>
    public bool TryDrop(PigeonController pigeon, GameSession session, float approachSpeed)
    {
        if (_cooldown > 0f || !session.TryUseAmmo())
            return false;

        _cooldown = GameConfig.PoopCooldown;
        var from = DropOrigin(pigeon);
        var velocity = new Vector3(pigeon.Velocity.X * 0.3f, -GameConfig.PoopInitialDown, 0f);
        if (LockedTarget != null && ComputeShot(from, LockedTarget, approachSpeed, out var shot))
            velocity = shot;

        var poop = GetFree();
        if (poop == null)
            return true; // pool pieno: munizione consumata comunque, caso rarissimo

        poop.Active = true;
        poop.OnRoad = false;
        poop.Velocity = velocity;
        poop.Node.Mesh = DropMesh;
        poop.Node.Position = from;
        poop.Node.Scale = Vector3.One;
        poop.Node.Visible = true;
        return true;
    }

    public void Tick(float dt, float groundStep, float trafficStep, IReadOnlyList<Vehicle> vehicles)
    {
        foreach (var poop in _poops)
        {
            if (!poop.Active)
                continue;

            var node = poop.Node;
            if (poop.OnRoad)
            {
                // la macchia sulla strada scorre col manto stradale
                node.Position += new Vector3(0f, 0f, groundStep);
                if (node.Position.Z > GameConfig.DespawnZ)
                    Deactivate(poop);
                continue;
            }

            poop.Velocity.Y -= GameConfig.PoopGravity * dt;
            var position = node.Position + poop.Velocity * dt;
            node.Position = position;
            node.Scale = new Vector3(0.85f, 1.25f, 0.85f); // goccia allungata in caduta

            if (CheckVehicleHit(poop, position, trafficStep, vehicles))
                continue;

            if (position.Y <= 0.04f)
            {
                poop.OnRoad = true;
                node.Mesh = RoadSplatMesh;
                node.Position = new Vector3(position.X, 0.03f, position.Z);
                node.Scale = Vector3.One;
                RoadHit?.Invoke(node.Position);
            }
            else if (position.Z < GameConfig.SpawnZ || position.Z > GameConfig.DespawnZ)
            {
                Deactivate(poop);
            }
        }
    }

    private bool CheckVehicleHit(Poop poop, Vector3 position, float trafficStep, IReadOnlyList<Vehicle> vehicles)
    {
        foreach (var vehicle in vehicles)
        {
            if (vehicle.IsHit)
                continue;

            // tolleranza su Z pari allo spostamento del mezzo in questo frame
            if (!vehicle.TargetBox(0.35f + trafficStep, 0.35f).HasPoint(position))
                continue;

            vehicle.MarkHit(position);
            Deactivate(poop);
            VehicleHit?.Invoke(vehicle, position);
            return true;
        }

        return false;
    }

    /// <summary>Calcola la velocità iniziale per centrare il mezzo. False se non è un bersaglio valido.</summary>
    private static bool ComputeShot(Vector3 from, Vehicle vehicle, float approachSpeed, out Vector3 velocity)
    {
        velocity = default;
        var spec = vehicle.Spec;

        var aimY = spec.TargetTop - 0.15f;
        var dy = from.Y - aimY;
        if (dy < 0.35f)
            return false; // il piccione è più basso del tetto

        if (Mathf.Abs(vehicle.Position.X - from.X) > spec.Width * 0.5f + 0.7f)
            return false; // corsia sbagliata

        var ahead = from.Z - vehicle.FrontZ;
        if (ahead < GameConfig.LockMinAhead || ahead > GameConfig.LockMaxAhead)
            return false;

        // tempo di caduta: dy = v0·t + ½·g·t²
        const float g = GameConfig.PoopGravity;
        const float v0 = GameConfig.PoopInitialDown;
        var t = (-v0 + Mathf.Sqrt(v0 * v0 + 2f * g * dy)) / g;
        if (t <= 0.01f)
            return false;

        var impactZ = vehicle.Position.Z + approachSpeed * t; // centro del mezzo all'impatto
        var vz = (impactZ - from.Z) / t;
        if (vz < -45f || vz > 15f)
            return false; // servirebbe un lancio irrealistico

        var vx = (vehicle.Position.X - from.X) / t;
        velocity = new Vector3(vx, -v0, vz);
        return true;
    }

    private static Vector3 DropOrigin(PigeonController pigeon) => pigeon.Position + new Vector3(0f, -0.25f, 0.15f);

    private Poop? GetFree()
    {
        foreach (var poop in _poops)
        {
            if (!poop.Active)
                return poop;
        }

        // ricicla la macchia sulla strada più vecchia (la più vicina alla camera)
        Poop? oldest = null;
        foreach (var poop in _poops)
        {
            if (poop.OnRoad && (oldest == null || poop.Node.Position.Z > oldest.Node.Position.Z))
                oldest = poop;
        }

        return oldest;
    }

    private static void Deactivate(Poop poop)
    {
        poop.Active = false;
        poop.OnRoad = false;
        poop.Node.Visible = false;
    }

    internal static ArrayMesh DropMesh => _dropMesh ??= new LowPolyBuilder()
        .Sphere(0.11f, Vector3.Zero, new Vector3(1f, 1.2f, 1f), Palette.Poop, 6, 4)
        .Sphere(0.06f, new Vector3(0.04f, 0.05f, 0.03f), Vector3.One, Palette.PoopShade, 5, 3)
        .Build();

    internal static ArrayMesh RoadSplatMesh => _roadSplatMesh ??= new LowPolyBuilder()
        .Sphere(0.35f, Vector3.Zero, new Vector3(1f, 0.06f, 1.4f), Palette.Poop, 7, 3)
        .Sphere(0.16f, new Vector3(0.25f, 0f, 0.3f), new Vector3(1f, 0.08f, 1f), Palette.PoopShade, 6, 3)
        .Build();

    /// <summary>Anello giallo unlit di raggio 1 (scalato in base al mezzo).</summary>
    internal static ArrayMesh ReticleMesh => _reticleMesh ??= new LowPolyBuilder()
        .Add(new TorusMesh { InnerRadius = 0.86f, OuterRadius = 1f, Rings = 24, RingSegments = 4 },
            Transform3D.Identity, Palette.Reticle, unlit: true)
        .Box(new Vector3(0.5f, 0.04f, 0.08f), new Vector3(0f, 0f, 0f), Palette.Reticle, unlit: true)
        .Box(new Vector3(0.08f, 0.04f, 0.5f), new Vector3(0f, 0f, 0f), Palette.Reticle, unlit: true)
        .Build();
}
