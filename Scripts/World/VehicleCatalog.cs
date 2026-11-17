namespace PigeonRush.World;

public enum VehicleKind
{
    Car,
    Van,
    Truck,
    Bus,
    Cabrio,
    CleanCar,
}

/// <param name="Length">Lunghezza lungo Z.</param>
/// <param name="Width">Larghezza lungo X.</param>
/// <param name="Height">Altezza dell'hitbox.</param>
/// <param name="TargetBottom">Base della zona bersaglio per la cacca.</param>
/// <param name="TargetTop">Cima della zona bersaglio (tetto o abitacolo).</param>
/// <param name="Points">Punti base del colpo (moltiplicati dalla combo).</param>
/// <param name="Boost">Stack di boost assegnati.</param>
/// <param name="HitLabel">Testo extra mostrato al colpo (vuoto = nessuno).</param>
/// <param name="BlocksMid">Se occupa anche la fascia media (furgoni, camion, bus).</param>
/// <param name="HeadlightX">Distanza laterale dei fari dal centro.</param>
/// <param name="HeadlightY">Altezza dei fari.</param>
public readonly record struct VehicleSpec(
    float Length,
    float Width,
    float Height,
    float TargetBottom,
    float TargetTop,
    int Points,
    int Boost,
    string HitLabel,
    bool BlocksMid,
    float HeadlightX,
    float HeadlightY);

public static class VehicleCatalog
{
    public static readonly VehicleSpec Car = new(4.3f, 1.85f, 1.48f, 0.95f, 1.48f, 100, 1, "", false, 0.62f, 0.72f);
    public static readonly VehicleSpec Van = new(5.2f, 2.0f, 2.3f, 1.7f, 2.3f, 120, 1, "", true, 0.66f, 0.92f);
    public static readonly VehicleSpec Truck = new(13f, 2.5f, 4.0f, 3.2f, 4.0f, 150, 1, "Truck splatted!", true, 0.85f, 1.0f);
    public static readonly VehicleSpec Bus = new(12f, 2.55f, 3.55f, 2.9f, 3.55f, 140, 1, "Bus splatted!", true, 0.9f, 0.78f);
    public static readonly VehicleSpec Cabrio = new(4.4f, 1.85f, 1.2f, 0.6f, 1.35f, 300, 2, "Right in the convertible!", false, 0.62f, 0.72f);
    public static readonly VehicleSpec CleanCar = new(4.3f, 1.85f, 1.48f, 0.95f, 1.48f, 250, 2, "Freshly washed!", false, 0.62f, 0.72f);

    public static VehicleSpec Get(VehicleKind kind) => kind switch
    {
        VehicleKind.Van => Van,
        VehicleKind.Truck => Truck,
        VehicleKind.Bus => Bus,
        VehicleKind.Cabrio => Cabrio,
        VehicleKind.CleanCar => CleanCar,
        _ => Car,
    };
}
