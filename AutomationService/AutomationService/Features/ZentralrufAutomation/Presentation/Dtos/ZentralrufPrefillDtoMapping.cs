using AutomationService.Features.ZentralrufAutomation.Domain.Services;

namespace AutomationService.Features.ZentralrufAutomation.Presentation.Dtos;

/// <summary>
/// Bildet das HTTP-DTO auf den Domänen-Auftrag ab. Diese Richtung ist die
/// einzige erlaubte: die Presentation kennt die Domain, nicht umgekehrt.
/// </summary>
public static class ZentralrufPrefillDtoMapping
{
    public static ZentralrufPrefillRequest ToDomain(this ZentralrufPrefillDto dto)
    {
        ArgumentNullException.ThrowIfNull(dto);

        return new ZentralrufPrefillRequest
        {
            Auftragsnummer = dto.Auftragsnummer,
            Auftragsjahr = dto.Auftragsjahr,
            Abteilung = dto.Abteilung,
            KennzeichenSchaediger = dto.KennzeichenSchaediger,
            Schadentag = dto.Schadentag,
            Referenz = dto.Referenz,
            Geschaedigter = dto.Geschaedigter?.ToDomain(),
            Anfrager = dto.Anfrager?.ToDomain(),
        };
    }

    public static ZentralrufGeschaedigter ToDomain(this ZentralrufGeschaedigterDto dto)
    {
        ArgumentNullException.ThrowIfNull(dto);

        return new ZentralrufGeschaedigter
        {
            Name = dto.Name,
            StrasseHausnummer = dto.StrasseHausnummer,
            Postleitzahl = dto.Postleitzahl,
            Ort = dto.Ort,
            Kennzeichen = dto.Kennzeichen,
        };
    }

    /// <summary>
    /// Die Anfragerdaten haben in der Domain bereits einen Typ: derselbe
    /// <c>ZentralrufAnfragerOptions</c> dient als feldweiser Rückfall
    /// (<c>ZentralrufAutomationService.ResolveAnfrager</c>). Deshalb kein dritter Typ.
    /// </summary>
    public static ZentralrufAnfragerOptions ToDomain(this ZentralrufAnfragerDto dto)
    {
        ArgumentNullException.ThrowIfNull(dto);

        return new ZentralrufAnfragerOptions
        {
            Personentyp = dto.Personentyp,
            Name = dto.Name,
            StrasseHausnummer = dto.StrasseHausnummer,
            Postleitzahl = dto.Postleitzahl,
            Ort = dto.Ort,
            EmailAdresse = dto.EmailAdresse,
            Telefonnummer = dto.Telefonnummer,
        };
    }
}
