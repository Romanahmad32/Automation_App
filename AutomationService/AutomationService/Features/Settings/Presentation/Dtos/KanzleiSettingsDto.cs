using AutomationService.Features.Settings.Domain.Persistence;
using AutomationService.Features.Settings.Domain.Services;

namespace AutomationService.Features.Settings.Presentation.Dtos;

/// <summary>
/// Übertragungsformat der Kanzlei-Einstellungen. Die PascalCase-Properties werden
/// von ASP.NET Core als camelCase serialisiert und passen damit 1:1 zum JSON der
/// Flutter-Entität <c>KanzleiSettings</c> (personentyp, strasseHausnummer, …).
///
/// Hier liegt seit #103 die Umrechnungsgrenze der fünf Ordnerpfade — dieselbe
/// Arbeitsteilung wie bei den Word-Pfaden (#33, <c>FormTemplatesController</c>):
/// hinaus gehen sie <em>aufgelöst</em>, hinein kommende werden relativ zum
/// synchronisierten Wurzelordner gespeichert, wenn sie darunter liegen. Das
/// Frontend rechnet nie um; es zeigt an, was es bekommt, und schickt es zurück.
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
    string AppDatenOrdner,
    string AktenStammordner,
    string MailSignatur,
    string MailSignaturHtml,
    string RegisterAblageOrdner,
    string RegisterDateiname,
    bool RegisterNachAbschlussSchreiben,
    string RegisterExportFilter,
    string VorlagenOrdner,
    string SicherungsAblageOrdner)
{
    /// <inheritdoc cref="From(KanzleiSettingsEntity, Func{string, string?})"/>
    public static KanzleiSettingsDto From(KanzleiSettingsEntity e) =>
        From(e, AppOrdnerPfad.Umgebung);

    /// <summary>
    /// Anzeigeform: Jeder Ordnerpfad geht aufgelöst hinaus, damit die
    /// Oberfläche zeigen kann, wo der Ordner auf <em>diesem</em> Rechner liegt.
    /// </summary>
    public static KanzleiSettingsDto From(KanzleiSettingsEntity e, Func<string, string?> umgebung) => new(
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
        Anzeigeform(e.AppDatenOrdner, umgebung),
        Anzeigeform(e.AktenStammordner, umgebung),
        e.MailSignatur,
        e.MailSignaturHtml,
        Anzeigeform(e.RegisterAblageOrdner, umgebung),
        e.RegisterDateiname,
        e.RegisterNachAbschlussSchreiben,
        e.RegisterExportFilter,
        Anzeigeform(e.VorlagenOrdner, umgebung),
        Anzeigeform(e.SicherungsAblageOrdner, umgebung));

    /// <inheritdoc cref="ToEntity(KanzleiSettingsEntity?, Func{string, string?})"/>
    public KanzleiSettingsEntity ToEntity() => ToEntity(null, AppOrdnerPfad.Umgebung);

    /// <inheritdoc cref="ToEntity(KanzleiSettingsEntity?, Func{string, string?})"/>
    public KanzleiSettingsEntity ToEntity(Func<string, string?> umgebung) => ToEntity(null, umgebung);

    /// <inheritdoc cref="ToEntity(KanzleiSettingsEntity?, Func{string, string?})"/>
    public KanzleiSettingsEntity ToEntity(KanzleiSettingsEntity? bisher) => ToEntity(bisher, AppOrdnerPfad.Umgebung);

    /// <summary>
    /// Speicherform: Jeder Ordnerpfad, der unter dem synchronisierten
    /// Wurzelordner liegt, wird auf <c>%Var%\Rest</c> verkürzt — sonst bleibt
    /// er absolut.
    ///
    /// <paramref name="bisher"/> ist der zuletzt gespeicherte Einstellungssatz
    /// (vor diesem Speichern geladen) — gegen Anker-Drift: Er kommt hier als
    /// aufgelöster absoluter Pfad hinein (<see cref="From(KanzleiSettingsEntity,
    /// Func{string, string?})"/>) und würde ohne den bisherigen gespeicherten
    /// Wert je Feld bei jedem Speichern neu gegen die Vorzugsreihenfolge
    /// geprüft, siehe <see cref="AppOrdnerPfad.MacheRelativ(string?, string?,
    /// Func{string, string?})"/>.
    /// </summary>
    public KanzleiSettingsEntity ToEntity(KanzleiSettingsEntity? bisher, Func<string, string?> umgebung) => new()
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
        AppDatenOrdner = AppOrdnerPfad.MacheRelativ(AppDatenOrdner, bisher?.AppDatenOrdner, umgebung),
        AktenStammordner = AppOrdnerPfad.MacheRelativ(AktenStammordner, bisher?.AktenStammordner, umgebung),
        MailSignatur = MailSignatur,
        MailSignaturHtml = MailSignaturHtml,
        RegisterAblageOrdner = AppOrdnerPfad.MacheRelativ(RegisterAblageOrdner, bisher?.RegisterAblageOrdner, umgebung),
        RegisterDateiname = RegisterDateiname,
        RegisterNachAbschlussSchreiben = RegisterNachAbschlussSchreiben,
        RegisterExportFilter = GespeicherterFilter(RegisterExportFilter),
        VorlagenOrdner = AppOrdnerPfad.MacheRelativ(VorlagenOrdner, bisher?.VorlagenOrdner, umgebung),
        SicherungsAblageOrdner = AppOrdnerPfad.MacheRelativ(SicherungsAblageOrdner, bisher?.SicherungsAblageOrdner, umgebung),
    };

    /// <summary>
    /// Der aufgelöste Pfad — oder, wenn er sich hier nicht auflösen lässt, die
    /// Speicherform unverändert.
    ///
    /// Das ist Absicht und kein Notbehelf: Ein Ordner, dessen Anker auf diesem
    /// Rechner fehlt, darf nicht als leeres Feld erscheinen, sonst überschriebe
    /// das nächste Speichern eine gültige Einstellung des anderen Rechners mit
    /// nichts. Was daran fehlt, sagt <c>GET api/Settings/ordner</c>.
    /// </summary>
    static string Anzeigeform(string gespeichert, Func<string, string?> umgebung) =>
        AppOrdnerPfad.LoeseAuf(gespeichert, umgebung) ?? gespeichert.Trim();

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
