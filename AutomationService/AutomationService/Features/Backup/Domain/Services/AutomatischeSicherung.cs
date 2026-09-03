using System.Globalization;
using AutomationService.Core.Ablage;
using AutomationService.Core.Persistence;

namespace AutomationService.Features.Backup.Domain.Services;

/// <summary>
/// Die automatische Sicherung in den synchronisierten Ordner (§7.2, #39).
///
/// <para>
/// Gebaut wird im Temp-Verzeichnis und erst zuletzt umbenannt
/// (<see cref="AtomareAblage"/>). Direkt im Ablageordner zu bauen hiesse, dem
/// Synchronisierungsdienst ein halbes Archiv zum Hochladen zu geben — und am
/// zweiten Rechner läge dann eine Sicherung, die keine ist.
/// </para>
///
/// <para>
/// Der Dateiname trägt den Rechnernamen. Damit gehört jede Sicherung sichtbar
/// einem Arbeitsplatz, und die Aufräumregel kann sich auf die <em>eigenen</em>
/// beschränken: Ein Rechner, der die Historie des anderen wegräumt, nähme ihm
/// genau das, was er zur Übergabe braucht.
/// </para>
///
/// <para>
/// <b>Wirft nie.</b> Die beiden Aufrufer sind Nebensachen an Stellen, an denen
/// die Hauptsache schon feststeht — ein abgeschlossener Vorgang darf an einer
/// misslungenen Sicherung nicht wieder aufgehen, und ein Herunterfahren nicht
/// daran hängenbleiben. Der Fehlschlag geht deshalb in die
/// <see cref="LetzteSicherungAkte"/> und von dort beim nächsten Start auf den
/// Bildschirm.
/// </para>
/// </summary>
/// <param name="sicherung">Baut das Archiv — dieselbe Sicherung wie auf Knopfdruck.</param>
/// <param name="merker">Nimmt das Ergebnis auf, damit der nächste Start es zeigen kann.</param>
/// <param name="ablageOrdner">
/// Liefert den eingestellten Ordner je Lauf neu — er ist ein Einstellungswert
/// und kann sich zur Laufzeit ändern (dasselbe Muster wie beim Vorlagenordner
/// im <see cref="DatabaseBackupService"/>).
/// </param>
/// <param name="logger">Hält den Fehlschlag mit Ursache im Protokoll fest.</param>
public sealed class AutomatischeSicherung(
    IDatabaseBackupService sicherung,
    LetzteSicherungAkte merker,
    Func<string> ablageOrdner,
    ILogger<AutomatischeSicherung> logger) : IAutomatischeSicherung
{
    /// <summary>
    /// So viele automatische Sicherungen bleiben <em>je Rechner</em> liegen.
    /// Dieselbe Groessenordnung wie bei den Sicherungen vor einer Migration
    /// (<c>DatabaseMigrationService.AufbewahrteSicherungen</c>); bei einer
    /// Sicherung je Sitzung deckt das gut eine Arbeitswoche ab.
    /// </summary>
    public const int AufbewahrteSicherungen = 10;

    /// <summary>Namensmuster der Archive: <c>automation-&lt;Rechner&gt;-&lt;Zeitstempel&gt;.zip</c>.</summary>
    public static string SuchmusterFuer(string rechnername) => $"automation-{rechnername}-*.zip";

    public async Task<LetzteSicherung?> SchreibeAsync(CancellationToken cancellationToken = default)
    {
        var ordner = Ablageordner();
        if (ordner is null || ordner.Length == 0)
        {
            return null;
        }

        string? gebaut = null;
        try
        {
            gebaut = await sicherung.CreateBackupFileAsync(cancellationToken);
            var zeitpunkt = DateTime.Now;
            var dateiname = Dateiname(zeitpunkt);
            AtomareAblage.Ersetze(gebaut, Path.Combine(ordner, dateiname));
            gebaut = null;

            ArbeitsplatzAkte.MerkeSicherung(ordner, zeitpunkt, dateiname);
            SqliteSicherung.RaeumeAelteSicherungenAuf(
                ordner, SuchmusterFuer(ArbeitsplatzAkte.DieserRechner), AufbewahrteSicherungen);

            merker.MerkeErfolg(zeitpunkt, dateiname);
            logger.LogInformation("Automatische Sicherung abgelegt: {Ordner}\\{Datei}", ordner, dateiname);
            return merker.Lies();
        }
        catch (OperationCanceledException)
        {
            return Gescheitert(
                "Die Sicherung wurde abgebrochen, bevor sie fertig war. "
                + "Der Stand dieser Sitzung liegt nicht im Ablageordner.");
        }
        catch (Exception ex)
        {
            // Bewusst alles: Der Lauf haengt an einem Ordner, den der Anwalt
            // gewaehlt hat und der offline, umbenannt oder voll sein kann. Was
            // hier durchkaeme, brechte die App beim Herunterfahren zu Fall —
            // und der Anwalt saehe kein Wort davon.
            logger.LogError(ex, "Automatische Sicherung nach {Ordner} fehlgeschlagen.", ordner);
            return Gescheitert($"{ex.Message} (Ablageordner: {ordner})");
        }
        finally
        {
            if (gebaut is not null)
            {
                TryDelete(gebaut);
            }
        }
    }

    public void MerkeArbeitsbeginn()
    {
        var ordner = Ablageordner();
        if (ordner is null || ordner.Length == 0)
        {
            return;
        }

        try
        {
            ArbeitsplatzAkte.MerkeArbeitsbeginn(ordner);
        }
        catch (Exception ex)
        {
            // Der Eintrag ist eine Auskunft, kein Betriebsmittel. Ein Ordner,
            // der beim Start nicht erreichbar ist, darf den Start nicht kosten
            // — auffallen wird es spaetestens, wenn die Sicherung scheitert.
            logger.LogWarning(ex, "Arbeitsplatz-Eintrag in {Ordner} nicht geschrieben.", ordner);
        }
    }

    /// <summary>
    /// Der eingestellte Ordner, oder <c>null</c>, wenn er sich nicht lesen ließ.
    ///
    /// Das Lesen geht über einen Scope in den Dienstcontainer, und dieser Lauf
    /// hängt am Herunterfahren — der Container kann darunter schon weg sein.
    /// Ein Fehlschlag <em>hier</em> wird deshalb nicht als misslungene Sicherung
    /// gemerkt: Wer die Einstellung nicht lesen kann, weiß nicht einmal, ob
    /// überhaupt gesichert werden sollte, und eine Meldung darüber wäre beim
    /// nächsten Start schlicht falsch.
    /// </summary>
    string? Ablageordner()
    {
        try
        {
            return ablageOrdner();
        }
        catch (Exception ex)
        {
            logger.LogWarning(ex, "Die Sicherungsablage konnte nicht gelesen werden.");
            return null;
        }
    }

    LetzteSicherung Gescheitert(string meldung)
    {
        var zeitpunkt = DateTime.Now;
        merker.MerkeFehler(zeitpunkt, meldung);
        return new LetzteSicherung(zeitpunkt, false, null, meldung, FehlerQuittiert: false);
    }

    static string Dateiname(DateTime zeitpunkt) =>
        $"automation-{ArbeitsplatzAkte.DieserRechner}-"
        + zeitpunkt.ToString("yyyyMMdd-HHmmss", CultureInfo.InvariantCulture)
        + ".zip";

    static void TryDelete(string pfad)
    {
        try
        {
            if (File.Exists(pfad))
            {
                File.Delete(pfad);
            }
        }
        catch (IOException)
        {
            // Zwischenstand im Temp-Verzeichnis: Windows raeumt ihn ohnehin ab.
        }
    }
}
