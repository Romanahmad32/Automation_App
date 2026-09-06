namespace AutomationService.Features.Mandanten.Domain.Persistence;

/// <summary>
/// Ein herausgegebenes Arbeitspaket des Mandanten-Imports (§5.1, §6.1). Der
/// Aktenbestand einer Kanzlei umfasst tausende Ordner; sie in einem Zug durch
/// einen KI-Agenten zu schicken, ist weder zu überblicken noch zu prüfen.
/// Deshalb wird der Vorrat in Pakete geteilt, und diese Tabelle ist das
/// Gedächtnis darüber: was wann herausging und was davon zurückkam.
///
/// Zusammengesetzt wird ein Paket im Frontend — nur dort ist der Bestand der
/// Ordner im Dateisystem bekannt. Das Backend führt <b>Buch</b> und rechnet;
/// es sieht keinen Stammordner und liest kein Verzeichnis.
/// </summary>
public class ImportPaketEntity
{
    public int Id { get; set; }

    /// <summary>
    /// Fortlaufende Paketnummer ab 1, vom Backend vergeben. Sie ist die Zahl,
    /// die der Anwalt sieht und im Dateinamen wiederfindet — die technische
    /// <see cref="Id"/> taugt dafür nicht, weil sie nichts verspricht.
    /// </summary>
    public int Nummer { get; set; }

    /// <summary>Wann das Paket herausgegeben wurde (UTC).</summary>
    public DateTime GeholtAm { get; set; }

    /// <summary>Wie viele Ordner im Paket liegen.</summary>
    public int AnzahlOrdner { get; set; }

    /// <summary>
    /// JSON-Array der Ordnernamen dieses Pakets (Muster: <see cref="MandantListen"/>).
    ///
    /// Kein toter Ballast, sondern der Grund, warum der Anwalt beim Import
    /// nichts auszuwählen hat: Ob eine eingelesene Datei zu diesem Paket
    /// gehört, rechnet die App aus diesen Namen aus, statt danach zu fragen.
    /// Nach außen geliefert wird die Liste trotzdem nicht — 200 Namen je Paket
    /// in einer Übersicht mit vier Spalten wäre Verschwendung.
    /// </summary>
    public string OrdnernamenJson { get; set; } = "[]";

    /// <summary>
    /// Wann das Paket vollständig zurückkam (UTC); <c>null</c> heißt: noch
    /// offen.
    /// </summary>
    public DateTime? EingelesenAm { get; set; }

    /// <summary>
    /// Zeilen der Importdatei, die das Paket geschlossen hat; <c>null</c>,
    /// solange es offen ist.
    /// </summary>
    public int? Zeilen { get; set; }
}
