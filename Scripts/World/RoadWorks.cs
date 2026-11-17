using System;
using Godot;
using PigeonRush.Core;
using PigeonRush.Rendering;

namespace PigeonRush.World;

/// <summary>
/// Cantiere che chiude la corsia sinistra o destra: la strada diventa a due corsie.
/// Le due estremità sono speculari: quella verso il piccione (+Z) e quella da cui arrivano le auto (-Z),
/// perché la chiusura serve al traffico. Ognuna ha cartello, carrello con freccia e invito con coni e rete.
/// Il ponteggio con rete alto 8 m (sopra il volo massimo) impedisce di passare sopra la corsia chiusa:
/// la rete è un muro morbido che spinge il piccione verso le corsie aperte (nessun danno).
/// I carrelli e i macchinari sono invece ostacoli veri.
/// </summary>
public partial class RoadWorks : Hazard
{
    private const int MaxMachines = 3;

    /// <summary>Distanza minima tra il centro del piccione e la rete (metà barriera + metà piccione + margine).</summary>
    private const float NetClearance = 0.7f;

    private static readonly float[] Ends = { 1f, -1f };

    private readonly MeshInstance3D _mesh;
    private readonly MeshInstance3D[] _beacons = new MeshInstance3D[2];
    private readonly MeshInstance3D[] _netTapers = new MeshInstance3D[2];
    private readonly MeshInstance3D _netStraight;
    private readonly MeshInstance3D[] _machines = new MeshInstance3D[MaxMachines];
    private readonly Label3D[] _worksLabels = new Label3D[2];
    private readonly Label3D[] _limitLabels = new Label3D[2];
    private float _blink;

    public int ClosedLane { get; private set; }
    public float Length { get; private set; }

    /// <summary>Include il cartello dell'estremità lontana, così non sparisce mentre è ancora in vista.</summary>
    public override float RearZ => Position.Z - Length * 0.5f - RoadWorksMeshes.SignAhead - 1f;

    public RoadWorks()
    {
        _mesh = new MeshInstance3D();
        AddChild(_mesh);

        _netStraight = MakeNet();
        for (var e = 0; e < 2; e++)
        {
            _beacons[e] = new MeshInstance3D
            {
                Mesh = RoadWorksMeshes.Beacons,
                CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
                Rotation = new Vector3(0f, e == 0 ? 0f : Mathf.Pi, 0f), // estremità -Z: girato verso le auto
            };
            AddChild(_beacons[e]);
            _netTapers[e] = MakeNet();

            _worksLabels[e] = new Label3D
            {
                Text = "ROADWORKS", FontSize = 64, PixelSize = 0.0042f, Modulate = Palette.PanelBlack, OutlineSize = 0,
                Rotation = new Vector3(0f, e == 0 ? 0f : Mathf.Pi, 0f),
            };
            _limitLabels[e] = new Label3D
            {
                Text = "80", FontSize = 72, PixelSize = 0.006f, Modulate = Palette.PanelBlack, OutlineSize = 0,
                Rotation = new Vector3(0f, e == 0 ? 0f : Mathf.Pi, 0f),
            };
            AddChild(_worksLabels[e]);
            AddChild(_limitLabels[e]);
        }

        for (var i = 0; i < MaxMachines; i++)
        {
            _machines[i] = new MeshInstance3D { Visible = false };
            AddChild(_machines[i]);
        }
    }

    /// <param name="closedLane">0 = sinistra, 2 = destra (dal punto di vista del piccione).</param>
    /// <param name="frontZ">Posizione dell'estremità verso il piccione (+Z), cartello escluso.</param>
    public void Activate(int closedLane, float length, float frontZ, Random rng)
    {
        ResetFlags();
        ClosedLane = closedLane;
        Length = length;
        Position = new Vector3(0f, 0f, frontZ - length * 0.5f);
        _mesh.Mesh = RoadWorksMeshes.Get(closedLane, length);

        var half = length * 0.5f;
        var laneX = GameConfig.LaneX(closedLane);
        var inner = RoadWorksMeshes.TaperInner(length);
        var trailerZ = half - RoadWorksMeshes.TrailerOffset;
        var signX = RoadWorksMeshes.SignPostX(closedLane);
        var signZ = half + RoadWorksMeshes.SignAhead + 0.06f;

        LocalBoxes.Clear();

        // barriera longitudinale nel tratto centrale
        var barrierX = RoadWorksMeshes.BarrierX(closedLane);
        LocalBoxes.Add(new Aabb(new Vector3(barrierX - 0.25f, 0f, -inner), new Vector3(0.5f, 1.0f, inner * 2f)));

        for (var e = 0; e < 2; e++)
        {
            var end = Ends[e];
            _beacons[e].Position = new Vector3(laneX, 0f, end * trailerZ);
            _worksLabels[e].Position = new Vector3(signX, 2.3f, end * signZ);
            _limitLabels[e].Position = new Vector3(signX, 3.4f, end * signZ);

            // carrello segnaletico (ostacolo)
            LocalBoxes.Add(new Aabb(new Vector3(laneX - 1.3f, 0f, end * trailerZ - 1.55f), new Vector3(2.6f, 3.95f, 3.1f)));
        }

        PlaceNets(closedLane, length);
        PlaceMachines(laneX, inner, rng);

        CellMask = Cells.Of(closedLane, 0) | Cells.Of(closedLane, 1) | Cells.Of(closedLane, 2);
    }

