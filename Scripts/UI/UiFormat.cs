using System.Globalization;

namespace PigeonRush.UI;

/// <summary>Formattazione numeri in inglese, indipendente dalla lingua del sistema (1,234 e non 1.234 / 1'234).</summary>
public static class UiFormat
{
    private static readonly CultureInfo English = CultureInfo.InvariantCulture;

    public static string Number(long value) => value.ToString("N0", English);

    public static string Multiplier(float value) => value.ToString("0.00", English);
}
