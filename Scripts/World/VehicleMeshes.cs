using System.Collections.Generic;
using Godot;
using PigeonRush.Rendering;

namespace PigeonRush.World;

/// <summary>
/// Mesh low-poly dei veicoli, costruiti una volta e messi in cache per (tipo, variante colore).
/// Origine = centro a livello strada; il muso guarda verso +Z (verso il piccione).
/// </summary>
public static class VehicleMeshes
{
    private static readonly Color[] CarColors =
    {
        new("c0392b"), new("2e86de"), new("7f8c8d"), new("27ae60"), new("34495e"), new("d35400"),
    };

    private static readonly Color[] VanColors = { new("f5c400"), new("ecf0f1"), new("95a5a6"), new("c0392b") };
    private static readonly Color[] TruckCabColors = { new("c0392b"), new("2e86de"), new("e67e22"), new("16a085") };
    private static readonly Color[] TruckStripeColors = { new("c0392b"), new("2e86de"), new("f39c12"), new("27ae60") };
    private static readonly Color[] CabrioColors = { new("e74c3c"), new("f1c40f"), new("8e44ad") };

    // giallo AutoPostale, pullman bianco/blu, rosso
    private static readonly Color[] BusColors = { new("f5c400"), new("f2f2ee"), new("c0392b") };
    private static readonly Color[] BusStripeColors = { new("c0392b"), new("2e86de"), new("f2f2ee") };

    private static readonly Dictionary<(VehicleKind, int), ArrayMesh> Cache = new();
    private static ArrayMesh? _splat;

    public static int VariantCount(VehicleKind kind) => kind switch
    {
        VehicleKind.Car => CarColors.Length,
        VehicleKind.Van => VanColors.Length,
        VehicleKind.Truck => TruckCabColors.Length,
        VehicleKind.Cabrio => CabrioColors.Length,
        VehicleKind.Bus => BusColors.Length,
        _ => 1,
    };

    public static ArrayMesh Get(VehicleKind kind, int variant)
    {
        variant %= VariantCount(kind);
        if (Cache.TryGetValue((kind, variant), out var mesh))
            return mesh;

        mesh = kind switch
        {
            VehicleKind.Van => BuildVan(VanColors[variant]),
            VehicleKind.Truck => BuildTruck(TruckCabColors[variant], TruckStripeColors[variant]),
            VehicleKind.Bus => BuildBus(BusColors[variant], BusStripeColors[variant]),
            VehicleKind.Cabrio => BuildCabrio(CabrioColors[variant]),
            VehicleKind.CleanCar => BuildCar(new Color("ffffff"), clean: true),
            _ => BuildCar(CarColors[variant], clean: false),
        };
        Cache[(kind, variant)] = mesh;
        return mesh;
    }

    /// <summary>Macchia di cacca che appare sul tetto colpito.</summary>
    public static ArrayMesh Splat => _splat ??= new LowPolyBuilder()
        .Sphere(0.45f, Vector3.Zero, new Vector3(1f, 0.12f, 1.2f), Palette.Poop, 7, 3)
        .Sphere(0.22f, new Vector3(0.35f, 0f, -0.3f), new Vector3(1f, 0.15f, 1f), Palette.PoopShade, 6, 3)
        .Sphere(0.18f, new Vector3(-0.3f, 0f, 0.38f), new Vector3(1f, 0.15f, 1f), Palette.Poop, 6, 3)
        .Build();

