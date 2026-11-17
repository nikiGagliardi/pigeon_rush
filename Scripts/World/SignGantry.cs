using System;
using Godot;
using PigeonRush.Core;
using PigeonRush.Rendering;

namespace PigeonRush.World;

/// <summary>Portale con cartelli verdi svizzeri. Trave in alto su tutta la larghezza + pannelli su 1-3 corsie.</summary>
public partial class SignGantry : Hazard
{
    private static readonly string[] Destinations =
    {
        "Bellinzona", "Lugano", "Chiasso", "Locarno", "S. Bernardino", "Gottardo", "Chur",
        "Zürich", "Milano", "Airolo", "Biasca", "Roveredo", "Mesocco", "Luzern", "Basel",
    };

    private readonly MeshInstance3D _panels;
    private readonly Label3D[] _labels = new Label3D[GameConfig.LaneCount];

    public SignGantry()
    {
        AddChild(new MeshInstance3D { Mesh = StructureMeshes.GantryFrame });
        _panels = new MeshInstance3D();
        AddChild(_panels);

        for (var i = 0; i < _labels.Length; i++)
        {
            _labels[i] = new Label3D
            {
                FontSize = 72,
                PixelSize = 0.005f,
                Modulate = Palette.SignWhite,
                OutlineSize = 0,
                Position = new Vector3(GameConfig.LaneX(i), (StructureMeshes.PanelTop + StructureMeshes.PanelBottom) * 0.5f, 0.08f),
                Visible = false,
            };
            AddChild(_labels[i]);
        }
    }

    /// <param name="laneBits">Corsie con pannello (bit 0..2), mai 0.</param>
    public void Activate(int laneBits, float z, Random rng)
    {
        ResetFlags();
        Position = new Vector3(0f, 0f, z);
        _panels.Mesh = StructureMeshes.Panels(laneBits);

        LocalBoxes.Clear();
        var span = GameConfig.FlyHalfWidth + 1f;
        LocalBoxes.Add(new Aabb(
            new Vector3(-span, StructureMeshes.GantryBeamBottom, -0.5f),
            new Vector3(span * 2f, StructureMeshes.GantryBeamTop - StructureMeshes.GantryBeamBottom, 1f)));

        CellMask = 0;
        for (var lane = 0; lane < GameConfig.LaneCount; lane++)
        {
            var hasPanel = (laneBits & (1 << lane)) != 0;
            _labels[lane].Visible = hasPanel;
            if (!hasPanel)
                continue;

            var x = GameConfig.LaneX(lane);
            LocalBoxes.Add(new Aabb(
                new Vector3(x - StructureMeshes.PanelWidth * 0.5f, StructureMeshes.PanelBottom, -0.45f),
                new Vector3(StructureMeshes.PanelWidth, StructureMeshes.PanelTop - StructureMeshes.PanelBottom, 0.9f)));
            CellMask |= LaneMask(lane, 2);

            var destination = Destinations[rng.Next(Destinations.Length)];
            _labels[lane].Text = $"{destination}\n{rng.Next(3, 95)} km";
        }
    }
}
