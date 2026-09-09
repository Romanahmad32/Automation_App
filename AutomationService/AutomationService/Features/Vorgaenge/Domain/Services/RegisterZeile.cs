using AutomationService.Features.RegisterHistorie.Domain.Services;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Eine Zeile des Sachgebiete-Registers (§6.2) im verbindlichen Spaltenschema.
///
/// Vier Felder, nicht drei: Die gewachsene Kanzleidatei schiebt Zeichen,
/// Parteien und Sachbestand in <em>eine</em> Freitextzelle zusammen — genau die
/// Spalte, an der ein Parser des Altbestands scheitert. Der Export gibt sie
/// getrennt aus (#40); die App modelliert sie ohnehin getrennt.
/// </summary>
/// <param name="Jahr">
/// Vierstellig ("2026") — die Zwischenüberschrift, unter der die Zeile steht.
/// Abgeleitet und nie leer, damit keine Zeile aus der Gliederung fällt.
/// </param>
/// <param name="LaufendeNummer">
/// Die laufende Nummer im Jahrgang, null solange keine vergeben ist. Ein
/// Vorgang bekommt sie erst mit dem Abschluss.
/// </param>
/// <param name="Zeichen">Zeichen samt Abteilung ("01/26 C03").</param>
/// <param name="Parteien">"Mandant ./. Gegner".</param>
/// <param name="Sachbestand">"Sachverhalt v. 28.12.2025"; leer ohne Datum.</param>
/// <param name="Rechtsgebiet">Anzeigename des Sachgebiets ("Verkehrsrecht").</param>
/// <param name="Abgeschlossen">
/// Ob der Vorgang versendet und damit abgeschlossen ist. Steht in der Datei
/// nicht als eigene Spalte — dafür ist der Satzspiegel zu schmal —, sondern
/// zeichnet die Zeile aus (siehe RegisterDokument).
/// </param>
/// <param name="Quelle">
/// Ob die Zeile aus einem Vorgang der App oder aus der übernommenen
/// Registerhistorie stammt (<see cref="RegisterQuellen"/>). Vorbelegt mit
/// <c>vorgang</c>, damit die zweite Quelle keine einzige Aufrufstelle der
/// ersten anfassen musste.
/// </param>
/// <param name="HistorieId">Schlüssel der historischen Zeile — nur bei Quelle <c>historie</c>.</param>
/// <param name="VorgangReferenz">
/// Die Referenz des Vorgangs ("01/26 C03_HG-E 1427") — nur bei Quelle
/// <c>vorgang</c>. Damit kann die Ansicht die Zeile öffnen, ohne die Zeichen
/// wieder zerlegen zu müssen.
/// </param>
/// <param name="Sicherheit">
/// Wie sicher die Zerlegung der historischen Zeile war. Ein Vorgang der App ist
/// immer <c>hoch</c>: Seine Felder hat niemand aus einer Freitextzelle geraten.
/// </param>
/// <param name="Befunde">
/// Was an der historischen Zeile auffiel (Widerspruch, unbekanntes Kürzel).
/// Leer bei Vorgängen der App.
/// </param>
public sealed record RegisterZeile(
    string Jahr,
    int? LaufendeNummer,
    string Zeichen,
    string Parteien,
    string Sachbestand,
    string Rechtsgebiet,
    bool Abgeschlossen,
    string Quelle = RegisterQuellen.Vorgang,
    int? HistorieId = null,
    string? VorgangReferenz = null,
    string Sicherheit = RegisterSicherheiten.Hoch,
    IReadOnlyList<string>? Befunde = null);