    private static ArrayMesh BuildCar(Color body, bool clean)
    {
        var spec = VehicleCatalog.Car;
        float l = spec.Length, w = spec.Width;
        var b = new LowPolyBuilder();

        b.Box(new Vector3(w, 0.62f, l), new Vector3(0f, 0.62f, 0f), body);                       // scocca
        b.Box(new Vector3(w * 0.86f, 0.5f, l * 0.48f), new Vector3(0f, 1.18f, -0.25f), Palette.Glass); // abitacolo
        b.Box(new Vector3(w * 0.84f, 0.06f, l * 0.42f), new Vector3(0f, 1.45f, -0.25f), body);    // tetto
        b.Box(new Vector3(w * 1.02f, 0.18f, 0.22f), new Vector3(0f, 0.4f, l * 0.5f), Palette.Trim); // paraurti ant.
        b.Box(new Vector3(w * 1.02f, 0.18f, 0.22f), new Vector3(0f, 0.4f, -l * 0.5f), Palette.Trim);
        b.Box(new Vector3(0.7f, 0.16f, 0.05f), new Vector3(0f, 0.68f, l * 0.5f + 0.01f), Palette.Trim); // griglia
        b.Box(new Vector3(0.36f, 0.14f, 0.06f), new Vector3(-0.62f, 0.72f, l * 0.5f + 0.02f), Palette.Headlight, unlit: true);
        b.Box(new Vector3(0.36f, 0.14f, 0.06f), new Vector3(0.62f, 0.72f, l * 0.5f + 0.02f), Palette.Headlight, unlit: true);
        AddTaillights(b, 0.65f, 0.75f, -l * 0.5f);
        AddWheels(b, w, l * 0.32f, 0.34f);

        if (clean)
        {
            // scintillii "appena lavata"
            b.Box(new Vector3(0.14f, 0.14f, 0.14f), new Vector3(-0.5f, 1.75f, 0.2f), new Color("bff4ff"), new Vector3(45f, 45f, 0f), unlit: true);
            b.Box(new Vector3(0.1f, 0.1f, 0.1f), new Vector3(0.45f, 1.9f, -0.6f), new Color("ffffff"), new Vector3(45f, 0f, 45f), unlit: true);
            b.Box(new Vector3(0.12f, 0.12f, 0.12f), new Vector3(0.2f, 1.68f, 1.2f), new Color("bff4ff"), new Vector3(0f, 45f, 45f), unlit: true);
        }

        return b.Build();
    }

    private static ArrayMesh BuildVan(Color body)
    {
        var spec = VehicleCatalog.Van;
        float l = spec.Length, w = spec.Width;
        var b = new LowPolyBuilder();

        var rearLength = l - 0.9f;
        b.Box(new Vector3(w, 1.95f, rearLength), new Vector3(0f, 1.3f, -0.45f), body);           // vano
        b.Box(new Vector3(w, 1.0f, 0.9f), new Vector3(0f, 0.85f, l * 0.5f - 0.45f), body);      // cofano
        b.Box(new Vector3(w * 0.9f, 0.75f, 0.06f), new Vector3(0f, 1.82f, rearLength * 0.5f - 0.43f), Palette.Glass); // parabrezza
        b.Box(new Vector3(w * 1.01f, 0.55f, 1.0f), new Vector3(0f, 1.82f, rearLength * 0.5f - 0.95f), Palette.Glass);  // finestrini
        b.Box(new Vector3(w * 1.02f, 0.2f, 0.22f), new Vector3(0f, 0.42f, l * 0.5f), Palette.Trim);
        b.Box(new Vector3(0.34f, 0.16f, 0.06f), new Vector3(-0.66f, 0.92f, l * 0.5f + 0.02f), Palette.Headlight, unlit: true);
        b.Box(new Vector3(0.34f, 0.16f, 0.06f), new Vector3(0.66f, 0.92f, l * 0.5f + 0.02f), Palette.Headlight, unlit: true);
        AddTaillights(b, 0.8f, 1.1f, -0.45f - rearLength * 0.5f);
        AddWheels(b, w, l * 0.34f, 0.36f);
        return b.Build();
    }

