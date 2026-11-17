using System;
using Godot;
using PigeonRush.Core;
using PigeonRush.Rendering;

namespace PigeonRush.World;

/// <summary>
/// Cantiere che chiude la corsia sinistra o destra: la strada diventa a due corsie.
/// Barriera continua, carrello con freccia lampeggiante e 1-3 macchinari (ostacoli) nella corsia chiusa.
/// Nessun veicolo viene generato nella corsia chiusa se lo attraverserebbe in vista.
/// </summary>
public partial class RoadWorks : Hazard
{
    private const int MaxMachines = 3;

    private readonly MeshInstance3D _mesh;
    private readonly MeshInstance3D _beacons;
    private readonly MeshInstance3D[] _machines = new MeshInstance3D[MaxMachines];
    private readonly Label3D _worksLabel;
    private readonly Label3D _limitLabel;
    private float _blink;

    public int ClosedLane { get; private set; }
    public float Length { get; private set; }

    public RoadWorks()
    {
        _mesh = new MeshInstance3D();
        AddChild(_mesh);
        _beacons = new MeshInstance3D
        {
            Mesh = RoadWorksMeshes.Beacons,
            CastShadow = GeometryInstance3D.ShadowCastingSetting.Off,
        };
        AddChild(_beacons);

        for (var i = 0; i < MaxMachines; i++)
        {
            _machines[i] = new MeshInstance3D { Visible = false };
            AddChild(_machines[i]);
        }

        _worksLabel = new Label3D { Text = "ROADWORKS", FontSize = 64, PixelSize = 0.0042f, Modulate = Palette.PanelBlack, OutlineSize = 0 };
        _limitLabel = new Label3D { Text = "80", FontSize = 72, PixelSize = 0.006f, Modulate = Palette.PanelBlack, OutlineSize = 0 };
        AddChild(_worksLabel);
        AddChild(_limitLabel);
    }

    /// <param name="closedLane">0 = sinistra, 2 = destra (dal punto di vista del piccione).</param>
    public void Activate(int closedLane, float length, float frontZ, Random rng)
    {
        ResetFlags();
        ClosedLane = closedLane;
        Length = length;
        Position = new Vector3(0f, 0f, frontZ - length * 0.5f);
        _mesh.Mesh = RoadWorksMeshes.Get(closedLane, length);

        var half = length * 0.5f;
        var laneX = GameConfig.LaneX(closedLane);
        var trailerZ = half - RoadWorksMeshes.TrailerOffset;
        _beacons.Position = new Vector3(laneX, 0f, trailerZ);

        var signX = RoadWorksMeshes.SignPostX(closedLane);
        var signZ = half + RoadWorksMeshes.SignAhead + 0.06f;
        _worksLabel.Position = new Vector3(signX, 2.3f, signZ);
        _limitLabel.Position = new Vector3(signX, 3.4f, signZ);

        LocalBoxes.Clear();

        // barriera longitudinale (fino all'inizio dei coni)
        var barrierX = RoadWorksMeshes.BarrierX(closedLane);
        LocalBoxes.Add(new Aabb(new Vector3(barrierX - 0.25f, 0f, -half), new Vector3(0.5f, 1.0f, length - RoadWorksMeshes.TaperLength)));

        // carrello segnaletico
        LocalBoxes.Add(new Aabb(new Vector3(laneX - 1.3f, 0f, trailerZ - 1.5f), new Vector3(2.6f, 3.95f, 3.1f)));

        // macchinari distribuiti nella corsia chiusa
        var count = rng.Next(1, MaxMachines + 1);
        var cursor = half - RoadWorksMeshes.TaperLength - 15f;
        for (var i = 0; i < MaxMachines; i++)
        {
            var machine = _machines[i];
            if (i >= count || cursor < -half + 10f)
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

        CellMask = Cells.Of(closedLane, 0) | Cells.Of(closedLane, 1) | Cells.Of(closedLane, 2);
    }

    public override void Animate(float dt)
    {
        _blink += dt;
        _beacons.Visible = Mathf.PosMod(_blink, 0.7f) < 0.35f;
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
