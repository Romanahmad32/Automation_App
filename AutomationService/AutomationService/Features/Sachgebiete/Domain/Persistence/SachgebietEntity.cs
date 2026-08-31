namespace AutomationService.Features.Sachgebiete.Domain.Persistence;

/// <summary>
/// Ein Sachgebiet aus dem Katalog der Kanzlei (§7.1): Abteilungskürzel plus
/// Name, wie sie im Kopf des gewachsenen Registers stehen. Der Katalog ist
/// Stammdatenbestand und speist die Auswahl der Abteilung (§4.2) und des
/// Rechtsgebiets (§6.2) — er ist bewusst breiter als der Aktenbestand, damit
/// auch selten genutzte Abteilungen wählbar bleiben.
///
/// Ein Kürzel ist Pflicht und wird ohne Leerzeichen geführt (§7.1,
/// Normalisierung): Das Referenzformat trennt die Abteilung am Leerzeichen,
/// ein Kürzel mit Leerzeichen zerlegte die Referenz auf beiden Seiten still.
/// </summary>
public class SachgebietEntity
{
    public int Id { get; set; }

    /// <summary>Abteilungskürzel, z. B. "C03o" — nie leer, nie mit Leerzeichen.</summary>
    public string Kuerzel { get; set; } = string.Empty;

    /// <summary>Name des Sachgebiets, z. B. "Ordnungswidrigkeitssache".</summary>
    public string Name { get; set; } = string.Empty;

    /// <summary>
    /// Vorschlag für die Sachgebietsspalte des Registers, wenn ein Vorgang
    /// dieser Abteilung noch kein Rechtsgebiet trägt. Meist gleich dem Namen;
    /// weicht ab, wo der Katalogname einen Zusatz führt, den die Spalte nicht
    /// zeigt ("Zivilrecht (allgemein)" → "Zivilrecht").
    /// </summary>
    public string RechtsgebietVorschlag { get; set; } = string.Empty;

    /// <summary>Reihenfolge in Auswahllisten — Katalogreihenfolge, nicht alphabetisch.</summary>
    public int Sortierung { get; set; }

    /// <summary>
    /// Inaktive Einträge verschwinden aus der Auswahl, bleiben aber für den
    /// Bestand lesbar — Vorarbeit für die spätere Pflege des Katalogs in der
    /// App (§7.1, [S]): Löschen würde gespeicherte Abteilungen verwaisen lassen.
    /// </summary>
    public bool Aktiv { get; set; } = true;
}
