namespace AutomationService.Features.Aktualisierung.Domain.Services;

/// <summary>
/// Woher Auskunft und Setup-Datei kommen: im Betrieb die GitHub-API
/// (<see cref="GithubAktualisierungsQuelle"/>), im E2E-Testmodus eine Attrappe,
/// die nichts nach außen schickt. Die Naht liegt hier und nicht erst am
/// HTTP-Handler, damit auch die Attrappe durch <see cref="SetupAuswahl"/> und
/// die Prüfung von Größe und SHA256 läuft — genau das soll ein Testlauf sehen.
/// </summary>
public interface IAktualisierungsQuelle
{
    /// <summary>Das neueste veröffentlichte Release. Wirft bei Netz-, HTTP- oder JSON-Fehlern.</summary>
    Task<ReleaseBeschreibung> HoleNeuesteAsync(CancellationToken cancellationToken);

    /// <summary>
    /// Öffnet den Download der Setup-Datei als Strom; der Aufrufer schließt ihn.
    /// Wirft bei einer Fehlerantwort, statt deren Inhalt als Setup auszugeben.
    /// </summary>
    Task<Stream> OeffneAsync(Uri adresse, CancellationToken cancellationToken);
}
