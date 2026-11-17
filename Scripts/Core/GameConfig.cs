using Godot;

namespace PigeonRush.Core;

/// <summary>
/// Costanti di gameplay. Unità: metri e secondi.
/// Convenzione assi: il piccione guarda verso -Z e resta a Z = 0;
/// il mondo (strada, mezzi, cartelli) scorre verso +Z.
/// </summary>
public static class GameConfig
{
    // --- Strada ---
    public const int LaneCount = 3;
    public const float LaneWidth = 3.6f;
    public const float RoadHalfWidth = LaneCount * LaneWidth * 0.5f;
    public static float LaneX(int lane) => (lane - (LaneCount - 1) * 0.5f) * LaneWidth;

    // --- Area di volo (abbastanza stretta da sovrapporsi alle corsie esterne) ---
    public const float FlyHalfWidth = 4.6f;
    public const float FlyMinY = 0.6f;
    public const float FlyMaxY = 7.0f;
    public const float PigeonStartY = 3.0f;
    public static readonly Vector3 PigeonHalfExtents = new(0.4f, 0.22f, 0.45f);

    // --- Fasce di altezza per la griglia "varco garantito" ---
    public const int BandCount = 3;
    public static float BandCenterY(int band) => band switch
    {
        0 => 1.3f,
        1 => 3.2f,
        _ => 5.4f,
    };

    // --- Mondo ---
    public const float SpawnZ = -300f;
    public const float DespawnZ = 25f;
    public const float SegmentLength = 40f;
    public const int SegmentCount = 10;

    // --- Velocità ---
    public const float TrafficSpeed = 20f;
    public const float BasePigeonSpeed = 16f;
    public const float MaxBasePigeonSpeed = 30f;
    public const float SpeedRamp = 0.11f;
    public const int MaxBoostStacks = 5;
    public const float BoostPerStack = 0.12f;
    public const float BoostStackDuration = 3.5f;

    // --- Movimento piccione ---
    public const float MaxLateralSpeed = 13f;
    public const float MaxVerticalSpeed = 9f;
    public const float FlyAcceleration = 55f;

    // --- Cacca ---
    public const int MaxAmmo = 10;
    public const int StartAmmo = 6;
    public const int CrumbsAmmo = 3;
    public const float PoopCooldown = 0.22f;
    public const float PoopGravity = 32f;
    public const float PoopInitialDown = 6f;
    public const float LockMinAhead = 2f;
    public const float LockMaxAhead = 32f;

    // --- Vite ---
    public const int MaxLives = 3;
    public const float InvulnerableTime = 1.6f;

    // --- Punteggio ---
    public const float ComboWindow = 3.5f;
    public const int MaxComboMultiplier = 5;
    public const float NearMissDistance = 0.9f;
    public const int NearMissPoints = 50;
    public const float LowFlyHeight = 2.0f;
    public const float LowFlyBonus = 1.5f;

    // --- Difficoltà ---
    public const float DifficultyRampTime = 150f;
    public const float StartGrace = 2.0f;
}
