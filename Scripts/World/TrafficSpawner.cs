using System;
using System.Collections.Generic;
using Godot;
using PigeonRush.Core;
using PigeonRush.Player;

namespace PigeonRush.World;

/// <summary>
/// Genera, muove e ricicla traffico, strutture e raccoglibili.
/// Il traffico arriva a "file" (righe): ogni riga lascia almeno <see cref="MinFreeCells"/> celle libere
/// e almeno una adiacente a una cella libera della riga precedente, quindi c'è sempre un varco raggiungibile.
/// </summary>
public partial class TrafficSpawner : Node3D
{
    private const int MinFreeCells = 2;
    private const float ArrivalWindow = 0.75f;

    // cambio corsia: solo mezzi lontani (in secondi dal piccione), raramente
    private const float LaneChangeMinTime = 3.5f;
    private const float LaneChangeMaxTime = 5.5f;
    private const float LaneChangeMaxAhead = 280f;
    private const float LaneChangeClearance = 12f;   // spazio libero davanti/dietro nella corsia di destinazione
    private const float RowNeighbourhood = 12f;      // mezzi considerati "sulla stessa fila" per il varco

    // finestra in cui un mezzo "vede" il piccione davanti e lampeggia
    private const float FlashMinAhead = 15f;
    private const float FlashMaxAhead = 85f;

    private readonly List<Vehicle> _vehicles = new();
    private readonly List<Hazard> _structures = new();
    private readonly List<Pickup> _pickups = new();
    private readonly Random _rng = new();

    private NodePool<Vehicle> _vehiclePool = null!;
    private NodePool<SignGantry> _gantryPool = null!;
    private NodePool<Overpass> _overpassPool = null!;
    private NodePool<Tunnel> _tunnelPool = null!;
    private NodePool<RoadWorks> _worksPool = null!;
    private NodePool<Pickup> _pickupPool = null!;

    private float _rowCountdown;
    private float _structureCountdown = 90f;
    private float _grace = GameConfig.StartGrace;
    private int _prevFreeMask = Cells.All;
    private float _laneChangeCooldown = 12f;

    public bool SpawningEnabled { get; set; }
    public IReadOnlyList<Vehicle> Vehicles => _vehicles;

    /// <summary>0..1: quanto il piccione è dentro una galleria (per l'illuminazione).</summary>
    public float TunnelDarkness { get; private set; }

    public event Action<Vector3>? PigeonHit;
    public event Action<Vector3>? NearMiss;
    public event Action<PickupKind, Vector3>? PickupCollected;

    public override void _Ready()
    {
        _vehiclePool = new NodePool<Vehicle>(this, () => new Vehicle(), 24);
        _gantryPool = new NodePool<SignGantry>(this, () => new SignGantry(), 3);
        _overpassPool = new NodePool<Overpass>(this, () => new Overpass(), 2);
        _tunnelPool = new NodePool<Tunnel>(this, () => new Tunnel(), 1);
        _worksPool = new NodePool<RoadWorks>(this, () => new RoadWorks(), 1);
        _pickupPool = new NodePool<Pickup>(this, () => new Pickup(), 8);
    }

    public void Tick(float dt, float groundStep, float trafficStep, GameSession session)
    {
        MoveAndRecycle(dt, groundStep, trafficStep);
        UpdateTunnelDarkness();

        if (!SpawningEnabled)
            return;

        if (_grace > 0f)
        {
            _grace -= dt;
            return;
        }

        _structureCountdown -= groundStep;
        if (_structureCountdown <= 0f)
        {
            var occupied = SpawnStructure(-_structureCountdown);
            _structureCountdown += occupied + NextStructureGap(session.Difficulty);
        }

        _rowCountdown -= trafficStep;
        if (_rowCountdown <= 0f)
        {
            SpawnRow(session, -_rowCountdown);
            _rowCountdown += RowSpacing(session);
        }

        _laneChangeCooldown -= dt;
        if (_laneChangeCooldown <= 0f)
        {
            _laneChangeCooldown = TryStartLaneChange(session)
                ? Mathf.Lerp(10f, 6f, session.Difficulty) + Range(0f, 5f)
                : 1f; // nessun candidato valido: riprova tra poco
        }
    }

