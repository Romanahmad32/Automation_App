using AutomationService.Core.Ablage;

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
/// genau das, was er zur Übergabe braucht. Wie lange die eigenen liegen bleiben,
/// entscheidet die <see cref="Aufbewahrungsregel"/> — nach Alter gestaffelt und
/// nicht nach Anzahl, seit der <c>SicherungsZeitgeber</c> halbstündlich sichert
/// (§7.2, #112).
/// </para>
///
/// <para>
/// <b>Es läuft immer nur ein Lauf.</b> Zeitgeber, Vorgangsabschluss und Beenden
/// stoßen dieselbe Sicherung an und können sich überlappen; die
/// <see cref="Schleuse"/> reiht sie hintereinander. Ohne sie schrieben zwei Läufe
/// im selben Moment in denselben Ordner und räumten sich gegenseitig auf.
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
    /// Reiht die Laeufe hintereinander. Statisch, weil sie den Ordner schuetzt
    /// und nicht die Instanz: Der Ablageordner ist derselbe, gleich welcher
    /// Aufrufer gerade sichert.
    /// </summary>
    static readonly SemaphoreSlim Schleuse = new(1, 1);

    /// <summary>Namensmuster der Archive: <c>automation-&lt;Rechner&gt;-&lt;Zeitstempel&gt;.zip</c>.</summary>
    public static string SuchmusterFuer(string rechnername) =>
        SicherungsDateiname.Suchmuster(rechnername);

    public async Task<LetzteSicherung?> SchreibeAsync(CancellationToken cancellationToken = default)
    {
        var ordner = Ablageordner();
        if (ordner is null || ordner.Length == 0)
        {
            return null;
        }

        string? gebaut = null;
        var eingetreten = false;
        try
        {
            // Vor dem ersten Handgriff anstellen: Wartet hier ein zweiter Lauf,
            // ist das kein Fehler, sondern der Normalfall beim Beenden waehrend
            // des Zeitgebers. Ein Abbruch beim Warten faellt in denselben catch.
            await Schleuse.WaitAsync(cancellationToken);
            eingetreten = true;

            gebaut = await sicherung.CreateBackupFileAsync(cancellationToken);
            var zeitpunkt = DateTime.Now;
            var dateiname = SicherungsDateiname.Baue(ArbeitsplatzAkte.DieserRechner, zeitpunkt);
            AtomareAblage.Ersetze(gebaut, Path.Combine(ordner, dateiname));
            gebaut = null;

            ArbeitsplatzAkte.MerkeSicherung(ordner, zeitpunkt, dateiname);
            SicherungsAufraeumung.RaeumeAuf(ordner, ArbeitsplatzAkte.DieserRechner, zeitpunkt);

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
            if (eingetreten)
            {
                Schleuse.Release();
            }

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
