using System.Globalization;

namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Eine dreistellige Versionsnummer, verglichen Zahl für Zahl. Seit #196 die
/// einzige Stelle, die entscheidet, ob ein Release neuer ist: Das Frontend
/// zeigt nur den <c>zustand</c> des Dienstes. Zwei Regeln für dieselbe Frage
/// ergäben eine App, deren Seitenleiste „aktuell" sagt, während der Dienst ein
/// Update anbietet.
///
/// Ausdrücklich kein Zeichenkettenvergleich: Sonst gälte <c>1.10.0</c> als
/// älter als <c>1.9.0</c>, und die zehnte Auslieferung würde nie gemeldet.
/// </summary>
public sealed record Versionsnummer(int Haupt, int Neben, int Fehlerbehebung)
{
    /// <summary>
    /// <c>v1.2.3+abc1234</c> → 1.2.3; alles andere → <c>null</c>. Das <c>v</c>
    /// tragen die Git-Tags, der Anhang hinter <c>+</c> ist der Commit aus der
    /// InformationalVersion (so meldet sie <c>/health</c>).
    ///
    /// Unlesbares ist <c>null</c> und damit nie ein Update: Ein Hinweis, der auf
    /// einer Fehldeutung beruht, schickte den Anwalt zu einem Download, den er
    /// längst hat.
    /// </summary>
    public static Versionsnummer? Lies(string? text)
    {
        if (string.IsNullOrWhiteSpace(text))
        {
            return null;
        }

        var kern = text.Trim();
        if (kern.StartsWith('v'))
        {
            kern = kern[1..];
        }

        var plus = kern.IndexOf('+', StringComparison.Ordinal);
        if (plus >= 0)
        {
            kern = kern[..plus];
        }

        var teile = kern.Split('.');
        if (teile.Length != 3)
        {
            return null;
        }

        var zahlen = new int[3];
        for (var stelle = 0; stelle < 3; stelle++)
        {
            // NumberStyles.None: nur Ziffern — kein Vorzeichen, kein Leerraum.
            if (!int.TryParse(teile[stelle], NumberStyles.None, CultureInfo.InvariantCulture, out zahlen[stelle]))
            {
                return null;
            }
        }

        return new Versionsnummer(zahlen[0], zahlen[1], zahlen[2]);
    }

    /// <summary>Ob <paramref name="kandidat"/> höher ist als <paramref name="bekannt"/>; Unlesbares nie.</summary>
    public static bool IstNeuer(string? kandidat, string? bekannt) =>
        Lies(kandidat) is { } neu && Lies(bekannt) is { } alt && neu.IstHoeherAls(alt);

    public bool IstHoeherAls(Versionsnummer andere)
    {
        ArgumentNullException.ThrowIfNull(andere);

        if (Haupt != andere.Haupt)
        {
            return Haupt > andere.Haupt;
        }

        return Neben != andere.Neben
            ? Neben > andere.Neben
            : Fehlerbehebung > andere.Fehlerbehebung;
    }

    public override string ToString() =>
        string.Create(CultureInfo.InvariantCulture, $"{Haupt}.{Neben}.{Fehlerbehebung}");
}
