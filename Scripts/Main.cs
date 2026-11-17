using Godot;
using PigeonRush.Audio;
using PigeonRush.CameraRig;
using PigeonRush.Core;
using PigeonRush.Effects;
using PigeonRush.Player;
using PigeonRush.Rendering;
using PigeonRush.UI;
using PigeonRush.World;

namespace PigeonRush;

/// <summary>
/// Regista del gioco: costruisce la scena da codice e orchestra l'ordine di aggiornamento
/// (input → velocità → mondo → mirino/cacca → collisioni → punteggio → camera/UI).
/// </summary>
public partial class Main : Node3D
{
    private enum GameState
    {
        Title,
        Playing,
        Paused,
        GameOver,
    }

    /// <summary>Dopo "Try again" la scena viene ricaricata: salta il titolo.</summary>
    private static bool _skipTitleOnLoad;

    private readonly GameSession _session = new();
    private readonly System.Random _rng = new();

    private DirectionalLight3D _sun = null!;
    private Godot.Environment _environment = null!;
    private float _appliedDarkness = -1f;

    private PigeonController _pigeon = null!;
    private ChaseCamera _camera = null!;
    private RoadScroller _road = null!;
    private TrafficSpawner _traffic = null!;
    private AmbientTraffic _ambient = null!;
    private PoopSystem _poop = null!;
    private FloatingTextPool _texts = null!;
    private CpuParticles3D _featherBurst = null!;
    private Hud _hud = null!;
    private TouchControls _touch = null!;
    private Screens _screens = null!;
    private AssetWarmup? _warmup;
    private GameAudio _audio = null!;

    private GameState _state = GameState.Title;
    private long _best;
    private bool _newRecord;
    private float _gameOverDelay;
    private float _inputDelay;
    private float _noAmmoCooldown;

    // audio: limiti di frequenza per non affollare il mix
    private float _hornCooldown;
    private float _lockSoundCooldown;
    private float _flapCooldown;
    private bool _climbing;
    private Vehicle? _lastLock;

    public override void _Ready()
    {
        Actions.EnsureRegistered();
        _best = SaveData.LoadBest();

        var worldEnvironment = SceneryFactory.CreateEnvironment();
        _environment = worldEnvironment.Environment!;
        AddChild(worldEnvironment);
        _sun = SceneryFactory.CreateSun();
        AddChild(_sun);
        AddChild(SceneryFactory.CreateBackdrop());

        // prima del traffico: veicoli e cantieri cercano GameAudio.Instance
        _audio = new GameAudio();
        AddChild(_audio);

        _road = new RoadScroller();
        AddChild(_road);

        _traffic = new TrafficSpawner();
        AddChild(_traffic);

        _ambient = new AmbientTraffic();
        AddChild(_ambient);

        _pigeon = new PigeonController();
        AddChild(_pigeon);

        _poop = new PoopSystem();
        AddChild(_poop);

        _texts = new FloatingTextPool();
        AddChild(_texts);

        _featherBurst = EffectsFactory.CreateFeatherBurst();
        AddChild(_featherBurst);

        _camera = new ChaseCamera { Target = _pigeon };
        AddChild(_camera);
        _camera.MakeCurrent();
        _camera.Snap();

        // prepara mesh e shader durante il menu: niente scatti alla prima galleria/cantiere
        _warmup = new AssetWarmup();
        _camera.AddChild(_warmup);

        var ui = new CanvasLayer { Layer = 10, ProcessMode = ProcessModeEnum.Always };
        AddChild(ui);
        _hud = new Hud();
        ui.AddChild(_hud);
        _touch = new TouchControls();
        ui.AddChild(_touch);
        _screens = new Screens();
        ui.AddChild(_screens);

        _hud.SetBest(_best);
        _hud.PausePressed += Pause;
        _screens.StartPressed += StartGame;
        _screens.ResumePressed += Resume;
        _screens.RestartPressed += Restart;
        _traffic.PigeonHit += OnPigeonHit;
        _traffic.NearMiss += OnNearMiss;
        _traffic.PickupCollected += OnPickupCollected;
        _traffic.VehicleWarned += OnVehicleWarned;
        _traffic.VehiclePassing += OnVehiclePassing;
        _poop.VehicleHit += OnVehicleHit;
        _poop.RoadHit += OnPoopRoadHit;

        if (_skipTitleOnLoad)
        {
            _skipTitleOnLoad = false;
            StartGame();
        }
        else
        {
            _hud.Visible = false;
            _screens.ShowTitle(_best);
        }
    }

