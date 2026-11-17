using System;
using System.Collections.Generic;
using Godot;

namespace PigeonRush.Audio;

/// <summary>Effetti sonori del gioco (file in res://Audio/sfx, generati da Tools/synth_sfx.py).</summary>
public enum Sfx
{
    HornCar,
    HornCarDouble,
    HornCarAngry,
    HornTruck,
    PassbyCar,
    PassbyTruck,
    Flap,
    PoopDrop,
    Splat,
    Crash,
    Pickup,
    Combo,
    LockOn,
    NearMiss,
    IndicatorTick,
    IndicatorTock,
    WorksBeep,
    CountdownBeep,
    CountdownGo,
    UiClick,
    GameOver,
}

/// <summary>
/// Audio del gioco: pool di player 2D e 3D, tre loop d'ambiente (strada, vento, galleria) e i bus.
/// Bus: World (effetti di gioco, riverbero attivo in galleria), Ambience (loop), UI (menu).
/// I player sono figli di questo nodo: con il gioco in pausa si fermano da soli, tranne quello della UI.
/// L'ascoltatore è la camera corrente.
/// </summary>
public partial class GameAudio : Node3D
{
    public const string WorldBus = "World";
    public const string AmbienceBus = "Ambience";
    public const string UiBus = "UI";

    // --- volumi da ritoccare a orecchio (dB) ---
    private const float WorldBusDb = 0f;
    private const float AmbienceBusDb = -3f;
    private const float UiBusDb = -4f;

    private const int Pool2D = 10;
    private const int Pool3D = 14;

    /// <summary>Volume base di ogni effetto, nello stesso ordine di <see cref="Sfx"/>.</summary>
    private static readonly float[] BaseDb =
    {
        -2f,  // HornCar
        -2f,  // HornCarDouble
        -1f,  // HornCarAngry
        -1f,  // HornTruck
        -5f,  // PassbyCar
        -3f,  // PassbyTruck
        -12f, // Flap
        -6f,  // PoopDrop
        -2f,  // Splat
        0f,   // Crash
        -3f,  // Pickup
        -4f,  // Combo
        -9f,  // LockOn
        -4f,  // NearMiss
        -6f,  // IndicatorTick
        -6f,  // IndicatorTock
        -4f,  // WorksBeep
        -3f,  // CountdownBeep
        -2f,  // CountdownGo
        -6f,  // UiClick
        -2f,  // GameOver
    };

    private static readonly string[] FileNames =
    {
        "horn_car", "horn_car_double", "horn_car_angry", "horn_truck", "passby_car", "passby_truck",
        "flap", "poop_drop", "splat", "crash", "pickup", "combo", "lock_on", "near_miss",
        "indicator_tick", "indicator_tock", "works_beep", "countdown_beep", "countdown_go", "ui_click", "game_over",
    };

    private sealed class Spatial
    {
        public AudioStreamPlayer3D Player = null!;
        public Node3D? Follow;
        public Vector3 Offset;
    }

    private struct Pending
    {
        public Sfx Sound;
        public Node3D? Follow;
        public Vector3 Position;
        public float VolumeDb;
        public float Pitch;
        public float Delay;
        public float UnitSize;
        public float MaxDistance;
        public bool Is3D;
    }

    private readonly AudioStream?[] _streams = new AudioStream?[FileNames.Length];
    private readonly AudioStreamPlayer[] _players2D = new AudioStreamPlayer[Pool2D];
    private readonly Spatial[] _players3D = new Spatial[Pool3D];
    private readonly List<Pending> _pending = new();
    private AudioStreamPlayer _uiPlayer = null!;
    private int _next2D;
    private int _next3D;

    // loop d'ambiente
    private AudioStreamPlayer _road = null!;
    private AudioStreamPlayer _wind = null!;
    private AudioStreamPlayer _tunnel = null!;
    private float _roadLevel, _windLevel, _tunnelLevel, _windPitch = 1f;
    private float _roadTarget, _windTarget, _tunnelTarget, _windPitchTarget = 1f;

    private int _worldBusIndex = -1;
    private bool _reverbOn;

    public static GameAudio? Instance { get; private set; }

    public override void _EnterTree() => Instance = this;

    public override void _ExitTree()
    {
        if (Instance == this)
            Instance = null;
    }

    public override void _Ready()
    {
        EnsureBuses();

        for (var i = 0; i < FileNames.Length; i++)
            _streams[i] = LoadStream(FileNames[i], loop: (Sfx)i == Sfx.WorksBeep);

        for (var i = 0; i < Pool2D; i++)
        {
            _players2D[i] = new AudioStreamPlayer { Bus = WorldBus };
            AddChild(_players2D[i]);
        }

        for (var i = 0; i < Pool3D; i++)
        {
            var player = CreateSpatialPlayer(WorldBus);
            AddChild(player);
            _players3D[i] = new Spatial { Player = player };
        }

        _uiPlayer = new AudioStreamPlayer { Bus = UiBus, ProcessMode = ProcessModeEnum.Always };
        AddChild(_uiPlayer);

        _road = CreateLoop("road_loop");
        _wind = CreateLoop("wind_loop");
        _tunnel = CreateLoop("tunnel_loop");
    }

