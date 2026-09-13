namespace AutomationService.Features.Vollmacht.Domain.Services;

/// <summary>Stand einer der drei Vollmachtsvorlagen auf der Platte.</summary>
public sealed record VollmachtVorlage(
    VollmachtArt Art,
    string Dateiname,
    string Pfad,
    bool Vorhanden,
    DateTime? GeaendertAm);

/// <summary>
/// Der Unterordner <c>Vollmacht/</c> im eingestellten Vorlagenordner (§4.11).
///
/// Feste Dateinamen statt einer Pflege über „Vorlagen verwalten": Die
/// Vorlagenverwaltung ist auf Anspruchsschreiben mit Feldbeschreibung gebaut,
/// und bei der Vollmacht gibt es nichts zu beschreiben — die Felder sind fest.
/// Wer eine Vorlage tauschen will, legt die Datei im Explorer an diese Stelle;
/// die Einstellungen zeigen, was die App tatsächlich findet.
///
/// Ein Unterordner und nicht der Vorlagenordner selbst: Dessen oberste Ebene
/// ist die Auswahlliste der Anspruchsschreiben (<c>VorlagenVerzeichnis.Auflisten</c>),
/// und dort hätte eine Vollmacht nichts zu suchen.
/// </summary>
/// <param name="vorlagenOrdner">Der wirksame Vorlagenordner.</param>
/// <param name="logger">Protokolliert, was übernommen wurde.</param>
public sealed class VollmachtVorlagenOrdner(string vorlagenOrdner, ILogger<VollmachtVorlagenOrdner> logger)
{
    public string Pfad { get; } = Path.Combine(vorlagenOrdner, VollmachtArten.Unterordner);

    public string PfadFuer(VollmachtArt art) => Path.Combine(Pfad, VollmachtArten.Dateiname(art));

    /// <summary>
    /// Der Stand aller drei Vorlagen. Legt den leeren Unterordner an, falls er
    /// fehlt — sonst liefe „Ordner öffnen" gerade dann ins Leere, wenn der
    /// Anwalt die erste Datei hineinlegen will. Scheitert das (Laufwerk weg),
    /// meldet der Stand eben „fehlt".
    /// </summary>
    public IReadOnlyList<VollmachtVorlage> Stand()
    {
        try
        {
            Directory.CreateDirectory(Pfad);
        }
        catch (Exception exception) when (exception is IOException or UnauthorizedAccessException)
        {
            logger.LogWarning(exception, "Vollmacht-Ordner konnte nicht angelegt werden: {Ordner}", Pfad);
        }

        return
        [
            .. VollmachtArten.Alle.Select(art =>
            {
                var datei = new FileInfo(PfadFuer(art));
                return new VollmachtVorlage(
                    art,
                    datei.Name,
                    datei.FullName,
                    datei.Exists,
                    datei.Exists ? datei.LastWriteTime : null);
            }),
        ];
    }

    /// <summary>
    /// Übernimmt die neutralen Muster aus <paramref name="quellOrdner"/> unter
    /// den festen Namen — nur, wo noch keine Datei liegt. Überschreibt nie:
    /// Die Datei an dieser Stelle trägt den Kopf der Kanzlei.
    /// </summary>
    /// <returns>Anzahl der kopierten Dateien.</returns>
    public int Ergaenze(string quellOrdner)
    {
        if (!Directory.Exists(quellOrdner))
        {
            logger.LogWarning("Mitgelieferte Vollmacht-Muster nicht gefunden: {Quelle}.", quellOrdner);
            return 0;
        }

        Directory.CreateDirectory(Pfad);
        var kopiert = 0;
        foreach (var art in VollmachtArten.Alle)
        {
            var quelle = Path.Combine(quellOrdner, VollmachtArten.Mustername(art));
            var ziel = PfadFuer(art);
            if (!File.Exists(quelle) || File.Exists(ziel))
            {
                continue;
            }

            File.Copy(quelle, ziel);
            kopiert++;
        }

        if (kopiert > 0)
        {
            logger.LogInformation("{Anzahl} Vollmacht-Muster nach {Ziel} übernommen.", kopiert, Pfad);
        }

        return kopiert;
    }
}