    public override void _Process(double delta)
    {
        var dt = Mathf.Min((float)delta, 1f / 20f); // niente salti enormi dopo un lag

        switch (_state)
        {
            case GameState.Title:
                TickAmbient(dt);
                _pigeon.TickIdle(dt);
                break;
            case GameState.Playing:
                TickPlaying(dt);
                break;
            case GameState.GameOver:
                TickGameOver(dt);
                break;
        }

        _camera.Tick(dt, _session.Speed.BoostNormalized, _session.Speed.SpeedNormalized, _traffic.CameraCeiling(_camera.Position.Z));
        ApplyTunnelLighting(_traffic.TunnelDarkness);
        UpdateAmbience();
        _texts.Tick(dt);
        _touch.Ammo = _session.Ammo;
        _hud.Refresh(dt, _session, _poop.LockedTarget != null, _pigeon.Position.Y < GameConfig.LowFlyHeight);
    }

    public override void _Notification(int what)
    {
        // su mobile: app in background = pausa automatica
        if (what == NotificationApplicationFocusOut || what == NotificationApplicationPaused)
            Pause();
    }

    private void TickPlaying(float dt)
    {
        // _inputDelay evita che lo stesso Esc che ha chiuso la pausa la riapra subito
        if (_inputDelay <= 0f && Input.IsActionJustPressed(Actions.Pause))
        {
            Pause();
            return;
        }

        _inputDelay = Mathf.Max(0f, _inputDelay - dt);
        _noAmmoCooldown = Mathf.Max(0f, _noAmmoCooldown - dt);
        _hornCooldown = Mathf.Max(0f, _hornCooldown - dt);
        _lockSoundCooldown = Mathf.Max(0f, _lockSoundCooldown - dt);
        _flapCooldown = Mathf.Max(0f, _flapCooldown - dt);

        _session.Tick(dt);
        var speed = _session.Speed;
        var groundStep = speed.PigeonSpeed * dt;
        var trafficStep = speed.ApproachSpeed * dt;

        var input = Input.GetVector(Actions.MoveLeft, Actions.MoveRight, Actions.MoveDown, Actions.MoveUp) + _touch.MoveVector;
        if (input.LengthSquared() > 1f)
            input = input.Normalized();
        _traffic.GetFlyLimits(_pigeon.Position.Z, out var minX, out var maxX);
        _pigeon.Tick(dt, input, 10f + speed.BoostNormalized * 8f, minX, maxX);
        PlayFlapOnClimb(input.Y);

        _road.Advance(groundStep);
        _traffic.Tick(dt, groundStep, trafficStep, _session);
        _ambient.Tick(dt, speed.PigeonSpeed);

        _poop.UpdateLock(dt, _pigeon, _traffic.Vehicles, speed.ApproachSpeed);
        PlayLockSound();
        var poopPressed = _touch.ConsumePoop() | Input.IsActionJustPressed(Actions.Poop);
        if (poopPressed && _inputDelay <= 0f)
            TryPoop();
        _poop.Tick(dt, groundStep, trafficStep, _traffic.Vehicles);

        _traffic.ResolvePigeon(_pigeon, groundStep, trafficStep, speed.ApproachSpeed);
        if (_state != GameState.Playing)
            return; // game over durante le collisioni

        _session.Score.Tick(dt, groundStep, speed.Multiplier, _pigeon.Position.Y < GameConfig.LowFlyHeight);
    }

    private void TickAmbient(float dt)
    {
        const float ambientSpeed = GameConfig.BasePigeonSpeed * 0.6f;
        var groundStep = ambientSpeed * dt;
        _road.Advance(groundStep);
        _traffic.Tick(dt, groundStep, groundStep, _session);
        _ambient.Tick(dt, ambientSpeed);
    }

    private void TickGameOver(float dt)
    {
        var speed = _session.Speed;
        speed.TimeScale -= dt * 0.9f;
        var groundStep = speed.PigeonSpeed * dt;
        var trafficStep = speed.ApproachSpeed * dt;

        _road.Advance(groundStep);
        _traffic.Tick(dt, groundStep, trafficStep, _session);
        _ambient.Tick(dt, speed.PigeonSpeed);
        _poop.Tick(dt, groundStep, trafficStep, _traffic.Vehicles);
        _pigeon.TickCrash(dt);

        if (_gameOverDelay <= 0f)
            return;

        _gameOverDelay -= dt;
        if (_gameOverDelay <= 0f)
        {
            _screens.ShowGameOver(_session, _best, _newRecord);
            _audio.PlayUi(Sfx.GameOver);
        }
    }

