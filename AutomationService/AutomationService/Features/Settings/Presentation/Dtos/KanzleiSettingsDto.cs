using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Services;

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
    string MailSignatur,
    string MailSignaturHtml,
    string RegisterAblageOrdner,
    string RegisterDateiname,
    bool RegisterNachAbschlussSchreiben,
    string RegisterExportFilter)
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
        e.MailSignatur,
        e.MailSignaturHtml,
        e.RegisterAblageOrdner,
        e.RegisterDateiname,
        e.RegisterNachAbschlussSchreiben,
        e.RegisterExportFilter);

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
        MailSignaturHtml = MailSignaturHtml,
        RegisterAblageOrdner = RegisterAblageOrdner,
        RegisterDateiname = RegisterDateiname,
        RegisterNachAbschlussSchreiben = RegisterNachAbschlussSchreiben,
        RegisterExportFilter = GespeicherterFilter(RegisterExportFilter),
    };

    /// <summary>
    /// Legt den Filter auf einen der beiden bekannten Werte fest, bevor er in
    /// die Datenbank geht.
    ///
    /// Der Spiegel selbst liest ihn tolerant (siehe
    /// <see cref="RegisterSpiegelVorgabe.NurAbgeschlossene"/>) und käme auch mit
    /// „" oder „vielleicht" zurecht. Die Oberfläche nicht: Das Auswahlfeld in
    /// den Einstellungen kennt genau zwei Einträge, und ein gespeicherter Wert,
    /// der zu keinem passt, bringt <c>ReactiveDropdownField</c> beim nächsten
    /// Öffnen zum Abbruch. Was auf die Platte geht, muss also anzeigbar sein —
    /// tolerant lesen heisst nicht, alles aufzuheben.
    /// </summary>
    static string GespeicherterFilter(string? filter) =>
        RegisterSpiegelVorgabe.NurAbgeschlossene(filter)
            ? RegisterSpiegelVorgabe.FilterAbgeschlossen
            : RegisterSpiegelVorgabe.FilterAlle;
}