    /// <summary>Collisioni, passaggi a filo e raccolta oggetti.</summary>
    public void ResolvePigeon(PigeonController pigeon, float groundStep, float trafficStep)
    {
        var pigeonBox = pigeon.Bounds;
        var pigeonZ = pigeon.Position.Z;

        FlashLeadVehicles(pigeonBox, pigeonZ);

        foreach (var vehicle in _vehicles)
            ResolveHazard(vehicle, pigeon, pigeonBox, pigeonZ, trafficStep);

        foreach (var structure in _structures)
            ResolveHazard(structure, pigeon, pigeonBox, pigeonZ, groundStep);

        for (var i = _pickups.Count - 1; i >= 0; i--)
        {
            var pickup = _pickups[i];
            var delta = pickup.Position - pigeon.Position;
            // tolleranza estesa su Z: a 60 m/s il raccoglibile si sposta di 1 m per frame
            if (Mathf.Abs(delta.X) < 1.1f && Mathf.Abs(delta.Y) < 1.0f && delta.Z > -1.2f - trafficStep && delta.Z < 1.2f)
            {
                PickupCollected?.Invoke(pickup.Kind, pickup.Position);
                RemovePickupAt(i);
            }
        }
    }

    /// <summary>
    /// Abbaglianti: lampeggia solo il primo mezzo di ogni corsia (il più vicino al piccione, non ancora passato),
    /// e solo se il piccione è sulla sua traiettoria. Quelli dietro non vedono il piccione.
    /// </summary>
    private void FlashLeadVehicles(Aabb pigeonBox, float pigeonZ)
    {
        Span<int> lead = stackalloc int[GameConfig.LaneCount];
        lead.Fill(-1);
        for (var i = 0; i < _vehicles.Count; i++)
        {
            var vehicle = _vehicles[i];
            if (vehicle.FrontZ >= pigeonZ)
                continue; // già accanto o dietro al piccione

            var current = lead[vehicle.Lane];
            if (current < 0 || vehicle.FrontZ > _vehicles[current].FrontZ)
                lead[vehicle.Lane] = i;
        }

        foreach (var index in lead)
        {
            if (index < 0)
                continue;

            var vehicle = _vehicles[index];
            if (vehicle.HasFlashed || vehicle.IsHit)
                continue;

            var ahead = pigeonZ - vehicle.FrontZ;
            if (ahead > FlashMinAhead && ahead < FlashMaxAhead && vehicle.IsInPath(pigeonBox))
                vehicle.FlashHighBeams(_rng.Next(2, 4)); // 2 o 3 lampeggi
        }
    }

    private void ResolveHazard(Hazard hazard, PigeonController pigeon, Aabb pigeonBox, float pigeonZ, float sweep)
    {
        if (hazard.PassedPigeon)
            return;

        var minGap = float.MaxValue;
        for (var b = 0; b < hazard.BoxCount; b++)
        {
            var box = hazard.WorldBox(b, sweep);
            if (box.Intersects(pigeonBox))
            {
                if (!hazard.TouchedPigeon)
                    PigeonHit?.Invoke(pigeon.Position);
                hazard.TouchedPigeon = true;
            }

            minGap = Mathf.Min(minGap, Hazard.GapXY(box, pigeonBox));
        }

        // Valuta il passaggio a filo quando l'ostacolo supera il piccione
        if (hazard.RearZ > pigeonZ + GameConfig.PigeonHalfExtents.Z)
        {
            hazard.PassedPigeon = true;
            if (!hazard.TouchedPigeon && minGap < GameConfig.NearMissDistance)
                NearMiss?.Invoke(pigeon.Position);
        }
    }

    private void MoveAndRecycle(float dt, float groundStep, float trafficStep)
    {
        var trafficDelta = new Vector3(0f, 0f, trafficStep);
        var groundDelta = new Vector3(0f, 0f, groundStep);

        for (var i = _vehicles.Count - 1; i >= 0; i--)
        {
            var vehicle = _vehicles[i];
            vehicle.Position += trafficDelta;
            vehicle.TickLights(dt);
            vehicle.TickLaneChange(dt);
            if (vehicle.RearZ > GameConfig.DespawnZ)
            {
                _vehiclePool.Release(vehicle);
                RemoveSwap(_vehicles, i);
            }
        }

        for (var i = _structures.Count - 1; i >= 0; i--)
        {
            var structure = _structures[i];
            structure.Position += groundDelta;
            structure.Animate(dt);
            if (structure.RearZ <= GameConfig.DespawnZ)
                continue;

            switch (structure)
            {
                case SignGantry gantry:
                    _gantryPool.Release(gantry);
                    break;
                case Overpass overpass:
                    _overpassPool.Release(overpass);
                    break;
                case Tunnel tunnel:
                    _tunnelPool.Release(tunnel);
                    break;
                case RoadWorks works:
                    _worksPool.Release(works);
                    break;
            }

            RemoveSwap(_structures, i);
        }

        for (var i = _pickups.Count - 1; i >= 0; i--)
        {
            var pickup = _pickups[i];
            pickup.Position += trafficDelta;
            pickup.Animate(dt);
            if (pickup.Position.Z > GameConfig.DespawnZ)
                RemovePickupAt(i);
        }
    }

