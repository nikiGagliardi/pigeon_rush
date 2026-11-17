using Godot;

namespace PigeonRush.Core;

/// <summary>
/// Velocità del piccione: base che cresce nel tempo + boost cumulabili ottenuti centrando i mezzi.
/// Ogni stack dura <see cref="GameConfig.BoostStackDuration"/> secondi, poi ne scade uno alla volta.
/// </summary>
public sealed class SpeedController
{
    private float _stackTimer;
    private float _timeScale = 1f;

    public float BaseSpeed { get; private set; } = GameConfig.BasePigeonSpeed;
    public int BoostStacks { get; private set; }

    /// <summary>Usato per rallentare il mondo al game over (0..1).</summary>
    public float TimeScale
    {
        get => _timeScale;
        set => _timeScale = Mathf.Clamp(value, 0f, 1f);
    }

    public float Multiplier => 1f + BoostStacks * GameConfig.BoostPerStack;
    public float PigeonSpeed => BaseSpeed * Multiplier * _timeScale;
    public float ApproachSpeed => PigeonSpeed + GameConfig.TrafficSpeed * _timeScale;

    public float BoostNormalized => (float)BoostStacks / GameConfig.MaxBoostStacks;
    public float StackProgress => BoostStacks == 0 ? 0f : _stackTimer / GameConfig.BoostStackDuration;
    public float SpeedNormalized =>
        (BaseSpeed - GameConfig.BasePigeonSpeed) / (GameConfig.MaxBasePigeonSpeed - GameConfig.BasePigeonSpeed);

    public void Tick(float dt)
    {
        BaseSpeed = Mathf.Min(GameConfig.MaxBasePigeonSpeed, BaseSpeed + GameConfig.SpeedRamp * dt);

        if (BoostStacks <= 0)
            return;

        _stackTimer -= dt;
        if (_stackTimer <= 0f)
        {
            BoostStacks--;
            _stackTimer = BoostStacks > 0 ? GameConfig.BoostStackDuration : 0f;
        }
    }

    public void AddBoost(int stacks)
    {
        BoostStacks = Mathf.Min(GameConfig.MaxBoostStacks, BoostStacks + stacks);
        _stackTimer = GameConfig.BoostStackDuration;
    }

    public void ClearBoost()
    {
        BoostStacks = 0;
        _stackTimer = 0f;
    }
}
