using System.Text;

namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>
/// Der Arbeitsordner der Dokumenterzeugung: je Vorgang ein Unterordner unter
/// <c>Generated/Arbeit/</c>, in dem immer nur die <em>aktuelle</em> Fassung des
/// Schreibens liegt.
///
/// Warum je Vorgang getrennt: der Ergebnisname trägt den Vorgang nicht (§4.9,
/// siehe <see cref="OutputFileNaming"/>) — er besteht aus Empfänger, laufender
/// Nummer und Vorlagenname. Zwei Vorgänge, die dieselbe Versicherung mit
/// derselben Vorlage anschreiben, träfen in einem gemeinsamen Ordner denselben
/// Dateinamen — und die zweite Erzeugung überschriebe das noch nicht abgelegte
/// Schreiben des ersten. Die Nummer trennt Schreiben <em>innerhalb</em> eines
/// Vorgangs, nicht die Vorgänge voneinander; das tut dieser Ordner.
///
/// Bleibendes Ergebnis ist allein die Kopie in der Mandantenakte (§4.6): nach
/// erfolgreicher Ablage löscht das Frontend den Arbeitsordner wieder
/// (<c>POST api/WordAutomation/arbeitsordner/aufraeumen</c>). Abgebrochene
/// Läufe räumt <see cref="AlteOrdnerLoeschen"/> beim Start nach
/// <see cref="MaxAlterTage"/> Tagen weg — dieselbe Regel wie beim PDF-Cache
/// nebenan.
/// </summary>
/// <param name="wurzel">
/// Wurzel aller Arbeitsordner. Kommt als Zeichenkette herein statt aus den
/// Optionen heraus, damit die Klasse ohne ContentRoot testbar bleibt — dieselbe
/// Aufteilung wie bei <see cref="VorlagenVerzeichnis"/>.
/// </param>
/// <param name="logger">Protokolliert, was gelöscht wurde und was hängen blieb.</param>
public sealed class ArbeitsVerzeichnis(string wurzel, ILogger<ArbeitsVerzeichnis> logger)
{
    private const int MaxAlterTage = 14;

    /// <summary>Ordnername ohne Vorgangsbezug (freie Erfassung, §4.4).</summary>
    public const string OhneVorgang = "Ohne Vorgang";

    /// <summary>Ein Ordnername soll lesbar bleiben und den Pfad nicht sprengen.</summary>
    private const int MaxNamensLaenge = 60;

    public string Wurzel { get; } = Directory.CreateDirectory(wurzel).FullName;

    /// <summary>Arbeitsordner des Vorgangs; wird angelegt, falls nötig.</summary>
    public string OrdnerFuer(string? vorgangSchluessel)
    {
        var ordner = Path.Combine(Wurzel, Ordnername(vorgangSchluessel));
        Directory.CreateDirectory(ordner);
        return ordner;
    }

    /// <summary>
    /// Löscht den Arbeitsordner des Vorgangs mitsamt Inhalt. Gibt <c>false</c>
    /// zurück, wenn etwas darin gesperrt ist (typisch: noch in Word geöffnet).
    /// Ein nicht vorhandener Ordner gilt als aufgeräumt.
    /// </summary>
    public bool Aufraeumen(string? vorgangSchluessel)
    {
        var ordner = Path.Combine(Wurzel, Ordnername(vorgangSchluessel));
        if (!Directory.Exists(ordner))
        {
            return true;
        }

        try
        {
            Directory.Delete(ordner, recursive: true);
            logger.LogInformation("Arbeitsordner aufgeräumt: {Ordner}", ordner);
            return true;
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            logger.LogWarning(exception, "Arbeitsordner konnte nicht gelöscht werden: {Ordner}", ordner);
            return false;
        }
    }

    /// <summary>
    /// Macht aus der Vorgangsreferenz einen Ordnernamen. Nötig, weil die
    /// Referenz Schrägstriche enthält ("84/26 C03_GG-XY 123") — die wechselten
    /// das Verzeichnis, statt eines zu benennen.
    /// </summary>
    public static string Ordnername(string? vorgangSchluessel)
    {
        var roh = vorgangSchluessel?.Trim();
        if (string.IsNullOrEmpty(roh))
        {
            return OhneVorgang;
        }

        var ungueltig = Path.GetInvalidFileNameChars();
        var gesaeubert = new StringBuilder(roh.Length);
        foreach (var zeichen in roh)
        {
            gesaeubert.Append(Array.IndexOf(ungueltig, zeichen) >= 0 ? '-' : zeichen);
        }

        var name = gesaeubert.ToString();
        if (name.Length > MaxNamensLaenge)
        {
            name = name[..MaxNamensLaenge];
        }

        // Abschließende Punkte/Leerzeichen sind unter Windows als Ordnername
        // unzulässig; nebenbei fallen damit "." und ".." weg, die sonst aus der
        // Wurzel herausführten.
        name = name.Trim().TrimEnd('.', ' ');
        return name.Length == 0 ? OhneVorgang : name;
    }

    /// <summary>
    /// Räumt Arbeitsordner ab, die seit <see cref="MaxAlterTage"/> Tagen nicht
    /// mehr angefasst wurden: abgebrochene Läufe, die nie in einer Akte
    /// gelandet sind. Best-Effort — ein Fehler beim Aufräumen darf den Start
    /// nicht aufhalten.
    /// </summary>
    public void AlteOrdnerLoeschen()
    {
        try
        {
            var grenze = DateTime.UtcNow.AddDays(-MaxAlterTage);
            foreach (var ordner in Directory.EnumerateDirectories(Wurzel))
            {
                if (Directory.GetLastWriteTimeUtc(ordner) >= grenze)
                {
                    continue;
                }

                Directory.Delete(ordner, recursive: true);
                logger.LogInformation("Verwaisten Arbeitsordner gelöscht: {Ordner}", ordner);
            }
        }
        catch (Exception exception)
        {
            logger.LogWarning(exception, "Aufräumen der Arbeitsordner fehlgeschlagen (unkritisch).");
        }
    }
}
