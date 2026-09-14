using System.Globalization;
using System.Text.Json;
using AutomationService.Core.Ablage;
using AutomationService.Core.Persistence;

namespace AutomationService.Features.MailboxMonitor.Domain.Services;

/// <summary>
/// Der Ablageort für das, was der Anwalt aus dem Posteingang herausholt: ein
/// einzelner Anhang oder die ganze Nachricht als <c>.eml</c>.
///
/// <b>Warum unter dem vorhandenen Anhänge-Ordner.</b> Dort räumt der
/// bestehende Aufräumer (<c>AnhangAblage.AltesLoeschen</c>, 14 Tage, rekursiv
/// über die ganze Wurzel) ohne jede Änderung mit ab. Ein eigener Ordner
/// daneben wäre ein Ablageort, den niemand leert — und der Posteingang einer
/// Kanzlei hat Anhänge genug, um eine Platte zu füllen. Aufgerufen wird der
/// Aufräumer nicht von hier: Er liegt in der Versand-Slice, und die Schnitt-
/// regel verbietet den Verweis dorthin (<c>SliceIsolationTests</c>). Der
/// gemeinsame Nenner ist der Ordner, nicht der Code.
///
/// Je Nachricht ein eigener Unterordner: Zwei Mails dürfen denselben
/// „Rechnung.pdf" tragen, und der Anwalt soll beim Öffnen die aus <em>dieser</em>
/// Mail bekommen.
/// </summary>
public static class PosteingangZwischenlager
{
    /// <summary>
    /// Zusammen mehr als das gehört nicht in einen Ordner, den niemand
    /// aufräumt — dieselbe Zahl wie bei den Anhängen einer erfassten Antwort.
    /// </summary>
    public const long MaxOrdnerBytes = 50L * 1024 * 1024;

    /// <summary>
    /// <c>Anhaenge\Posteingang\&lt;Konto&gt;\&lt;Uid&gt;</c>. Der Kontoschlüssel
    /// ist der Hash aus <see cref="PosteingangKennung.KontoFuer"/>, auf 16
    /// Zeichen gekürzt: Er muss zwei Postfächer auseinanderhalten, nicht
    /// fälschungssicher sein, und ein 64-Zeichen-Ordner ist auf Windows ein
    /// Beitrag zur Pfadlängengrenze.
    /// </summary>
    public static string Ordner(string konto, uint uid)
    {
        var ordner = Path.Combine(
            AppDataPaths.EnsureAnhaengeDirectory(),
            "Posteingang",
            Kontoschluessel(konto),
            uid.ToString(CultureInfo.InvariantCulture));
        Directory.CreateDirectory(ordner);
        return ordner;
    }

    /// <summary>
    /// Ein Dateiname aus fremder Post ist nichts, was man dem Dateisystem
    /// vorlegt: Er kann Pfadtrenner, Doppelpunkte und Steuerzeichen tragen.
    /// </summary>
    public static string SichererName(string dateiname) => Entschaerft(Path.GetFileName(dateiname));

    /// <summary>
    /// Ersetzt, was im Dateisystem verboten ist — <b>ohne</b> einen Pfad in der
    /// Zeichenkette zu vermuten. Für einen selbst gebauten Namen ist das der
    /// richtige Weg: <c>Path.GetFileName</c> schnitte an einem Schrägstrich im
    /// Betreff alles davor ab, samt Datum und Absender.
    /// </summary>
    public static string Entschaerft(string wert)
    {
        var name = wert;
        foreach (var verboten in Path.GetInvalidFileNameChars())
        {
            name = name.Replace(verboten, '_');
        }

        // "." und ".." sind erlaubte Dateinamenzeichen und ueberleben die
        // Ersetzung oben unveraendert -- als tatsaechlicher Dateiname zeigen
        // sie aber auf den aktuellen bzw. den Elternordner, nicht auf eine
        // Datei. Ein Content-Disposition-Dateiname exakt "..": File.Create
        // wirft dann eine UnauthorizedAccessException auf den Elternordner,
        // statt eine Datei anzulegen.
        return string.IsNullOrWhiteSpace(name) || name is "." or ".." ? "Anhang" : name;
    }

    /// <summary>Zwei Anhänge derselben Mail dürfen gleich heißen — im Dateisystem nicht.</summary>
    public static string FreierPfad(string ordner, string dateiname)
    {
        var pfad = Path.Combine(ordner, dateiname);
        if (!File.Exists(pfad))
        {
            return pfad;
        }

        var stamm = Path.GetFileNameWithoutExtension(dateiname);
        var endung = Path.GetExtension(dateiname);
        for (var nummer = 2; ; nummer++)
        {
            pfad = Path.Combine(ordner, $"{stamm} ({nummer}){endung}");
            if (!File.Exists(pfad))
            {
                return pfad;
            }
        }
    }

