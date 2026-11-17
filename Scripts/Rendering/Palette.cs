using Godot;

namespace PigeonRush.Rendering;

/// <summary>Colori e materiali condivisi. I mesh low-poly usano vertex color: 1 materiale = meno draw call.</summary>
public static class Palette
{
    // Strada
    public static readonly Color Asphalt = new("45484e");
    public static readonly Color AsphaltDark = new("3a3d42");
    public static readonly Color LineWhite = new("eeeeee");
    public static readonly Color Concrete = new("c9c6bd");
    public static readonly Color ConcreteDark = new("9e9a90");
    public static readonly Color Metal = new("a9b0b8");
    public static readonly Color Grass = new("6e9b4a");
    public static readonly Color Lamp = new("fff2c4");

    // Natura
    public static readonly Color TreeDark = new("3f6b3a");
    public static readonly Color TreeMid = new("4d7d40");
    public static readonly Color TreeLight = new("6a9a4c");
    public static readonly Color Trunk = new("6b4a2f");
    public static readonly Color Rock = new("8d8a84");
    public static readonly Color Mountain = new("6d7a8c");
    public static readonly Color MountainLight = new("7d8a9c");
    public static readonly Color Snow = new("f4f7fb");

    // Veicoli
    public static readonly Color Glass = new("2b3d52");
    public static readonly Color Tire = new("1e1e1e");
    public static readonly Color Trim = new("2f3640");
    public static readonly Color Headlight = new("fff6d5");
    public static readonly Color Taillight = new("ff2a2a");
    public static readonly Color DestinationDisplay = new("ffb020");
    public static readonly Color Chrome = new("c8d0d8");
    public static readonly Color Seat = new("5a1f1f");

    // Gallerie
    public static readonly Color TunnelWall = new("b9b5aa");
    public static readonly Color TunnelTile = new("dcd8cc");
    public static readonly Color TunnelCeiling = new("5f5f5f");
    public static readonly Color TunnelLamp = new("ffe3a6");
    public static readonly Color SosGreen = new("22c55e");
    public static readonly Color Amber = new("ffb020");
    public static readonly Color SignBlue = new("1f4e9c");

    // Cantiere
    public static readonly Color WorksYellow = new("f2c300");
    public static readonly Color WorksOrange = new("ff6a00");
    public static readonly Color WorksRed = new("d62828");
    public static readonly Color MilledAsphalt = new("2f3134");
    public static readonly Color MachineYellow = new("f2b705");
    public static readonly Color PanelBlack = new("1a1a1a");

    // Segnaletica svizzera (autostrada = verde)
    public static readonly Color SignGreen = new("00843d");
    public static readonly Color SignWhite = new("ffffff");

    // Piccione
    public static readonly Color PigeonBody = new("7d8796");
    public static readonly Color PigeonHead = new("8a94a3");
    public static readonly Color PigeonNeck = new("4f7a6a");
    public static readonly Color PigeonNeckPurple = new("6b4f7a");
    public static readonly Color PigeonWing = new("8f99a8");
    public static readonly Color PigeonWingBar = new("3e4552");
    public static readonly Color PigeonTail = new("4a5260");
    public static readonly Color Beak = new("d9a066");
    public static readonly Color Eye = new("ff8c1a");
    public static readonly Color Foot = new("e07a7a");

    // Gameplay
    public static readonly Color Poop = new("f3f1e8");
    public static readonly Color PoopShade = new("cfc9b6");
    public static readonly Color Reticle = new("ffd400");
    public static readonly Color Crumb = new("e1b866");
    public static readonly Color CrumbDark = new("c8963e");
    public static readonly Color Gold = new("ffd54a");
    public static readonly Color Danger = new("ff5a4f");
    public static readonly Color Info = new("7fe3ff");

    private static StandardMaterial3D? _lit;
    private static StandardMaterial3D? _unlit;
    private static StandardMaterial3D? _shadowBlob;

    /// <summary>Materiale illuminato con vertex color (flat shading arriva dalle normali per faccia).</summary>
    public static StandardMaterial3D Lit => _lit ??= new StandardMaterial3D
    {
        VertexColorUseAsAlbedo = true,
        VertexColorIsSrgb = true,
        Roughness = 0.9f,
    };

    /// <summary>Materiale non illuminato: fari, lampioni, mirino.</summary>
    public static StandardMaterial3D Unlit => _unlit ??= new StandardMaterial3D
    {
        VertexColorUseAsAlbedo = true,
        VertexColorIsSrgb = true,
        ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
    };

    public static StandardMaterial3D ShadowBlob => _shadowBlob ??= new StandardMaterial3D
    {
        ShadingMode = BaseMaterial3D.ShadingModeEnum.Unshaded,
        Transparency = BaseMaterial3D.TransparencyEnum.Alpha,
        AlbedoColor = new Color(0f, 0f, 0f, 0.35f),
    };
}
