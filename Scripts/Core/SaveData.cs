using Godot;

namespace PigeonRush.Core;

/// <summary>Record persistente in user:// (funziona uguale su PC e mobile).</summary>
public static class SaveData
{
    private const string FilePath = "user://pigeon_rush.cfg";
    private const string Section = "records";
    private const string BestKey = "best_score";

    public static long LoadBest()
    {
        var cfg = new ConfigFile();
        if (cfg.Load(FilePath) != Error.Ok)
            return 0;
        return cfg.GetValue(Section, BestKey, 0L).AsInt64();
    }

    public static void SaveBest(long score)
    {
        var cfg = new ConfigFile();
        cfg.Load(FilePath); // se non esiste parte vuoto
        cfg.SetValue(Section, BestKey, score);
        cfg.Save(FilePath);
    }
}
