using System.Collections.Generic;
using Godot;

namespace PigeonRush.Rendering;

/// <summary>
/// Compone più primitive (box, cilindri, sfere…) in un unico ArrayMesh con
/// normali per faccia (look low-poly) e vertex color.
/// Superficie 0 = illuminata, superficie 1 = unlit (luci, fari).
/// <para>
/// Prestazioni: chiedere i vertici a Godot (oggetto PrimitiveMesh + GetMeshArrays) è costoso.
/// Le forme standard vengono quindi generate una sola volta in forma "unitaria" e messe in cache:
/// box 1×1×1, sfera di raggio 1 (per segmenti/anelli), cilindro alto 1 con base di raggio 1
/// (per proporzione tra le basi e segmenti), prisma 1×1×1. Ogni chiamata successiva
/// riusa i vertici in cache e li scala/ruota/sposta in C#: niente oggetti Godot per pezzo.
/// </para>
/// </summary>
public sealed class LowPolyBuilder
{
    private sealed class Surface
    {
        public readonly List<Vector3> Vertices = new();
        public readonly List<Vector3> Normals = new();
        public readonly List<Color> Colors = new();
    }

    /// <summary>Vertici, normali e indici di una primitiva, già convertiti in array C#.</summary>
    private sealed class ShapeData
    {
        public ShapeData(Vector3[] vertices, Vector3[] normals, int[]? indices)
        {
            Vertices = vertices;
            Normals = normals;
            Indices = indices is { Length: > 0 } ? indices : null;
        }

        public Vector3[] Vertices { get; }
        public Vector3[] Normals { get; }
        public int[]? Indices { get; }
    }

    private enum ShapeType
    {
        Box,
        Sphere,
        Cylinder,
        Prism,
    }

    /// <param name="A">Sfera: segmenti. Cilindro: segmenti.</param>
    /// <param name="B">Sfera: anelli. Cilindro: rapporto tra le basi ×1000.</param>
    /// <param name="C">Cilindro: 1 se la base larga è in alto.</param>
    private readonly record struct ShapeKey(ShapeType Type, int A, int B, int C);

    private static readonly Dictionary<ShapeKey, ShapeData> ShapeCache = new();
    private static readonly object CacheLock = new();

    private readonly Surface _lit = new();
    private readonly Surface _unlit = new();

    /// <summary>Aggiunge una primitiva qualsiasi (non in cache: usare per forme rare, es. TorusMesh).</summary>
    public LowPolyBuilder Add(PrimitiveMesh mesh, Transform3D transform, Color color, bool unlit = false)
        => AddShape(ToShapeData(mesh), transform, color, unlit);

    public LowPolyBuilder Box(Vector3 size, Vector3 center, Color color, Vector3? rotationDeg = null, bool unlit = false)
        => AddShape(GetShape(new ShapeKey(ShapeType.Box, 0, 0, 0)), MakeTransform(center, rotationDeg, size), color, unlit);

    /// <summary>Box definito da estremi min/max (comodo per volumi architettonici).</summary>
    public LowPolyBuilder Block(float x0, float x1, float y0, float y1, float z0, float z1, Color color, bool unlit = false)
        => Box(new Vector3(x1 - x0, y1 - y0, z1 - z0), new Vector3((x0 + x1) * 0.5f, (y0 + y1) * 0.5f, (z0 + z1) * 0.5f), color, null, unlit);

    public LowPolyBuilder Cylinder(float topRadius, float bottomRadius, float height, Vector3 center, Color color,
        int segments = 8, Vector3? rotationDeg = null, bool unlit = false)
    {
        // forma unitaria: base larga di raggio 1, altezza 1; l'altra base in proporzione
        var wideOnTop = topRadius > bottomRadius;
        var wide = wideOnTop ? topRadius : bottomRadius;
        var narrow = wideOnTop ? bottomRadius : topRadius;
        var ratio = wide > 0f ? narrow / wide : 1f;
        var key = new ShapeKey(ShapeType.Cylinder, segments, Mathf.RoundToInt(ratio * 1000f), wideOnTop ? 1 : 0);

        var scale = new Vector3(Mathf.Max(wide, 1e-4f), height, Mathf.Max(wide, 1e-4f));
        return AddShape(GetShape(key), MakeTransform(center, rotationDeg, scale), color, unlit);
    }

    public LowPolyBuilder Cone(float radius, float height, Vector3 baseCenter, Color color, int segments = 6)
        => Cylinder(0f, radius, height, baseCenter + new Vector3(0f, height * 0.5f, 0f), color, segments);

    public LowPolyBuilder Sphere(float radius, Vector3 center, Vector3 scale, Color color,
        int segments = 8, int rings = 5, Vector3? rotationDeg = null, bool unlit = false)
        => AddShape(GetShape(new ShapeKey(ShapeType.Sphere, segments, rings, 0)),
            MakeTransform(center, rotationDeg, scale * radius), color, unlit);

    public LowPolyBuilder Prism(Vector3 size, Vector3 center, Color color, Vector3? rotationDeg = null)
        => AddShape(GetShape(new ShapeKey(ShapeType.Prism, 0, 0, 0)), MakeTransform(center, rotationDeg, size), color, false);

