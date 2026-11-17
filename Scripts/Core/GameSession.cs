using Godot;

namespace PigeonRush.Core;

/// <summary>Stato di una partita. Classe C# pura: nessuna dipendenza dai nodi.</summary>
public sealed class GameSession
{
    public SpeedController Speed { get; } = new();
    public ScoreService Score { get; } = new();

    public int Lives { get; private set; } = GameConfig.MaxLives;
    public int Ammo { get; private set; } = GameConfig.StartAmmo;
    public float Elapsed { get; private set; }

    public float Difficulty => Mathf.Clamp(Elapsed / GameConfig.DifficultyRampTime, 0f, 1f);
    public bool IsOver => Lives <= 0;

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

    /// <returns>true se la piuma è stata aggiunta (false se già al massimo).</returns>
    public bool AddLife()
    {
        if (Lives >= GameConfig.MaxLives)
            return false;
        Lives++;
        return true;
    }

    public void TakeDamage()
    {
        if (Lives <= 0)
            return;
        Lives--;
        Speed.ClearBoost();
        Score.BreakCombo();
    }
}
