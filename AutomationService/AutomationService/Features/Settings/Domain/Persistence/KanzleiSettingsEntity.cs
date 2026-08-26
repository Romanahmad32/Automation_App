namespace AutomationService.Features.Settings.Domain.Persistence;

/// <summary>
/// Persistenz-Abbild der Kanzlei-/App-Einstellungen. Bewusst eine Single-Row-
/// Tabelle mit festem <see cref="SingletonId"/> = 1: es gibt genau einen
/// Einstellungssatz. Enthält u. a. die laufende Auftragsnummer (§7.1), die
/// nach Abschluss eines Vorgangs hochgezählt wird.
/// </summary>
public class KanzleiSettingsEntity
{
    public const int SingletonId = 1;

    public int Id { get; set; } = SingletonId;

    public string Personentyp { get; set; } = string.Empty;
    public string Name { get; set; } = string.Empty;
    public string StrasseHausnummer { get; set; } = string.Empty;
    public string Postleitzahl { get; set; } = string.Empty;
    public string Ort { get; set; } = string.Empty;
    public string EmailAdresse { get; set; } = string.Empty;
    public string Telefonnummer { get; set; } = string.Empty;

    public int LaufendeAuftragsnummer { get; set; }
    public string Abteilung { get; set; } = string.Empty;
    public string TabellenkopfFarbeHex { get; set; } = string.Empty;
    public string AktenStammordner { get; set; } = string.Empty;

    /// <summary>
    /// Signaturblock unter dem Mailtext beim Direktversand (§4.7). Kommt aus
    /// der bereits eingerichteten Signatur des Mailprogramms ("Aus Outlook
    /// übernehmen"), nicht aus Abtippen. Beim Entwurf im Mailprogramm bleibt
    /// er ungenutzt — dort setzt Outlook seine eigene ein.
    /// </summary>
    public string MailSignatur { get; set; } = string.Empty;
}