    /// <summary>Limiti laterali di volo alla coordinata Z (le reti dei cantieri restringono la strada).</summary>
    public void GetFlyLimits(float z, out float minX, out float maxX)
    {
        minX = -GameConfig.FlyHalfWidth;
        maxX = GameConfig.FlyHalfWidth;
        foreach (var structure in _structures)
        {
            if (structure is not RoadWorks works || !works.TryGetLateralLimit(z, out var limit))
                continue;

            if (works.ClosedLane == 0)
                minX = Mathf.Max(minX, limit);
            else
                maxX = Mathf.Min(maxX, limit);
        }
    }

    /// <summary>Quota massima della camera alla coordinata Z indicata (gallerie).</summary>
    public float CameraCeiling(float z)
    {
        var ceiling = float.MaxValue;
        foreach (var structure in _structures)
        {
            if (structure is Tunnel tunnel)
                ceiling = Mathf.Min(ceiling, tunnel.CameraCeilingAt(z));
        }

        return ceiling;
    }

    private void UpdateTunnelDarkness()
    {
        var darkness = 0f;
        foreach (var structure in _structures)
        {
            if (structure is Tunnel tunnel)
                darkness = Mathf.Max(darkness, tunnel.DarknessAt(0f));
        }

        TunnelDarkness = darkness;
    }

    /// <returns>Lunghezza occupata dalla struttura oltre la sua profondità standard (gallerie, cantieri).</returns>
    private float SpawnStructure(float overshoot)
    {
        var z = GameConfig.SpawnZ + overshoot;
        var roll = _rng.NextSingle();

        if (roll < 0.16f)
        {
            var length = TunnelMeshes.Lengths[_rng.Next(TunnelMeshes.Lengths.Length)];
            var tunnel = _tunnelPool.Get();
            tunnel.Activate(length, z, _rng);
            _structures.Add(tunnel);
            return length + Tunnel.PortalDepth;
        }

        if (roll < 0.32f)
        {
            var length = RoadWorksMeshes.Lengths[_rng.Next(RoadWorksMeshes.Lengths.Length)];
            var works = _worksPool.Get();
            // il cartello "ROADWORKS" sta 40 m prima del cantiere: è lui a comparire per primo sulla linea di spawn
            works.Activate(_rng.NextSingle() < 0.5f ? 0 : GameConfig.LaneCount - 1, length, z - RoadWorksMeshes.SignAhead, _rng);
            _structures.Add(works);
            return length + RoadWorksMeshes.SignAhead * 2f; // un cartello per estremità
        }

        if (roll < 0.74f)
        {
            var panelRoll = _rng.NextSingle();
            var laneBits = panelRoll < 0.5f
                ? 1 << _rng.Next(GameConfig.LaneCount)
                : panelRoll < 0.85f
                    ? 0b111 & ~(1 << _rng.Next(GameConfig.LaneCount))
                    : 0b111;
            var gantry = _gantryPool.Get();
            gantry.Activate(laneBits, z, _rng);
            _structures.Add(gantry);
        }
        else
        {
            var overpass = _overpassPool.Get();
            overpass.Activate(z);
            _structures.Add(overpass);
        }

        return 0f;
    }

