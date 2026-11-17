using System;
using Godot;
using PigeonRush.Core;
using PigeonRush.Rendering;

namespace PigeonRush.World;

/// <summary>
/// Galleria a doppia canna: soffitto basso per tutta la lunghezza, ventilatori appesi,
/// buio all'interno (gestito da Main tramite <see cref="DarknessAt"/>).
/// Coordinate locali: corpo da -Length/2 a +Length/2, portale d'ingresso sporgente verso +Z.
/// </summary>
public partial class Tunnel : Hazard
{
    public const float CeilingY = 5.6f;
    public const float PortalDepth = 1.5f;
    public const float FanStart = 35f;
    public const float FanSpacing = 70f;
    public const float FanEndMargin = 20f;
    public const float FanX = 2.6f;
    public const float FanRadius = 0.55f;
    public const float FanLength = 3.6f;
    public const float FanBottom = CeilingY - 0.6f - FanRadius;

    private const float DarknessRamp = 22f;
    private const float CameraMargin = 0.45f;
    private const float CameraApproach = 14f;

    private static readonly string[] Names =
    {
        "San Bernardino Tunnel", "Roveredo Tunnel", "Gotthard Tunnel",
        "Vedeggio-Cassarate Tunnel", "Melide-Grancia Tunnel",
    };

    private readonly MeshInstance3D _mesh;
    private readonly Label3D _name;

    public float Length { get; private set; }
    public float EntranceZ => Position.Z + Length * 0.5f + PortalDepth;
    public float ExitZ => Position.Z - Length * 0.5f;

    public Tunnel()
    {
        _mesh = new MeshInstance3D();
        AddChild(_mesh);
        _name = new Label3D
        {
            FontSize = 96,
            PixelSize = 0.011f,
            Modulate = Palette.SignWhite,
            OutlineSize = 0,
        };
        AddChild(_name);
    }

    public void Activate(float length, float frontZ, Random rng)
    {
        ResetFlags();
        Length = length;
        Position = new Vector3(0f, 0f, frontZ - length * 0.5f - PortalDepth);
        _mesh.Mesh = TunnelMeshes.Get(length);
        _name.Text = Names[rng.Next(Names.Length)];
        _name.Position = new Vector3(TunnelMeshes.SignX, TunnelMeshes.SignY, length * 0.5f + 0.2f);

        var half = length * 0.5f;
        var span = GameConfig.FlyHalfWidth + 1f;
        LocalBoxes.Clear();
        LocalBoxes.Add(new Aabb(new Vector3(-span, CeilingY, -half), new Vector3(span * 2f, 6f, length + PortalDepth)));

        for (var z = -half + FanStart; z < half - FanEndMargin; z += FanSpacing)
        {
            foreach (var x in new[] { -FanX, FanX })
            {
                LocalBoxes.Add(new Aabb(
                    new Vector3(x - FanRadius - 0.05f, FanBottom, z - FanLength * 0.5f),
                    new Vector3((FanRadius + 0.05f) * 2f, CeilingY - FanBottom, FanLength)));
            }
        }

        CellMask = Cells.Band(2);
    }

    /// <summary>0 fuori, 1 in piena galleria, con rampa vicino ai portali.</summary>
    public float DarknessAt(float z)
    {
        if (z > EntranceZ || z < ExitZ)
            return 0f;
        var depth = Mathf.Min(EntranceZ - z, z - ExitZ);
        return Mathf.SmoothStep(0f, DarknessRamp, depth);
    }

    /// <summary>Quota massima per la camera a coordinata <paramref name="z"/> (float.MaxValue se libera).</summary>
    public float CameraCeilingAt(float z)
    {
        var inside = CeilingY - CameraMargin;
        if (z <= EntranceZ && z >= ExitZ)
            return inside;

        if (z > EntranceZ && z < EntranceZ + CameraApproach)
        {
            // scende gradualmente mentre il portale si avvicina, niente scatti
            var t = (z - EntranceZ) / CameraApproach;
            return Mathf.Lerp(inside, 12f, t);
        }

        return float.MaxValue;
    }
}