    /// <summary>Loop d'ambiente: strada e vento crescono con la velocità, la galleria col buio.</summary>
    private void UpdateAmbience()
    {
        var speed = _session.Speed;
        var tunnel = _traffic.TunnelDarkness;
        switch (_state)
        {
            case GameState.Title:
                _audio.SetAmbience(0.3f, 0.12f, 0.9f, tunnel);
                break;
            case GameState.Playing:
                _audio.SetAmbience(
                    0.55f + 0.35f * speed.SpeedNormalized,
                    0.2f + 0.45f * speed.SpeedNormalized + 0.35f * speed.BoostNormalized,
                    0.9f + 0.25f * speed.SpeedNormalized + 0.12f * speed.BoostNormalized,
                    tunnel);
                break;
            case GameState.GameOver:
                _audio.SetAmbience(0f, 0f, 0.7f, tunnel * 0.5f);
                break;
        }
    }

    /// <summary>Battito d'ali quando il piccione inizia a salire.</summary>
    private void PlayFlapOnClimb(float inputY)
    {
        var climbing = inputY > 0.5f;
        if (climbing && !_climbing && _flapCooldown <= 0f)
        {
            _audio.Play(Sfx.Flap, 0f, 0.9f + _rng.NextSingle() * 0.2f);
            _flapCooldown = 0.3f;
        }

        _climbing = climbing;
    }

    private void PlayLockSound()
    {
        var locked = _poop.LockedTarget;
        if (locked != null && locked != _lastLock && _lockSoundCooldown <= 0f)
        {
            _audio.Play(Sfx.LockOn);
            _lockSoundCooldown = 0.25f;
        }

        _lastLock = locked;
    }

    /// <summary>In galleria sole e luce ambiente si spengono: restano visibili lampade e fari (unlit).</summary>
    private void ApplyTunnelLighting(float darkness)
    {
        if (Mathf.Abs(darkness - _appliedDarkness) < 0.005f)
            return;

        _appliedDarkness = darkness;
        _sun.LightEnergy = Mathf.Lerp(SceneryFactory.SunEnergy, 0f, darkness);
        _environment.AmbientLightEnergy = Mathf.Lerp(SceneryFactory.AmbientEnergy, 0.3f, darkness);
        _environment.FogLightColor = SceneryFactory.FogColor.Lerp(SceneryFactory.TunnelFogColor, darkness);
    }

    private void TryPoop()
    {
        if (_session.Ammo <= 0)
        {
            _audio.Play(Sfx.UiClick, 0f, 0.6f); // "clic a vuoto"

            if (_noAmmoCooldown <= 0f)
            {
                _texts.Spawn("Out of poop! Grab some crumbs", Palette.Danger, _pigeon.Position + new Vector3(0f, 1.2f, -2f), 0.6f, 1.2f);
                _noAmmoCooldown = 1.2f;
            }

            return;
        }

        if (_poop.TryDrop(_pigeon, _session, _session.Speed.ApproachSpeed))
            _audio.Play(Sfx.PoopDrop, 0f, 0.95f + _rng.NextSingle() * 0.15f);
    }

    /// <summary>Il mezzo davanti lampeggia: clacson (tromba per camion e bus).</summary>
    private void OnVehicleWarned(Vehicle vehicle)
    {
        if (_hornCooldown > 0f)
            return;

        _hornCooldown = 0.6f;
        var sound = vehicle.IsHeavy ? Sfx.HornTruck : _rng.NextSingle() < 0.5f ? Sfx.HornCar : Sfx.HornCarDouble;
        var pitch = vehicle.IsHeavy ? 0.97f + _rng.NextSingle() * 0.06f : 0.92f + _rng.NextSingle() * 0.1f;
        _audio.PlayAt(sound, vehicle, new Vector3(0f, 1f, vehicle.Spec.Length * 0.5f), 0f, pitch, 25f, 220f);
    }

    private void OnVehiclePassing(Vehicle vehicle)
    {
        var sound = vehicle.IsHeavy ? Sfx.PassbyTruck : Sfx.PassbyCar;
        _audio.PlayAt(sound, vehicle, Vector3.Zero, 0f, 0.95f + _rng.NextSingle() * 0.1f, 20f, 120f);
    }

