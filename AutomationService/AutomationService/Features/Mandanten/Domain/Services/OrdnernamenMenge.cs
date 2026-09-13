namespace AutomationService.Features.Mandanten.Domain.Services;

/// <summary>
/// Eine Menge von Akten-Ordnernamen, die <b>getrimmt und ohne Rücksicht auf
/// Groß-/Kleinschreibung</b> vergleicht — dieselbe Regel wie
/// <c>OrdnernamenMenge</c> im Frontend. Der Name kommt aus dem
/// Windows-Dateisystem, und dort meinen „VUnfallursache Mark" und
/// „Vunfallursache Mark " denselben Ordner.
///
/// Getrimmt wird auf <b>beiden</b> Seiten: Kürzte nur die geprüfte Seite,
/// gälte ein gespeichertes „ Foo" im Backend als frei und im Frontend als
/// vergeben — die beiden Schichten wären sich uneins, wem ein Ordner gehört.
/// </summary>
public sealed class OrdnernamenMenge(IEnumerable<string> ordnernamen)
{
    readonly HashSet<string> _namen = new(
        ordnernamen.Select(Schluessel), StringComparer.OrdinalIgnoreCase);

    /// <summary>Ob <paramref name="ordnername"/> in der Menge steht — gleich, wie er geschrieben ist.</summary>
    public bool Enthaelt(string ordnername) => _namen.Contains(Schluessel(ordnername));

    /// <summary>
    /// Die Vergleichsform eines Ordnernamens. Wer Namen als Schlüssel eines
    /// Wörterbuchs mit <see cref="StringComparer.OrdinalIgnoreCase"/> ablegt,
    /// nimmt sie für Ablage <b>und</b> Nachschlagen.
    /// </summary>
    public static string Schluessel(string ordnername) => ordnername.Trim();
}
