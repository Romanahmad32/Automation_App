using AutomationService.Features.Settings.Domain.Persistence;

namespace AutomationService.Features.Settings.Presentation.Dtos;

/// <summary>
/// Übertragungsformat der Kanzlei-Einstellungen. Die PascalCase-Properties werden
/// von ASP.NET Core als camelCase serialisiert und passen damit 1:1 zum JSON der
/// Flutter-Entität <c>KanzleiSettings</c> (personentyp, strasseHausnummer, …).
/// </summary>
public sealed record KanzleiSettingsDto(
    string Personentyp,
    string Name,
    string StrasseHausnummer,
    string Postleitzahl,
    string Ort,
    string EmailAdresse,
    string Telefonnummer,
    int LaufendeAuftragsnummer,
    string Abteilung,
    string TabellenkopfFarbeHex,
    string AktenStammordner,
    string MailSignatur)
{
    public static KanzleiSettingsDto From(KanzleiSettingsEntity e) => new(
        e.Personentyp,
        e.Name,
        e.StrasseHausnummer,
        e.Postleitzahl,
        e.Ort,
        e.EmailAdresse,
        e.Telefonnummer,
        e.LaufendeAuftragsnummer,
        e.Abteilung,
        e.TabellenkopfFarbeHex,
        e.AktenStammordner,
        e.MailSignatur);

    public KanzleiSettingsEntity ToEntity() => new()
    {
        Id = KanzleiSettingsEntity.SingletonId,
        Personentyp = Personentyp,
        Name = Name,
        StrasseHausnummer = StrasseHausnummer,
        Postleitzahl = Postleitzahl,
        Ort = Ort,
        EmailAdresse = EmailAdresse,
        Telefonnummer = Telefonnummer,
        LaufendeAuftragsnummer = LaufendeAuftragsnummer,
        Abteilung = Abteilung,
        TabellenkopfFarbeHex = TabellenkopfFarbeHex,
        AktenStammordner = AktenStammordner,
        MailSignatur = MailSignatur,
    };
}
