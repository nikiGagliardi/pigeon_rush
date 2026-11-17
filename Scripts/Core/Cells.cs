using System.Numerics;

namespace PigeonRush.Core;

/// <summary>
/// Griglia 3 corsie × 3 fasce di altezza codificata come bitmask.
/// Serve allo spawner per garantire sempre un varco raggiungibile.
/// </summary>
public static class Cells
{
    public const int CellCount = GameConfig.LaneCount * GameConfig.BandCount;
    public const int All = (1 << CellCount) - 1;

    public static int Of(int lane, int band) => 1 << (lane * GameConfig.BandCount + band);

    public static int Band(int band)
    {
        var mask = 0;
        for (var lane = 0; lane < GameConfig.LaneCount; lane++)
            mask |= Of(lane, band);
        return mask;
    }

    public static int CountOf(int mask) => BitOperations.PopCount((uint)mask);

    public static bool Has(int mask, int lane, int band) => (mask & Of(lane, band)) != 0;

    /// <summary>Espande la maschera alle celle adiacenti (±1 corsia, ±1 fascia, diagonali incluse).</summary>
    public static int Dilate(int mask)
    {
        var result = 0;
        for (var lane = 0; lane < GameConfig.LaneCount; lane++)
        for (var band = 0; band < GameConfig.BandCount; band++)
        {
            if (!Has(mask, lane, band))
                continue;

            for (var dl = -1; dl <= 1; dl++)
            for (var db = -1; db <= 1; db++)
            {
                int l = lane + dl, b = band + db;
                if (l >= 0 && l < GameConfig.LaneCount && b >= 0 && b < GameConfig.BandCount)
                    result |= Of(l, b);
            }
        }

        return result;
    }
}
