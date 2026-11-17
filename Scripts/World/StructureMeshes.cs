using System.Collections.Generic;
using Godot;
using PigeonRush.Core;
using PigeonRush.Rendering;

namespace PigeonRush.World;

/// <summary>Mesh di portali segnaletici e cavalcavia.</summary>
public static class StructureMeshes
{
    public const float GantryPostX = 7.0f;
    public const float GantryBeamBottom = 6.4f;
    public const float GantryBeamTop = 7.6f;
    public const float PanelBottom = 4.55f;
    public const float PanelTop = 6.45f;
    public const float PanelWidth = 3.3f;

    public const float OverpassDeckBottom = 5.4f;
    public const float OverpassDepth = 12f;

    private static ArrayMesh? _gantryFrame;
    private static ArrayMesh? _overpass;
    private static readonly Dictionary<int, ArrayMesh> PanelCache = new();

    public static ArrayMesh GantryFrame => _gantryFrame ??= BuildGantryFrame();
    public static ArrayMesh Overpass => _overpass ??= BuildOverpass();

    /// <summary>Pannelli per la combinazione di corsie richiesta (bit 0..2).</summary>
    public static ArrayMesh Panels(int laneBits)
    {
        if (PanelCache.TryGetValue(laneBits, out var mesh))
            return mesh;

        var b = new LowPolyBuilder();
        var panelHeight = PanelTop - PanelBottom;
        var centerY = (PanelTop + PanelBottom) * 0.5f;
        for (var lane = 0; lane < GameConfig.LaneCount; lane++)
        {
            if ((laneBits & (1 << lane)) == 0)
                continue;

            var x = GameConfig.LaneX(lane);
            b.Box(new Vector3(PanelWidth + 0.12f, panelHeight + 0.12f, 0.08f), new Vector3(x, centerY, -0.06f), Palette.SignWhite);
            b.Box(new Vector3(PanelWidth, panelHeight, 0.12f), new Vector3(x, centerY, 0f), Palette.SignGreen);
            // tiranti verso la trave
            b.Box(new Vector3(0.08f, GantryBeamBottom - PanelTop + 0.1f, 0.08f), new Vector3(x - 1.2f, (GantryBeamBottom + PanelTop) * 0.5f, -0.05f), Palette.Metal);
            b.Box(new Vector3(0.08f, GantryBeamBottom - PanelTop + 0.1f, 0.08f), new Vector3(x + 1.2f, (GantryBeamBottom + PanelTop) * 0.5f, -0.05f), Palette.Metal);
        }

        mesh = b.Build();
        PanelCache[laneBits] = mesh;
        return mesh;
    }

    private static ArrayMesh BuildGantryFrame()
    {
        var b = new LowPolyBuilder();
        var beamHeight = GantryBeamTop - GantryBeamBottom;
        var postHeight = GantryBeamTop + 0.2f;

        foreach (var side in new[] { -1f, 1f })
        {
            b.Cylinder(0.22f, 0.26f, postHeight, new Vector3(side * GantryPostX, postHeight * 0.5f, 0f), Palette.Metal, 8);
            b.Box(new Vector3(0.9f, 0.3f, 0.9f), new Vector3(side * GantryPostX, 0.15f, 0f), Palette.Concrete);
        }

        // trave reticolare: due correnti + diagonali
        b.Box(new Vector3(GantryPostX * 2f + 0.4f, 0.22f, 0.5f), new Vector3(0f, GantryBeamTop - 0.11f, 0f), Palette.Metal);
        b.Box(new Vector3(GantryPostX * 2f + 0.4f, 0.22f, 0.5f), new Vector3(0f, GantryBeamBottom + 0.11f, 0f), Palette.Metal);
        for (var x = -GantryPostX + 0.7f; x < GantryPostX; x += 1.4f)
            b.Box(new Vector3(0.08f, beamHeight * 1.25f, 0.08f), new Vector3(x, GantryBeamBottom + beamHeight * 0.5f, 0f), Palette.Metal, new Vector3(0f, 0f, 35f));

        return b.Build();
    }

    private static ArrayMesh BuildOverpass()
    {
        var b = new LowPolyBuilder();
        const float width = 46f;
        const float deckThickness = 1.2f;
        var deckY = OverpassDeckBottom + deckThickness * 0.5f;
        var half = OverpassDepth * 0.5f;

        b.Box(new Vector3(width, deckThickness, OverpassDepth), new Vector3(0f, deckY, 0f), Palette.Concrete);              // impalcato
        b.Box(new Vector3(width, 0.4f, OverpassDepth - 1.5f), new Vector3(0f, OverpassDeckBottom - 0.2f, 0f), Palette.ConcreteDark); // travi
        b.Box(new Vector3(width, 0.06f, OverpassDepth - 1.2f), new Vector3(0f, OverpassDeckBottom + deckThickness + 0.03f, 0f), Palette.AsphaltDark);
        b.Box(new Vector3(width, 0.9f, 0.3f), new Vector3(0f, OverpassDeckBottom + deckThickness + 0.45f, half - 0.15f), Palette.Concrete); // parapetti
        b.Box(new Vector3(width, 0.9f, 0.3f), new Vector3(0f, OverpassDeckBottom + deckThickness + 0.45f, -half + 0.15f), Palette.Concrete);

        // pile fuori dall'area di volo
        // pile: fuori dal guardrail esterno, sullo spartitraffico, oltre la carreggiata opposta
        foreach (var x in new[] { -8.2f, RoadMeshes.MedianX, RoadMeshes.OppositeCenterX + 7.8f })
            b.Box(new Vector3(0.9f, OverpassDeckBottom, OverpassDepth - 3f), new Vector3(x, OverpassDeckBottom * 0.5f, 0f), Palette.ConcreteDark);

        // rampe di terra ai lati
        b.Box(new Vector3(14f, OverpassDeckBottom + 0.6f, OverpassDepth + 6f), new Vector3(-30f, (OverpassDeckBottom + 0.6f) * 0.5f, 0f), Palette.Grass);
        b.Box(new Vector3(14f, OverpassDeckBottom + 0.6f, OverpassDepth + 6f), new Vector3(37f, (OverpassDeckBottom + 0.6f) * 0.5f, 0f), Palette.Grass);

        return b.Build();
    }
}
