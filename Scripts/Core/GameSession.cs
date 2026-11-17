using Godot;

namespace PigeonRush.Core;

/// <summary>Stato di una partita. Classe C# pura: nessuna dipendenza dai nodi.</summary>
public sealed class GameSession
{
    public SpeedController Speed { get; } = new();
    public ScoreService Score { get; } = new();

    public int Ammo { get; private set; } = GameConfig.StartAmmo;
    public float Elapsed { get; private set; }

    public float Difficulty => Mathf.Clamp(Elapsed / GameConfig.DifficultyRampTime, 0f, 1f);
    /// <summary>Regola del gioco: al primo colpo il piccione è spacciato.</summary>
    public bool IsOver { get; private set; }

    public void Tick(float dt)
    {
        Elapsed += dt;
        Speed.Tick(dt);
    }

    public bool TryUseAmmo()
    {
        if (Ammo <= 0)
            return false;
        Ammo--;
        return true;
    }

    public void AddAmmo(int amount) => Ammo = Mathf.Min(GameConfig.MaxAmmo, Ammo + amount);

    public void Crash()
    {
        IsOver = true;
        Speed.ClearBoost();
        Score.BreakCombo();
    }
}
