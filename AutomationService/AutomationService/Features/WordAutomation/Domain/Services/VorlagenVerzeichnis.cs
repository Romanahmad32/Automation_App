namespace AutomationService.Features.WordAutomation.Domain.Services;

/// <summary>
/// Der Vorlagenordner des Anwenders (%APPDATA%\AutomationService\Vorlagen).
///
/// Die Anwendung liefert Vorlagen mit, besitzt sie aber nicht: der Anwalt passt
/// sie an und legt eigene daneben. Deshalb werden die mitgelieferten beim Start
/// nur <em>ergaenzt</em> — eine Datei, die es schon gibt, bleibt unangetastet.
/// Wuerde hier ueberschrieben, verloere er mit jedem Update seinen Briefkopf und
/// merkte es erst im verschickten Schreiben.
///
/// Loescht er eine mitgelieferte Vorlage bewusst, kommt sie beim naechsten Start
/// zurueck. Das ist der Preis dafuer, dass eine leere Auswahl nach einer
/// Neuinstallation nicht vorkommen kann — und die Vorlage stoert im Ordner
/// weniger, als ihr Fehlen im Arbeitsablauf stoeren wuerde.
/// </summary>
/// <param name="pfad">
/// Der Vorlagenordner. Kommt als Zeichenkette herein statt aus AppDataPaths
/// heraus, damit die Klasse ohne %APPDATA% testbar bleibt — dieselbe Aufteilung
/// wie beim Sicherungsdienst.
/// </param>
/// <param name="logger">Protokolliert, was uebernommen wurde.</param>
public sealed class VorlagenVerzeichnis(string pfad, ILogger<VorlagenVerzeichnis> logger)
{
    public string Pfad { get; } = Directory.CreateDirectory(pfad).FullName;

    /// <summary>
    /// Kopiert die mitgelieferten Vorlagen aus <paramref name="quellVerzeichnis"/>
    /// in den Vorlagenordner, sofern dort noch keine gleichnamige Datei liegt.
    /// </summary>
    /// <returns>Anzahl der tatsaechlich kopierten Dateien.</returns>
    public int Ergaenze(string quellVerzeichnis)
    {
        if (!Directory.Exists(quellVerzeichnis))
        {
            logger.LogWarning(
                "Mitgelieferte Vorlagen nicht gefunden: {Quelle}. Der Vorlagenordner bleibt, wie er ist.",
                quellVerzeichnis);
            return 0;
        }

        var ziel = Pfad;
        var kopiert = 0;

        foreach (var quelle in Directory.EnumerateFiles(quellVerzeichnis, "*.docx"))
        {
            var zielPfad = Path.Combine(ziel, Path.GetFileName(quelle));
            if (File.Exists(zielPfad))
            {
                continue;
            }

            File.Copy(quelle, zielPfad);
            kopiert++;
        }

        if (kopiert > 0)
        {
            logger.LogInformation(
                "{Anzahl} mitgelieferte Vorlage(n) nach {Ziel} uebernommen.", kopiert, ziel);
        }

        return kopiert;
    }

    /// <summary>Alle Vorlagen im Ordner, neueste zuerst.</summary>
    public IReadOnlyList<VorlagenDatei> Auflisten()
    {
        return
        [
            .. new DirectoryInfo(Pfad)
                .GetFiles("*.docx")
                .OrderByDescending(datei => datei.LastWriteTime)
                .Select(datei => new VorlagenDatei(datei.Name, datei.FullName, datei.LastWriteTime))
        ];
    }
}
