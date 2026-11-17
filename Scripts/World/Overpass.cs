using Godot;
using PigeonRush.Core;

namespace PigeonRush.World;

/// <summary>Cavalcavia: blocca tutta la parte alta, si passa solo sotto.</summary>
public partial class Overpass : Hazard
{
    public Overpass()
    {
        AddChild(new MeshInstance3D { Mesh = StructureMeshes.Overpass });
    }

    public void Activate(float z)
    {
        ResetFlags();
        Position = new Vector3(0f, 0f, z);

        LocalBoxes.Clear();
        var span = GameConfig.FlyHalfWidth + 1f;
        var half = StructureMeshes.OverpassDepth * 0.5f;
        LocalBoxes.Add(new Aabb(
            new Vector3(-span, StructureMeshes.OverpassDeckBottom, -half),
            new Vector3(span * 2f, 4f, StructureMeshes.OverpassDepth)));

        CellMask = Cells.Band(2);
    }
}
