namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Was beim Versand herauskam. Der Zeitpunkt geht an den Vorgang zurück, damit
/// die Oberfläche den Abschluss begründen kann ("am … an 2 Empfänger gesendet")
/// — der Abschluss selbst bleibt der eigene Schritt des Anwalts (§4.8).
/// </summary>
/// <param name="GesendetAm">Zeitpunkt der Übergabe an den SMTP-Server.</param>
/// <param name="Empfaenger">Alle angeschriebenen Adressen (An und Kopie).</param>
/// <param name="ImGesendetOrdner">
/// True, wenn die Nachricht nachweislich im Ordner "Gesendet" des Postfachs
/// liegt — entweder vom Anbieter selbst abgelegt oder von hier nachgetragen.
/// §4.7 nennt diesen Ordner als einzigen Versandnachweis.
/// </param>
/// <param name="Hinweis">
/// Klartext zu einem Nebenbefund, der den Versand nicht verhindert hat (z. B.
/// die Kopie in "Gesendet" ließ sich nicht ablegen). Null im Regelfall.
/// </param>
public sealed record EmailVersandErgebnis(
    DateTimeOffset GesendetAm,
    IReadOnlyList<string> Empfaenger,
    bool ImGesendetOrdner,
    string? Hinweis);
