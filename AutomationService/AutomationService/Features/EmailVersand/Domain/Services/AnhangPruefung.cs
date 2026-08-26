namespace AutomationService.Features.EmailVersand.Domain.Services;

/// <summary>
/// Liest die Anhänge ein und lehnt den Versand ab, solange auch nur einer
/// fehlt, gesperrt ist oder das Paket zu groß wird (REQUIREMENTS.md §4.7).
///
/// Alles oder nichts — dieselbe Haltung wie bei der Ablage in der Akte: Eine
/// Mail, der ausgerechnet das Anspruchsschreiben fehlt, ist schlimmer als eine,
/// die gar nicht erst hinausging. Der häufigste Fall ist harmlos und muss
/// deshalb im Klartext gemeldet werden: Das Dokument ist noch in Word geöffnet.
/// </summary>
public static class AnhangPruefung
{
    /// <param name="pfade">Vollstaendige Pfade der Anhaenge.</param>
    /// <param name="maxGesamtMb">Obergrenze aller Anhaenge zusammen.</param>
    /// <param name="namen">
    /// Abweichender Dateiname je Pfad, wenn der Anwalt umbenannt hat. Die Datei
    /// auf Platte bleibt unberuehrt — umbenannt wird nur, was beim Empfaenger
    /// ankommt.
    /// </param>
    public static IReadOnlyList<GeladenerAnhang> Lade(
        IReadOnlyList<string> pfade,
        int maxGesamtMb,
        IReadOnlyDictionary<string, string>? namen = null)
    {
        var nachVollpfad = Normalisiert(namen);
        return [.. Sammle(pfade, maxGesamtMb)
            .Select(datei => new GeladenerAnhang(Anzeigename(datei, nachVollpfad), LiesInhalt(datei)))];
    }

    /// <summary>
    /// Bringt die Schluessel auf dieselbe Form wie <c>FileInfo.FullName</c>.
    /// Die Oberflaeche schickt den Pfad, wie sie ihn hat — mit Schraegstrichen
    /// aus der Dateiauswahl etwa —, und ein Zeichenkettenvergleich darauf
    /// scheiterte still: Der Anhang ginge unter seinem alten Namen hinaus.
    /// </summary>
    private static Dictionary<string, string> Normalisiert(IReadOnlyDictionary<string, string>? namen)
    {
        var karte = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        if (namen is null)
        {
            return karte;
        }

        foreach (var (pfad, name) in namen)
        {
            try
            {
                karte[Path.GetFullPath(pfad)] = name;
            }
            catch (Exception ausnahme) when (ausnahme is ArgumentException or NotSupportedException or PathTooLongException)
            {
                // Unbrauchbarer Pfad: Dann bleibt es beim Namen auf Platte.
            }
        }

        return karte;
    }

    /// <summary>
    /// Der Name, unter dem der Anhang hinausgeht. Ein umbenannter Anhang darf
    /// die Datei nicht aus ihrem Ordner heben: Nur der Dateiname zaehlt, ein
    /// mitgegebener Pfad waere ein Versehen oder ein Angriff.
    /// </summary>
    private static string Anzeigename(FileInfo datei, Dictionary<string, string> namen)
    {
        if (!namen.TryGetValue(datei.FullName, out var gewuenscht))
        {
            return datei.Name;
        }

        var sauber = Path.GetFileName(gewuenscht.Trim());
        return string.IsNullOrWhiteSpace(sauber) ? datei.Name : sauber;
    }

    /// <summary>
    /// Prüft dieselben Bedingungen, ohne die Dateien einzulesen — für den
    /// Entwurf im Mailprogramm, das die Anhänge selbst öffnet. Ein fehlender
    /// oder gesperrter Anhang soll trotzdem auffallen, bevor ein Fenster
    /// aufgeht, das nach fertiger Arbeit aussieht.
    /// </summary>
    public static void Pruefe(IReadOnlyList<string> pfade, int maxGesamtMb)
    {
        foreach (var datei in Sammle(pfade, maxGesamtMb))
        {
            // Öffnen und gleich wieder schließen: Das beantwortet die Frage
            // „lesbar?" vollständig und kostet nichts.
            LiesbarkeitPruefen(datei);
        }
    }

    /// <summary>
    /// Die Dateien hinter den Pfaden — vorhanden und zusammen unter der Grenze.
    /// Leere Pfade werden übergangen: Eine leere Zeile in der Liste ist keine
    /// Angabe, sondern nichts.
    /// </summary>
    private static List<FileInfo> Sammle(IReadOnlyList<string> pfade, int maxGesamtMb)
    {
        var dateien = new List<FileInfo>(pfade.Count);
        long gesamt = 0;
        var grenze = (long)Math.Max(1, maxGesamtMb) * 1024 * 1024;

        foreach (var pfad in pfade)
        {
            if (string.IsNullOrWhiteSpace(pfad))
            {
                continue;
            }

            var datei = new FileInfo(pfad);
            if (!datei.Exists)
            {
                throw new EmailVersandException(
                    EmailVersandFehler.Anhang,
                    $"Der Anhang \"{datei.Name}\" liegt nicht (mehr) unter {pfad}. " +
                    "Es wurde nichts gesendet.");
            }

            gesamt += datei.Length;
            if (gesamt > grenze)
            {
                throw new EmailVersandException(
                    EmailVersandFehler.Anhang,
                    $"Die Anhänge sind zusammen größer als {maxGesamtMb} MB. Die meisten " +
                    "Postfächer weisen solche Nachrichten ab — bitte weniger anhängen " +
                    "oder die Dateien vorher verkleinern.");
            }

            dateien.Add(datei);
        }

        return dateien;
    }

    /// <summary>
    /// Liest die Datei und lässt Mitleser zu (<see cref="FileShare.ReadWrite"/>):
    /// Ein in Word geöffnetes Dokument ist lesbar, solange man niemanden
    /// aussperrt. Bleibt es trotzdem gesperrt, nennt die Meldung den
    /// wahrscheinlichen Grund statt der Windows-Fehlernummer.
    /// </summary>
    private static byte[] LiesInhalt(FileInfo datei)
    {
        using var strom = Oeffne(datei);
        using var puffer = new MemoryStream();
        strom.CopyTo(puffer);
        return puffer.ToArray();
    }

    private static void LiesbarkeitPruefen(FileInfo datei) => Oeffne(datei).Dispose();

    private static FileStream Oeffne(FileInfo datei)
    {
        try
        {
            return datei.Open(FileMode.Open, FileAccess.Read, FileShare.ReadWrite);
        }
        catch (IOException exception)
        {
            throw new EmailVersandException(
                EmailVersandFehler.Anhang,
                $"Der Anhang \"{datei.Name}\" lässt sich nicht lesen — vermutlich ist er " +
                $"noch in einem anderen Programm geöffnet. Bitte schließen und erneut " +
                $"versuchen. ({exception.Message})");
        }
        catch (UnauthorizedAccessException exception)
        {
            throw new EmailVersandException(
                EmailVersandFehler.Anhang,
                $"Auf den Anhang \"{datei.Name}\" darf nicht zugegriffen werden. " +
                $"({exception.Message})");
        }
    }
}