    private void SpawnRow(GameSession session, float overshoot)
    {
        var speed = session.Speed;
        var difficulty = session.Difficulty;
        var z = GameConfig.SpawnZ + overshoot;

        var structureMask = StructureMaskAt(z, speed, out var closedLanes);

        // Contenuto delle corsie: -1 = vuota
        Span<int> kinds = stackalloc int[GameConfig.LaneCount];
        kinds.Fill(-1);
        var openLanes = 0;
        for (var lane = 0; lane < GameConfig.LaneCount; lane++)
        {
            if ((closedLanes & (1 << lane)) == 0)
                openLanes++;
        }

        var count = Math.Min(PickVehicleCount(difficulty), openLanes);
        for (var placed = 0; placed < count;)
        {
            var lane = _rng.Next(GameConfig.LaneCount);
            if (kinds[lane] >= 0 || (closedLanes & (1 << lane)) != 0)
                continue;
            kinds[lane] = (int)PickKind(difficulty);
            placed++;
        }

        // Garantisce varco minimo e raggiungibilità dalla riga precedente
        var reachable = Cells.Dilate(_prevFreeMask);
        var blocked = BlockedMask(kinds, structureMask);
        for (var guard = 0; guard < GameConfig.LaneCount; guard++)
        {
            var free = Cells.All & ~blocked;
            if (Cells.CountOf(free) >= MinFreeCells && (free & reachable) != 0)
                break;

            var lane = LaneToClear(kinds, reachable);
            if (lane < 0)
                break;
            kinds[lane] = -1;
            blocked = BlockedMask(kinds, structureMask);
        }

        var freeMask = Cells.All & ~blocked;
        _prevFreeMask = freeMask != 0 ? freeMask : Cells.All;

        for (var lane = 0; lane < GameConfig.LaneCount; lane++)
        {
            if (kinds[lane] < 0)
                continue;

            var kind = (VehicleKind)kinds[lane];
            var vehicle = _vehiclePool.Get();
            var x = GameConfig.LaneX(lane) + Range(-0.25f, 0.25f);
            vehicle.Activate(kind, _rng.Next(16), lane, x, z + Range(-2.5f, 2.5f));
            _vehicles.Add(vehicle);
        }

        TrySpawnPickup(session, freeMask, z);
    }

    /// <summary>
    /// Celle occupate dalle strutture quando un mezzo che ora è in <paramref name="z"/> arriverà al piccione,
    /// e corsie chiuse da cantieri che quel mezzo attraverserebbe in vista.
    /// </summary>
    private int StructureMaskAt(float z, SpeedController speed, out int closedLanes)
    {
        var pigeonSpeed = Mathf.Max(1f, speed.PigeonSpeed);
        var arrival = -z / Mathf.Max(1f, speed.ApproachSpeed);
        var mask = 0;
        closedLanes = 0;
        foreach (var structure in _structures)
        {
            var start = -structure.FrontZ / pigeonSpeed;
            var end = -structure.RearZ / pigeonSpeed;
            if (arrival > start - ArrivalWindow && arrival < end + ArrivalWindow)
                mask |= structure.CellMask;

            if (structure is RoadWorks works && works.BlocksVehicle(z, speed.ApproachSpeed, pigeonSpeed))
                closedLanes |= 1 << works.ClosedLane;
        }

        return mask;
    }

    /// <summary>
    /// Sceglie a caso un mezzo lontano che può spostarsi in una corsia adiacente in sicurezza.
    /// Regole: spazio libero nella corsia di destinazione, niente corsie chiuse da cantieri,
    /// e la "fila" del mezzo deve continuare a lasciare almeno <see cref="MinFreeCells"/> celle libere.
    /// </summary>
    private bool TryStartLaneChange(GameSession session)
    {
        if (_vehicles.Count == 0)
            return false;

        var speed = session.Speed;
        var approach = Mathf.Max(1f, speed.ApproachSpeed);
        var minAhead = LaneChangeMinTime * approach;
        var maxAhead = Mathf.Min(LaneChangeMaxAhead, LaneChangeMaxTime * approach);

        var start = _rng.Next(_vehicles.Count);
        for (var n = 0; n < _vehicles.Count; n++)
        {
            var vehicle = _vehicles[(start + n) % _vehicles.Count];
            if (vehicle.IsChangingLane)
                continue;

            var ahead = -vehicle.FrontZ; // il piccione è a Z = 0
            if (ahead < minAhead || ahead > maxAhead)
                continue;

            // prova prima una direzione a caso, poi l'altra
            var first = _rng.NextSingle() < 0.5f ? -1 : 1;
            for (var d = 0; d < 2; d++)
            {
                var target = vehicle.Lane + (d == 0 ? first : -first);
                if (CanChangeLane(vehicle, target, speed))
                {
                    vehicle.StartLaneChange(target);
                    return true;
                }
            }
        }

        return false;
    }