    private static ArrayMesh BuildTruck(Color cab, Color stripe)
    {
        var spec = VehicleCatalog.Truck;
        float l = spec.Length, w = spec.Width;
        var b = new LowPolyBuilder();

        const float cabLength = 2.4f;
        var cabZ = l * 0.5f - cabLength * 0.5f;
        b.Box(new Vector3(w, 2.6f, cabLength), new Vector3(0f, 2.0f, cabZ), cab);                                   // cabina
        b.Box(new Vector3(w * 0.9f, 1.0f, 0.06f), new Vector3(0f, 2.65f, l * 0.5f + 0.01f), Palette.Glass);       // parabrezza
        b.Box(new Vector3(w * 0.88f, 0.55f, 1.4f), new Vector3(0f, 3.58f, cabZ - 0.3f), cab);                      // spoiler
        b.Box(new Vector3(w * 1.02f, 0.35f, 0.25f), new Vector3(0f, 0.75f, l * 0.5f), Palette.Trim);              // paraurti
        b.Box(new Vector3(1.2f, 0.6f, 0.05f), new Vector3(0f, 1.45f, l * 0.5f + 0.02f), Palette.Chrome);           // griglia
        b.Box(new Vector3(0.4f, 0.2f, 0.06f), new Vector3(-0.85f, 1.0f, l * 0.5f + 0.03f), Palette.Headlight, unlit: true);
        b.Box(new Vector3(0.4f, 0.2f, 0.06f), new Vector3(0.85f, 1.0f, l * 0.5f + 0.03f), Palette.Headlight, unlit: true);

        var trailerLength = l - cabLength - 0.3f;
        var trailerZ = -l * 0.5f + trailerLength * 0.5f;
        b.Box(new Vector3(w, 3.0f, trailerLength), new Vector3(0f, 2.5f, trailerZ), new Color("f2f2ee"));        // rimorchio
        b.Box(new Vector3(w + 0.02f, 0.4f, trailerLength), new Vector3(0f, 2.0f, trailerZ), stripe);              // fascia
        b.Box(new Vector3(w * 0.8f, 0.4f, l - 0.4f), new Vector3(0f, 0.75f, 0f), Palette.Trim);                   // telaio
        b.Box(new Vector3(0.06f, 2.8f, 0.04f), new Vector3(0f, 2.5f, -l * 0.5f - 0.02f), Palette.ConcreteDark);   // porte posteriori
        AddTaillights(b, 1.0f, 1.1f, -l * 0.5f);

        const float r = 0.5f;
        float wx = w * 0.5f - 0.15f;
        foreach (var z in new[] { l * 0.5f - 0.9f, l * 0.5f - 3.3f, -l * 0.5f + 2.6f, -l * 0.5f + 1.4f })
        {
            b.Wheel(-wx, z, r, 0.4f);
            b.Wheel(wx, z, r, 0.4f);
        }

        return b.Build();
    }

    private static ArrayMesh BuildCabrio(Color body)
    {
        var spec = VehicleCatalog.Cabrio;
        float l = spec.Length, w = spec.Width;
        var b = new LowPolyBuilder();

        b.Box(new Vector3(w, 0.6f, l), new Vector3(0f, 0.6f, 0f), body);
        b.Box(new Vector3(w * 0.8f, 0.04f, l * 0.45f), new Vector3(0f, 0.91f, -0.2f), Palette.Trim);   // interno
        b.Box(new Vector3(0.6f, 0.45f, 0.5f), new Vector3(-0.42f, 1.12f, -0.35f), Palette.Seat);         // sedili
        b.Box(new Vector3(0.6f, 0.45f, 0.5f), new Vector3(0.42f, 1.12f, -0.35f), Palette.Seat);
        b.Box(new Vector3(0.6f, 0.35f, 0.12f), new Vector3(-0.42f, 1.5f, -0.62f), Palette.Seat);         // schienali
        b.Box(new Vector3(0.6f, 0.35f, 0.12f), new Vector3(0.42f, 1.5f, -0.62f), Palette.Seat);
        b.Box(new Vector3(w * 0.9f, 0.4f, 0.05f), new Vector3(0f, 1.1f, 0.55f), Palette.Glass, new Vector3(-30f, 0f, 0f));
        b.Box(new Vector3(w * 1.02f, 0.18f, 0.22f), new Vector3(0f, 0.4f, l * 0.5f), Palette.Trim);
        b.Box(new Vector3(0.36f, 0.12f, 0.06f), new Vector3(-0.62f, 0.72f, l * 0.5f + 0.02f), Palette.Headlight, unlit: true);
        b.Box(new Vector3(0.36f, 0.12f, 0.06f), new Vector3(0.62f, 0.72f, l * 0.5f + 0.02f), Palette.Headlight, unlit: true);
        AddTaillights(b, 0.65f, 0.7f, -l * 0.5f);
        AddWheels(b, w, l * 0.32f, 0.34f);
        return b.Build();
    }

