namespace AutomationService.Features.Vorgaenge.Domain.Persistence;

/// <summary>
/// Persistenz-Abbild eines Vorgangs — der gemeinsamen Klammer über den
/// Lebenszyklus (Anfrage → Antwort → Schreiben → Ablage → Versand). Felder, nach
/// denen gefiltert/sortiert/zugeordnet wird, sind echte Spalten; die als Ganzes
/// gelesenen Antwortdaten liegen als JSON in <see cref="AntwortJson"/>.
///
/// Die <see cref="Referenz"/> ("Nr/Jahr Abteilung_Kennzeichen") ist fachlich der
/// Schlüssel (Unique-Index); über sie wird eine eingehende Zentralruf-Antwort
/// dem richtigen Vorgang zugeordnet.
/// </summary>
public class VorgangEntity
{
    public int Id { get; set; }

    public string Referenz { get; set; } = string.Empty;
    public DateTime AngefragtAm { get; set; }
    public string Status { get; set; } = string.Empty;
    public string Rechtsgebiet { get; set; } = string.Empty;

    public int? LaufendeNummer { get; set; }
    public string? Jahr { get; set; }
    public string? Abteilung { get; set; }
    public string? Kennzeichen { get; set; }

    public int? MandantId { get; set; }
    public string? MandantName { get; set; }
    public string? Gegner { get; set; }
    public string? UnfallDatum { get; set; }
    public string? GeschaedigtenKennzeichen { get; set; }
    public string? Unfallort { get; set; }
    public string? Unfalluhrzeit { get; set; }
    public string? PolizeiVorgangsnummer { get; set; }

    /// <summary>Serialisierte ZentralrufReplyData; null, solange keine Antwort vorliegt.</summary>
    public string? AntwortJson { get; set; }

    /// <summary>
    /// Die zuletzt im Word-Assistenten ausgefüllten Formularfelder als JSON-Objekt
    /// (Label → Wert). Damit lassen sich Folge-/Korrekturschreiben zum selben
    /// Vorgang vorbelegen, statt alles neu zu erfassen. Null, solange noch kein
    /// Dokument erzeugt wurde.
    /// </summary>
    public string? FeldWerteJson { get; set; }

    /// <summary>
    /// Die zuletzt erfasste Schadensaufstellung (serialisierte DamageListing des
    /// Frontends) — wie <see cref="AntwortJson"/> ein opakes JSON, das das
    /// Backend nur durchreicht. Null ohne Aufstellung.
    /// </summary>
    public string? SchadensaufstellungJson { get; set; }

    /// <summary>
    /// Ein <b>angefangener</b> Ausfüllstand des Word-Assistenten (Zeitpunkt,
    /// Formularwerte, Schadensaufstellung) als opakes JSON — getrennt von
    /// <see cref="FeldWerteJson"/>, das nur bestätigte Werte trägt. Bestätigt
    /// bleibt bestätigt; ein Entwurf ist ein Angebot, das der Anwalt beim
    /// Wiedereinstieg annehmen oder verwerfen kann. Null, wenn keiner offen ist.
    /// </summary>
    public string? EntwurfJson { get; set; }

    /// <summary>
    /// Laufende Nummer des zuletzt erzeugten Schreibens innerhalb des Vorgangs
    /// (§4.9): das erste hat 1, das zweite 2. Steht im Dateinamen und trennt
    /// dort die Schreiben, die alle im selben Aktenunterordner landen.
    ///
    /// Sie steigt nur, wenn der Anwalt beim Erzeugen ausdrücklich ein
    /// <em>neues</em> Schreiben verlangt — eine Korrektur behält ihre Nummer und
    /// ersetzt damit die vorige Fassung. Geraten wird das nicht; die
    /// Änderungszeit der Datei kann beides nicht unterscheiden. Null, solange
    /// noch kein Schreiben erzeugt wurde.
    /// </summary>
    public int? SchreibenNummer { get; set; }

    public string? DokumentPfad { get; set; }
    public string? AktenOrdner { get; set; }
    public DateTime? AbgeschlossenAm { get; set; }
}