    private bool CanChangeLane(Vehicle vehicle, int target, SpeedController speed)
    {
        if (target < 0 || target >= GameConfig.LaneCount)
            return false;

        var structureMask = StructureMaskAt(vehicle.Position.Z, speed, out var closedLanes);
        if ((closedLanes & (1 << target)) != 0)
            return false; // corsia chiusa da un cantiere

        var blocked = structureMask;
        foreach (var other in _vehicles)
        {
            if (other == vehicle)
                continue;

            var dz = Mathf.Abs(other.Position.Z - vehicle.Position.Z);

            // spazio libero nella corsia di destinazione (anche per chi ci sta già entrando)
            var gap = (other.Spec.Length + vehicle.Spec.Length) * 0.5f + LaneChangeClearance;
            if (dz < gap && (other.Lane == target || other.TargetLane == target))
                return false;

            // occupazione della "fila": chi cambia corsia conta su entrambe
            if (dz < RowNeighbourhood)
                blocked |= VehicleMask(other.Lane, other.Spec) | VehicleMask(other.TargetLane, other.Spec);
        }

        blocked |= VehicleMask(target, vehicle.Spec) | VehicleMask(vehicle.Lane, vehicle.Spec);
        return Cells.CountOf(Cells.All & ~blocked) >= MinFreeCells;
    }

    private static int VehicleMask(int lane, VehicleSpec spec)
        => Cells.Of(lane, 0) | (spec.BlocksMid ? Cells.Of(lane, 1) : 0);

    private void TrySpawnPickup(GameSession session, int freeMask, float z)
    {
        var chance = session.Ammo <= 2 ? 0.5f : 0.25f;
        if (freeMask == 0 || _rng.NextSingle() > chance)
            return;

        // cella libera casuale
        var pick = _rng.Next(Cells.CountOf(freeMask));
        for (var lane = 0; lane < GameConfig.LaneCount; lane++)
        for (var band = 0; band < GameConfig.BandCount; band++)
        {
            if (!Cells.Has(freeMask, lane, band) || pick-- != 0)
                continue;

            var pickup = _pickupPool.Get();
            pickup.Activate(PickupKind.Crumbs, new Vector3(GameConfig.LaneX(lane), GameConfig.BandCenterY(band), z - 8f));
            _pickups.Add(pickup);
            return;
        }
    }

    private static int BlockedMask(ReadOnlySpan<int> kinds, int structureMask)
    {
        var mask = structureMask;
        for (var lane = 0; lane < kinds.Length; lane++)
        {
            if (kinds[lane] < 0)
                continue;
            mask |= Cells.Of(lane, 0);
            if (VehicleCatalog.Get((VehicleKind)kinds[lane]).BlocksMid)
                mask |= Cells.Of(lane, 1);
        }

        return mask;
    }

    /// <summary>Sceglie la corsia occupata più vicina alle celle raggiungibili.</summary>
    private static int LaneToClear(ReadOnlySpan<int> kinds, int reachable)
    {
        var best = -1;
        var bestScore = int.MaxValue;
        for (var lane = 0; lane < kinds.Length; lane++)
        {
            if (kinds[lane] < 0)
                continue;

            var score = 10;
            for (var band = 0; band < GameConfig.BandCount; band++)
            {
                if (Cells.Has(reachable, lane, band))
                {
                    score = band; // preferisci liberare dove il piccione può già arrivare in basso
                    break;
                }
            }

            if (score < bestScore)
            {
                bestScore = score;
                best = lane;
            }
        }

        return best;
    }

    private int PickVehicleCount(float difficulty)
    {
        var r = _rng.NextSingle();
        if (r < 0.08f) return 0;
        if (r < 0.08f + 0.10f + 0.35f * difficulty) return 3;
        if (r < 0.65f + 0.1f * difficulty) return 2;
        return 1;
    }

    private VehicleKind PickKind(float difficulty)
    {
        var r = _rng.NextSingle();
        if (r < 0.05f) return VehicleKind.Cabrio;
        if (r < 0.10f) return VehicleKind.CleanCar;
        if (r < 0.21f + 0.06f * difficulty) return VehicleKind.Truck;
        if (r < 0.32f + 0.13f * difficulty) return VehicleKind.Bus;
        if (r < 0.50f + 0.13f * difficulty) return VehicleKind.Van;
        return VehicleKind.Car;
    }

    private float RowSpacing(GameSession session)
        => Mathf.Lerp(46f, 30f, session.Difficulty) + session.Speed.ApproachSpeed * 0.15f + Range(-4f, 6f);

    private float NextStructureGap(float difficulty) => Mathf.Lerp(150f, 85f, difficulty) + Range(0f, 50f);

    private void RemovePickupAt(int index)
    {
        _pickupPool.Release(_pickups[index]);
        RemoveSwap(_pickups, index);
    }

    private float Range(float min, float max) => min + (max - min) * _rng.NextSingle();

    private static void RemoveSwap<T>(List<T> list, int index)
    {
        var last = list.Count - 1;
        list[index] = list[last];
        list.RemoveAt(last);
    }
}