    private static ArrayMesh BuildBus(Color body, Color stripe)
    {
        var spec = VehicleCatalog.Bus;
        float l = spec.Length, w = spec.Width;
        var b = new LowPolyBuilder();

        b.Box(new Vector3(w, 2.9f, l), new Vector3(0f, 1.95f, 0f), body);                                            // carrozzeria
        b.Box(new Vector3(w + 0.02f, 0.95f, l - 2.6f), new Vector3(0f, 2.6f, -0.5f), Palette.Glass);                   // finestrini laterali
        b.Box(new Vector3(w + 0.02f, 0.28f, l), new Vector3(0f, 1.45f, 0f), stripe);                                  // fascia
        b.Box(new Vector3(w * 0.92f, 1.35f, 0.06f), new Vector3(0f, 2.35f, l * 0.5f + 0.01f), Palette.Glass);         // parabrezza
        b.Box(new Vector3(1.5f, 0.22f, 0.05f), new Vector3(0f, 3.17f, l * 0.5f + 0.02f), Palette.DestinationDisplay, unlit: true); // display destinazione
        b.Box(new Vector3(1.5f, 0.22f, 2.6f), new Vector3(0f, 3.46f, -1.5f), Palette.Chrome);                          // clima sul tetto
        b.Box(new Vector3(w * 1.02f, 0.3f, 0.22f), new Vector3(0f, 0.6f, l * 0.5f), Palette.Trim);                     // paraurti
        b.Box(new Vector3(0.42f, 0.16f, 0.06f), new Vector3(-spec.HeadlightX, spec.HeadlightY, l * 0.5f + 0.03f), Palette.Headlight, unlit: true);
        b.Box(new Vector3(0.42f, 0.16f, 0.06f), new Vector3(spec.HeadlightX, spec.HeadlightY, l * 0.5f + 0.03f), Palette.Headlight, unlit: true);
        b.Box(new Vector3(w * 0.85f, 0.9f, 0.05f), new Vector3(0f, 2.7f, -l * 0.5f - 0.01f), Palette.Glass);           // lunotto
        AddTaillights(b, 1.05f, 0.9f, -l * 0.5f);

        const float r = 0.5f;
        float wx = w * 0.5f - 0.12f;
        foreach (var z in new[] { l * 0.5f - 2.2f, -l * 0.5f + 3.6f, -l * 0.5f + 2.4f })
        {
            b.Wheel(-wx, z, r, 0.36f);
            b.Wheel(wx, z, r, 0.36f);
        }

        return b.Build();
    }

    /// <summary>Fanalini rossi sul retro (visibili sulla carreggiata opposta).</summary>
    private static void AddTaillights(LowPolyBuilder b, float x, float y, float rearZ)
    {
        b.Box(new Vector3(0.32f, 0.14f, 0.06f), new Vector3(-x, y, rearZ - 0.02f), Palette.Taillight, unlit: true);
        b.Box(new Vector3(0.32f, 0.14f, 0.06f), new Vector3(x, y, rearZ - 0.02f), Palette.Taillight, unlit: true);
    }

    private static void AddWheels(LowPolyBuilder b, float width, float axleZ, float radius)
    {
        float x = width * 0.5f;
        b.Wheel(-x, axleZ, radius);
        b.Wheel(x, axleZ, radius);
        b.Wheel(-x, -axleZ, radius);
        b.Wheel(x, -axleZ, radius);
    }
}
