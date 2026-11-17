using Godot;

namespace PigeonRush.World;

/// <summary>
/// Risorse condivise per gli abbaglianti: bagliore (quad billboard additivo con gradiente radiale)
/// e cono di luce (cilindro additivo). Nessuna luce dinamica: costo minimo anche su mobile.
/// </summary>
public static class HighBeamVisuals
{
    public const float BeamLength = 16f;

    private static QuadMesh? _flare;
    private static CylinderMesh? _beam;

    public static QuadMesh Flare => _flare ??= new QuadMesh
    {
        Size = new Vector2(2.8f, 2.8f),
        Material = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            BlendMode = BaseMaterial3D.BlendModeEnum.Add,
            BillboardMode = BaseMaterial3D.BillboardModeEnum.Enabled,
            AlbedoColor = new Color(1f, 0.96f, 0.85f),
            AlbedoTexture = new GradientTexture2D
            {
                Width = 64,
                Height = 64,
                Fill = GradientTexture2D.FillEnum.Radial,
                FillFrom = new Vector2(0.5f, 0.5f),
                FillTo = new Vector2(0.5f, 0f),
                Gradient = new Gradient
                {
                    Offsets = new[] { 0f, 0.18f, 1f },
                    Colors = new[] { new Color(1f, 1f, 1f), new Color(0.75f, 0.7f, 0.55f), new Color(0f, 0f, 0f) },
                },
            },
        },
    };

    /// <summary>Cono centrato nell'origine: punta stretta in +Y, base larga in -Y (ruotato di -90° su X punta verso +Z).</summary>
    public static CylinderMesh Beam => _beam ??= new CylinderMesh
    {
        TopRadius = 0.12f,
        BottomRadius = 1.9f,
        Height = BeamLength,
        RadialSegments = 10,
        Rings = 1,
        CapTop = false,
        CapBottom = false,
        Material = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            BlendMode = BaseMaterial3D.BlendModeEnum.Add,
            CullMode = BaseMaterial3D.CullModeEnum.Disabled,
            AlbedoColor = new Color(0.2f, 0.19f, 0.15f),
        },
    };
}
