namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Die zu versendende Nachricht, wie die Fachlogik sie sieht (REQUIREMENTS.md
/// §4.7). Eigener Eingabetyp der Domain statt des Presentation-Dtos, damit der
/// HTTP-Vertrag nicht die Signatur der Fachlogik diktiert.
/// </summary>
/// <param name="An">Empfänger; mindestens einer.</param>
/// <param name="Kopie">Empfänger in Kopie (CC); darf leer sein.</param>
/// <param name="Betreff">Betreffzeile.</param>
/// <param name="Text">Nachrichtentext als reiner Text (kein HTML).</param>
/// <param name="AnhangPfade">
/// Vollständige Pfade der Anhänge auf demselben Rechner. Dienst und Oberfläche
/// laufen auf einer Maschine — der Weg über Pfade erspart es, jede Datei durch
/// die HTTP-Schnittstelle zu schieben (dasselbe Muster wie bei der Ablage).
/// </param>
/// <param name="AnhangNamen">
/// Abweichender Dateiname je Anhangpfad, sofern der Anwalt umbenannt hat.
/// Die Datei in der Akte behaelt ihren Namen — geaendert wird nur, was beim
/// Empfaenger ankommt. "Dokument1.pdf" sagt dort niemandem etwas.
/// </param>
/// <param name="OhneSignaturBilder">
/// Dateinamen der Signaturbilder, die bei <b>dieser</b> Mail wegbleiben — das
/// schwere Werbebild etwa. Leer heißt: alle gehen mit. Die Signatur selbst
/// bleibt davon unberührt; entschieden wird je Nachricht (§4.7).
/// </param>
/// <param name="AbsenderName">
/// Anzeigename vor der Absenderadresse ("Kanzlei … &lt;kanzlei@…&gt;"). Kommt aus
/// den Kanzleidaten des Frontends; die Adresse selbst steht im Postfach-Zugang.
/// </param>
public sealed record EmailNachricht(
    IReadOnlyList<string> An,
    IReadOnlyList<string> Kopie,
    string Betreff,
    string Text,
    IReadOnlyList<string> AnhangPfade,
    string AbsenderName,
    IReadOnlyDictionary<string, string>? AnhangNamen = null,
    IReadOnlyList<string>? OhneSignaturBilder = null);
