namespace AutomationService.Features.RegisterHistorie.Domain.Persistence;

/// <summary>
/// Eine Zeile des gewachsenen Kanzleiregisters ab 2018 (§6.2), übernommen aus
/// dem 90-seitigen Word-Dokument.
///
/// Bewusst <b>keine</b> <c>VorgangEntity</c>: Ein historischer Eintrag ist kein
/// Vorgang, den man öffnen, ausfüllen oder abschließen könnte. Als Vorgang
/// geführt stünden Tausende toter Zeilen in der Vorgangsliste, und jede
/// Auswertung über offene Aufträge wäre falsch.
///
/// Wiedererkannt wird eine Zeile über <c>(Jahr, LaufendeNummer, NummerZusatz)</c>
/// — das ist der natürliche Schlüssel des Registers; der Zusatz gehört dazu,
/// weil <c>10/19</c> und <c>10/19-I</c> zwei Akten sind.
/// <see cref="Kennung"/> ist die stabile Referenz nach außen (§7.2): Sie
/// überlebt Sicherung und Wiederherstellung, während die Id eine Zählnummer der
/// Datenbank bleibt.
///
/// Die Werte stehen so darin, wie sie in der Datei standen. Widersprüche
/// werden <b>nicht</b> stillschweigend berichtigt, sondern in
/// <see cref="BefundeJson"/> benannt — die Bereinigung ist Sache des Anwalts in
/// der App, mit Bestätigung, und nicht Sache des Erzeugers der Importdatei.
/// </summary>
public class RegisterHistorieEntity
{
    /// <summary>Die Zeile stammt aus einer eingelesenen Registerdatei.</summary>
    public const string QuelleImport = "import";

    public int Id { get; set; }

    /// <summary>Stabile Referenz (GUID als Zeichenkette), einmal vergeben und nie geändert.</summary>
    public string Kennung { get; set; } = string.Empty;

    /// <summary>Vierstelliger Jahrgang, z. B. 2019.</summary>
    public int Jahr { get; set; }

    /// <summary>Laufende Nummer im Jahrgang — mit Jahr und Zusatz eindeutig.</summary>
    public int LaufendeNummer { get; set; }

    /// <summary>
    /// Zusatz hinter der Nummer, z. B. "-I" in "10/19-I". Meist leer, aber Teil
    /// des Schlüssels: Ohne ihn verdrängte "10/19-I" die Akte "10/19".
    /// </summary>
    public string NummerZusatz { get; set; } = string.Empty;

    /// <summary>
    /// Spalte 1 der Tabelle, wörtlich. Sie wiederholt die Nummer aus Spalte 2;
    /// aufgehoben wird sie, damit ein Widerspruch nachvollziehbar bleibt statt
    /// nur als Befund behauptet zu werden.
    /// </summary>
    public string Spalte1 { get; set; } = string.Empty;

    /// <summary>Aktenzeichen wie in der Datei, z. B. "10/19-I".</summary>
    public string Aktenzeichen { get; set; } = string.Empty;

    /// <summary>Abteilungskürzel ohne Leerzeichen, z. B. "C03o" (§7.1).</summary>
    public string Abteilung { get; set; } = string.Empty;

    /// <summary>
    /// Die Abteilung in der Schreibweise der Datei ("C 03o"). Ohne sie ließe
    /// sich später nicht mehr prüfen, ob die Normalisierung richtig lag.
    /// </summary>
    public string AbteilungRoh { get; set; } = string.Empty;

    /// <summary>Art der Sache in Form B, z. B. "Bußgeldsache". Leer bei Form A.</summary>
    public string Sachart { get; set; } = string.Empty;

    public string Mandant { get; set; } = string.Empty;

    /// <summary>Die Gegenseite in Form A. Leer bei Form B (dort gibt es keine).</summary>
    public string Gegner { get; set; } = string.Empty;

    /// <summary>Der Sachbestand ohne Datum, z. B. "Ehescheidung".</summary>
    public string Sachbestand { get; set; } = string.Empty;

    /// <summary>
    /// Das Datum aus der Freitextzelle, wörtlich als Text — im Bestand steht es
    /// mal zwei-, mal vierstellig ("28.12.17", "12.01.2020"). Als Datum gelesen
    /// müsste geraten werden, welches Jahrhundert gemeint ist.
    /// </summary>
    public string Unfalldatum { get; set; } = string.Empty;

    /// <summary>Spalte 3 der Tabelle, z. B. "Verkehrsrecht".</summary>
    public string Rechtsgebiet { get; set; } = string.Empty;

    /// <summary>Die ganze Freitextzelle, ungeteilt — der Beleg für jede Zerlegung.</summary>
    public string Freitext { get; set; } = string.Empty;

    /// <summary>Selbsteinschätzung des Erzeugers: hoch, mittel, niedrig, ohneAngabe.</summary>
    public string Sicherheit { get; set; } = string.Empty;

    /// <summary>Hinweise des Erzeugers, JSON-Liste von Sätzen.</summary>
    public string HinweiseJson { get; set; } = "[]";

    /// <summary>Befunde der App (Lücke, Widerspruch, Katalog), JSON-Liste von Sätzen.</summary>
    public string BefundeJson { get; set; } = "[]";

    /// <summary>
    /// Der zugeordnete Mandant — von Anfang an vorhanden, aber vorerst immer
    /// <c>null</c>: Die Zuordnung historischer Zeilen zu Mandanten ist ein
    /// eigener Schnitt. Ein Import überschreibt einen gesetzten Wert nie.
    /// </summary>
    public int? MandantId { get; set; }

    /// <summary>Woher die Zeile stammt — derzeit nur <see cref="QuelleImport"/>.</summary>
    public string Quelle { get; set; } = QuelleImport;

    public DateTime ImportiertAm { get; set; }

    /// <summary>
    /// Wann der Anwalt die Zeile zuletzt selbst geändert hat. Gesetzt heißt:
    /// Diese Zeile ist von Hand nachgeführt, und ein zweiter Import derselben
    /// Datei darf sie nicht zurückdrehen.
    /// </summary>
    public DateTime? GeaendertAm { get; set; }
}
