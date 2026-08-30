using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace AutomationService.Features.Vorgaenge.Domain.Services;

/// <summary>
/// Merkt sich, was zuletzt in den Spiegel geschrieben wurde — damit derselbe
/// Bestand nicht zweimal geschrieben wird.
///
/// Das ist keine Sparsamkeit um ihrer selbst willen. Die abgelöste
/// Kanzleidatei steht bei Revision 5341; ein Spiegel, der bei jedem Abschluss
/// stumpf neu schreibt, erzeugt dasselbe in Neu — nur diesmal im
/// Versionsverlauf des Synchronisierungsdienstes, der dann aus hunderten
/// identischen Fassungen besteht und niemandem mehr sagt, wann sich wirklich
/// etwas geändert hat.
///
/// Der Stand liegt neben der Datenbank und <b>nicht</b> im Ablageordner: Dort
/// wäre er eine Fremddatei, die mitsynchronisiert und auf dem Handy sichtbar
/// würde.
/// </summary>
/// <param name="dateiPfad">Ablageort der Standdatei.</param>
public sealed class RegisterSpiegelStand(string dateiPfad)
{
    /// <summary>
    /// Fließt in den Fingerabdruck ein. Hochzählen, wenn sich am Aufbau des
    /// Dokuments etwas ändert — sonst bliebe nach einer Layout-Änderung die
    /// alte Datei liegen, weil die Daten ja dieselben sind.
    /// </summary>
    const int LayoutFassung = 1;

    /// <summary>
    /// Trennt die Felder im Fingerabdruck. Ein Steuerzeichen, damit kein
    /// Mandantenname ihn enthalten kann — sonst ergaeben zwei verschiedene
    /// Zeilen denselben Abdruck und eine Aenderung bliebe ungeschrieben.
    /// </summary>
    const char Trenner = '\u001F';

    /// <summary>
    /// Was der letzte Lauf hinterlassen hat.
    /// </summary>
    /// <param name="Fingerabdruck">Über die Zeilen, den Filter und die Layout-Fassung.</param>
    /// <param name="Ziel">Der volle Pfad der geschriebenen .docx.</param>
    /// <param name="GeschriebenAm">Zeitpunkt des Laufs.</param>
    /// <param name="PdfGeschrieben">
    /// Ob dabei auch die PDF-Fassung entstand. Ohne dieses Feld liesse sich
    /// „im Ablageordner liegt kein PDF" nicht von „dort liegt ein veraltetes"
    /// unterscheiden — und genau daran hing, dass eine einmal gescheiterte
    /// Wandlung ein PDF von gestern für immer neben einer aktuellen .docx
    /// stehen liess. Fehlt das Feld in einer älteren Standdatei, ist es
    /// <c>false</c>: Der nächste Lauf schreibt dann einmal neu, und das ist
    /// die sichere Richtung.
    /// </param>
    public sealed record Eintrag(
        string Fingerabdruck,
        string Ziel,
        DateTime GeschriebenAm,
        bool PdfGeschrieben = false);

    /// <summary>
    /// Der Stand ist ein Singleton, und <c>StandAsync</c> liest ihn, während
    /// ein Schreiblauf ihn setzen kann — beim Öffnen der Registerseite mitten
    /// im Export nach einem Vorgangsabschluss.
    ///
    /// <c>File.WriteAllText</c> ist kein unteilbarer Schritt: Ein Leser kann
    /// die halbe Datei erwischen. Das wäre für sich genommen harmlos, weil
    /// unlesbar hier „neu schreiben" heisst — nur zeigt die Seite dann „noch
    /// nie geschrieben" neben einem Spiegel, der eine Sekunde alt ist.
    /// </summary>
    readonly Lock schloss = new();

    public Eintrag? Lesen()
    {
        try
        {
            lock (schloss)
            {
                if (!File.Exists(dateiPfad)) return null;
                return JsonSerializer.Deserialize<Eintrag>(File.ReadAllText(dateiPfad));
            }
        }
        catch (Exception ex) when (ex is IOException or JsonException or UnauthorizedAccessException)
        {
            // Ein unlesbarer Stand heißt: neu schreiben. Das ist immer die
            // sichere Richtung — schlimmstenfalls entsteht eine Fassung zu viel.
            return null;
        }
    }

    public void Schreiben(Eintrag eintrag)
    {
        try
        {
            var ordner = Path.GetDirectoryName(dateiPfad);
            if (!string.IsNullOrEmpty(ordner)) Directory.CreateDirectory(ordner);
            lock (schloss)
            {
                File.WriteAllText(dateiPfad, JsonSerializer.Serialize(eintrag));
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // Der Spiegel liegt richtig; nur die Ersparnis beim nächsten Mal
            // entfällt. Kein Grund, den Lauf als gescheitert zu melden.
        }
    }

    /// <summary>
    /// Fingerabdruck über den <em>Inhalt</em> der künftigen Datei: die Zeilen,
    /// der Filter und die Layout-Fassung. Bewusst nicht über die erzeugte
    /// .docx — die enthält einen Zeitstempel und wäre bei jedem Lauf anders.
    /// </summary>
    public static string Fingerabdruck(IReadOnlyList<RegisterZeile> zeilen, bool nurAbgeschlossene)
    {
        ArgumentNullException.ThrowIfNull(zeilen);

        var inhalt = new StringBuilder()
            .Append(LayoutFassung).Append('|')
            .Append(nurAbgeschlossene).Append('\n');
        foreach (var z in zeilen)
        {
            inhalt.Append(z.Jahr).Append(Trenner)
                .Append(z.LaufendeNummer).Append(Trenner)
                .Append(z.Zeichen).Append(Trenner)
                .Append(z.Parteien).Append(Trenner)
                .Append(z.Sachbestand).Append(Trenner)
                .Append(z.Rechtsgebiet).Append(Trenner)
                .Append(z.Abgeschlossen).Append('\n');
        }

        return Convert.ToHexStringLower(
            SHA256.HashData(Encoding.UTF8.GetBytes(inhalt.ToString())));
    }
}