    public override void _Process(double delta)
    {
        var dt = (float)delta;
        TickPending(dt);
        TickFollowers();
        TickAmbience(dt);
    }

    /// <summary>Player 3D già configurato (usato anche per sorgenti fisse come il cicalino del cantiere).</summary>
    public static AudioStreamPlayer3D CreateSpatialPlayer(string bus, float unitSize = 10f, float maxDistance = 160f) => new()
    {
        Bus = bus,
        UnitSize = unitSize,
        MaxDistance = maxDistance,
        AttenuationModel = AudioStreamPlayer3D.AttenuationModelEnum.InverseDistance,
        AttenuationFilterCutoffHz = 12000f,
        DopplerTracking = AudioStreamPlayer3D.DopplerTrackingEnum.Disabled, // il Doppler è già nei file di passaggio
    };

    public AudioStream? Stream(Sfx sound) => _streams[(int)sound];

    /// <summary>Effetto non posizionale (eventi del piccione, punteggio).</summary>
    public void Play(Sfx sound, float volumeDb = 0f, float pitch = 1f, float delay = 0f)
    {
        if (delay > 0f)
        {
            _pending.Add(new Pending { Sound = sound, VolumeDb = volumeDb, Pitch = pitch, Delay = delay });
            return;
        }

        var stream = _streams[(int)sound];
        if (stream == null)
            return;

        var player = _players2D[_next2D];
        for (var n = 0; n < Pool2D; n++)
        {
            var candidate = _players2D[(_next2D + n) % Pool2D];
            if (!candidate.Playing)
            {
                player = candidate;
                break;
            }
        }

        _next2D = (_next2D + 1) % Pool2D;
        player.Stream = stream;
        player.VolumeDb = BaseDb[(int)sound] + volumeDb;
        player.PitchScale = pitch;
        player.Play();
    }

    /// <summary>
    /// Effetto posizionale. Con <paramref name="follow"/> la sorgente segue il nodo (veicolo) finché suona.
    /// </summary>
    public void PlayAt(Sfx sound, Node3D? follow, Vector3 position, float volumeDb = 0f, float pitch = 1f,
        float unitSize = 10f, float maxDistance = 160f, float delay = 0f)
    {
        if (delay > 0f)
        {
            _pending.Add(new Pending
            {
                Sound = sound, Follow = follow, Position = position, VolumeDb = volumeDb, Pitch = pitch, Delay = delay,
                UnitSize = unitSize, MaxDistance = maxDistance, Is3D = true,
            });
            return;
        }

        var stream = _streams[(int)sound];
        if (stream == null)
            return;

        var slot = _players3D[_next3D];
        for (var n = 0; n < Pool3D; n++)
        {
            var candidate = _players3D[(_next3D + n) % Pool3D];
            if (!candidate.Player.Playing)
            {
                slot = candidate;
                break;
            }
        }

        _next3D = (_next3D + 1) % Pool3D;
        var player = slot.Player;
        slot.Follow = follow;
        slot.Offset = follow != null ? position : Vector3.Zero;
        player.GlobalPosition = follow != null ? follow.GlobalPosition + position : position;
        player.Stream = stream;
        player.VolumeDb = BaseDb[(int)sound] + volumeDb;
        player.PitchScale = pitch;
        player.UnitSize = unitSize;
        player.MaxDistance = maxDistance;
        player.Play();
    }

    /// <summary>Suoni dei menu: funzionano anche col gioco in pausa.</summary>
    public void PlayUi(Sfx sound, float volumeDb = 0f, float pitch = 1f)
    {
        var stream = _streams[(int)sound];
        if (stream == null)
            return;

        _uiPlayer.Stream = stream;
        _uiPlayer.VolumeDb = BaseDb[(int)sound] + volumeDb;
        _uiPlayer.PitchScale = pitch;
        _uiPlayer.Play();
    }

    /// <summary>Livelli (0..1) dei loop d'ambiente: vengono raggiunti con una dissolvenza morbida.</summary>
    public void SetAmbience(float road, float wind, float windPitch, float tunnel)
    {
        _roadTarget = Mathf.Clamp(road, 0f, 1f);
        _windTarget = Mathf.Clamp(wind, 0f, 1f);
        _windPitchTarget = windPitch;
        _tunnelTarget = Mathf.Clamp(tunnel, 0f, 1f);
        SetReverb(tunnel > 0.3f);
    }

