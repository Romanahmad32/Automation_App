namespace AutomationService.Features.Mandanten.Presentation.Dtos;

/// <summary>
/// Eingabe zum Anlegen eines Mandanten. Id und ErstelltAm vergibt das Register
/// beim Speichern (spiegelt die Flutter-Entität <c>CreateMandantRequest</c>).
/// </summary>
public sealed record CreateMandantDto(
    string Anrede,
    string Vorname,
    string Nachname,
    string StrasseHausnummer,
    string Postleitzahl,
    string Ort,
    string EmailAdresse,
    string Telefonnummer,
    string Notiz,
    IReadOnlyList<string> AktenOrdnernamen,
    IReadOnlyList<string> Kennzeichen);
