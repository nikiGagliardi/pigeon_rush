using System;

namespace PigeonRush.Core;

/// <summary>Punteggio: distanza × boost × bonus volo radente, colpi con combo, passaggi a filo.</summary>
public sealed class ScoreService
{
    private double _score;
    private float _comboTimer;

    public long Score => (long)_score;
    public float Distance { get; private set; }
    public int Combo { get; private set; }
    public int Hits { get; private set; }
    public int NearMisses { get; private set; }
    public int BestCombo { get; private set; }

    public int ComboMultiplier => Math.Clamp(Combo, 1, GameConfig.MaxComboMultiplier);
    public float ComboTimeLeft => Combo > 0 ? _comboTimer / GameConfig.ComboWindow : 0f;

    public void Tick(float dt, float metres, float speedMultiplier, bool lowFlying)
    {
        Distance += metres;
        _score += metres * speedMultiplier * (lowFlying ? GameConfig.LowFlyBonus : 1f);

        if (Combo <= 0)
            return;

        _comboTimer -= dt;
        if (_comboTimer <= 0f)
            Combo = 0;
    }

    /// <returns>Punti assegnati per il colpo.</returns>
    public int RegisterHit(int basePoints)
    {
        Combo++;
        BestCombo = Math.Max(BestCombo, Combo);
        Hits++;
        _comboTimer = GameConfig.ComboWindow;
        var points = basePoints * ComboMultiplier;
        _score += points;
        return points;
    }

    /// <returns>Punti assegnati per il passaggio a filo.</returns>
    public int RegisterNearMiss()
    {
        NearMisses++;
        if (Combo > 0)
            _comboTimer = GameConfig.ComboWindow; // un passaggio a filo tiene viva la combo
        var points = GameConfig.NearMissPoints * ComboMultiplier;
        _score += points;
        return points;
    }

    public void AddPoints(int points) => _score += points;

    public void BreakCombo()
    {
        Combo = 0;
        _comboTimer = 0f;
    }
}
