using Godot;
using PigeonRush.Rendering;

namespace PigeonRush.World;

/// <summary>Risorse condivise per le frecce: lampadina gialla + piccolo bagliore additivo visibile da lontano.</summary>
public static class IndicatorVisuals
{
    private static BoxMesh? _lamp;
    private static QuadMesh? _flare;

    public static BoxMesh Lamp => _lamp ??= new BoxMesh
    {
        Size = new Vector3(0.24f, 0.14f, 0.08f),
        Material = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            AlbedoColor = Palette.Indicator,
        },
    };

    public static QuadMesh Flare => _flare ??= new QuadMesh
    {
        Size = new Vector2(1.3f, 1.3f),
        Material = new StandardMaterial3D
        {
            ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
            BlendMode = BaseMaterial3D.BlendModeEnum.Add,
            BillboardMode = BaseMaterial3D.BillboardModeEnum.Enabled,
            AlbedoColor = new Color(1f, 0.9f, 0.05f),
            AlbedoTexture = HighBeamVisuals.RadialGlow,
        },
    };
}