    /// <summary>
    /// Der Name der Zuordnungsdatei je Nachrichtenordner (Schlüssel → tatsächlich
    /// vergebener Dateiname). Zählt nicht zur 50-MB-Grenze mit — sie ist
    /// Buchhaltung, kein Anhang.
    /// </summary>
    private const string ZuordnungsDatei = "zwischenlager-zuordnung.json";

    /// <summary>
    /// Liegt unter diesem Schlüssel (Anhang-Id oder ein fester Schlüssel für
    /// die ganze Nachricht als <c>.eml</c>) schon eine Datei, ist das ihr Pfad
    /// — sonst <c>null</c>.
    ///
    /// <b>Bewusst nicht über die Größe verglichen.</b> <c>Octets</c> ist laut
    /// RFC 3501 die Größe in Transferkodierung: Bei Base64 rund ein Drittel
    /// größer als die abgelegte, dekodierte Datei. Ein Größenvergleich träfe
    /// dann nie — jeder Klick hätte neu geladen und wegen
    /// <see cref="FreierPfad"/> „Name (2).pdf“ angelegt, bis die
    /// 50-MB-Grenze fälschlich griff. Stattdessen merkt sich <see cref="Merke"/>
    /// je Schlüssel den tatsächlich vergebenen Dateinamen.
    /// </summary>
    public static string? Vorhanden(string ordner, string schluessel)
    {
        if (!Zuordnung(ordner).TryGetValue(schluessel, out var dateiname))
        {
            return null;
        }

        var pfad = Path.Combine(ordner, dateiname);
        return File.Exists(pfad) ? pfad : null;
    }

    /// <summary>Merkt sich, unter welchem Dateinamen ein Schlüssel abgelegt wurde.</summary>
    public static void Merke(string ordner, string schluessel, string dateiname)
    {
        var zuordnung = Zuordnung(ordner);
        zuordnung[schluessel] = dateiname;
        var pfad = Path.Combine(ordner, ZuordnungsDatei);
        var temp = pfad + $".{Guid.NewGuid():N}.tmp";
        File.WriteAllText(temp, JsonSerializer.Serialize(zuordnung));
        AtomareAblage.Ersetze(temp, pfad);
    }

    private static Dictionary<string, string> Zuordnung(string ordner)
    {
        var pfad = Path.Combine(ordner, ZuordnungsDatei);
        if (!File.Exists(pfad))
        {
            return new Dictionary<string, string>(StringComparer.Ordinal);
        }

        return JsonSerializer.Deserialize<Dictionary<string, string>>(File.ReadAllText(pfad))
            ?? new Dictionary<string, string>(StringComparer.Ordinal);
    }

    /// <summary>Was in diesem Nachrichtenordner bereits liegt — ohne die Zuordnungsdatei selbst.</summary>
    public static long BelegteBytes(string ordner) =>
        Directory.Exists(ordner)
            ? new DirectoryInfo(ordner).EnumerateFiles()
                .Where(datei => datei.Name != ZuordnungsDatei)
                .Sum(datei => datei.Length)
            : 0;

    /// <summary>
    /// Schreibt zunächst in eine Temp-Datei und benennt erst am Ende an den
    /// Zielnamen um (<see cref="AtomareAblage"/>): Bricht der Abruf mittendrin
    /// ab, liegt unter dem Zielnamen nie ein angefangenes Fragment.
    /// </summary>
    public static async Task SchreibeAtomarAsync(Func<Stream, Task> schreiben, string ziel)
    {
        var temp = Path.GetTempFileName();
        try
        {
            await using (var strom = File.Create(temp))
            {
                await schreiben(strom);
            }

            AtomareAblage.Ersetze(temp, ziel);
        }
        catch
        {
            VersuchLoeschen(temp);
            throw;
        }
    }

    /// <summary>
    /// Übersetzt einen lokalen Schreibfehler (Platte voll, Pfad nicht
    /// beschreibbar) in die fachliche Ausnahme, die der Controller versteht —
    /// statt der 502-Meldung für einen nicht erreichbaren Server: Das Postfach
    /// wurde erreicht, nur das eigene Zwischenlager schreibt nicht.
    /// </summary>
    public static PosteingangException SchreibfehlerAlsFachlich(Exception ursache) =>
        new($"Anhang konnte nicht im Zwischenlager gespeichert werden: {ursache.Message}", 500);

    private static void VersuchLoeschen(string pfad)
    {
        try
        {
            if (File.Exists(pfad)) File.Delete(pfad);
        }
        catch (Exception ex) when (ex is IOException or UnauthorizedAccessException)
        {
            // Ein liegen gebliebener Temp-Rest ist kein Grund, den eigentlichen Fehler zu verdecken.
        }
    }

    private static string Kontoschluessel(string konto)
    {
        var sauber = new string([.. konto.Select(zeichen => char.IsLetterOrDigit(zeichen) ? zeichen : '_')]);
        if (sauber.Length == 0)
        {
            return "unbekannt";
        }

        return sauber.Length <= 16 ? sauber : sauber[..16];
    }
}
