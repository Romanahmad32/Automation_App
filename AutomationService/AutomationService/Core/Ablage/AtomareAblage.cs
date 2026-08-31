using AutomationService.Features.WordAutomation.Domain.Exceptions;

namespace AutomationService.Core.Ablage;

/// <summary>
/// Legt eine fertig gebaute Datei so an ihren Zielort, dass ein Beobachter des
/// Zielordners sie nie halbfertig sieht.
///
/// Das ist der Kern der OneDrive-Anbindung (#40) — und der Grund, warum die App
/// trotzdem keine Zeile Cloud-Code braucht. Der Synchronisierungsdienst
/// reagiert auf Dateiänderungen, nicht auf „fertig geschrieben": Würde die
/// .docx direkt im synchronisierten Ordner aufgebaut, könnte er mitten im
/// Schreibvorgang zu übertragen beginnen, und auf dem Handy läge eine
/// beschädigte Datei. Deshalb wird woanders gebaut und am Ende <em>umbenannt</em>
/// — ein Rename ist auf demselben Laufwerk ein einziger, unteilbarer Schritt.
///
/// Liegt das Ziel auf einem anderen Laufwerk, wäre <c>File.Move</c> ein
/// Kopiervorgang und damit wieder teilbar. Dann wird zuerst neben das Ziel
/// kopiert und erst von dort umbenannt.
///
/// Lag zunächst im Vorgaenge-Slice, weil der Register-Spiegel der einzige Nutzer
/// war. Mit der automatischen Sicherung in den synchronisierten Ordner (#39) gibt
/// es einen zweiten — und für den wäre der Weg über einen fremden Slice eine
/// Kopplung ohne Grund. Deshalb steht sie jetzt hier: Sie weiß nichts von
/// Registern und nichts von Sicherungen, sie legt eine fertige Datei ab.
/// </summary>
public static class AtomareAblage
{
    /// <summary>
    /// Verschiebt <paramref name="quelle"/> nach <paramref name="ziel"/> und
    /// ersetzt eine dort liegende Datei. Die Quelle ist danach fort.
    /// </summary>
    /// <exception cref="ZieldateiGesperrtException">
    /// Die Zieldatei ist geöffnet — praktisch immer, weil das Register gerade in
    /// Word offen ist. Bewusst dieselbe Ausnahme wie beim Anspruchsschreiben:
    /// Der Fall ist derselbe und der Anwender liest denselben Satz.
    /// </exception>
    public static void Ersetze(string quelle, string ziel)
    {
        ArgumentException.ThrowIfNullOrWhiteSpace(quelle);
        ArgumentException.ThrowIfNullOrWhiteSpace(ziel);

        var zielOrdner = Path.GetDirectoryName(Path.GetFullPath(ziel));
        if (!string.IsNullOrEmpty(zielOrdner))
        {
            Directory.CreateDirectory(zielOrdner);
            AltlastenWegraeumen(zielOrdner, ziel);
        }

        // Das Schreibschutz-Flag setzt der Spiegel selbst (siehe
        // RegisterSpiegelService). Ohne dieses Zuruecknehmen scheitert das
        // Ersetzen an der eigenen Vorsichtsmassnahme.
        SchreibschutzLoesen(ziel);

        var quelleAufZielLaufwerk = GleichesLaufwerk(quelle, ziel)
            ? quelle
            : NebenDasZielKopieren(quelle, ziel);

        try
        {
            File.Move(quelleAufZielLaufwerk, ziel, overwrite: true);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            if (quelleAufZielLaufwerk != quelle) Loesche(quelleAufZielLaufwerk);
            Loesche(quelle);
            throw new ZieldateiGesperrtException(Path.GetFileName(ziel), ex);
        }
    }

    /// <summary>
    /// Nimmt einen gesetzten Schreibschutz zurück. Fehlt die Datei, ist nichts
    /// zu tun — sie wird gleich angelegt.
    /// </summary>
    public static void SchreibschutzLoesen(string pfad)
    {
        try
        {
            if (!File.Exists(pfad)) return;
            var attribute = File.GetAttributes(pfad);
            if (attribute.HasFlag(FileAttributes.ReadOnly))
                File.SetAttributes(pfad, attribute & ~FileAttributes.ReadOnly);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // Kein Grund abzubrechen: Gelingt das Ersetzen trotzdem, ist alles
            // gut; gelingt es nicht, meldet Ersetze den Fall mit der Ausnahme,
            // die der Anwender versteht.
        }
    }

