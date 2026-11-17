using System;
using Godot;
using PigeonRush.Core;

namespace PigeonRush.World;

/// <summary>
/// Traffico scenografico sulla carreggiata opposta: va nella stessa direzione del piccione (verso -Z),
/// niente collisioni. Velocità relativa = velocità piccione − velocità auto:
/// a inizio partita le auto ti sorpassano, quando acceleri sei tu a superarle.
/// Corsia 0 = sorpasso (vicino allo spartitraffico), corsia 2 = lenta (camion e bus).
/// </summary>
public partial class AmbientTraffic : Node3D
{
    private sealed class Car
    {
        public MeshInstance3D Node = null!;
        public float Speed;
        public int Lane;
        public bool Active;
    }

    private const int PoolSize = 16;
    private const float MinGap = 22f;
    private static readonly float[] LaneSpeeds = { 33f, 27f, 22f };

    private readonly Car[] _cars = new Car[PoolSize];
    private readonly Random _rng = new();
    private float _spawnTimer;

    public override void _Ready()
    {
        for (var i = 0; i < PoolSize; i++)
        {
            var node = new MeshInstance3D
            {
                RotationDegrees = new Vector3(0f, 180f, 0f), // muso verso -Z: vediamo il retro
                Visible = false,
            };
            AddChild(node);
            _cars[i] = new Car { Node = node };
        }

        // popolazione iniziale distribuita sulla strada visibile
        for (var i = 0; i < 7; i++)
            TrySpawn(Range(GameConfig.SpawnZ + 40f, 0f));
    }

    /// <param name="pigeonSpeed">Velocità del piccione rispetto alla strada.</param>
    public void Tick(float dt, float pigeonSpeed)
    {
        foreach (var car in _cars)
        {
            if (!car.Active)
                continue;

            var position = car.Node.Position;
            position.Z += (pigeonSpeed - car.Speed) * dt;
            car.Node.Position = position;

            if (position.Z > GameConfig.DespawnZ + 15f || position.Z < GameConfig.SpawnZ - 40f)
            {
                car.Active = false;
                car.Node.Visible = false;
            }
        }

        _spawnTimer -= dt;
        if (_spawnTimer > 0f)
            return;

        _spawnTimer = Range(0.6f, 1.6f);

        // se il piccione è più lento le auto arrivano da dietro la camera, altrimenti le raggiunge da lontano
        var lane = _rng.Next(GameConfig.LaneCount);
        var faster = pigeonSpeed > LaneSpeeds[lane];
        TrySpawn(faster ? GameConfig.SpawnZ - 20f : GameConfig.DespawnZ + 10f, lane);
    }

    private void TrySpawn(float z, int lane = -1)
    {
        if (lane < 0)
            lane = _rng.Next(GameConfig.LaneCount);

        Car? free = null;
        foreach (var car in _cars)
        {
            if (!car.Active)
            {
                free ??= car;
                continue;
            }

            if (car.Lane == lane && Mathf.Abs(car.Node.Position.Z - z) < MinGap)
                return; // corsia occupata in quel punto
        }

        if (free == null)
            return;

        var kind = PickKind(lane);
        free.Active = true;
        free.Lane = lane;
        free.Speed = LaneSpeeds[lane] + Range(-0.4f, 0.4f);
        free.Node.Mesh = VehicleMeshes.Get(kind, _rng.Next(16));
        free.Node.Position = new Vector3(RoadMeshes.OppositeCenterX + GameConfig.LaneX(lane), 0f, z);
        free.Node.Visible = true;
    }

    private VehicleKind PickKind(int lane)
    {
        var r = _rng.NextSingle();
        return lane switch
        {
            2 => r < 0.3f ? VehicleKind.Truck : r < 0.45f ? VehicleKind.Bus : r < 0.65f ? VehicleKind.Van : VehicleKind.Car,
            1 => r < 0.2f ? VehicleKind.Van : VehicleKind.Car,
            _ => r < 0.1f ? VehicleKind.Cabrio : VehicleKind.Car,
        };
    }

    private float Range(float min, float max) => min + (max - min) * _rng.NextSingle();
}