    private void OnPoopRoadHit(Vector3 position)
        => _audio.PlayAt(Sfx.Splat, null, position, -10f, 1.3f, 6f, 60f);

    private void OnVehicleHit(Vehicle vehicle, Vector3 position)
    {
        var points = _session.Score.RegisterHit(vehicle.Spec.Points);
        _session.Speed.AddBoost(vehicle.Spec.Boost);

        _texts.Spawn($"+{points}", Palette.Gold, position + new Vector3(0f, 1f, 0f), 1.2f);
        if (vehicle.Spec.HitLabel.Length > 0)
            _texts.Spawn(vehicle.Spec.HitLabel, Colors.White, position + new Vector3(0f, 2.2f, 0f), 0.7f, 1.1f);

        _camera.AddTrauma(0.12f);

        _audio.Play(Sfx.Splat);
        var combo = _session.Score.Combo;
        if (combo >= 2)
            _audio.Play(Sfx.Combo, 0f, 1f + 0.06f * (Mathf.Min(combo, GameConfig.MaxComboMultiplier) - 2), 0.08f);

        // l'autista non la prende bene
        if (_rng.NextSingle() < 0.7f)
        {
            var horn = vehicle.IsHeavy ? Sfx.HornTruck : Sfx.HornCarAngry;
            _audio.PlayAt(horn, vehicle, new Vector3(0f, 1f, 0f), 0f, 0.95f + _rng.NextSingle() * 0.05f, 20f, 160f, 0.35f);
        }
    }

    private void OnNearMiss(Vector3 position)
    {
        var points = _session.Score.RegisterNearMiss();
        _audio.Play(Sfx.NearMiss);
        _texts.Spawn($"Close call! +{points}", Palette.Info, position + new Vector3(0f, 0.9f, -2.5f), 0.7f);
    }

    private void OnPickupCollected(PickupKind kind, Vector3 position)
    {
        var textPosition = _pigeon.Position + new Vector3(0f, 1f, -2.5f);
        switch (kind)
        {
            case PickupKind.Crumbs:
                _session.AddAmmo(GameConfig.CrumbsAmmo);
                _audio.Play(Sfx.Pickup);
                _session.Score.AddPoints(20);
                _texts.Spawn($"+{GameConfig.CrumbsAmmo} poop", Palette.Crumb, textPosition, 0.8f);
                break;
        }
    }

    private void OnPigeonHit(Vector3 position)
    {
        if (_state != GameState.Playing)
            return;

        // un colpo e basta: niente vite, niente invulnerabilità
        _session.Crash();
        _audio.Play(Sfx.Crash);
        _camera.AddTrauma(0.85f);
        _featherBurst.GlobalPosition = position;
        _featherBurst.Restart();
        Input.VibrateHandheld(250);
        EnterGameOver();
    }

    private void StartGame()
    {
        if (_warmup != null && IsInstanceValid(_warmup) && !_warmup.IsDone)
            _warmup.FinishNow();

        _state = GameState.Playing;
        _inputDelay = 0.25f; // evita che lo Spazio del menu sganci subito
        _session.Speed.TimeScale = 1f;
        _screens.HideAll();
        _hud.Visible = true;
        _touch.Enabled = true;
        _traffic.SpawningEnabled = true;
    }

    private void Pause()
    {
        if (_state != GameState.Playing)
            return;

        _state = GameState.Paused;
        _touch.Enabled = false;
        _audio.PlayUi(Sfx.UiClick);
        GetTree().Paused = true;
        _screens.ShowPause();
    }

    private void Resume()
    {
        if (_state != GameState.Paused)
            return;

        GetTree().Paused = false;
        _state = GameState.Playing;
        _inputDelay = 0.25f;
        _screens.HideAll();
        _touch.Enabled = true;
    }

    private void Restart()
    {
        GetTree().Paused = false;
        _skipTitleOnLoad = true;
        GetTree().ReloadCurrentScene();
    }

    private void EnterGameOver()
    {
        _state = GameState.GameOver;
        _touch.Enabled = false;
        _traffic.SpawningEnabled = false;
        _gameOverDelay = 1.3f;

        var score = _session.Score.Score;
        _newRecord = score > _best;
        if (_newRecord)
        {
            _best = score;
            SaveData.SaveBest(score);
        }
    }
}