    private void TickPending(float dt)
    {
        for (var i = _pending.Count - 1; i >= 0; i--)
        {
            var pending = _pending[i];
            pending.Delay -= dt;
            if (pending.Delay > 0f)
            {
                _pending[i] = pending;
                continue;
            }

            _pending.RemoveAt(i);
            if (!pending.Is3D)
            {
                Play(pending.Sound, pending.VolumeDb, pending.Pitch);
            }
            else if (pending.Follow == null || (IsInstanceValid(pending.Follow) && pending.Follow.Visible))
            {
                // se nel frattempo il veicolo è tornato nel pool, il suono non parte più
                PlayAt(pending.Sound, pending.Follow, pending.Position, pending.VolumeDb, pending.Pitch, pending.UnitSize, pending.MaxDistance);
            }
        }
    }

    private void TickFollowers()
    {
        foreach (var slot in _players3D)
        {
            if (slot.Follow == null)
                continue;

            // il veicolo è tornato nel pool: la sorgente resta dov'era
            if (!slot.Player.Playing || !IsInstanceValid(slot.Follow) || !slot.Follow.Visible)
            {
                slot.Follow = null;
                continue;
            }

            slot.Player.GlobalPosition = slot.Follow.GlobalPosition + slot.Offset;
        }
    }

    private void TickAmbience(float dt)
    {
        _roadLevel = Mathf.MoveToward(_roadLevel, _roadTarget, dt * 0.8f);
        _windLevel = Mathf.MoveToward(_windLevel, _windTarget, dt * 0.8f);
        _tunnelLevel = Mathf.MoveToward(_tunnelLevel, _tunnelTarget, dt * 1.5f);
        _windPitch = Mathf.MoveToward(_windPitch, _windPitchTarget, dt * 0.5f);

        ApplyLoop(_road, _roadLevel, 1f);
        ApplyLoop(_wind, _windLevel, _windPitch);
        ApplyLoop(_tunnel, _tunnelLevel, 1f);
    }

    private static void ApplyLoop(AudioStreamPlayer player, float level, float pitch)
    {
        if (level <= 0.001f)
        {
            if (player.Playing)
                player.Stop();
            return;
        }

        player.VolumeDb = Mathf.LinearToDb(level);
        player.PitchScale = Mathf.Max(0.05f, pitch);
        if (!player.Playing && player.Stream != null)
            player.Play();
    }

    private AudioStreamPlayer CreateLoop(string fileName)
    {
        var player = new AudioStreamPlayer { Bus = AmbienceBus, Stream = LoadStream(fileName, loop: true), VolumeDb = -80f };
        AddChild(player);
        return player;
    }

    private static AudioStream? LoadStream(string fileName, bool loop)
    {
        var path = $"res://Audio/sfx/{fileName}.wav";
        if (!ResourceLoader.Exists(path))
        {
            GD.PushWarning($"[Audio] manca {path}");
            return null;
        }

        var stream = GD.Load<AudioStream>(path);
        if (loop && stream is AudioStreamWav wav && wav.LoopMode == AudioStreamWav.LoopModeEnum.Disabled)
        {
            // i loop sono già "senza cucitura" nel file: si ripete tutto, dall'inizio alla fine
            wav.LoopBegin = 0;
            wav.LoopEnd = (int)Math.Round(wav.GetLength() * wav.MixRate);
            wav.LoopMode = AudioStreamWav.LoopModeEnum.Forward;
        }

        return stream;
    }

    /// <summary>I bus restano nell'AudioServer anche dopo il ricaricamento della scena: si creano una volta sola.</summary>
    private void EnsureBuses()
    {
        _worldBusIndex = EnsureBus(WorldBus, WorldBusDb);
        EnsureBus(AmbienceBus, AmbienceBusDb);
        EnsureBus(UiBus, UiBusDb);

        if (AudioServer.GetBusEffectCount(_worldBusIndex) == 0)
        {
            var reverb = new AudioEffectReverb
            {
                RoomSize = 0.55f,
                Damping = 0.35f,
                Spread = 0.8f,
                Hipass = 0.15f,
                Dry = 1f,
                Wet = 0.28f,
                PredelayMsec = 40f,
            };
            AudioServer.AddBusEffect(_worldBusIndex, reverb);
        }

        _reverbOn = true;
        SetReverb(false);
    }

    private static int EnsureBus(string name, float volumeDb)
    {
        var index = AudioServer.GetBusIndex(name);
        if (index < 0)
        {
            AudioServer.AddBus();
            index = AudioServer.BusCount - 1;
            AudioServer.SetBusName(index, name);
            AudioServer.SetBusSend(index, "Master");
        }

        AudioServer.SetBusVolumeDb(index, volumeDb);
        return index;
    }

    private void SetReverb(bool on)
    {
        if (on == _reverbOn || _worldBusIndex < 0)
            return;

        _reverbOn = on;
        AudioServer.SetBusEffectEnabled(_worldBusIndex, 0, on);
    }
}
