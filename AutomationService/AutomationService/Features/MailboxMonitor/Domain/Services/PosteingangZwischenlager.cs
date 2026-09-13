using System.Globalization;
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

        return string.IsNullOrWhiteSpace(name) ? "Anhang" : name;
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
    /// Derselbe Name, dieselbe Größe: dann ist die Datei schon da und wird
    /// nicht noch einmal über die Leitung geholt. Der Anwalt klickt beim
    /// Durchsehen mehrfach auf denselben Anhang.
    /// </summary>
    public static string? Vorhanden(string ordner, string dateiname, long groesse)
    {
        var pfad = Path.Combine(ordner, dateiname);
        return File.Exists(pfad) && new FileInfo(pfad).Length == groesse ? pfad : null;
    }

    /// <summary>Was in diesem Nachrichtenordner bereits liegt.</summary>
    public static long BelegteBytes(string ordner) =>
        Directory.Exists(ordner)
            ? new DirectoryInfo(ordner).EnumerateFiles().Sum(datei => datei.Length)
            : 0;

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
