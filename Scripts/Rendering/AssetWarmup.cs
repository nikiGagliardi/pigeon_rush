using System;
using System.Collections.Generic;
using System.Diagnostics;
using Godot;
using PigeonRush.Effects;
using PigeonRush.Player;
using PigeonRush.World;

namespace PigeonRush.Rendering;

/// <summary>
/// Evita i micro-blocchi alla prima comparsa di un oggetto (galleria, cantiere, bus, abbaglianti…).
/// Durante il menu costruisce tutti i mesh procedurali (uno per frame, così il menu resta fluido)
/// e li disegna una volta in miniatura davanti alla camera: così la geometria è già caricata sulla GPU
/// e gli shader/pipeline sono già compilati quando inizia la partita.
/// Va aggiunto come figlio della camera.
/// </summary>
public partial class AssetWarmup : Node3D
{
    private const float PreviewDistance = 3f;
    private const float PreviewSize = 0.05f;   // pochi pixel, e dietro al pannello del titolo
    private const int FramesVisible = 3;       // frame di rendering prima di rimuovere le anteprime

    private readonly Queue<Func<Mesh>> _jobs = new();
    private readonly List<Node3D> _previews = new();
    private int _framesLeft = -1;
    private readonly Stopwatch _buildTime = new();
    private int _built;

    public bool IsDone { get; private set; }

    public override void _Ready()
    {
        foreach (var job in Catalog())
            _jobs.Enqueue(job);

        AddGlyphPreviews();
        AddParticlePreview();
    }

    public override void _Process(double delta)
    {
        if (IsDone)
            return;

        if (_jobs.Count > 0)
        {
            Build(_jobs.Dequeue()); // un solo mesh per frame: il menu non si blocca
            return;
        }

        if (_framesLeft < 0)
            _framesLeft = FramesVisible;

        if (--_framesLeft > 0)
            return;

        foreach (var preview in _previews)
            preview.QueueFree();
        _previews.Clear();
        IsDone = true;
        GD.Print($"[Warmup] {_built} mesh costruiti in {_buildTime.ElapsedMilliseconds} ms, forme in cache: {LowPolyBuilder.CachedShapeCount}");
        QueueFree();
    }

    /// <summary>Se si preme Play prima della fine, completa subito il lavoro rimasto.</summary>
    public void FinishNow()
    {
        while (_jobs.Count > 0)
            Build(_jobs.Dequeue());
    }

    private void Build(Func<Mesh> job)
    {
        _buildTime.Start();
        var mesh = job();
        _buildTime.Stop();
        _built++;
        var aabb = mesh.GetAabb();
        var extent = Mathf.Max(aabb.Size.X, Mathf.Max(aabb.Size.Y, aabb.Size.Z));
        var scale = extent > 0f ? PreviewSize / extent : 1f;

        // posizione a spirale per non sovrapporre tutto nello stesso punto
        var i = _previews.Count;
        var offset = new Vector3((i % 8 - 3.5f) * 0.06f, (i / 8 % 4 - 1.5f) * 0.06f, 0f);
        var center = aabb.Position + aabb.Size * 0.5f;

        var preview = new MeshInstance3D
        {
            Mesh = mesh,
            Scale = Vector3.One * scale,
            Position = new Vector3(0f, 0f, -PreviewDistance) + offset - center * scale,
            CastShadow = GeometryInstance3D.ShadowCastingSetting.On, // compila anche la passata ombre
        };
        AddChild(preview);
        _previews.Add(preview);
    }

    /// <summary>Tutti i mesh creati a runtime dal gioco.</summary>
    private static IEnumerable<Func<Mesh>> Catalog()
    {
        foreach (var mesh in RoadMeshes.Variants)
            yield return () => mesh;

        foreach (VehicleKind kind in Enum.GetValues(typeof(VehicleKind)))
        {
            for (var v = 0; v < VehicleMeshes.VariantCount(kind); v++)
            {
                var variant = v;
                yield return () => VehicleMeshes.Get(kind, variant);
            }
        }

        yield return () => VehicleMeshes.Splat;

        yield return () => StructureMeshes.GantryFrame;
        yield return () => StructureMeshes.Overpass;
        for (var bits = 1; bits <= 0b111; bits++)
        {
            var laneBits = bits;
            yield return () => StructureMeshes.Panels(laneBits);
        }

        foreach (var length in TunnelMeshes.Lengths)
            yield return () => TunnelMeshes.Get(length);

        foreach (var length in RoadWorksMeshes.Lengths)
        {
            yield return () => RoadWorksMeshes.Get(0, length);
            yield return () => RoadWorksMeshes.Get(2, length);
        }

        yield return () => RoadWorksMeshes.Machine(MachineKind.Excavator);
        yield return () => RoadWorksMeshes.Machine(MachineKind.Roller);
        yield return () => RoadWorksMeshes.Beacons;
        yield return () => RoadWorksMeshes.Net;

        yield return () => HighBeamVisuals.Flare;
        yield return () => HighBeamVisuals.Beam;
        yield return () => IndicatorVisuals.Lamp;
        yield return () => IndicatorVisuals.Flare;

        yield return () => Pickup.CrumbsMesh;
        yield return () => PoopSystem.DropMesh;
        yield return () => PoopSystem.RoadSplatMesh;
        yield return () => PoopSystem.ReticleMesh;
    }

    /// <summary>Etichette 3D con tutti i caratteri e le dimensioni usate, per popolare l'atlante dei font.</summary>
    private void AddGlyphPreviews()
    {
        const string glyphs = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyzüöä0123456789+-!.,'/ ";
        (int size, int outline)[] styles = { (64, 14), (64, 0), (72, 0), (96, 0) };
        for (var i = 0; i < styles.Length; i++)
        {
            var label = new Label3D
            {
                Text = glyphs,
                FontSize = styles[i].size,
                OutlineSize = styles[i].outline,
                PixelSize = 0.00005f,
                Billboard = i == 0 ? BaseMaterial3D.BillboardModeEnum.Enabled : BaseMaterial3D.BillboardModeEnum.Disabled,
                NoDepthTest = i == 0,
                Position = new Vector3(0f, -0.05f - i * 0.02f, -PreviewDistance),
            };
            AddChild(label);
            _previews.Add(label);
        }
    }

    /// <summary>Le particelle usano una variante di shader diversa (multimesh): va compilata anche quella.</summary>
    private void AddParticlePreview()
    {
        var particles = EffectsFactory.CreateFeatherBurst();
        particles.LocalCoords = true;
        particles.Scale = Vector3.One * 0.02f;
        particles.Position = new Vector3(0f, 0.05f, -PreviewDistance);
        AddChild(particles);
        particles.Emitting = true;
        _previews.Add(particles);
    }
}
