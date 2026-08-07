namespace AutomationService.Features.WordAutomation.Presentation.Dtos;

/// <summary>
/// Antwort von <c>GET api/WordAutomation/vorlagen</c>.
/// </summary>
/// <param name="Verzeichnis">
/// Der Vorlagenordner. Das Frontend oeffnet den Datei-Dialog darin — sonst
/// beginnt „Durchsuchen" irgendwo im Dateisystem, und der Anwalt muesste den
/// Pfad nach %APPDATA% kennen.
/// </param>
/// <param name="Vorlagen">Die dort liegenden .docx-Dateien, neueste zuerst.</param>
public sealed record VorlagenUebersichtDto(
    string Verzeichnis,
    IReadOnlyList<VorlageDto> Vorlagen);
