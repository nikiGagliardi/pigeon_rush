using System;
using System.Collections.Generic;
using Godot;
using PigeonRush.Core;

namespace PigeonRush.World;

/// <summary>Nastro di segmenti di strada riciclati: quando uno supera la camera torna in fondo con una variante casuale.</summary>
public partial class RoadScroller : Node3D
{
    private readonly List<MeshInstance3D> _segments = new();
    private readonly Random _rng = new();
    private ArrayMesh[] _variants = Array.Empty<ArrayMesh>();

    public override void _Ready()
    {
        _variants = RoadMeshes.Variants;
        const float length = GameConfig.SegmentLength;
        for (var i = 0; i < GameConfig.SegmentCount; i++)
        {
            var segment = new MeshInstance3D
            {
                Mesh = _variants[_rng.Next(_variants.Length)],
                Position = new Vector3(0f, 0f, GameConfig.DespawnZ - length * 0.5f - i * length),
            };
            AddChild(segment);
            _segments.Add(segment);
        }
    }

    public void Advance(float step)
    {
        const float length = GameConfig.SegmentLength;
        foreach (var segment in _segments)
        {
            var p = segment.Position;
            p.Z += step;
            if (p.Z - length * 0.5f > GameConfig.DespawnZ)
            {
                p.Z -= GameConfig.SegmentCount * length;
                segment.Mesh = _variants[_rng.Next(_variants.Length)];
            }

            segment.Position = p;
        }
    }
}