    /// <summary>
    /// Limite laterale imposto dalla rete alla coordinata Z del mondo.
    /// Per la corsia 0 è un minimo su X, per la corsia 2 un massimo.
    /// La rete si chiude in diagonale all'estremità +Z e si riapre, speculare, all'estremità -Z.
    /// </summary>
    public bool TryGetLateralLimit(float worldZ, out float limit)
    {
        limit = 0f;
        var distance = Mathf.Abs(worldZ - Position.Z);
        var outer = RoadWorksMeshes.TaperOuter(Length);
        if (distance > outer)
            return false;

        var inner = RoadWorksMeshes.TaperInner(Length);
        var barrier = RoadWorksMeshes.BarrierX(ClosedLane);
        var wall = distance <= inner
            ? barrier
            : Mathf.Lerp(RoadWorksMeshes.EdgeX(ClosedLane), barrier, (outer - distance) / RoadWorksMeshes.TaperLength);
        limit = wall - RoadWorksMeshes.Side(ClosedLane) * NetClearance;
        return true;
    }

    public override void Animate(float dt)
    {
        _blink += dt;
        var on = Mathf.PosMod(_blink, 0.7f) < 0.35f;
        _beacons[0].Visible = on;
        _beacons[1].Visible = on;
    }

    /// <summary>
    /// True se un mezzo generato in <paramref name="spawnZ"/> nella corsia chiusa attraverserebbe il cantiere
    /// prima di uscire dalla visuale (i mezzi sono più veloci del cantiere e lo raggiungono da dietro).
    /// </summary>
    public bool BlocksVehicle(float spawnZ, float approachSpeed, float pigeonSpeed)
    {
        const float margin = 8f; // mezza lunghezza del mezzo più lungo + tolleranza
        var front = Position.Z + Length * 0.5f + margin;
        var rear = Position.Z - Length * 0.5f - margin;
        if (spawnZ >= front)
            return false; // già davanti al cantiere: non lo incontrerà mai

        var relative = Mathf.Max(0.1f, approachSpeed - pigeonSpeed);
        var catchUp = Mathf.Max(0f, (rear - spawnZ) / relative);
        return spawnZ + approachSpeed * catchUp < GameConfig.DespawnZ;
    }

    private MeshInstance3D MakeNet()
    {
        var net = new MeshInstance3D { Mesh = RoadWorksMeshes.Net, CastShadow = GeometryInstance3D.ShadowCastingSetting.Off };
        AddChild(net);
        return net;
    }

    private void PlaceNets(int lane, float length)
    {
        var height = RoadWorksMeshes.ScaffoldHeight;
        var barrierX = RoadWorksMeshes.BarrierX(lane);
        var edge = RoadWorksMeshes.EdgeX(lane);
        var inner = RoadWorksMeshes.TaperInner(length);
        var outer = RoadWorksMeshes.TaperOuter(length);

        // rete dritta: quad ruotato di 90° su Y (asse X locale → asse Z del mondo)
        _netStraight.Position = new Vector3(barrierX, height * 0.5f, 0f);
        _netStraight.Rotation = new Vector3(0f, Mathf.Pi * 0.5f, 0f);
        _netStraight.Scale = new Vector3(inner * 2f, height, 1f);

        // reti diagonali: dal bordo esterno (±outer) alla barriera (±inner)
        for (var e = 0; e < 2; e++)
        {
            var end = Ends[e];
            var dx = barrierX - edge;
            var dz = end * (inner - outer);
            var diagonal = Mathf.Sqrt(dx * dx + dz * dz);
            var net = _netTapers[e];
            net.Position = new Vector3(edge + dx * 0.5f, height * 0.5f, end * outer + dz * 0.5f);
            net.Rotation = new Vector3(0f, Mathf.Atan2(-dz, dx), 0f);
            net.Scale = new Vector3(diagonal, height, 1f);
        }
    }

    private void PlaceMachines(float laneX, float inner, Random rng)
    {
        var count = rng.Next(1, MaxMachines + 1);
        var cursor = inner - 15f;
        for (var i = 0; i < MaxMachines; i++)
        {
            var machine = _machines[i];
            if (i >= count || cursor < -inner + 10f)
            {
                machine.Visible = false;
                continue;
            }

            var z = cursor - rng.NextSingle() * 15f;
            var kind = rng.NextSingle() < 0.6f ? MachineKind.Excavator : MachineKind.Roller;
            var x = laneX + (rng.NextSingle() - 0.5f) * 0.5f;
            machine.Mesh = RoadWorksMeshes.Machine(kind);
            machine.Position = new Vector3(x, 0f, z);
            machine.Visible = true;
            AddMachineBoxes(kind, x, z);
            cursor = z - 30f - rng.NextSingle() * 20f;
        }
    }

    private void AddMachineBoxes(MachineKind kind, float x, float z)
    {
        if (kind == MachineKind.Excavator)
        {
            LocalBoxes.Add(new Aabb(new Vector3(x - 1.3f, 0f, z - 2.1f), new Vector3(2.6f, 3.5f, 4.2f)));   // corpo
            LocalBoxes.Add(new Aabb(new Vector3(x - 0.15f, 2.1f, z + 1.0f), new Vector3(1.2f, 3.3f, 4.9f))); // braccio
        }
        else
        {
            LocalBoxes.Add(new Aabb(new Vector3(x - 1.1f, 0f, z - 2.2f), new Vector3(2.2f, 3.1f, 4.6f)));
        }
    }
}
