using System.Collections.Generic;
using Godot;

namespace PigeonRush.Rendering;

/// <summary>
/// Compone più primitive (box, cilindri, sfere…) in un unico ArrayMesh con
/// normali per faccia (look low-poly) e vertex color.
/// Superficie 0 = illuminata, superficie 1 = unlit (luci, fari).
/// </summary>
public sealed class LowPolyBuilder
{
    private sealed class Surface
    {
        public readonly List<Vector3> Vertices = new();
        public readonly List<Vector3> Normals = new();
        public readonly List<Color> Colors = new();
    }

    private readonly Surface _lit = new();
    private readonly Surface _unlit = new();

    public LowPolyBuilder Add(PrimitiveMesh mesh, Transform3D transform, Color color, bool unlit = false)
    {
        var arrays = mesh.GetMeshArrays();
        var vertices = arrays[(int)Mesh.ArrayType.Vertex].AsVector3Array();
        var normals = arrays[(int)Mesh.ArrayType.Normal].AsVector3Array();
        var indexVariant = arrays[(int)Mesh.ArrayType.Index];
        var indices = indexVariant.VariantType == Variant.Type.Nil ? null : indexVariant.AsInt32Array();
        var count = indices is { Length: > 0 } ? indices.Length : vertices.Length;
        var target = unlit ? _unlit : _lit;
        var basis = transform.Basis;

        for (var i = 0; i + 2 < count; i += 3)
        {
            int i0 = indices is { Length: > 0 } ? indices[i] : i;
            int i1 = indices is { Length: > 0 } ? indices[i + 1] : i + 1;
            int i2 = indices is { Length: > 0 } ? indices[i + 2] : i + 2;

            var a = transform * vertices[i0];
            var b = transform * vertices[i1];
            var c = transform * vertices[i2];

            var faceNormal = (b - a).Cross(c - a);
            if (faceNormal.LengthSquared() < 1e-10f)
                continue; // triangolo degenere (es. punta dei coni)

            faceNormal = faceNormal.Normalized();
            if (normals.Length > i2)
            {
                // Il verso lo decide la normale originale della primitiva: robusto rispetto al winding.
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

    public LowPolyBuilder Box(Vector3 size, Vector3 center, Color color, Vector3? rotationDeg = null, bool unlit = false)
        => Add(new BoxMesh { Size = size }, MakeTransform(center, rotationDeg, Vector3.One), color, unlit);

    /// <summary>Box definito da estremi min/max (comodo per volumi architettonici).</summary>
    public LowPolyBuilder Block(float x0, float x1, float y0, float y1, float z0, float z1, Color color, bool unlit = false)
        => Box(new Vector3(x1 - x0, y1 - y0, z1 - z0), new Vector3((x0 + x1) * 0.5f, (y0 + y1) * 0.5f, (z0 + z1) * 0.5f), color, null, unlit);

    public LowPolyBuilder Cylinder(float topRadius, float bottomRadius, float height, Vector3 center, Color color,
        int segments = 8, Vector3? rotationDeg = null, bool unlit = false)
        => Add(new CylinderMesh
        {
            TopRadius = topRadius,
            BottomRadius = bottomRadius,
            Height = height,
            RadialSegments = segments,
            Rings = 1,
        }, MakeTransform(center, rotationDeg, Vector3.One), color, unlit);

    public LowPolyBuilder Cone(float radius, float height, Vector3 baseCenter, Color color, int segments = 6)
        => Cylinder(0f, radius, height, baseCenter + new Vector3(0f, height * 0.5f, 0f), color, segments);

    public LowPolyBuilder Sphere(float radius, Vector3 center, Vector3 scale, Color color,
        int segments = 8, int rings = 5, Vector3? rotationDeg = null, bool unlit = false)
        => Add(new SphereMesh
        {
            Radius = radius,
            Height = radius * 2f,
            RadialSegments = segments,
            Rings = rings,
        }, MakeTransform(center, rotationDeg, scale), color, unlit);

    public LowPolyBuilder Prism(Vector3 size, Vector3 center, Color color, Vector3? rotationDeg = null)
        => Add(new PrismMesh { Size = size }, MakeTransform(center, rotationDeg, Vector3.One), color);

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
