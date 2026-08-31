namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Spielt die Vorlagen einer Sicherung in den Vorlagenordner dieses Rechners
/// ein — schonend (#33): Eine Datei, die lokal fehlt, wird kopiert (samt
/// Unterordnern). Eine, die lokal identisch vorliegt, wird still uebersprungen.
/// Eine, die lokal mit <em>anderem</em> Inhalt liegt, wird <em>nicht</em>
/// ersetzt, sondern gemeldet — der lokale Stand koennte der neuere sein, und
/// wer eine Sicherung einspielt, greift nach der Datenbank, nicht nach dem
/// Recht, die Handarbeit im Vorlagenordner zu ueberschreiben.
/// </summary>
public static class VorlagenWiederherstellung
{
    /// <summary>Liefert die relativen Pfade der nicht ersetzten Vorlagen.</summary>
    public static IReadOnlyList<string> StelleWiederHer(string quellVerzeichnis, string zielOrdner)
    {
        Directory.CreateDirectory(zielOrdner);
        var uebersprungen = new List<string>();

        foreach (var quelle in Directory.EnumerateFiles(
            quellVerzeichnis, "*.docx", SearchOption.AllDirectories))
        {
            if (SicherungsArchiv.IstSperrdatei(quelle))
            {
                continue;
            }

            var relativ = Path.GetRelativePath(quellVerzeichnis, quelle);
            var ziel = Path.Combine(zielOrdner, relativ);
            if (File.Exists(ziel))
            {
                if (!GleicherInhalt(quelle, ziel))
                {
                    uebersprungen.Add(relativ);
                }

                continue;
            }

            Directory.CreateDirectory(Path.GetDirectoryName(ziel)!);
            File.Copy(quelle, ziel);
        }

        return uebersprungen;
    }

    static bool GleicherInhalt(string erster, string zweiter)
    {
        var infoErster = new FileInfo(erster);
        var infoZweiter = new FileInfo(zweiter);
        if (infoErster.Length != infoZweiter.Length)
        {
            return false;
        }

        using var streamErster = infoErster.OpenRead();
        using var streamZweiter = infoZweiter.OpenRead();
        Span<byte> pufferErster = stackalloc byte[8192];
        Span<byte> pufferZweiter = stackalloc byte[8192];
        int gelesen;
        while ((gelesen = streamErster.ReadAtLeast(
            pufferErster, pufferErster.Length, throwOnEndOfStream: false)) > 0)
        {
            streamZweiter.ReadAtLeast(
                pufferZweiter[..gelesen], gelesen, throwOnEndOfStream: false);
            if (!pufferErster[..gelesen].SequenceEqual(pufferZweiter[..gelesen]))
            {
                return false;
            }
        }

        return true;
    }
}
