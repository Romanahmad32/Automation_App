namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>
/// Ergebnis eines Dokumentenauftrags. Die Warnungen melden die Platzhalter, die
/// in der Vorlage stehen geblieben sind — dieser Rückkanal ist verbindlich
/// (§4.4): der Anwalt soll sehen, was das Dokument noch nicht
/// enthält, statt es unbemerkt zu verschicken.
/// </summary>
public sealed record DocumentGenerationResult(string OutputFilePath, IReadOnlyList<string> Warnings);
