namespace AutomationService.Features.EmailVersand.Presentation.Dtos;

/// <summary>
/// Welche der in Outlook eingerichteten Signaturen übernommen werden soll
/// (REQUIREMENTS.md §4.7). Nur der Name — den Inhalt liest der Dienst selbst
/// aus dem Signaturordner, samt Bildern.
/// </summary>
public sealed record SignaturUebernahmeDto(string Name);