    /// <summary>Ruota con asse lungo X (per veicoli che guardano verso +Z).</summary>
    public LowPolyBuilder Wheel(float x, float z, float radius, float width = 0.28f)
        => Cylinder(radius, radius, width, new Vector3(x, radius, z), Palette.Tire, 8, new Vector3(0f, 0f, 90f));

    public ArrayMesh Build()
    {
        var mesh = new ArrayMesh();
        AddSurface(mesh, _lit, Palette.Lit);
        AddSurface(mesh, _unlit, Palette.Unlit);
        return mesh;
    }

    /// <summary>Numero di forme distinte in cache (utile per verificare che la cache lavori).</summary>
    public static int CachedShapeCount
    {
        get
        {
            lock (CacheLock)
                return ShapeCache.Count;
        }
    }

    private LowPolyBuilder AddShape(ShapeData shape, Transform3D transform, Color color, bool unlit)
    {
        var vertices = shape.Vertices;
        var normals = shape.Normals;
        var indices = shape.Indices;
        var count = indices?.Length ?? vertices.Length;
        var target = unlit ? _unlit : _lit;
        var basis = transform.Basis;

        for (var i = 0; i + 2 < count; i += 3)
        {
            int i0 = indices?[i] ?? i;
            int i1 = indices?[i + 1] ?? i + 1;
            int i2 = indices?[i + 2] ?? i + 2;

            var a = transform * vertices[i0];
            var b = transform * vertices[i1];
            var c = transform * vertices[i2];

            var faceNormal = (b - a).Cross(c - a);
            if (faceNormal.LengthSquared() < 1e-12f)
                continue; // triangolo degenere (es. punta dei coni)

            faceNormal = faceNormal.Normalized();
            if (normals.Length > i2)
            {
                // Il verso lo decide la normale originale della primitiva: robusto rispetto al winding.
                // Con scale positive (anche non uniformi) il segno del prodotto scalare è preservato.
                var reference = basis * (normals[i0] + normals[i1] + normals[i2]);
                if (faceNormal.Dot(reference) < 0f)
                    faceNormal = -faceNormal;
            }

            target.Vertices.Add(a);
            target.Vertices.Add(b);
            target.Vertices.Add(c);
            target.Normals.Add(faceNormal);
            target.Normals.Add(faceNormal);
            target.Normals.Add(faceNormal);
            target.Colors.Add(color);
            target.Colors.Add(color);
            target.Colors.Add(color);
        }

        return this;
    }

    private static ShapeData GetShape(ShapeKey key)
    {
        lock (CacheLock)
        {
            if (ShapeCache.TryGetValue(key, out var cached))
                return cached;
        }

        var data = ToShapeData(CreateUnitShape(key));
        lock (CacheLock)
        {
            ShapeCache[key] = data;
        }

        return data;
    }

    private static PrimitiveMesh CreateUnitShape(ShapeKey key) => key.Type switch
    {
        ShapeType.Box => new BoxMesh { Size = Vector3.One },
        ShapeType.Prism => new PrismMesh { Size = Vector3.One },
        ShapeType.Sphere => new SphereMesh { Radius = 1f, Height = 2f, RadialSegments = key.A, Rings = key.B },
        _ => new CylinderMesh
        {
            TopRadius = key.C == 1 ? 1f : key.B / 1000f,
            BottomRadius = key.C == 1 ? key.B / 1000f : 1f,
            Height = 1f,
            RadialSegments = key.A,
            Rings = 1,
        },
    };

    private static ShapeData ToShapeData(PrimitiveMesh mesh)
    {
        var arrays = mesh.GetMeshArrays();
        var indexVariant = arrays[(int)Mesh.ArrayType.Index];
        return new ShapeData(
            arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array(),
            arrays[(int)Mesh.ArrayType.Normal].AsVector3Array(),
            indexVariant.VariantType == Variant.Type.Nil ? null : indexVariant.AsInt32Array());
    }

    private static void AddSurface(ArrayMesh mesh, Surface surface, Material material)
    {
        if (surface.Vertices.Count == 0)
            return;

        var arrays = new Godot.Collections.Array();
        arrays.Resize((int)Mesh.ArrayType.Max);
        arrays[(int)Mesh.ArrayType.Vertex] = surface.Vertices.ToArray();
        arrays[(int)Mesh.ArrayType.Normal] = surface.Normals.ToArray();
        arrays[(int)Mesh.ArrayType.Color] = surface.Colors.ToArray();
        mesh.AddSurfaceFromArrays(Mesh.PrimitiveType.Triangles, arrays);
        mesh.SurfaceSetMaterial(mesh.GetSurfaceCount() - 1, material);
    }

    private static Transform3D MakeTransform(Vector3 center, Vector3? rotationDeg, Vector3 scale)
    {
        var rotation = rotationDeg ?? Vector3.Zero;
        var radians = new Vector3(
            Mathf.DegToRad(rotation.X),
            Mathf.DegToRad(rotation.Y),
            Mathf.DegToRad(rotation.Z));
        var basis = Basis.FromEuler(radians) * Basis.FromScale(scale);
        return new Transform3D(basis, center);
    }
}
