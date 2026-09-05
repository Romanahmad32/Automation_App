namespace AutomationService.Features.Mandanten.Domain.Persistence;

/// <summary>
/// Ein Arbeitspaket des Mandanten-Imports (§5.1/§6.1): die Ordner, die einmal
/// zur Bearbeitung herausgegeben wurden, mit dem Zeitpunkt des Holens und dem
/// des Einlesens.
///
/// Der Anlass ist die Größe des Bestands. Rund 4000 Ordner sind in einer
/// Sitzung nicht zu bearbeiten, also läuft der Import in Paketen von etwa 200 —
/// und wer in Paketen arbeitet, braucht eine Stelle, die Buch führt. Ohne sie
/// fällt nicht auf, dass Paket 3 nie eingelesen wurde, bis am Ende jemand die
/// Ordner nachzählt.
///
/// Die Ordnernamen stehen als JSON-Liste in einer Spalte, wie am
/// <see cref="MandantEntity"/> auch: sie werden immer als Ganzes gelesen und
/// nie einzeln abgefragt (<see cref="MandantListen"/>).
/// </summary>
public class ArbeitspaketEntity
{
    public int Id { get; set; }

    /// <summary>
    /// Fortlaufende Paketnummer ab 1 — die Zahl, unter der der Anwalt das Paket
    /// wiedererkennt. Bewusst nicht die technische <see cref="Id"/>: die zählt
    /// je Datenbank und sagt fachlich nichts.
    /// </summary>
    public int Nummer { get; set; }

    /// <summary>Wann das Paket herausgegeben wurde.</summary>
    public DateTime GeholtAm { get; set; }

    /// <summary>JSON-Array der Ordnernamen dieses Pakets.</summary>
    public string OrdnernamenJson { get; set; } = "[]";

    /// <summary>
    /// Wann zum ersten Mal ein Import Ordner dieses Pakets erledigt hat;
    /// <c>null</c>, solange keiner davon zugeordnet oder vermerkt ist. Gesetzt
    /// wird das Datum ausschließlich von einem <b>Import</b> und nie von der
    /// Handarbeit im Zuordnungsstapel — sonst sagte die Spalte etwas anderes
    /// aus, als ihr Name verspricht.
    /// </summary>
    public DateTime? EingelesenAm { get; set; }

    /// <summary>
    /// Wie viele Ordner des Pakets inzwischen erledigt sind (zugeordnet oder
    /// als „ohne Mandantenbezug" vermerkt). Wird bei jedem Import neu gerechnet
    /// statt hochgezählt: ein zweiter Lauf derselben Datei darf die Zahl nicht
    /// verändern.
    /// </summary>
    public int ErledigtAnzahl { get; set; }
}
