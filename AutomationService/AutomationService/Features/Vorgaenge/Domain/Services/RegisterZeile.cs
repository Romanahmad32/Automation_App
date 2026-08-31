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
public sealed record RegisterZeile(
    string Jahr,
    int? LaufendeNummer,
    string Zeichen,
    string Parteien,
    string Sachbestand,
    string Rechtsgebiet,
    bool Abgeschlossen);
