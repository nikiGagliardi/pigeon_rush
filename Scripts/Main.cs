using Godot;
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

    private GameState _state = GameState.Title;
    private long _best;
    private bool _newRecord;
    private float _gameOverDelay;
    private float _inputDelay;
    private float _noAmmoCooldown;

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
        _poop.VehicleHit += OnVehicleHit;

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

        _session.Tick(dt);
        var speed = _session.Speed;
        var groundStep = speed.PigeonSpeed * dt;
        var trafficStep = speed.ApproachSpeed * dt;

        var input = Input.GetVector(Actions.MoveLeft, Actions.MoveRight, Actions.MoveDown, Actions.MoveUp) + _touch.MoveVector;
        if (input.LengthSquared() > 1f)
            input = input.Normalized();
        _traffic.GetFlyLimits(_pigeon.Position.Z, out var minX, out var maxX);
        _pigeon.Tick(dt, input, 10f + speed.BoostNormalized * 8f, minX, maxX);

        _road.Advance(groundStep);
        _traffic.Tick(dt, groundStep, trafficStep, _session);
        _ambient.Tick(dt, speed.PigeonSpeed);

        _poop.UpdateLock(dt, _pigeon, _traffic.Vehicles, speed.ApproachSpeed);
        var poopPressed = _touch.ConsumePoop() | Input.IsActionJustPressed(Actions.Poop);
        if (poopPressed && _inputDelay <= 0f)
            TryPoop();
        _poop.Tick(dt, groundStep, trafficStep, _traffic.Vehicles);

        _traffic.ResolvePigeon(_pigeon, groundStep, trafficStep);
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
            _screens.ShowGameOver(_session, _best, _newRecord);
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
            if (_noAmmoCooldown <= 0f)
            {
                _texts.Spawn("Out of poop! Grab some crumbs", Palette.Danger, _pigeon.Position + new Vector3(0f, 1.2f, -2f), 0.6f, 1.2f);
                _noAmmoCooldown = 1.2f;
            }

            return;
        }

        _poop.TryDrop(_pigeon, _session, _session.Speed.ApproachSpeed);
    }

    private void OnVehicleHit(Vehicle vehicle, Vector3 position)
    {
        var points = _session.Score.RegisterHit(vehicle.Spec.Points);
        _session.Speed.AddBoost(vehicle.Spec.Boost);

        _texts.Spawn($"+{points}", Palette.Gold, position + new Vector3(0f, 1f, 0f), 1.2f);
        if (vehicle.Spec.HitLabel.Length > 0)
            _texts.Spawn(vehicle.Spec.HitLabel, Colors.White, position + new Vector3(0f, 2.2f, 0f), 0.7f, 1.1f);

        _camera.AddTrauma(0.12f);
    }

    private void OnNearMiss(Vector3 position)
    {
        var points = _session.Score.RegisterNearMiss();
        _texts.Spawn($"Close call! +{points}", Palette.Info, position + new Vector3(0f, 0.9f, -2.5f), 0.7f);
    }

    private void OnPickupCollected(PickupKind kind, Vector3 position)
    {
        var textPosition = _pigeon.Position + new Vector3(0f, 1f, -2.5f);
        switch (kind)
        {
            case PickupKind.Crumbs:
                _session.AddAmmo(GameConfig.CrumbsAmmo);
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
        _camera.AddTrauma(0.85f);
        _featherBurst.GlobalPosition = position;
        _featherBurst.Restart();
        Input.VibrateHandheld(250);
        EnterGameOver();
    }

    private void StartGame()
    {
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
