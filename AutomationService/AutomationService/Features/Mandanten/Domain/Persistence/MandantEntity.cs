namespace AutomationService.Features.Mandanten.Domain.Persistence;

/// <summary>
/// Persistenz-Abbild eines Mandanten (Stammdaten, §5.1). Die 0..n-Listen
/// (Akten-Ordnernamen, Kfz-Kennzeichen) werden als Ganzes gelesen/geschrieben
/// und nie einzeln abgefragt — daher als JSON-Spalte statt eigener Kindtabelle.
/// </summary>
public class MandantEntity
{
    public int Id { get; set; }

    public string Anrede { get; set; } = string.Empty;
    public string Vorname { get; set; } = string.Empty;
    public string Nachname { get; set; } = string.Empty;
    public string StrasseHausnummer { get; set; } = string.Empty;
    public string Postleitzahl { get; set; } = string.Empty;
    public string Ort { get; set; } = string.Empty;
    public string EmailAdresse { get; set; } = string.Empty;
    public string Telefonnummer { get; set; } = string.Empty;
    public string Notiz { get; set; } = string.Empty;
    public DateTime ErstelltAm { get; set; }

    /// <summary>JSON-Array der zugeordneten Akten-Ordnernamen (relativ zum Stammordner).</summary>
    public string AktenOrdnernamenJson { get; set; } = "[]";

    /// <summary>JSON-Array der Kfz-Kennzeichen des Mandanten (mit Bindestrich).</summary>
    public string KennzeichenJson { get; set; } = "[]";
}