    /// <summary>
    /// Setzt den Schreibschutz. Er schützt zuverlässig nur den Arbeitsplatz —
    /// ob ein Synchronisierungsdienst das Attribut auf andere Geräte weiterreicht,
    /// ist nicht zugesichert. Der Schutz, der überall ankommt, ist die
    /// Hinweiszeile im Dokument selbst.
    /// </summary>
    public static void SchreibschutzSetzen(string pfad)
    {
        try
        {
            if (File.Exists(pfad))
                File.SetAttributes(pfad, File.GetAttributes(pfad) | FileAttributes.ReadOnly);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // Der Spiegel liegt richtig; nur der Zusatzschutz fehlt.
        }
    }

    static bool GleichesLaufwerk(string a, string b) =>
        string.Equals(
            Path.GetPathRoot(Path.GetFullPath(a)),
            Path.GetPathRoot(Path.GetFullPath(b)),
            StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// Kopiert neben das Ziel, damit der letzte Schritt ein Umbenennen auf
    /// demselben Laufwerk bleibt. Der Name beginnt mit einer Tilde, damit die
    /// Zwischendatei im Ordner als das erkennbar ist, was sie ist.
    /// </summary>
    static string NebenDasZielKopieren(string quelle, string ziel)
    {
        var zwischenstand = Path.Combine(
            Path.GetDirectoryName(Path.GetFullPath(ziel))!,
            $"~{Path.GetFileNameWithoutExtension(ziel)}-{Guid.NewGuid():N}.tmp");
        File.Copy(quelle, zwischenstand, overwrite: true);
        Loesche(quelle);
        return zwischenstand;
    }

    /// <summary>
    /// Wirft Zwischenstände früherer Läufe weg, bevor ein neuer entsteht.
    ///
    /// Der Weg über eine Zwischendatei wird nur bei einem Laufwerkswechsel
    /// gegangen, und dann liegt sie im <em>synchronisierten</em> Zielordner.
    /// Stürzt der Dienst zwischen <c>File.Copy</c> und <c>File.Move</c> ab —
    /// oder wird er beendet, weil die App zugeht —, bleibt sie dort für immer:
    /// Der <c>Aufraeumen</c> des Bauordners kennt sie nicht, sie liegt ja
    /// woanders. Auf dem Handy erscheint sie als „~Sachgebiete-Register
    /// (App)-a3f9….tmp", eine je Absturz.
    ///
    /// Aufgeräumt wird deshalb vor <em>jedem</em> Ersetzen und nicht nur beim
    /// Laufwerkswechsel: Wer die Zwischendatei einmal erzeugt hat, hat sie im
    /// Zweifel mehrfach erzeugt, und der Zielordner ist derselbe.
    ///
    /// Angefasst wird nur, was unverkennbar von hier stammt: Tilde, derselbe
    /// Basisname, Endung <c>.tmp</c>. Was gerade in Arbeit ist, lässt sich nicht
    /// löschen (die Datei ist offen) — der Versuch scheitert still und der
    /// laufende Vorgang bleibt unberührt.
    /// </summary>
    static void AltlastenWegraeumen(string zielordner, string ziel)
    {
        try
        {
            var muster = $"~{Path.GetFileNameWithoutExtension(ziel)}-*.tmp";
            foreach (var altlast in Directory.EnumerateFiles(zielordner, muster))
            {
                Loesche(altlast);
            }
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // Aufräumen ist Kür. Der eigentliche Vorgang läuft weiter.
        }
    }

    static void Loesche(string pfad)
    {
        try
        {
            if (File.Exists(pfad)) File.Delete(pfad);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // Ein liegen gebliebener Zwischenstand ist ärgerlich, aber kein
            // Grund, den eigentlichen Fehler zu verdecken.
        }
    }
}
